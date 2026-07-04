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
    // Optional, not a plain "= ..." default, for the same reason as
    // isPrivateProfileRaw above: this field was added after some accounts
    // (including at least one real test account) already existed in
    // Firestore without it. A non-Optional String with no value present at
    // all throws "the data couldn't be read because it is missing" on
    // every single getUser() call for that account — breaking Settings,
    // Profile, Stats, Friends, and anywhere else a profile is loaded, not
    // just the referral feature itself.
    var referralCode: String?
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

