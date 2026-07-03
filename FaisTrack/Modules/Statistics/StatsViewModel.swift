import Foundation
import SwiftUI
import FirebaseFirestore

/// Computes every Statistics-tab metric client-side from the user's raw
/// Drives + Cars. Nothing here is Pro-gated — all personal bests are
/// available to every user.
@MainActor
class StatsViewModel: ObservableObject {
    @Published var drives: [Drive] = []
    @Published var cars: [Car] = []
    @Published var isLoading = true

    func load() async {
        guard let uid = AuthService.shared.currentUser?.uid else { isLoading = false; return }
        async let fetchedDrives = FirebaseService.shared.getDrives(uid: uid, limit: 2000)
        async let fetchedCars = FirebaseService.shared.getCars(uid: uid)
        drives = (try? await fetchedDrives) ?? []
        cars = (try? await fetchedCars) ?? []
        isLoading = false
    }

    // MARK: - Totals

    var totalDistanceKm: Double { drives.reduce(0) { $0 + $1.distance } }
    var averageDriveDistanceKm: Double { drives.isEmpty ? 0 : totalDistanceKm / Double(drives.count) }
    var totalDurationSeconds: Int { drives.reduce(0) { $0 + $1.duration } }
    var totalDurationHours: Double { Double(totalDurationSeconds) / 3600 }
    var averageDriveMinutes: Int { drives.isEmpty ? 0 : (totalDurationSeconds / drives.count) / 60 }
    var topSpeedKmh: Double { drives.map(\.topSpeed).max() ?? 0 }

    // MARK: - Distance comparisons (distances in km)

    /// Length of one lap of the Indianapolis Motor Speedway oval.
    private let indy500LapKm: Double = 4.023
    /// Approximate driving distance New York to Los Angeles.
    private let coastToCoastKm: Double = 4500
    /// Earth's circumference at the equator.
    private let aroundEarthKm: Double = 40075
    /// Average Earth-Moon distance.
    private let toTheMoonKm: Double = 384400

    var indy500Laps: Double { totalDistanceKm / indy500LapKm }
    var coastToCoastRatio: Double { totalDistanceKm / coastToCoastKm }
    var aroundEarthRatio: Double { totalDistanceKm / aroundEarthKm }
    var toTheMoonRatio: Double { totalDistanceKm / toTheMoonKm }

    // MARK: - Notable single drives

    var longestDrive: Drive? { drives.max(by: { $0.distance < $1.distance }) }
    var fastestDrive: Drive? { drives.max(by: { $0.topSpeed < $1.topSpeed }) }
    var longestDriveByTime: Drive? { drives.max(by: { $0.duration < $1.duration }) }
    var bestAvgSpeedDrive: Drive? { drives.max(by: { $0.avgSpeed < $1.avgSpeed }) }

    // MARK: - Speed distribution

    struct SpeedBucket: Identifiable {
        let id = UUID()
        let label: String
        let count: Int
        let color: Color
    }

    var speedDistribution: [SpeedBucket] {
        let buckets: [(String, (Double) -> Bool, Color)] = [
            (NSLocalizedString("stats.speedBucket.city", comment: ""), { $0 < 60 }, .speedGreen),
            (NSLocalizedString("stats.speedBucket.road", comment: ""), { $0 >= 60 && $0 < 90 }, Color.mint),
            (NSLocalizedString("stats.speedBucket.highway", comment: ""), { $0 >= 90 && $0 < 120 }, .speedOrange),
            (NSLocalizedString("stats.speedBucket.fast", comment: ""), { $0 >= 120 && $0 < 150 }, Color.orange),
            (NSLocalizedString("stats.speedBucket.veryFast", comment: ""), { $0 >= 150 }, .speedRed),
        ]
        return buckets.map { label, match, color in
            SpeedBucket(label: label, count: drives.filter { match($0.topSpeed) }.count, color: color)
        }
    }

    // MARK: - Day / night time split

    var dayHours: Double { Double(drives.filter { !$0.isNight }.reduce(0) { $0 + $1.duration }) / 3600 }
    var nightHours: Double { Double(drives.filter { $0.isNight }.reduce(0) { $0 + $1.duration }) / 3600 }

    // MARK: - Grouping helpers

    private func groupedByDay() -> [Date: [Drive]] {
        Dictionary(grouping: drives) { Calendar.current.startOfDay(for: $0.startTime.dateValue()) }
    }

    private func groupedByWeek() -> [Date: [Drive]] {
        Dictionary(grouping: drives) { drive -> Date in
            let cal = Calendar.current
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: drive.startTime.dateValue())
            return cal.date(from: comps) ?? drive.startTime.dateValue()
        }
    }

    private func groupedByMonth() -> [Date: [Drive]] {
        Dictionary(grouping: drives) { drive -> Date in
            let cal = Calendar.current
            let comps = cal.dateComponents([.year, .month], from: drive.startTime.dateValue())
            return cal.date(from: comps) ?? drive.startTime.dateValue()
        }
    }

    private func groupedByCar() -> [String: [Drive]] {
        Dictionary(grouping: drives) { $0.carId }
    }

    // MARK: - Personal bests

    var bigDayEnergyKm: Double {
        groupedByDay().values.map { day in day.reduce(0) { $0 + $1.distance } }.max() ?? 0
    }

    var roadWarriorHours: Double {
        Double(groupedByDay().values.map { day in day.reduce(0) { $0 + $1.duration } }.max() ?? 0) / 3600
    }

    var errandEraCount: Int {
        groupedByDay().values.map { $0.count }.max() ?? 0
    }

    var hotWeekKm: Double {
        groupedByWeek().values.map { week in week.reduce(0) { $0 + $1.distance } }.max() ?? 0
    }

    var mileageMonsterKm: Double {
        groupedByMonth().values.map { month in month.reduce(0) { $0 + $1.distance } }.max() ?? 0
    }

    /// Longest run of consecutive calendar days with at least one drive.
    var onARollStreak: Int {
        let days = Set(groupedByDay().keys).sorted()
        guard !days.isEmpty else { return 0 }
        var longest = 1
        var current = 1
        for i in 1..<days.count {
            if Calendar.current.dateComponents([.day], from: days[i - 1], to: days[i]).day == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    struct CarStat {
        let car: Car
        let driveCount: Int
        let km: Double
        let topSpeed: Double
    }

    private var carStats: [CarStat] {
        groupedByCar().compactMap { carId, carDrives in
            guard let car = cars.first(where: { $0.id == carId }) else { return nil }
            return CarStat(
                car: car,
                driveCount: carDrives.count,
                km: carDrives.reduce(0) { $0 + $1.distance },
                topSpeed: carDrives.map(\.topSpeed).max() ?? 0
            )
        }
    }

    /// The car with the most drives logged — shown as the "Most Driven
    /// Vehicle" hero card and doubles as the "Daily Driver" personal best.
    var mostDrivenCar: CarStat? { carStats.max(by: { $0.driveCount < $1.driveCount }) }
    var favoriteRideCar: CarStat? { carStats.max(by: { $0.km < $1.km }) }
    var garageRocketCar: CarStat? { carStats.max(by: { $0.topSpeed < $1.topSpeed }) }
}
