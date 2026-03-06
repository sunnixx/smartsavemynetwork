import SwiftUI
import UserNotifications

@main
struct SmartSaveApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContactListView()
                .environment(\.managedObjectContext, PersistenceController.shared.context)
        }
    }
}

@MainActor
class AppDelegate: NSObject, UIApplicationDelegate, @unchecked Sendable {
    nonisolated func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationService.requestPermission()
        Task { @MainActor in
            PersistenceController.shared.importFromDeviceContactsIfNeeded()
        }
        return true
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let idString = response.notification.request.content.userInfo["contactID"] as? String,
              let contactID = UUID(uuidString: idString) else { return }
        NotificationCenter.default.post(name: .openContact, object: contactID)
    }
}

extension Notification.Name {
    static let openContact = Notification.Name("openContact")
}
