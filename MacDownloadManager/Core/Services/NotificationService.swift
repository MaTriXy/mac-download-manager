import Foundation
import UserNotifications

@MainActor
final class NotificationService: NSObject, Sendable {

    static let shared = NotificationService()

    private override init() {
        super.init()
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func postDownloadStarted(filename: String) {
        let content = UNMutableNotificationContent()
        content.title = "Download Started"
        content.body = filename
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "download-started-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func postDownloadCompleted(filename: String) {
        let content = UNMutableNotificationContent()
        content.title = "Download Complete"
        content.body = filename
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "download-completed-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
