import AccuChekKit
import CGMBLEKit
import Combine
import EversenseKit
import Foundation
import G7SensorKit
import LibreLoop
import LibreTransmitter
import LoopKit
import LoopKitUI
import ShareClient
import SyaiKit
import UIKit

final class PluginSource: GlucoseSource {
    /// How long to hold Dexcom Share readings before storing them, so a Bluetooth reading from
    /// the connection that triggered the fetch is stored first (the longest connect-to-disconnect
    /// in the logs that motivated this was 1.55 s).
    private static let shareFallbackDelay: TimeInterval = 3

    /// G5/G6 readings arrive every 5 minutes.
    private static let dexcomReadingInterval: TimeInterval = 5 * 60

    private let processQueue = DispatchQueue(label: "CGMPluginSource.processQueue")
    private let glucoseStorage: GlucoseStorage!
    private let deviceLogStore: DeviceLogStore
    var glucoseManager: FetchGlucoseManager?

    let cgmDisplayState = CurrentValueSubject<CgmDisplayState?, Never>(nil)
    let cgmProgressHighlight = CurrentValueSubject<DeviceLifecycleProgress?, Never>(nil)

    var cgmManager: CGMManagerUI? {
        didSet {
            publishCGMStatus()
            Self.applyG6FixSettings(to: cgmManager)
        }
    }

    /// UserDefaults keys for the G5/G6 switches in CGM settings ("G6 Diagnostics"). All default
    /// on, and true always means the fix or diagnostic is active.
    static let skipRedundantReconnectKey = "G6FixSkipRedundantReconnect"
    static let keepMessagesDuringSetupKey = "G6FixKeepMessagesDuringSubscriptionSetup"
    static let shareRetryAfterMissKey = "G6FixShareRetryAfterMiss"

    /// A stored switch. On if it was never set.
    static func isG6FixEnabled(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }

    /// Applies the CGM settings switches to a G5/G6 transmitter. Requires the CGMBLEKit patch in
    /// `patches/`.
    static func applyG6FixSettings(to manager: CGMManagerUI?) {
        guard let transmitter = (manager as? TransmitterManager)?.transmitter else { return }

        transmitter.skipRedundantReconnect = isG6FixEnabled(skipRedundantReconnectKey)
        transmitter.keepMessagesDuringSubscriptionSetup = isG6FixEnabled(keepMessagesDuringSetupKey)
    }

    /// Must match `G6SessionDiagnostics.sessionDidEndNotification` in the CGMBLEKit patch.
    private static let g6SessionDidEndNotification = Notification.Name("com.loopkit.CGMBLEKit.G6SessionDidEnd")

    /// When the Share retry asks Dexcom Share, in seconds after a session ended without a reading.
    /// Kept well inside the ~30 s of background time iOS usually allows.
    private static let shareRetryDelays: [TimeInterval] = [5, 12, 20]

    /// An attempt that runs this much later than scheduled means iOS suspended Trio in between.
    private static let shareRetryLateTolerance: TimeInterval = 10

    /// How long the Share retry keeps its background time after storing a reading, so there is no
    /// gap before glucose storage and the loop take their own.
    private static let shareRetryHoldAfterStore: TimeInterval = 5

    /// Only touched on `processQueue`.
    private var shareRetryRunning = false
    private var g6SessionObserver: NSObjectProtocol?

    var cgmHasValidSensorSession: Bool = false

    init(glucoseStorage: GlucoseStorage, glucoseManager: FetchGlucoseManager, deviceLogStore: DeviceLogStore) {
        self.glucoseStorage = glucoseStorage
        self.deviceLogStore = deviceLogStore
        self.glucoseManager = glucoseManager

        cgmManager = glucoseManager.cgmManager
        cgmManager?.delegateQueue = processQueue
        cgmManager?.cgmManagerDelegate = self
        // didSet doesn't fire from the defining class's own init.
        publishCGMStatus()
        Self.applyG6FixSettings(to: cgmManager)

        g6SessionObserver = NotificationCenter.default.addObserver(
            forName: Self.g6SessionDidEndNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            let session = notification.userInfo?["session"] as? String ?? "S?"
            let glucoseSeen = notification.userInfo?["glucoseSeen"] as? Bool ?? true
            guard let self = self else { return }
            self.processQueue.async {
                self.g6SessionDidEnd(session: session, glucoseSeen: glucoseSeen)
            }
        }
    }

