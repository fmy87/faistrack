import Foundation
import CoreLocation
import CoreMotion

class DriveDetectionService: ObservableObject {
    static let shared = DriveDetectionService()
    private let motionManager = CMMotionActivityManager()
    @Published var isDriving: Bool = false
    @Published var currentDrive: Drive?

    // Live-tracking state consumed by LiveDriveView while a drive is in
    // progress. Updated incrementally in processLocation() rather than
    // recomputed from the full buffer each time, so this stays cheap even
    // on a long drive.
    @Published private(set) var liveDistanceKm: Double = 0
    @Published private(set) var liveRouteCoordinates: [CLLocationCoordinate2D] = []
    @Published private(set) var currentSpeedKmh: Double = 0
    private(set) var driveStartTime: Date?

    private var locationBuffer: [CLLocation] = []
    private var hardBrakingCount = 0
    private var fastAccelCount = 0
    private var idleSeconds = 0
    private var lastSpeed: Double = 0

    func startMonitoring() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        motionManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let activity = activity else { return }
            if activity.automotive && !self!.isDriving {
                self?.driveDidStart()
            } else if !activity.automotive && !activity.unknown && self!.isDriving {
                self?.driveDidEnd()
            }
        }
    }

    func processLocation(_ location: CLLocation?) {
        guard let location = location, isDriving else { return }
        if let last = locationBuffer.last {
            liveDistanceKm += location.distance(from: last) / 1000
        }
        locationBuffer.append(location)
        liveRouteCoordinates.append(location.coordinate)
        let speedKmh = max(0, location.speed * 3.6)
        currentSpeedKmh = speedKmh
        if speedKmh < 5 { idleSeconds += 1 }
        if lastSpeed - speedKmh > 25 { hardBrakingCount += 1 }
        if speedKmh - lastSpeed > 20 { fastAccelCount += 1 }
        lastSpeed = speedKmh
    }

    private func driveDidStart() {
        isDriving = true
        driveStartTime = Date()
        locationBuffer = []
        liveRouteCoordinates = []
        liveDistanceKm = 0
        currentSpeedKmh = 0
        hardBrakingCount = 0
        fastAccelCount = 0
        idleSeconds = 0
        NotificationService.shared.sendDriveStartNotification()
    }

    private func driveDidEnd() {
        isDriving = false
        currentSpeedKmh = 0
        guard let startTime = driveStartTime,
              let uid = AuthService.shared.currentUser?.uid else { return }
        let endTime = Date()
        let duration = Int(endTime.timeIntervalSince(startTime))
        guard duration > 120 else { return } // ignore drives < 2 min
        let speeds = locationBuffer.map { $0.speed * 3.6 }.filter { $0 > 0 }
        let topSpeed = speeds.max() ?? 0
        let avgSpeed = speeds.isEmpty ? 0 : speeds.reduce(0, +) / Double(speeds.count)
        let distance = calculateDistance()
        let hour = Calendar.current.component(.hour, from: startTime)
        let isNight = hour < 6 || hour > 20
        let routePolyline = encodedRoutePolyline()
        var drive = Drive(
            ownerUID: uid,
            carId: getActiveCarId(),
            startTime: .init(date: startTime),
            endTime: .init(date: endTime),
            distance: distance,
            topSpeed: topSpeed,
            avgSpeed: avgSpeed,
            duration: duration,
            idleTime: idleSeconds,
            isNight: isNight,
            hardBrakingCount: hardBrakingCount,
            fastAccelCount: fastAccelCount,
            polylineEncoded: routePolyline
        )
        drive.behaviorScore = calculateBehaviorScore(drive: drive)
        Task {
            try? await FirebaseService.shared.saveDrive(drive, uid: uid)
            await NotificationService.shared.sendDriveEndNotification(drive: drive)
            await LeaderboardService.shared.updateLeaderboard(drive: drive, uid: uid)
        }
    }

    private func calculateDistance() -> Double {
        var total = 0.0
        for i in 1..<locationBuffer.count {
            total += locationBuffer[i].distance(from: locationBuffer[i-1])
        }
        return total / 1000 // km
    }

    /// Builds a compact encoded polyline from the recorded route, downsampled
    /// so very long drives don't produce an oversized Firestore field.
    private func encodedRoutePolyline(maxPoints: Int = 500) -> String? {
        guard locationBuffer.count > 1 else { return nil }
        let points = downsampled(locationBuffer, maxPoints: maxPoints)
        let coordinates = points.map { $0.coordinate }
        guard coordinates.count > 1 else { return nil }
        return PolylineCodec.encode(coordinates)
    }

    private func downsampled(_ points: [CLLocation], maxPoints: Int) -> [CLLocation] {
        guard points.count > maxPoints else { return points }
        let stride = Double(points.count) / Double(maxPoints)
        var result: [CLLocation] = []
        var index = 0.0
        while Int(index) < points.count {
            result.append(points[Int(index)])
            index += stride
        }
        if let last = points.last, result.last !== last {
            result.append(last)
        }
        return result
    }

    private func calculateBehaviorScore(drive: Drive) -> Int {
        var score = 100
        score -= min(drive.hardBrakingCount * 5, 30)
        score -= min(drive.fastAccelCount * 3, 20)
        if drive.topSpeed > 150 { score -= 20 }
        else if drive.topSpeed > 120 { score -= 10 }
        return max(score, 0)
    }

    private func getActiveCarId() -> String {
        return UserDefaults.standard.string(forKey: "activeCarId") ?? ""
    }
}

