import UserNotifications
import Foundation

struct NotificationService {

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func schedule(contactID: UUID, contactName: String, date: Date) {
        let request = buildRequest(contactID: contactID, contactName: contactName, date: date)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancel(contactID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [contactID.uuidString])
    }

    static func buildRequest(contactID: UUID, contactName: String, date: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Follow up with \(contactName)"
        content.body = "You set a reminder to follow up."
        content.sound = .default
        content.userInfo = ["contactID": contactID.uuidString]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        return UNNotificationRequest(identifier: contactID.uuidString, content: content, trigger: trigger)
    }
}
