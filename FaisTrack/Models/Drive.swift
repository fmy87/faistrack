import Foundation
import FirebaseFirestore

struct Drive: Identifiable, Codable {
    @DocumentID var id: String?
    var ownerUID: String
    var carId: String
    var startTime: Timestamp
    var endTime: Timestamp?
    var distance: Double = 0         // kilometers
    var topSpeed: Double = 0         // km/h
    var avgSpeed: Double = 0         // km/h
    var duration: Int = 0            // seconds
    var idleTime: Int = 0            // seconds
    var isNight: Bool = false
    var hardBrakingCount: Int = 0
    var fastAccelCount: Int = 0
    var polylineEncoded: String?
    var behaviorScore: Int?          // Pro feature 0-100
    var startPlaceName: String?
    var endPlaceName: String?

    var distanceKm: String { String(format: "%.1f km", distance) }
    var distanceMi: String { String(format: "%.1f mi", distance * 0.621371) }
    var topSpeedKmh: String { String(format: "%.0f km/h", topSpeed) }
    var topSpeedMph: String { String(format: "%.0f mph", topSpeed * 0.621371) }

    /// useMetric: true for km, false for miles — matches the "unitsPreference"
    /// value ("km"/"mi") set from Settings.
    func distanceFormatted(useMetric: Bool) -> String { useMetric ? distanceKm : distanceMi }
    func topSpeedFormatted(useMetric: Bool) -> String { useMetric ? topSpeedKmh : topSpeedMph }
    var durationFormatted: String {
        let minutes = duration / 60
        if minutes < 60 {
            return String(format: NSLocalizedString("drive.duration.minutes", comment: ""), minutes)
        }
        return String(format: NSLocalizedString("drive.duration.hoursMinutes", comment: ""), minutes / 60, minutes % 60)
    }
    var speedColor: SpeedColor {
        if topSpeed < 60 { return .green }
        if topSpeed < 100 { return .orange }
        return .red
    }
}

enum SpeedColor {
    case green, orange, red
}
