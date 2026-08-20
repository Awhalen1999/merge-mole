import Foundation
import AppKit
import UserNotifications

/// One banner's content, fully decided by the model — the notifier renders it
/// verbatim. `id` is the PR id and doubles as the notification identifier, so a
/// re-delivery replaces rather than stacks, and a sweep can target exactly the
/// PRs that were settled.
struct PRNotification: Equatable, Sendable {
    let id: String
    let title: String
    let body: String
    let url: URL
}

/// The seam between `AppModel` and macOS notifications. The model owns every
/// decision — when a banner fires, what it says, when it's swept — and this
/// protocol only executes them, so the whole feature tests against a recording
/// fake with no `UserNotifications` in sight.
protocol PRNotifier: AnyObject {
    /// Called with the PR id after the user clicks a banner (the notifier has
    /// already opened the PR in the browser). The model hooks this to mark the
    /// PR read, so the badge drops on the same gesture.
    var prOpened: ((String) -> Void)? { get set }

    /// Ask macOS for permission to show banners. Called when the user enables
    /// notifications in Settings — never at launch, so no install is ever
    /// greeted by a permission prompt it didn't ask for.
    func requestAuthorization()

    func deliver(_ notification: PRNotification)

    /// Drop delivered banners for these PR ids from Notification Center. A
    /// banner must never outlive its reason: once a PR reads as caught-up (or
    /// is gone), its banner goes too.
    func removeDelivered(ids: [String])

    /// Drop every delivered banner — for disconnect/reset, where the whole
    /// list the banners pointed at is gone.
    func removeAllDelivered()
}

/// Production notifier over `UNUserNotificationCenter`. Delegate duties: present
/// banners even though the app is technically "active" (a menu-bar app always
/// is, which would otherwise silence every banner), and route clicks to the PR.
final class UserNotificationNotifier: NSObject, PRNotifier, UNUserNotificationCenterDelegate {
    var prOpened: ((String) -> Void)?

    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorization() {
        // Fire and forget: if macOS says no, delivery below is a silent no-op,
        // and the Settings caption points at System Settings for the remedy.
        center.requestAuthorization(options: [.alert]) { _, _ in }
    }

    func deliver(_ notification: PRNotification) {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.userInfo = ["url": notification.url.absoluteString, "pr": notification.id]
        center.add(UNNotificationRequest(identifier: notification.id, content: content, trigger: nil))
    }

    func removeDelivered(ids: [String]) {
        guard !ids.isEmpty else { return }
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    func removeAllDelivered() {
        center.removeAllDeliveredNotifications()
    }

    // MARK: UNUserNotificationCenterDelegate (system queue → hop to main)

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        let url = (info["url"] as? String).flatMap(URL.init(string:))
        let prID = info["pr"] as? String
        Task { @MainActor in
            if let url { NSWorkspace.shared.open(url) }
            if let prID { self.prOpened?(prID) }
            completionHandler()
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // .list as well as .banner: a banner that fires while nobody's looking
        // must still land in Notification Center, or the sweep-on-read contract
        // has nothing to sweep and the user has nothing to come back to.
        completionHandler([.banner, .list])
    }
}

/// Inert stand-in for the test-host scenes (see `MergeMoleApp`): the real
/// notifier would claim the process-wide notification-center delegate inside
/// the test runner. The suites themselves use the recording fake in TestSupport.
final class NoopNotifier: PRNotifier {
    var prOpened: ((String) -> Void)?
    func requestAuthorization() {}
    func deliver(_ notification: PRNotification) {}
    func removeDelivered(ids: [String]) {}
    func removeAllDelivered() {}
}
