import Foundation
import CoreLocation
import CoreMotion

class DriveDetectionService: ObservableObject {
    static let shared = DriveDetectionService()
    private let motionManager = CMMotionActivityManager()
    @Published var isDriving: Bool = false
    @Published var currentDrive: Drive?
    private var locationBuffer: [CLLocation] = []
    private var driveStartTime: Date?
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
        locationBuffer.append(location)
        let speedKmh = location.speed * 3.6
        if speedKmh < 5 { idleSeconds += 1 }
        if lastSpeed - speedKmh > 25 { hardBrakingCount += 1 }
        if speedKmh - lastSpeed > 20 { fastAccelCount += 1 }
        lastSpeed = speedKmh
    }

    private func driveDidStart() {
        isDriving = true
        driveStartTime = Date()
        locationBuffer = []
        hardBrakingCount = 0
        fastAccelCount = 0
        idleSeconds = 0
        NotificationService.shared.sendDriveStartNotification()
    }

    private func driveDidEnd() {
        isDriving = false
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
            fastAccelCount: fastAccelCount
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
