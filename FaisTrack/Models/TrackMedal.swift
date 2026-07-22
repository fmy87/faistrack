import SwiftUI

/// Gives every track a target beyond just "be #1" — Bronze for finishing
/// at all, Silver for a genuinely competitive time, Gold for holding (or
/// tying) the actual record. Computed from the track's best time and the
/// user's own best result on it — nothing persisted, recalculated fresh
/// each time the track's detail screen loads.
enum TrackMedal: Equatable {
    case gold, silver, bronze, none

    static func evaluate(myBestDuration: Double?, trackBestDuration: Double?) -> TrackMedal {
        guard let myBestDuration, let trackBestDuration, trackBestDuration > 0 else { return .none }
        let ratio = myBestDuration / trackBestDuration
        if ratio <= 1.0 { return .gold }
        if ratio <= 1.10 { return .silver }
        return .bronze
    }

    var icon: String {
        switch self {
        case .gold: return "🥇"
        case .silver: return "🥈"
        case .bronze: return "🥉"
        case .none: return ""
        }
    }

    var label: String {
        switch self {
        case .gold: return NSLocalizedString("trackMedal.gold", comment: "")
        case .silver: return NSLocalizedString("trackMedal.silver", comment: "")
        case .bronze: return NSLocalizedString("trackMedal.bronze", comment: "")
        case .none: return NSLocalizedString("trackMedal.none", comment: "")
        }
    }

    var color: Color {
        switch self {
        case .gold: return .yellow
        case .silver: return Color(white: 0.75)
        case .bronze: return .ftAccentOrange
        case .none: return .ftTextSecondary
        }
    }
}
