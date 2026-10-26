import AppKit
import UserNotifications

/// Posts user notifications (hotkey/Services errors, the accessibility prompt)
/// through UserNotifications, replacing the NSUserNotification API deprecated
/// in macOS 11.
@MainActor
final class Notifier: NSObject {
    static let shared = Notifier()

    nonisolated private static let accessibilityCategory = "ACCESSIBILITY_REQUIRED"
    nonisolated private static let openSettingsAction = "OPEN_ACCESSIBILITY_SETTINGS"
    private static let accessibilitySettingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    /// UNUserNotificationCenter.current() throws an Objective-C exception (an
    /// uncatchable crash) when the process isn't an app bundle, e.g. when run as
    /// the bare `.build/release/BMO` binary. Fall back to logging there.
    private var isAvailable: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    /// Call at launch: the delegate must be set before the app finishes
    /// launching to receive a click on a notification that relaunched it.
    func configure() {
        guard isAvailable else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let openSettings = UNNotificationAction(
            identifier: Self.openSettingsAction,
            title: "Open Settings",
            options: [.foreground]
        )
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.accessibilityCategory, actions: [openSettings], intentIdentifiers: [])
        ])
    }

    func post(title: String, message: String) {
        post(title: title, message: message, category: nil)
    }

    /// Clicking the notification or its "Open Settings" button opens
    /// System Settings → Privacy & Security → Accessibility.
    func postAccessibilityRequired(message: String) {
        post(title: "Accessibility Permission Required", message: message, category: Self.accessibilityCategory)
    }

    private func post(title: String, message: String, category: String?) {
        guard isAvailable else {
            NSLog("BMO notification (not in an app bundle): \(title): \(message)")
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        if let category {
            content.categoryIdentifier = category
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)

        Task {
            let center = UNUserNotificationCenter.current()
            do {
                // Prompts the first time only; later calls return the saved choice.
                guard try await center.requestAuthorization(options: [.alert, .sound]) else {
                    NSLog("BMO notification not shown (notifications disabled): \(title): \(message)")
                    return
                }
                try await center.add(request)
            } catch {
                NSLog("BMO notification failed: \(error.localizedDescription)")
            }
        }
    }
}

extension Notifier: UNUserNotificationCenterDelegate {
    /// Show banners even while Sig is the active app (e.g. popover open).
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let category = response.notification.request.content.categoryIdentifier
        let action = response.actionIdentifier
        guard category == Self.accessibilityCategory,
              action == UNNotificationDefaultActionIdentifier || action == Self.openSettingsAction else {
            return
        }
        await MainActor.run {
            _ = NSWorkspace.shared.open(Self.accessibilitySettingsURL)
        }
    }
}
