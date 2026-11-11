import CGMBLEKit
import Foundation
import LoopKit
import LoopKitUI
import ShareClient
import UIKit

/// Recovers Dexcom G5/G6 readings that Bluetooth missed, from Dexcom Share.
///
/// The G5/G6 plugin keeps the user's Dexcom Share login and fetches from Share whenever its last
/// Bluetooth reading is more than 4.5 minutes old. This class does two things with that:
///
/// 1. **Stores what the plugin fetched.** `PluginSource` used to discard these readings.
/// 2. **Asks Share right after a missed reading.** When a Bluetooth connection ends without a
///    reading, it asks Share 5, 12 and 20 seconds later, instead of waiting 5 minutes for the
///    next connection. The Dexcom app on the same phone usually has the reading on Share within
///    15 seconds. Controlled by `DexcomG6Options.checkShareAfterMiss`.
///
/// Readings are stored through `FetchGlucoseManager.newGlucoseFromCgmManager`, the same path
/// Bluetooth readings take, so the usual protections apply: a reading only counts as new if it is
/// more than 3.5 minutes after the last stored one, and loops never start within 3 minutes of each
/// other. On top of that, Share readings dated more than a minute in the future are ignored, and
/// if the next Bluetooth reading is under 3.5 minutes away, Share readings are stored as history
/// only, so they never cause an extra loop.
///
/// Every step is written to the CGM log (tagged `[G6DIAG]`), so log exports show what happened.
///
/// Runs on the `PluginSource` process queue.
final class DexcomShareFallback {
    /// How long to hold readings from the regular fetch before storing them, so a Bluetooth
    /// reading from the same connection is stored first.
    private static let storeDelay: TimeInterval = 3

    /// G5/G6 readings arrive every 5 minutes.
    private static let readingInterval: TimeInterval = 5 * 60

    /// When to ask Share after a connection ends without a reading, in seconds. Kept well inside
    /// the 30 seconds or so of background time iOS allows.
    private static let retryDelays: [TimeInterval] = [5, 12, 20]

    /// A retry that runs this much later than scheduled means iOS suspended the app in between.
    private static let retryLateTolerance: TimeInterval = 10

    /// Share readings dated further ahead of the phone's clock than this are ignored. A reading
    /// from the future would make Trio reject real readings until the clock caught up.
    private static let futureTolerance: TimeInterval = 60

    /// How long to keep background time after storing a recovered reading, so glucose storage and
    /// the loop can take over theirs.
    private static let holdAfterStore: TimeInterval = 5

    private weak var source: PluginSource?
    private let processQueue: DispatchQueue
    private let glucoseStorage: GlucoseStorage
    private let deviceLogStore: DeviceLogStore

    // Only touched on `processQueue`
    private var retryRunning = false
    /// The reading the last retry looked for, so a burst of empty connections in one 5-minute
    /// cycle asks Share once, not once per connection.
    private var lastRetriedReading: Date?
    private var connectionObserver: NSObjectProtocol?

    init(source: PluginSource, processQueue: DispatchQueue, glucoseStorage: GlucoseStorage, deviceLogStore: DeviceLogStore) {
        self.source = source
        self.processQueue = processQueue
        self.glucoseStorage = glucoseStorage
        self.deviceLogStore = deviceLogStore

        connectionObserver = Foundation.NotificationCenter.default.addObserver(
            forName: Transmitter.connectionDidEndNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            let session = notification.userInfo?[Transmitter.connectionDidEndSessionKey] as? String ?? "S?"
            let receivedGlucose = notification.userInfo?[Transmitter.connectionDidEndReceivedGlucoseKey] as? Bool ?? true
            guard let self = self else { return }
            self.processQueue.async {
                self.connectionDidEnd(session: session, receivedGlucose: receivedGlucose)
            }
        }
    }

