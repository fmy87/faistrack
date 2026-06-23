import Foundation
import UserNotifications
import FirebaseMessaging

class NotificationService {
    static let shared = NotificationService()

    func requestPermission() async {
        try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    func updateFCMToken(_ token: String) {
        guard let uid = AuthService.shared.currentUser?.uid else { return }
        Task {
            try? await FirebaseService.shared.db
                .collection("users").document(uid)
                .updateData(["fcmToken": token])
        }
    }

    func sendDriveStartNotification() {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notification.driveStart.title", comment: "")
        content.body = NSLocalizedString("notification.driveStart.body", comment: "")
        content.sound = .default
        let request = UNNotificationRequest(identifier: "driveStart", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    func sendDriveEndNotification(drive: Drive) async {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notification.driveEnd.title", comment: "")
        content.body = String(format: NSLocalizedString("notification.driveEnd.body", comment: ""),
                              drive.distanceKm, drive.topSpeedKmh)
        content.sound = .default
        let request = UNNotificationRequest(identifier: "driveEnd_\(UUID())", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
