import Combine
import Sparkle

/// Owns Sparkle's updater for the app's lifetime. Created once in `MergeMoleApp` and
/// shared into the Settings scene via the environment, so the About tab drives the same
/// updater the scheduled background checker uses.
///
/// Sparkle's `SPUUpdater` is the source of truth; we mirror the two bits the UI needs
/// into observable properties so the Settings controls stay in lockstep with it — never
/// a shadow copy that can drift. All update *config* (feed URL, signing key, cadence,
/// default-on) lives in Info.plist: `SUFeedURL`, `SUPublicEDKey`,
/// `SUEnableAutomaticChecks`, `SUScheduledCheckInterval`, `SUEnableInstallerLauncherService`.
@Observable
final class Updater {
    @ObservationIgnored private let controller: SPUStandardUpdaterController
    @ObservationIgnored private var cancellable: AnyCancellable?

    /// Mirrors Sparkle's readiness — false while a check is already in flight, so the
    /// "Check for Updates…" button disables itself and can't double-fire.
    private(set) var canCheckForUpdates = false

    /// Mirrors Sparkle's persisted "check automatically" setting for the Settings toggle.
    private(set) var automaticallyChecksForUpdates: Bool

    init() {
        // startingUpdater: true launches the scheduled checker immediately, reading its
        // config from Info.plist. nil delegates = Sparkle's stock update UI + flow.
        controller = SPUStandardUpdaterController(startingUpdater: true,
                                                  updaterDelegate: nil,
                                                  userDriverDelegate: nil)
        let updater = controller.updater
        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        // KVO publisher emits its current value up front, so this both seeds and keeps
        // `canCheckForUpdates` live as Sparkle's state changes.
        cancellable = updater.publisher(for: \.canCheckForUpdates)
            .sink { [weak self] in self?.canCheckForUpdates = $0 }
    }

    /// Manual "Check for Updates…" — shows Sparkle's progress / up-to-date / update UI.
    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }

    /// Push the Settings toggle back into Sparkle so the scheduled checker honours it.
    func setAutomaticChecks(_ enabled: Bool) {
        controller.updater.automaticallyChecksForUpdates = enabled
        automaticallyChecksForUpdates = enabled
    }
}
