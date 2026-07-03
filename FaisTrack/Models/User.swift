import Foundation
import FirebaseFirestore

struct FTUser: Identifiable, Codable {
    @DocumentID var id: String?
    var uid: String
    var name: String
    var username: String
    var email: String?
    var phone: String?
    var photoURL: String?
    var instagramHandle: String?
    var isPrivateProfile: Bool = false
    var isPro: Bool = false
    var proExpiry: Timestamp?
    var referralCode: String
    var freeDaysEarned: Int = 0
    var language: String = "en"
    var units: String = "km"         // "km" or "mi"
    var fcmToken: String?
    var createdAt: Timestamp = Timestamp()

    var isMetric: Bool { units == "km" }
}
