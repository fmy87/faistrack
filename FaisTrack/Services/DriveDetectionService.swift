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
    @Published private(set) var liveAverageSpeedKmh: Double = 0
    @Published private(set) var liveTopSpeedKmh: Double = 0
    @Published private(set) var liveAltitudeMeters: Double = 0
    @Published private(set) var movingSeconds: Int = 0
    @Published private(set) var stoppedSeconds: Int = 0
    private(set) var driveStartTime: Date?

    /// Hides this user's live driving status from friends. Persisted so it
    /// carries over between drives without needing to re-toggle every time.
    /// When on, broadcastLiveStatus() reports `isDriving: false` regardless
    /// of the actual state, so friends' clients never see this user as
    /// driving at all — see FriendsView/FriendsViewModel for how that's
    /// consumed.
    @Published var isGhostMode: Bool {
        didSet {
            UserDefaults.standard.set(isGhostMode, forKey: "isGhostMode")
            // If this changes mid-drive, immediately reflect it — turning
            // Ghost Mode on should hide you from friends right away, not
            // just for your next drive.
            if isDriving { broadcastLiveStatus(isDriving: true) }
        }
    }

    /// Lets the person mark themselves as a passenger *during* the drive
    /// (via LiveDriveView) instead of only being able to correct it after
    /// the fact in DriveDetailView. Resets to false at the start of every
    /// new drive — it doesn't carry over between drives the way Ghost Mode
    /// does, since who's driving can change trip to trip.
    @Published var isPassengerMode: Bool = false

    private var locationBuffer: [CLLocation] = []
    private var hardBrakingCount = 0
    private var fastAccelCount = 0
    private var idleSeconds = 0
    private var lastSpeed: Double = 0
    private var speedSampleCount = 0
    private var speedSampleSum: Double = 0
    private var movingStoppedTimer: Timer?
    private var lastLocationBroadcast: Date?

    // MARK: - Automotive-vs-walking confirmation
    // CoreMotion's "automotive" classification can misfire on brisk
    // walking, jogging, being a passenger on a bus/train, etc. Rather than
    // starting a drive off a single ambiguous signal, a candidate signal is
    // held as "pending" and only confirmed once actual GPS speed crosses a
    // threshold no walker/jogger/cyclist realistically sustains.
    private var pendingAutomotiveConfirmation = false
    private var pendingConfirmationTimer: Timer?
    /// Faster than any realistic walking, jogging, or casual cycling speed
    /// — a brisk walk tops out around 7 km/h, running around 15-18 km/h for
    /// all but elite sprinters. 25 km/h sustained is a strong real-car signal.
    private let drivingSpeedThresholdKmh: Double = 25
    /// How long to wait for GPS to confirm real driving speed before giving
    /// up on a candidate automotive signal and treating it as a false alarm.
    private let confirmationWindowSeconds: TimeInterval = 25

    /// How often to re-broadcast location while driving. Every single GPS
    /// update would be excessive Firestore writes for marginal benefit on a
    /// map pin that's only glanced at occasionally — this keeps friends'
    /// view reasonably fresh without hammering the free-tier write quota.
    private let locationBroadcastInterval: TimeInterval = 15

    // MARK: - Aircraft detection
    // The strongest signal that something is a flight rather than a drive
    // isn't speed alone — a fast car and a taxiing plane can both hit
    // 100+ km/h — it's speed *combined with* altitude and climb rate,
    // since no road on Earth lets you combine highway speeds with rapid
    // altitude gain or true cruising altitude. None of these thresholds are
    // reachable by a car, but a plane crosses at least one within its
    // first minute or two of climbing.
    private var startAltitude: Double?
    /// No car anywhere sustains this regardless of context — a hard
    /// backstop that catches cruise speed even if the altitude reading is
    /// briefly noisy.
    private let impossibleDrivingSpeedKmh: Double = 300
    /// Combined with high speed, this altitude is the discriminator for
    /// "high mountain road" vs "in the air" — very few public roads sit
    /// above this AND allow highway speeds at the same time.
    private let aircraftAltitudeMeters: Double = 1800
    private let aircraftAltitudeSpeedThresholdKmh: Double = 180
    /// A climb this fast, sustained while already moving quickly, is a
    /// takeoff — no road gains this much elevation this fast, even a steep
    /// mountain pass, at anything close to these speeds.
    private let aircraftClimbMeters: Double = 500
    private let aircraftClimbSpeedThresholdKmh: Double = 80

    init() {
        isGhostMode = UserDefaults.standard.bool(forKey: "isGhostMode")
    }

    func startMonitoring() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        motionManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self, let activity = activity else { return }

            // Low-confidence classifications are exactly the ones most
            // likely to misfire — CoreMotion itself is telling us it isn't
            // sure, so treat those as noise rather than acting on them.
            guard activity.confidence != .low else { return }

            if activity.automotive && !activity.walking && !self.isDriving && !self.pendingAutomotiveConfirmation {
                // Don't start the drive yet — CoreMotion alone isn't
                // trusted here. Wait for GPS to actually confirm driving
                // speed (see processLocation) before committing.
                self.beginPendingAutomotiveConfirmation()
            } else if (!activity.automotive || activity.walking) && self.pendingAutomotiveConfirmation {
                // The signal reversed (or turned out to be walking after
                // all) before GPS ever confirmed real driving speed —
                // cancel rather than starting a drive off a blip.
                self.cancelPendingAutomotiveConfirmation()
            } else if !activity.automotive && !activity.unknown && self.isDriving {
                self.driveDidEnd()
            }
        }
    }

    private func beginPendingAutomotiveConfirmation() {
        pendingAutomotiveConfirmation = true
        LocationService.shared.startUpdating()
        pendingConfirmationTimer?.invalidate()
        pendingConfirmationTimer = Timer.scheduledTimer(withTimeInterval: confirmationWindowSeconds, repeats: false) { [weak self] _ in
            // GPS never confirmed real driving speed within the window —
            // treat this as a false alarm (e.g. a brisk walk or a bus
            // stopped in traffic) rather than starting a drive anyway.
            self?.cancelPendingAutomotiveConfirmation()
        }
    }

    private func cancelPendingAutomotiveConfirmation() {
        pendingAutomotiveConfirmation = false
        pendingConfirmationTimer?.invalidate()
        pendingConfirmationTimer = nil
    }

    /// Lets the person end the drive immediately from the LiveDriveView HUD,
    /// instead of only ever being able to stop via CoreMotion detecting
    /// they're no longer moving automotively (which can lag behind reality,
    /// e.g. sitting at a long red light, or CoreMotion misclassifying).
    func endDriveManually() {
        guard isDriving else { return }
        driveDidEnd()
    }

    func processLocation(_ location: CLLocation?) {
        guard let location = location else { return }

        // Waiting for GPS to confirm a candidate "automotive" signal from
        // CoreMotion is actually real driving speed, not a misclassified
        // walk/jog/cycle — see beginPendingAutomotiveConfirmation().
        if pendingAutomotiveConfirmation {
            let speedKmh = max(0, location.speed * 3.6)
            if speedKmh >= drivingSpeedThresholdKmh {
                // Even at the moment GPS would otherwise confirm this as a
                // drive, check whether it already looks like a flight (e.g.
                // the phone was already at cruising altitude, or mid-taxi
                // acceleration already reads as a plane) — don't start
                // tracking a "drive" that's actually a flight from the outset.
                if isAircraftSignature(speedKmh: speedKmh, altitude: location.altitude, climbFrom: nil) {
                    cancelPendingAutomotiveConfirmation()
                    return
                }
                cancelPendingAutomotiveConfirmation()
                driveDidStart()
            }
            return
        }

        guard isDriving else { return }
        if startAltitude == nil { startAltitude = location.altitude }

        if isAircraftSignature(speedKmh: max(0, location.speed * 3.6), altitude: location.altitude, climbFrom: startAltitude) {
            // This looked like a real drive at first (e.g. taxiing, or the
            // takeoff roll before liftoff), but has now clearly become a
            // flight — discard it entirely rather than saving a "drive"
            // that would show an impossible top speed or distance.
            cancelDriveAsAircraft()
            return
        }

        if let last = locationBuffer.last {
            liveDistanceKm += location.distance(from: last) / 1000
        }
        locationBuffer.append(location)
        liveRouteCoordinates.append(location.coordinate)
        liveAltitudeMeters = location.altitude
        let speedKmh = max(0, location.speed * 3.6)
        currentSpeedKmh = speedKmh
        liveTopSpeedKmh = max(liveTopSpeedKmh, speedKmh)
        if speedKmh > 0 {
            speedSampleSum += speedKmh
            speedSampleCount += 1
            liveAverageSpeedKmh = speedSampleSum / Double(speedSampleCount)
        }
        if speedKmh < 5 { idleSeconds += 1 }
        if lastSpeed - speedKmh > 25 { hardBrakingCount += 1 }
        if speedKmh - lastSpeed > 20 { fastAccelCount += 1 }
        lastSpeed = speedKmh

        if lastLocationBroadcast == nil || Date().timeIntervalSince(lastLocationBroadcast!) >= locationBroadcastInterval {
            lastLocationBroadcast = Date()
            broadcastLiveStatus(isDriving: true, coordinate: location.coordinate)
        }
    }

    /// True if this reading looks like a flight rather than driving —
    /// see the constants above for exactly which combinations trigger this.
    /// `climbFrom` is the drive's starting altitude, if known; pass nil
    /// when there's no baseline yet (e.g. checking the very first
    /// confirming location before a drive has technically started).
    private func isAircraftSignature(speedKmh: Double, altitude: Double, climbFrom startAltitude: Double?) -> Bool {
        if speedKmh > impossibleDrivingSpeedKmh { return true }
        if altitude > aircraftAltitudeMeters && speedKmh > aircraftAltitudeSpeedThresholdKmh { return true }
        if let startAltitude, altitude - startAltitude > aircraftClimbMeters && speedKmh > aircraftClimbSpeedThresholdKmh {
            return true
        }
        return false
    }

    /// Discards the in-progress drive entirely once it's been identified as
    /// a flight — deliberately does NOT save anything or touch the
    /// leaderboard, as if this "drive" never happened.
    private func cancelDriveAsAircraft() {
        isDriving = false
        currentSpeedKmh = 0
        movingStoppedTimer?.invalidate()
        broadcastLiveStatus(isDriving: false)
        locationBuffer = []
        liveRouteCoordinates = []
        driveStartTime = nil
        startAltitude = nil
    }

    private func driveDidStart() {
        isDriving = true
        driveStartTime = Date()
        startAltitude = nil
        locationBuffer = []
        liveRouteCoordinates = []
        liveDistanceKm = 0
        currentSpeedKmh = 0
        liveAverageSpeedKmh = 0
        liveTopSpeedKmh = 0
        liveAltitudeMeters = 0
        movingSeconds = 0
        stoppedSeconds = 0
        speedSampleSum = 0
        speedSampleCount = 0
        isPassengerMode = false
        hardBrakingCount = 0
        fastAccelCount = 0
        idleSeconds = 0
        lastLocationBroadcast = nil
        NotificationService.shared.sendDriveStartNotification()
        broadcastLiveStatus(isDriving: true)

        movingStoppedTimer?.invalidate()
        movingStoppedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.currentSpeedKmh >= 5 {
                self.movingSeconds += 1
            } else {
                self.stoppedSeconds += 1
            }
        }
    }

    private func driveDidEnd() {
        isDriving = false
        currentSpeedKmh = 0
        startAltitude = nil
        movingStoppedTimer?.invalidate()
        broadcastLiveStatus(isDriving: false)
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
        drive.isPassenger = isPassengerMode
        drive.behaviorScore = calculateBehaviorScore(drive: drive)
        let startLocation = locationBuffer.first
        let endLocation = locationBuffer.last
        Task {
            // Previously nothing ever set these, so every drive showed
            // "Unknown Location" permanently regardless of where it
            // actually happened. Reverse geocoding is best-effort — if it
            // fails (no network, rate limited), the place name stays nil
            // and the UI still falls back to "Unknown Location" rather
            // than crashing or blocking the save.
            drive.startPlaceName = await Self.reverseGeocode(startLocation)
            drive.endPlaceName = await Self.reverseGeocode(endLocation)

            await saveDriveWithRetryQueue(drive, uid: uid)
            await NotificationService.shared.sendDriveEndNotification(drive: drive)
            // If the person marked themselves as a passenger live (via
            // LiveDriveView) rather than after the fact, there's no need to
            // ever add this to the leaderboard just to immediately reverse
            // it — skip it outright.
            if !drive.isPassenger {
                await LeaderboardService.shared.updateLeaderboard(drive: drive, uid: uid)
            }
        }
    }

    /// Converts a coordinate into a short human-readable place name (e.g. a
    /// neighborhood or locality) for display instead of raw lat/lng or a
    /// permanent "Unknown Location" placeholder.
    private static func reverseGeocode(_ location: CLLocation?) async -> String? {
        guard let location else { return nil }
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }
            return placemark.locality ?? placemark.subLocality ?? placemark.name
        } catch {
            return nil
        }
    }

    /// A completed drive is real, one-time data — losing it to a transient
    /// network failure (previously a silent `try?`) means it's gone forever
    /// with zero indication anything went wrong. If the save fails, this
    /// queues the drive to disk and retries on the next app launch/foreground
    /// via retryPendingDrives(), instead of just dropping it.
    private func saveDriveWithRetryQueue(_ drive: Drive, uid: String) async {
        do {
            try await FirebaseService.shared.saveDrive(drive, uid: uid)
        } catch {
            queuePendingDrive(drive, uid: uid)
        }
    }

    private static let pendingDrivesKey = "pendingUnsavedDrives"

    private func queuePendingDrive(_ drive: Drive, uid: String) {
        var pending = loadPendingDrives()
        pending.append(PendingDrive(uid: uid, drive: drive))
        if let encoded = try? JSONEncoder().encode(pending) {
            UserDefaults.standard.set(encoded, forKey: Self.pendingDrivesKey)
        }
    }

    private func loadPendingDrives() -> [PendingDrive] {
        guard let data = UserDefaults.standard.data(forKey: Self.pendingDrivesKey),
              let decoded = try? JSONDecoder().decode([PendingDrive].self, from: data) else { return [] }
        return decoded
    }

    /// Call on app launch/foreground to flush any drives that failed to
    /// save earlier. Each success is removed from the queue individually so
    /// a partial-failure batch doesn't lose progress already made.
    func retryPendingDrives() async {
        let pending = loadPendingDrives()
        guard !pending.isEmpty else { return }
        var stillPending: [PendingDrive] = []
        for item in pending {
            do {
                try await FirebaseService.shared.saveDrive(item.drive, uid: item.uid)
                await LeaderboardService.shared.updateLeaderboard(drive: item.drive, uid: item.uid)
            } catch {
                stillPending.append(item)
            }
        }
        if let encoded = try? JSONEncoder().encode(stillPending) {
            UserDefaults.standard.set(encoded, forKey: Self.pendingDrivesKey)
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

    /// Reports driving status (and optionally location) to Firestore's
    /// `liveStatus/{uid}` doc for friends to read (see
    /// FirebaseService.updateLiveStatus / getFriendsLiveLocations). Ghost
    /// Mode overrides the reported `isDriving` to `false` regardless of
    /// what's actually happening, and drops the coordinate entirely rather
    /// than sending it anyway — this ensures both a stale "still driving"
    /// status *and* a stale/real location from before Ghost Mode was turned
    /// on get actively cleared instead of lingering.
    private func broadcastLiveStatus(isDriving: Bool, coordinate: CLLocationCoordinate2D? = nil) {
        guard let uid = AuthService.shared.currentUser?.uid else { return }
        let reportedValue = isGhostMode ? false : isDriving
        let reportedCoordinate = isGhostMode ? nil : coordinate
        Task {
            await FirebaseService.shared.updateLiveStatus(uid: uid, isDriving: reportedValue, coordinate: reportedCoordinate)
        }
    }
}

/// A drive that finished but failed to save to Firestore, queued to disk
/// so it survives an app relaunch and gets retried later.
private struct PendingDrive: Codable {
    let uid: String
    let drive: Drive
}







