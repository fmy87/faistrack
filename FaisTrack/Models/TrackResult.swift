import Foundation
import FirebaseFirestore

/// A single completed attempt at racing a Track.
struct TrackResult: Identifiable, Codable {
    @DocumentID var id: String?
    var trackId: String
    var uid: String
    var username: String
    var duration: Double   // seconds
    /// km/h — captured live during the attempt the same way Drive.topSpeed
    /// is, so the best-time holder's top speed can be shown on the track's
    /// share card without an extra lookup.
    var topSpeed: Double = 0
    /// Denormalized rather than just a carId — the share card needs to
    /// display this without an async Car lookup, and a car nickname/model
    /// won't change after the fact in a way that matters for a historical result.
    var carName: String?
    var completedAt: Timestamp = Timestamp()

    var durationFormatted: String {
        String(format: "%.1fs", duration)
    }
}

