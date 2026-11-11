import CGMBLEKit
import Foundation
import LoopKitUI

/// The Dexcom G5/G6 reliability switches in CGM settings.
///
/// All default on, and on always means the fix is active. They exist so a fix can be turned off
/// for a deliberate comparison without rebuilding. Stored in UserDefaults; the keys are the ones
/// earlier builds used, so saved choices carry over.
enum DexcomG6Options {
    private enum Key {
        static let preventDuplicateConnections = "G6FixSkipRedundantReconnect"
        static let keepMessagesDuringSetup = "G6FixKeepMessagesDuringSubscriptionSetup"
        static let checkShareAfterMiss = "G6FixShareRetryAfterMiss"
    }

    /// Don't ask Bluetooth to connect again while a connection is already pending. Applied to
    /// CGMBLEKit by `apply(to:)`.
    static var preventDuplicateConnections: Bool {
        get { isOn(Key.preventDuplicateConnections) }
        set { UserDefaults.standard.set(newValue, forKey: Key.preventDuplicateConnections) }
    }

    /// Keep messages that arrive while a Bluetooth subscription is being set up, instead of
    /// discarding them. Applied to CGMBLEKit by `apply(to:)`.
    static var keepMessagesDuringSetup: Bool {
        get { isOn(Key.keepMessagesDuringSetup) }
        set { UserDefaults.standard.set(newValue, forKey: Key.keepMessagesDuringSetup) }
    }

    /// After a connection ends without a reading, ask Dexcom Share for it. Read by
    /// `DexcomShareFallback` each time it's needed.
    static var checkShareAfterMiss: Bool {
        get { isOn(Key.checkShareAfterMiss) }
        set { UserDefaults.standard.set(newValue, forKey: Key.checkShareAfterMiss) }
    }

    /// Applies the Bluetooth switches to a G5/G6 transmitter. Does nothing for other CGMs.
    static func apply(to manager: CGMManagerUI?) {
        guard let transmitter = (manager as? TransmitterManager)?.transmitter else { return }

        transmitter.preventDuplicateConnections = preventDuplicateConnections
        transmitter.keepMessagesDuringSetup = keepMessagesDuringSetup
    }

    /// On unless it was turned off.
    private static func isOn(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }
}