    deinit {
        if let observer = connectionObserver {
            Foundation.NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Readings the plugin fetched

    /// Stores Share readings returned by the plugin's regular `fetchNewDataIfNeeded`. Ignores
    /// results from any CGM other than G5/G6.
    func storeFetchResult(_ result: CGMReadingResult, from manager: CGMManagerUI) {
        guard manager is G6CGMManager || manager is G5CGMManager else { return }

        processQueue.async { [weak self] in
            guard let self = self else { return }

            switch result {
            case let .newData(samples):
                guard let newest = samples.map(\.date).max(), let oldest = samples.map(\.date).min() else { return }
                self.log("share fetch returned \(samples.count) readings \(oldest) to \(newest); storing in \(Int(Self.storeDelay)) s")

                let taskName = "Store Dexcom Share readings"
                let backgroundTaskID = startBackgroundTask(withName: taskName)

                self.processQueue.asyncAfter(deadline: .now() + Self.storeDelay) { [weak self] in
                    var taskID = backgroundTaskID
                    defer { endBackgroundTaskSafely(&taskID, taskName: taskName) }

                    guard let self = self else { return }
                    self.store(result)
                }

            case let .error(error):
                self.log("share fetch failed: \(error.localizedDescription)")

            case .noData,
                 .unreliableData:
                break
            }
        }
    }

    /// True when `manager` is the Dexcom Share client inside the G5/G6 plugin (not Share selected
    /// as the CGM itself).
    static func isShareInsideG5G6(_ manager: CGMManager, cgmManager: CGMManagerUI?) -> Bool {
        manager.pluginIdentifier == "DexShareClient" && (cgmManager is G6CGMManager || cgmManager is G5CGMManager)
    }

    /// The oldest reading time to accept from Share. Share returns the last 30 minutes; letting
    /// all of them through means readings Bluetooth missed are still backfilled after a newer
    /// Bluetooth reading arrived. Storage drops duplicates.
    static func earliestShareReadingToAccept(lastGlucoseDate: Date) -> Date {
        min(lastGlucoseDate, Date().addingTimeInterval(-31 * 60))
    }

    /// Stores Share readings. Newer readings count as new (and trigger a loop) unless the next
    /// Bluetooth reading is close; older ones are backfill.
    ///
    /// Must run on `processQueue`.
    private func store(_ result: CGMReadingResult) {
        dispatchPrecondition(condition: .onQueue(processQueue))

        guard let source = source else { return }

        let fetched: [BloodGlucose]
        switch source.readCGMResult(readingResult: result) {
        case let .success(values):
            fetched = values
        case let .failure(error):
            log("share readings not usable: \(error.localizedDescription)")
            return
        }

        let latestAllowed = Date().addingTimeInterval(Self.futureTolerance)
        let futureCount = fetched.filter { $0.dateString > latestAllowed }.count
        if futureCount > 0 {
            log("share ignoring \(futureCount) readings dated more than \(Int(Self.futureTolerance)) s in the future")
        }
        let glucose = fetched.filter { $0.dateString <= latestAllowed }

        guard glucose.isNotEmpty else { return }

        let lastStored = glucoseStorage.syncDate()
        let newerCount = glucose.filter { $0.dateString > lastStored }.count

        // A loop now would make the next Bluetooth reading's loop be skipped as too soon. The 30 s
        // of slack covers the pump update that runs before a triggered loop starts.
        if newerCount > 0, let nextBluetoothReading = expectedNextBluetoothReading(),
           nextBluetoothReading.timeIntervalSinceNow < Config.loopInterval + 30
        {
            log("share storing \(glucose.count) readings as history only (\(newerCount) newer than last stored \(lastStored)); next Bluetooth reading due \(nextBluetoothReading)")
            Task {
                do {
                    try await self.glucoseStorage.backfillGlucose(glucose)
                } catch {
                    warning(.cgm, "Storing Dexcom Share history failed", error: error)
                }
            }
            return
        }

        log("share storing \(glucose.count) readings (\(newerCount) newer than last stored \(lastStored), rest backfill or duplicate)")
        source.glucoseManager?.newGlucoseFromCgmManager(newGlucose: glucose)
    }

    /// When the next Bluetooth reading should arrive: 5-minute steps from the last one, plus
    /// 10 seconds for the connection (readings arrive 6 to 12 seconds after their timestamp).
    /// Nil if there's no Bluetooth reading yet.
    private func expectedNextBluetoothReading() -> Date? {
        guard let last = lastBluetoothReading() else { return nil }

        let elapsed = max(0, Date().timeIntervalSince(last))
        let intervalsElapsed = (elapsed / Self.readingInterval).rounded(.down) + 1
        return last.addingTimeInterval(intervalsElapsed * Self.readingInterval + 10)
    }

    private func lastBluetoothReading() -> Date? {
        (source?.cgmManager as? TransmitterManager)?.latestReading?.readDate
    }

    // MARK: - Asking Share right after a missed reading

    /// Called when a G5/G6 Bluetooth connection ends. Starts a retry if the connection should have
    /// delivered a reading and didn't.
    ///
    /// Must run on `processQueue`.
    private func connectionDidEnd(session: String, receivedGlucose: Bool) {
        dispatchPrecondition(condition: .onQueue(processQueue))

        guard !receivedGlucose, !retryRunning, DexcomG6Options.checkShareAfterMiss,
              let manager = source?.cgmManager as? TransmitterManager
        else { return }

        // The short follow-up connection after a good reading is not a miss
        let lastReading = manager.latestReading?.readDate
        if let lastReading = lastReading, Date().timeIntervalSince(lastReading) < 270 {
            return
        }

        // Once per missed reading: the reading that should have arrived in this 5-minute cycle
        let missedReading = lastReading.map { last -> Date in
            let cycles = max(1, Int((Date().timeIntervalSince(last) + 30) / Self.readingInterval))
            return last.addingTimeInterval(Double(cycles) * Self.readingInterval)
        }
        if let missedReading = missedReading, missedReading == lastRetriedReading {
            return
        }
        lastRetriedReading = missedReading

        retryRunning = true
        let endedAt = Date()
        let lastReadingText = lastReading.map { "\($0)" } ?? "none"
        log("share retry \(session): session ended without a reading; last Bluetooth reading \(lastReadingText)")

        let backgroundTask = SelfEndingBackgroundTask(name: "Check Dexcom Share after a missed reading") { [weak self] in
            self?.processQueue.async {
                self?.log("share retry \(session): iOS background time expired")
            }
        }
        logAppState(prefix: "share retry \(session) start")

        retry(attempt: 0, manager: manager, session: session, endedAt: endedAt, lastReading: lastReading) { [weak self] in
            backgroundTask.end()
            self?.retryRunning = false
        }
    }

    /// One attempt, then the next, until Share has the reading or the attempts run out.
    ///
    /// Must run on `processQueue`. `done` is called on `processQueue`.
    private func retry(
        attempt: Int,
        manager: TransmitterManager,
        session: String,
        endedAt: Date,
        lastReading: Date?,
        done: @escaping () -> Void
    ) {
        dispatchPrecondition(condition: .onQueue(processQueue))

        guard attempt < Self.retryDelays.count else {
            let lastDelay = Int(Self.retryDelays.last ?? 0)
            log("share retry \(session): Share did not have a newer reading by +\(lastDelay) s")
            done()
            return
        }

        let delay = Self.retryDelays[attempt]
        let prefix = "share retry \(session) +\(Int(delay)) s"
        let scheduledAt = endedAt.addingTimeInterval(delay)

        processQueue.asyncAfter(deadline: .now() + max(0, scheduledAt.timeIntervalSinceNow)) { [weak self] in
            guard let self = self else {
                done()
                return
            }

            let lateBy = Date().timeIntervalSince(scheduledAt)
            if lateBy > Self.retryLateTolerance {
                self.log("\(prefix): ran \(Int(lateBy)) s late (Trio was suspended); stopping")
                done()
                return
            }

            // The regular Share fetch at connection time often stores the reading first
            let lastStored = self.glucoseStorage.syncDate()
            if let lastReading = lastReading, lastStored > lastReading.addingTimeInterval(60) {
                self.log("\(prefix): missed reading already stored (\(lastStored)); stopping")
                done()
                return
            }

            self.logAppState(prefix: prefix)
            let askedAt = Date()

            manager.shareManager.fetchNewDataIfNeeded { [weak self] result in
                guard let self = self else {
                    done()
                    return
                }

                self.processQueue.async {
                    let found = self.logRetryAnswer(result, prefix: prefix, askedAt: askedAt, endedAt: endedAt, lastReading: lastReading)

                    if found {
                        self.store(result)
                        self.processQueue.asyncAfter(deadline: .now() + Self.holdAfterStore) {
                            done()
                        }
                    } else {
                        self.retry(
                            attempt: attempt + 1,
                            manager: manager,
                            session: session,
                            endedAt: endedAt,
                            lastReading: lastReading,
                            done: done
                        )
                    }
                }
            }
        }
    }

    /// Logs Share's answer to one attempt. Returns true when Share has a reading newer than the
    /// last Bluetooth reading.
    private func logRetryAnswer(
        _ result: CGMReadingResult,
        prefix: String,
        askedAt: Date,
        endedAt: Date,
        lastReading: Date?
    ) -> Bool {
        let roundTrip = String(format: "%.1f", Date().timeIntervalSince(askedAt))

        switch result {
        case let .newData(samples):
            let latestAllowed = Date().addingTimeInterval(Self.futureTolerance)
            guard let newest = samples.map(\.date).filter({ $0 <= latestAllowed }).max() else {
                log("\(prefix): Share returned no readings (\(roundTrip) s)")
                return false
            }
            if let lastReading = lastReading, newest <= lastReading.addingTimeInterval(60) {
                log("\(prefix): Share newest is \(newest), no newer than the last Bluetooth reading (\(roundTrip) s)")
                return false
            }
            let afterReading = Int(Date().timeIntervalSince(newest))
            let afterSessionEnd = Int(Date().timeIntervalSince(endedAt))
            log("\(prefix): Share HAS the missed reading \(newest), \(afterReading) s after its timestamp, \(afterSessionEnd) s after the session ended (\(roundTrip) s); storing it")
            return true

        case let .error(error):
            log("\(prefix): Share fetch failed (\(roundTrip) s): \(error.localizedDescription)")
            return false

        case .noData:
            log("\(prefix): Share returned nothing new (\(roundTrip) s)")
            return false

        case .unreliableData:
            log("\(prefix): Share returned unreliable data (\(roundTrip) s)")
            return false
        }
    }

    // MARK: - Logging

    /// Logs app state, lock state and remaining background time. UIKit, so read on the main queue.
    private func logAppState(prefix: String) {
        DispatchQueue.main.async { [weak self] in
            let app = UIApplication.shared
            let state: String
            switch app.applicationState {
            case .active: state = "active"
            case .inactive: state = "inactive"
            case .background: state = "background"
            @unknown default: state = "unknown"
            }
            let remaining = app.backgroundTimeRemaining
            let remainingText = remaining > 1_000_000 ? "unlimited" : String(format: "%.0f s", remaining)
            let lockText = app.isProtectedDataAvailable ? "unlocked" : "locked"
            self?.processQueue.async {
                self?.log("\(prefix): app \(state), phone \(lockText), background time left \(remainingText)")
            }
        }
    }

    /// Writes a line to the CGM's device log, so it appears in the CGM log export.
    private func log(_ message: String) {
        guard let pluginIdentifier = source?.cgmManager?.pluginIdentifier else { return }
        deviceLogStore.log(
            managerIdentifier: pluginIdentifier,
            deviceIdentifier: nil,
            type: .delegate,
            message: "[G6DIAG] " + message
        )
    }
}

/// Background time that ends itself when iOS reclaims it. Trio's `startBackgroundTask` helper
/// doesn't end the task on expiry, and an app that holds expired background time can be
/// terminated.
private final class SelfEndingBackgroundTask {
    private let lock = NSLock()
    private var taskID: UIBackgroundTaskIdentifier = .invalid

    init(name: String, onExpire: @escaping () -> Void) {
        let newID = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            onExpire()
            self?.end()
        }
        lock.lock()
        taskID = newID
        lock.unlock()
    }

    func end() {
        lock.lock()
        let id = taskID
        taskID = .invalid
        lock.unlock()

        if id != .invalid {
            UIApplication.shared.endBackgroundTask(id)
        }
    }
}
