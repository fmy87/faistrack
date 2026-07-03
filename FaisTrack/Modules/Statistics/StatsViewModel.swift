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

    /// Drives where the user was actually driving. Every stat below except
    /// `passengerMiles` is based on this, not the raw `drives` array — a
    /// drive reclassified as "I was a passenger" (see DriveDetailView)
    /// shouldn't count toward the user's own distance, speed, or streak stats.
    private var drivingDrives: [Drive] { drives.filter { !$0.isPassenger } }
    var drivingDriveCount: Int { drivingDrives.count }

    /// Total distance logged while marked as a passenger — feeds the
    /// "Passenger Princess" personal best.
    var passengerMiles: Double { drives.filter { $0.isPassenger }.reduce(0) { $0 + $1.distance } }

    // MARK: - Totals

    var totalDistanceKm: Double { drivingDrives.reduce(0) { $0 + $1.distance } }
    var averageDriveDistanceKm: Double { drivingDrives.isEmpty ? 0 : totalDistanceKm / Double(drivingDrives.count) }
    var totalDurationSeconds: Int { drivingDrives.reduce(0) { $0 + $1.duration } }
    var totalDurationHours: Double { Double(totalDurationSeconds) / 3600 }
    var averageDriveMinutes: Int { drivingDrives.isEmpty ? 0 : (totalDurationSeconds / drivingDrives.count) / 60 }
    var topSpeedKmh: Double { drivingDrives.map(\.topSpeed).max() ?? 0 }

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

    var longestDrive: Drive? { drivingDrives.max(by: { $0.distance < $1.distance }) }
    var fastestDrive: Drive? { drivingDrives.max(by: { $0.topSpeed < $1.topSpeed }) }
    var longestDriveByTime: Drive? { drivingDrives.max(by: { $0.duration < $1.duration }) }
    var bestAvgSpeedDrive: Drive? { drivingDrives.max(by: { $0.avgSpeed < $1.avgSpeed }) }

    // MARK: - Speed distribution

    struct SpeedBucket: Identifiable {
        let id = UUID()
        let label: String
        let count: Int
        let color: Color
    }

    var speedDistribution: [SpeedBucket] {
        let buckets: [(String, (Double) -> Bool, Color)] = [
            (NSLocalizedString("stats.speedBucket.city", comment: ""), { $0 < 60 }, .cyan),
            (NSLocalizedString("stats.speedBucket.road", comment: ""), { $0 >= 60 && $0 < 90 }, .speedGreen),
            (NSLocalizedString("stats.speedBucket.highway", comment: ""), { $0 >= 90 && $0 < 120 }, .yellow),
            (NSLocalizedString("stats.speedBucket.fast", comment: ""), { $0 >= 120 && $0 < 150 }, .speedOrange),
            (NSLocalizedString("stats.speedBucket.veryFast", comment: ""), { $0 >= 150 }, .speedRed),
        ]
        return buckets.map { label, match, color in
            SpeedBucket(label: label, count: drivingDrives.filter { match($0.topSpeed) }.count, color: color)
        }
    }

    // MARK: - Day / night time split

    var dayHours: Double { Double(drivingDrives.filter { !$0.isNight }.reduce(0) { $0 + $1.duration }) / 3600 }
    var nightHours: Double { Double(drivingDrives.filter { $0.isNight }.reduce(0) { $0 + $1.duration }) / 3600 }

    // MARK: - Grouping helpers

    private func groupedByDay(_ source: [Drive]) -> [Date: [Drive]] {
        Dictionary(grouping: source) { Calendar.current.startOfDay(for: $0.startTime.dateValue()) }
    }

    private func groupedByWeek(_ source: [Drive]) -> [Date: [Drive]] {
        Dictionary(grouping: source) { drive -> Date in
            let cal = Calendar.current
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: drive.startTime.dateValue())
            return cal.date(from: comps) ?? drive.startTime.dateValue()
        }
    }

    private func groupedByMonth(_ source: [Drive]) -> [Date: [Drive]] {
        Dictionary(grouping: source) { drive -> Date in
            let cal = Calendar.current
            let comps = cal.dateComponents([.year, .month], from: drive.startTime.dateValue())
            return cal.date(from: comps) ?? drive.startTime.dateValue()
        }
    }

    private func groupedByCar(_ source: [Drive]) -> [String: [Drive]] {
        Dictionary(grouping: source) { $0.carId }
    }

    // MARK: - Personal bests

    var bigDayEnergyKm: Double {
        groupedByDay(drivingDrives).values.map { day in day.reduce(0) { $0 + $1.distance } }.max() ?? 0
    }

    var roadWarriorHours: Double {
        Double(groupedByDay(drivingDrives).values.map { day in day.reduce(0) { $0 + $1.duration } }.max() ?? 0) / 3600
    }

    var errandEraCount: Int {
        groupedByDay(drivingDrives).values.map { $0.count }.max() ?? 0
    }

    var hotWeekKm: Double {
        groupedByWeek(drivingDrives).values.map { week in week.reduce(0) { $0 + $1.distance } }.max() ?? 0
    }

    var mileageMonsterKm: Double {
        groupedByMonth(drivingDrives).values.map { month in month.reduce(0) { $0 + $1.distance } }.max() ?? 0
    }

    /// Longest run of consecutive calendar days with at least one drive.
    var onARollStreak: Int {
        let days = Set(groupedByDay(drivingDrives).keys).sorted()
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

    struct CarStat: Identifiable {
        var id: String { car.id ?? car.nickname }
        let car: Car
        let driveCount: Int
        let km: Double
        let topSpeed: Double
    }

    /// Every car with at least one drive, sorted by distance descending —
    /// backs the vehicle-distance breakdown bar as well as the personal
    /// bests that pick a "best" car.
    var carStats: [CarStat] {
        groupedByCar(drivingDrives).compactMap { carId, carDrives in
            guard let car = cars.first(where: { $0.id == carId }) else { return nil }
            return CarStat(
                car: car,
                driveCount: carDrives.count,
                km: carDrives.reduce(0) { $0 + $1.distance },
                topSpeed: carDrives.map(\.topSpeed).max() ?? 0
            )
        }.sorted { $0.km > $1.km }
    }

    /// The car with the most drives logged — shown as the "Most Driven
    /// Vehicle" hero card and doubles as the "Daily Driver" personal best.
    var mostDrivenCar: CarStat? { carStats.max(by: { $0.driveCount < $1.driveCount }) }
    var favoriteRideCar: CarStat? { carStats.max(by: { $0.km < $1.km }) }
    var garageRocketCar: CarStat? { carStats.max(by: { $0.topSpeed < $1.topSpeed }) }

    // MARK: - Monthly recap

    /// True for the first week of a new month, once there's at least one
    /// driving drive logged in the month that just ended — mirrors the
    /// reference app's "Your [MONTH] Recap is Here" banner.
    var showRecapBanner: Bool {
        Calendar.current.component(.day, from: Date()) <= 7 && !previousMonthDrives.isEmpty
    }

    var previousMonthDrives: [Drive] {
        let cal = Calendar.current
        guard let firstOfThisMonth = cal.date(from: cal.dateComponents([.year, .month], from: Date())),
              let previousMonth = cal.date(byAdding: .month, value: -1, to: firstOfThisMonth) else { return [] }
        let comps = cal.dateComponents([.year, .month], from: previousMonth)
        return drivingDrives.filter {
            let d = cal.dateComponents([.year, .month], from: $0.startTime.dateValue())
            return d.year == comps.year && d.month == comps.month
        }
    }

    var previousMonthName: String {
        let cal = Calendar.current
        guard let firstOfThisMonth = cal.date(from: cal.dateComponents([.year, .month], from: Date())),
              let previousMonth = cal.date(byAdding: .month, value: -1, to: firstOfThisMonth) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: previousMonth).uppercased()
    }

    var previousMonthDistanceKm: Double { previousMonthDrives.reduce(0) { $0 + $1.distance } }
    var previousMonthTopSpeed: Double { previousMonthDrives.map(\.topSpeed).max() ?? 0 }
    var previousMonthHours: Double { Double(previousMonthDrives.reduce(0) { $0 + $1.duration }) / 3600 }
    var previousMonthDriveCount: Int { previousMonthDrives.count }
    var previousMonthLongestDrive: Drive? { previousMonthDrives.max(by: { $0.distance < $1.distance }) }

    // MARK: - Safety score

    /// Average behaviorScore across driving drives that have one. Not every
    /// drive necessarily has a score (older data, or if scoring logic
    /// changes), so this only averages the ones that do rather than
    /// treating missing scores as zero.
    var averageSafetyScore: Int? {
        let scores = drivingDrives.compactMap { $0.behaviorScore }
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / scores.count
    }

    /// Chronological scores for the most recent drives, oldest first, for a
    /// simple trend sparkline — lets the user see if their driving has been
    /// getting safer or riskier lately, not just a single flat average.
    var safetyScoreTrend: [Int] {
        drivingDrives
            .sorted { $0.startTime.dateValue() < $1.startTime.dateValue() }
            .compactMap { $0.behaviorScore }
            .suffix(10)
    }
}