    /// Republishes the manager's lifecycle/highlight to the subjects.
    /// Called from `cgmManager.didSet` and after delegate state updates.
    func publishCGMStatus() {
        if let highlight = cgmManager?.cgmStatusHighlight {
            cgmDisplayState.value = CgmDisplayState(
                localizedMessage: highlight.localizedMessage,
                imageName: highlight.imageName,
                status: CgmDisplayStatus.from(highlight.state)
            )
        } else {
            cgmDisplayState.value = nil
        }
        cgmProgressHighlight.value = cgmManager?.cgmLifecycleProgress
    }

    /// Function that fetches blood glucose data
    /// This function combines two data fetching mechanisms (`callBLEFetch` and `fetchIfNeeded`) into a single publisher.
    /// It returns the first non-empty result from either of the sources within a 5-minute timeout period.
    /// If no valid data is fetched within the timeout, it returns an empty array.
    ///
    /// - Parameter timer: An optional `DispatchTimer` (not used in the function but can be used to trigger fetch logic).
    /// - Returns: An `AnyPublisher` that emits an array of `BloodGlucose` values or an empty array if an error occurs or the timeout is reached.
    func fetch(_: DispatchTimer?) -> AnyPublisher<[BloodGlucose], Never> {
        fetchIfNeeded()
            .filter { !$0.isEmpty }
            .first()
            .timeout(60 * 5, scheduler: processQueue, options: nil, customError: nil)
            .replaceError(with: [])
            .eraseToAnyPublisher()
    }

    func fetchIfNeeded() -> AnyPublisher<[BloodGlucose], Never> {
        Future<[BloodGlucose], Error> { [weak self] promise in
            guard let self = self else { return }
            self.processQueue.async {
                guard let cgmManager = self.cgmManager else { return }
                cgmManager.fetchNewDataIfNeeded { [weak self] result in
                    // The timer's publisher still completes with no values, so it can never
                    // race a Bluetooth reading. G5/G6 Dexcom Share readings returned here are
                    // stored separately through newGlucoseFromCgmManager, the same path
                    // Bluetooth readings use.
                    promise(.success([]))
                    self?.handleShareFallbackResult(result, from: cgmManager)
                }
            }
        }
        .replaceError(with: [])
        .replaceEmpty(with: [])
        .eraseToAnyPublisher()
    }

