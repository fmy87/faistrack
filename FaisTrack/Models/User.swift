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
    // Optional (not "= false" non-optional) so that decoding an existing
    // document created before this field existed doesn't throw a
    // keyNotFound error — Swift's synthesized Decodable does NOT fall back
    // to a property's default value for missing keys, only for Optionals.
    var isPrivateProfileRaw: Bool?
    var isPro: Bool = false
    var proExpiry: Timestamp?
    var referralCode: String
    var freeDaysEarned: Int = 0
    var language: String = "en"
    var units: String = "km"         // "km" or "mi"
    var fcmToken: String?
    var createdAt: Timestamp = Timestamp()

    var isMetric: Bool { units == "km" }

    var isPrivateProfile: Bool {
        get { isPrivateProfileRaw ?? false }
        set { isPrivateProfileRaw = newValue }
    }
}
