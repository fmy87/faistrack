import SwiftUI

/// A career-mode style title that levels up with total distance, drives,
/// and tracks created — shown on Profile. XP is a simple weighted sum
/// (distance in km, plus a flat bonus per drive and per track created) so
/// no single activity dominates: someone who drives often ranks up even
/// with modest distances, and creating tracks meaningfully counts too.
enum DriverRank: Int, CaseIterable {
    case rookie, streetRacer, pro, veteran, legend

    /// The XP threshold at which this rank begins.
    var minXP: Double {
        switch self {
        case .rookie: return 0
        case .streetRacer: return 100
        case .pro: return 500
        case .veteran: return 1500
        case .legend: return 4000
        }
    }

    var icon: String {
        switch self {
        case .rookie: return "🔧"
        case .streetRacer: return "🏎️"
        case .pro: return "🏆"
        case .veteran: return "⭐️"
        case .legend: return "👑"
        }
    }

    var title: String {
        switch self {
        case .rookie: return NSLocalizedString("rank.rookie", comment: "")
        case .streetRacer: return NSLocalizedString("rank.streetRacer", comment: "")
        case .pro: return NSLocalizedString("rank.pro", comment: "")
        case .veteran: return NSLocalizedString("rank.veteran", comment: "")
        case .legend: return NSLocalizedString("rank.legend", comment: "")
        }
    }

    static func computeXP(totalDistanceKm: Double, totalDrives: Int, tracksCreated: Int) -> Double {
        totalDistanceKm + Double(totalDrives) * 5 + Double(tracksCreated) * 20
    }

    static func forXP(_ xp: Double) -> DriverRank {
        allCases.last { xp >= $0.minXP } ?? .rookie
    }

    /// Progress (0...1) toward the next rank, for a progress bar. Legend
    /// has no "next" rank, so it's always full.
    static func progress(for xp: Double) -> Double {
        let rank = forXP(xp)
        guard let nextIndex = allCases.firstIndex(of: rank).map({ $0 + 1 }), nextIndex < allCases.count else {
            return 1.0
        }
        let next = allCases[nextIndex]
        let span = next.minXP - rank.minXP
        guard span > 0 else { return 1.0 }
        return min(1.0, max(0.0, (xp - rank.minXP) / span))
    }
}
