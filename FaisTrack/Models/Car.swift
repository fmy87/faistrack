import Foundation
import FirebaseFirestore

struct Car: Identifiable, Codable {
    @DocumentID var id: String?
    var ownerUID: String
    var nickname: String
    var make: String
    var model: String
    var year: Int
    var photoURL: String?
    var engineSize: String?
    var cylinders: Int?
    var horsepower: Int?
    var torque: Int?
    var isTurbo: Bool = false
    var isSupercharged: Bool = false
    var suspensionNotes: String?
    var wheels: String?
    var isActive: Bool = false
    var isPublic: Bool = false
    var createdAt: Timestamp = Timestamp()

    var displayName: String {
        nickname.isEmpty ? "\(year) \(make) \(model)" : nickname
    }
}
