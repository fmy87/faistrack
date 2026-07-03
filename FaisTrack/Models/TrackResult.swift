import Foundation
import FirebaseFirestore

/// A single completed attempt at racing a Track.
struct TrackResult: Identifiable, Codable {
    @DocumentID var id: String?
    var trackId: String
    var uid: String
    var username: String
    var duration: Double   // seconds
    var completedAt: Timestamp = Timestamp()

    var durationFormatted: String {
        String(format: "%.1fs", duration)
    }
}