    deinit {
        // dexcomManager.transmitter.stopScanning()
        if let observer = g6SessionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Dexcom Share fallback (G5/G6)

    /// G5/G6 return Dexcom Share readings only through the `fetchNewDataIfNeeded` completion, and
    /// only when the last Bluetooth reading is more than 4.5 minutes old. Store them instead of
    /// discarding them.
    ///
    /// After `shareFallbackDelay`, storage decides what each reading is: at or before the last
    /// stored CGM reading it is backfill (deduplicated within 3.5 minutes, never triggers a loop);
    /// newer, it is a reading Bluetooth missed and triggers the loop as usual. One exception: if
    /// the next Bluetooth reading is due within the minimum loop interval, a loop now would make
    /// that fresh reading's loop be skipped as too soon, so the readings are stored as history only.
    private func handleShareFallbackResult(_ result: CGMReadingResult, from manager: CGMManagerUI) {
        guard manager is G6CGMManager || manager is G5CGMManager else { return }

        processQueue.async { [weak self] in
            guard let self = self else { return }

            switch result {
            case let .newData(samples):
                guard let newest = samples.map(\.date).max(), let oldest = samples.map(\.date).min() else { return }
                self.logCGMDiagnostic(
                    "share fetch returned \(samples.count) readings \(oldest) to \(newest); storing in \(Int(Self.shareFallbackDelay)) s"
                )

                let taskName = "Store Dexcom Share fallback readings"
                let backgroundTaskID = startBackgroundTask(withName: taskName)

                self.processQueue.asyncAfter(deadline: .now() + Self.shareFallbackDelay) { [weak self] in
                    var taskID = backgroundTaskID
                    defer { endBackgroundTaskSafely(&taskID, taskName: taskName) }

                    guard let self = self else { return }
                    self.storeShareFallbackReadings(result)
                }

            case let .error(error):
                self.logCGMDiagnostic("share fetch failed: \(error.localizedDescription)")

            case .noData,
                 .unreliableData:
                break
            }
        }
    }

    /// Must run on `processQueue`.
    private func storeShareFallbackReadings(_ result: CGMReadingResult) {
        dispatchPrecondition(condition: .onQueue(processQueue))

        let glucose: [BloodGlucose]
        switch readCGMResult(readingResult: result) {
        case let .success(values):
            glucose = values
        case let .failure(error):
            logCGMDiagnostic("share readings not usable: \(error.localizedDescription)")
            return
        }

        guard glucose.isNotEmpty else { return }

        let lastStored = glucoseStorage.syncDate()
        let newerCount = glucose.filter { $0.dateString > lastStored }.count

        // 30 s of slack covers the pump update that runs before a triggered loop starts
        if newerCount > 0, let nextBluetoothReading = expectedNextBluetoothReading(),
           nextBluetoothReading.timeIntervalSinceNow < Config.loopInterval + 30
        {
            logCGMDiagnostic(
                "share storing \(glucose.count) readings as history only (\(newerCount) newer than last stored \(lastStored)); next Bluetooth reading due \(nextBluetoothReading)"
            )
            Task {
                do {
                    try await self.glucoseStorage.backfillGlucose(glucose)
                } catch {
                    warning(.cgm, "Storing Dexcom Share history failed", error: error)
                }
            }
            return
        }

        logCGMDiagnostic(
            "share storing \(glucose.count) readings (\(newerCount) newer than last stored \(lastStored), rest backfill or duplicate)"
        )
        glucoseManager?.newGlucoseFromCgmManager(newGlucose: glucose)
    }

    /// When the next G5/G6 Bluetooth reading should arrive, from the last one received over
    /// Bluetooth, allowing 10 seconds for the connection (logs show 6-12 s after the reading's
    /// timestamp). Nil if there is no Bluetooth reading yet.
    private func expectedNextBluetoothReading() -> Date? {
        let lastBluetoothReading: Date?
        if let manager = cgmManager as? G6CGMManager {
            lastBluetoothReading = manager.latestReading?.readDate
        } else if let manager = cgmManager as? G5CGMManager {
            lastBluetoothReading = manager.latestReading?.readDate
        } else {
            lastBluetoothReading = nil
        }

        guard let last = lastBluetoothReading else { return nil }

        let elapsed = max(0, Date().timeIntervalSince(last))
        let intervalsElapsed = (elapsed / Self.dexcomReadingInterval).rounded(.down) + 1
        return last.addingTimeInterval(intervalsElapsed * Self.dexcomReadingInterval + 10)
    }

    // MARK: - Share retry after a missed reading (G5/G6)

    /// When a G5/G6 Bluetooth session ends without a reading, asks Dexcom Share at +5, +12 and
    /// +20 s, stopping at the first answer that has the missed reading, and stores it through the
    /// regular Share fallback path (same date filter, too-frequent filter and history-only rule
    /// when the next Bluetooth reading is close). Storing a newer reading runs the loop, about
    /// 4.5 minutes sooner than waiting for the next connection. Every step is logged: Share's
    /// answer and timing, app and lock state, and background time left.
    ///
    /// Must run on `processQueue`.
    private func g6SessionDidEnd(session: String, glucoseSeen: Bool) {
        dispatchPrecondition(condition: .onQueue(processQueue))

        guard !glucoseSeen, !shareRetryRunning, Self.isG6FixEnabled(Self.shareRetryAfterMissKey),
              let manager = cgmManager as? TransmitterManager
        else { return }

        // The short follow-up connection after a good reading is not a miss
        let lastReading = manager.latestReading?.readDate
        if let lastReading = lastReading, Date().timeIntervalSince(lastReading) < 270 {
            return
        }

        shareRetryRunning = true
        let endedAt = Date()
        let lastReadingText = lastReading.map { "\($0)" } ?? "none"
        logCGMDiagnostic("share retry \(session): session ended without a reading; last Bluetooth reading \(lastReadingText)")

        let backgroundTask = ShareRetryBackgroundTask(name: "G6 Share retry after miss") { [weak self] in
            self?.processQueue.async {
                self?.logCGMDiagnostic("share retry \(session): iOS background time expired")
            }
        }
        logAppState(prefix: "share retry \(session) start")

        runShareRetry(attempt: 0, manager: manager, session: session, endedAt: endedAt, lastReading: lastReading) { [weak self] in
            backgroundTask.end()
            self?.shareRetryRunning = false
        }
    }

    /// Must run on `processQueue`. `done` is called on `processQueue`.
    private func runShareRetry(
        attempt: Int,
        manager: TransmitterManager,
        session: String,
        endedAt: Date,
        lastReading: Date?,
        done: @escaping () -> Void
    ) {
        dispatchPrecondition(condition: .onQueue(processQueue))

        guard attempt < Self.shareRetryDelays.count else {
            let lastDelay = Int(Self.shareRetryDelays.last ?? 0)
            logCGMDiagnostic("share retry \(session): Share did not have a newer reading by +\(lastDelay) s")
            done()
            return
        }

        let delay = Self.shareRetryDelays[attempt]
        let scheduledAt = endedAt.addingTimeInterval(delay)
        processQueue.asyncAfter(deadline: .now() + max(0, scheduledAt.timeIntervalSinceNow)) { [weak self] in
            guard let self = self else {
                done()
                return
            }

            let lateBy = Date().timeIntervalSince(scheduledAt)
            if lateBy > Self.shareRetryLateTolerance {
                self.logCGMDiagnostic("share retry \(session) +\(Int(delay)) s: ran \(Int(lateBy)) s late (Trio was suspended); stopping")
                done()
                return
            }

            self.logAppState(prefix: "share retry \(session) +\(Int(delay)) s")
            let askedAt = Date()
            manager.shareManager.fetchNewDataIfNeeded { [weak self] result in
                guard let self = self else {
                    done()
                    return
                }
                self.processQueue.async {
                    let found = self.logShareRetryResult(
                        result,
                        prefix: "share retry \(session) +\(Int(delay)) s",
                        askedAt: askedAt,
                        endedAt: endedAt,
                        lastReading: lastReading
                    )
                    if found {
                        // Same storage path and guards as the regular Share fallback
                        self.storeShareFallbackReadings(result)
                        self.processQueue.asyncAfter(deadline: .now() + Self.shareRetryHoldAfterStore) {
                            done()
                        }
                    } else {
                        self.runShareRetry(
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

    /// Logs one retry answer. Returns true when Share has a reading newer than the last Bluetooth
    /// reading, which ends the retry.
    private func logShareRetryResult(
        _ result: CGMReadingResult,
        prefix: String,
        askedAt: Date,
        endedAt: Date,
        lastReading: Date?
    ) -> Bool {
        let roundTrip = String(format: "%.1f", Date().timeIntervalSince(askedAt))

        switch result {
        case let .newData(samples):
            guard let newest = samples.map(\.date).max() else {
                logCGMDiagnostic("\(prefix): Share returned no readings (\(roundTrip) s)")
                return false
            }
            if let lastReading = lastReading, newest <= lastReading.addingTimeInterval(60) {
                logCGMDiagnostic("\(prefix): Share newest is \(newest), no newer than the last Bluetooth reading (\(roundTrip) s)")
                return false
            }
            let afterReading = Int(Date().timeIntervalSince(newest))
            let afterSessionEnd = Int(Date().timeIntervalSince(endedAt))
            logCGMDiagnostic(
                "\(prefix): Share HAS the missed reading \(newest), \(afterReading) s after its timestamp, \(afterSessionEnd) s after the session ended (\(roundTrip) s); storing it"
            )
            return true

        case let .error(error):
            logCGMDiagnostic("\(prefix): Share fetch failed (\(roundTrip) s): \(error.localizedDescription)")
            return false

        case .noData:
            logCGMDiagnostic("\(prefix): Share returned nothing new (\(roundTrip) s)")
            return false

        case .unreliableData:
            logCGMDiagnostic("\(prefix): Share returned unreliable data (\(roundTrip) s)")
            return false
        }
    }

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
                self?.logCGMDiagnostic("\(prefix): app \(state), phone \(lockText), background time left \(remainingText)")
            }
        }
    }

    /// Writes a line to the CGM's device log, so it appears in the CGM log export.
    private func logCGMDiagnostic(_ message: String) {
        guard let pluginIdentifier = cgmManager?.pluginIdentifier else { return }
        deviceLogStore.log(
            managerIdentifier: pluginIdentifier,
            deviceIdentifier: nil,
            type: .delegate,
            message: "[G6DIAG] " + message
        )
    }
}

extension PluginSource: CGMManagerDelegate {
    func deviceManager(
        _ manager: LoopKit.DeviceManager,
        logEventForDeviceIdentifier deviceIdentifier: String?,
        type: LoopKit.DeviceLogEntryType,
        message: String,
        completion: ((Error?) -> Void)?
    ) {
        deviceLogStore.log(
            managerIdentifier: manager.pluginIdentifier,
            deviceIdentifier: deviceIdentifier,
            type: type,
            message: message,
            completion: completion
        )
    }

    /// Forwards CGMManager-issued alerts into the unified `TrioAlertManager`
    /// pipeline so they get the same in-app banner + UN scheduling + history
    /// logging treatment as everything else. Used to be a no-op; on
    /// dev-libre3 / LibreLoop builds that meant CGM-issued alerts (sensor
    /// failure, signal loss, expiry, etc.) silently dropped.
    nonisolated func issueAlert(_ alert: LoopKit.Alert) {
        processQueue.async { self.glucoseManager?.trioAlertManager?.issueAlert(alert) }
    }

    nonisolated func retractAlert(identifier: LoopKit.Alert.Identifier) {
        processQueue.async { self.glucoseManager?.trioAlertManager?.retractAlert(identifier: identifier) }
    }

    /// LoopKit asks this on reconnect to avoid re-issuing an alert that's
    /// still live. `TrioAlertManager` deduplicates downstream via its own
    /// throttler and live-alert table, so answering "no" here is safe — at
    /// worst we get one duplicate banner, which the throttler suppresses.
    func doesIssuedAlertExist(identifier _: LoopKit.Alert.Identifier) async throws -> Bool {
        false
    }

    func lookupAllUnretracted(managerIdentifier _: String) async throws -> [LoopKit.PersistedAlert] {
        []
    }

    func lookupAllUnacknowledgedUnretracted(managerIdentifier _: String) async throws -> [LoopKit.PersistedAlert] {
        []
    }

    /// LoopKit calls this when a manager itself decides an alert is no
    /// longer relevant. Mirror the action on our pipeline so the in-app
    /// banner, scheduled UN, and history all clear.
    nonisolated func recordRetractedAlert(_ alert: LoopKit.Alert, at _: Date) async throws {
        processQueue.async { self.glucoseManager?.trioAlertManager?.retractAlert(identifier: alert.identifier) }
    }

    func cgmManagerWantsDeletion(_ manager: CGMManager) async {
        info(.cgm, "CGM \(manager.pluginIdentifier) requested removal")
        await glucoseManager?.deleteGlucoseSource()
    }

    func cgmManager(_: CGMManager, hasNew readingResult: CGMReadingResult) {
        processQueue.async { [weak self] in
            guard let self = self else { return }

            dispatchPrecondition(condition: .onQueue(self.processQueue))

            switch self.readCGMResult(readingResult: readingResult) {
            case let .success(glucose):
                self.glucoseManager?.newGlucoseFromCgmManager(newGlucose: glucose)
            case let .failure(error):
                debug(.cgm, "CGM reading not usable: \(error.localizedDescription)")
            }

            self.glucoseManager?.reportCGMSensorObservation(self.currentSensorObservation())

            self.publishCGMStatus()
        }
    }

    func cgmManager(_: LoopKit.CGMManager, hasNew events: [LoopKit.PersistedCgmEvent]) {
        processQueue.async { [weak self] in
            guard let self = self else { return }

            dispatchPrecondition(condition: .onQueue(self.processQueue))

            // TODO: Events in APS ?
            // currently only display in log the date of the event
            events.forEach { event in
                debug(.cgm, "CGM event \(event.type) at \(event.date)")

                if event.type == .sensorStart {
                    info(.cgm, "Sensor started")
                    self.glucoseManager?.removeCalibrations()
                    self.glucoseManager?.startCGMSensorSession(startedAt: event.date)
                }
            }
        }
    }

    func startDateToFilterNewData(for manager: CGMManager) -> Date? {
        dispatchPrecondition(condition: .onQueue(processQueue))

        let lastGlucoseDate = glucoseStorage.lastGlucoseDate()

        // G5/G6 Dexcom Share fallback: Share only returns the last 30 minutes. Let all of them
        // through, so readings Bluetooth missed are backfilled even after a newer Bluetooth
        // reading arrived; storage drops duplicates within 3.5 minutes of existing readings.
        // Scoped to Share inside G5/G6, not Share selected as the CGM itself.
        if manager.pluginIdentifier == "DexShareClient",
           cgmManager is G6CGMManager || cgmManager is G5CGMManager,
           let lastGlucoseDate = lastGlucoseDate
        {
            return min(lastGlucoseDate, Date().addingTimeInterval(-31 * 60))
        }

        return lastGlucoseDate
    }

    func cgmManagerDidUpdateState(_ cgmManager: CGMManager) {
        processQueue.async { [weak self] in
            guard let self = self else { return }

            dispatchPrecondition(condition: .onQueue(self.processQueue))

            guard let fetchGlucoseManager = self.glucoseManager else {
                debug(.cgm, "CGM state update ignored: no glucose manager")
                return
            }
            // Adjust app-specific NS Upload setting value when CGM setting is changed
            fetchGlucoseManager.settingsManager.settings.uploadGlucose = cgmManager.shouldSyncToRemoteService

            fetchGlucoseManager.updateGlucoseSource(
                cgmGlucoseSourceType: fetchGlucoseManager.settingsManager.settings.cgm,
                cgmGlucosePluginId: fetchGlucoseManager.settingsManager.settings.cgmPluginIdentifier,
                newManager: cgmManager as? CGMManagerUI
            )

            self.publishCGMStatus()
        }
    }

    func credentialStoragePrefix(for _: CGMManager) -> String {
        // return string unique to this instance of the CGMManager
        UUID().uuidString
    }

    func cgmManager(_: CGMManager, didUpdate status: CGMManagerStatus) {
        debug(.cgm, "CGM status: valid sensor session \(status.hasValidSensorSession)")
        processQueue.async { [weak self] in
            guard let self = self else { return }

            dispatchPrecondition(condition: .onQueue(self.processQueue))

            if self.cgmHasValidSensorSession != status.hasValidSensorSession {
                info(.cgm, status.hasValidSensorSession ? "Sensor session started" : "Sensor session ended")
                self.cgmHasValidSensorSession = status.hasValidSensorSession
            }
        }
    }

    // The live reading carries the sensor state; a backfill's .newData says nothing about it.
    private func currentSensorObservation() -> CGMSensorObservation {
        if let cgmTransmitterManager = cgmManager as? G7CGMManager {
            return cgmTransmitterManager.latestReading?.algorithmState.observation ?? .unavailable
        } else if let cgmTransmitterManager = cgmManager as? G6CGMManager {
            return cgmTransmitterManager.latestReading?.state.observation ?? .unavailable
        }
        return .unavailable
    }

    private func readCGMResult(readingResult: CGMReadingResult) -> Result<[BloodGlucose], Error> {
        if glucoseManager?.glucoseSource == nil {
            debug(.cgm, "CGM reading received with no glucose source set")
        }

        switch readingResult {
        case let .newData(values):

            var sensorActivatedAt: Date?
            var sensorStartDate: Date?
            var sensorTransmitterID: String?

            /// SAGE
            if let cgmTransmitterManager = cgmManager as? LibreTransmitterManagerV3 {
                let sensorInfo = cgmTransmitterManager.sensorInfoObservable
                sensorActivatedAt = sensorInfo.activatedAt
                sensorStartDate = sensorInfo.activatedAt
                sensorTransmitterID = sensorInfo.sensorSerial
            } else if let cgmTransmitterManager = cgmManager as? G5CGMManager {
                let latestReading = cgmTransmitterManager.latestReading
                sensorActivatedAt = latestReading?.activationDate
                sensorStartDate = latestReading?.sessionStartDate
                sensorTransmitterID = latestReading?.transmitterID
            } else if let cgmTransmitterManager = cgmManager as? G6CGMManager {
                let latestReading = cgmTransmitterManager.latestReading
                sensorActivatedAt = latestReading?.activationDate
                sensorStartDate = latestReading?.sessionStartDate
                sensorTransmitterID = latestReading?.transmitterID
            } else if let cgmTransmitterManager = cgmManager as? G7CGMManager {
                sensorActivatedAt = cgmTransmitterManager.sensorActivatedAt
                sensorStartDate = cgmTransmitterManager.sensorActivatedAt
                sensorTransmitterID = cgmTransmitterManager.sensorName
            } else if let cgmTransmitterManager = cgmManager as? LibreLoopCGMManager {
                sensorActivatedAt = cgmTransmitterManager.state.activatedAt
                sensorStartDate = cgmTransmitterManager.state.activatedAt
                sensorTransmitterID = cgmTransmitterManager.state.sensorSerial
            } else if let cgmTransmitterManager = cgmManager as? AccuChekCgmManager {
                sensorActivatedAt = cgmTransmitterManager.state.cgmStartTime
                sensorStartDate = cgmTransmitterManager.state.cgmStartTime
                sensorTransmitterID = cgmTransmitterManager.state.sensorInfo?.serialNumber
            } else if let cgmTransmitterManager = cgmManager as? EversenseCGMManager {
                sensorActivatedAt = cgmTransmitterManager.state.activatedAt
                sensorStartDate = cgmTransmitterManager.state.activatedAt
                sensorTransmitterID = cgmTransmitterManager.state.bleNameString
            } else if let cgmTransmitterManager = cgmManager as? SyaiCGMManager {
                sensorActivatedAt = cgmTransmitterManager.state.activatedAt
                sensorStartDate = cgmTransmitterManager.state.activatedAt
                sensorTransmitterID = cgmTransmitterManager.state.mac
            }

            // isDisplayOnly means "shifted for visual consistency after calibration"
            // (LoopKit), not "unsafe to dose"; drivers withhold sensor-reported faults.
            let bloodGlucose = values.compactMap { newGlucoseSample -> BloodGlucose? in
                if newGlucoseSample.isDisplayOnly {
                    debug(.cgm, "Display-only reading at \(newGlucoseSample.date), storing it")
                }

                let quantity = newGlucoseSample.quantity

                let value = Int(quantity.doubleValue(for: .milligramsPerDeciliter))

                if newGlucoseSample.wasUserEntered {
                    // Store the calibration for the sensor as manual glucose
                    return BloodGlucose(
                        id: UUID().uuidString,
                        mbg: value,
                        date: Decimal(Int(newGlucoseSample.date.timeIntervalSince1970 * 1000)),
                        dateString: newGlucoseSample.date,
                        filtered: nil,
                        noise: nil,
                        glucose: value,
                        type: "mbg",
                        activationDate: sensorActivatedAt,
                        sessionStartDate: sensorStartDate,
                        transmitterID: sensorTransmitterID
                    )
                }

                return BloodGlucose(
                    id: UUID().uuidString,
                    sgv: value,
                    direction: .init(trendType: newGlucoseSample.trend),
                    date: Decimal(Int(newGlucoseSample.date.timeIntervalSince1970 * 1000)),
                    dateString: newGlucoseSample.date,
                    unfiltered: Decimal(value),
                    filtered: nil,
                    noise: nil,
                    glucose: value,
                    type: "sgv",
                    activationDate: sensorActivatedAt,
                    sessionStartDate: sensorStartDate,
                    transmitterID: sensorTransmitterID
                )
            }
            return .success(bloodGlucose)
        case .unreliableData:
            // loopManager.receivedUnreliableCGMReading()
            return .failure(GlucoseDataError.unreliableData)
        case .noData:
            return .failure(GlucoseDataError.noData)
        case let .error(error):
            return .failure(error)
        }
    }
}

extension PluginSource {
    func sourceInfo() -> [String: Any]? {
        [GlucoseSourceKey.description.rawValue: "Plugin CGM source"]
    }
}

/// Background time for the Share retry. Unlike `startBackgroundTask`, it ends itself when
/// iOS expires it, so holding it can never get Trio terminated.
private final class ShareRetryBackgroundTask {
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
