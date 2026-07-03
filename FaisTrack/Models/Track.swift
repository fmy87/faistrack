import Foundation
import FirebaseFirestore
import CoreLocation

/// A competable point-to-point route derived from a published Drive.
/// Users race against the clock along the same path; the finish line is
/// the original drive's last recorded point.
struct Track: Identifiable, Codable {
    @DocumentID var id: String?
    var ownerUID: String
    var ownerUsername: String
    var name: String
    var startLatitude: Double
    var startLongitude: Double
    var endLatitude: Double
    var endLongitude: Double
    var distance: Double          // meters
    var polylineEncoded: String
    var bestTime: Double?         // seconds
    var bestTimeUsername: String?
    /// Needed (not just the username) so a Cloud Function can look up the
    /// previous record holder's fcmToken and notify them when their record
    /// is broken — see functions/index.js.
    var bestTimeUid: String?
    var attemptCount: Int = 0
    var createdAt: Timestamp = Timestamp()

    var startCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: startLatitude, longitude: startLongitude)
    }
    var endCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: endLatitude, longitude: endLongitude)
    }
    var distanceFormatted: String {
        distance >= 1000 ? String(format: "%.1f km", distance / 1000) : String(format: "%.0f m", distance)
    }

    /// Tracks must be at least this long to be published.
    static let minimumDistanceMeters: Double = 200
}

