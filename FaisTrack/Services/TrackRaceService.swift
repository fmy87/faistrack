import Foundation
import CoreLocation
import Combine

/// Drives the full "compete" flow: approach the start line, detect arrival,
/// run a 10-second countdown once the user taps Start, time the race, and
/// automatically detect the finish line via GPS to stop the clock.
///
/// This stays GPS-only end-to-end — no manual start/end shortcuts. Competing
/// against an already-published Track needs consistent, GPS-verified timing
/// against that track's real recorded coordinates for results to be fair and
/// comparable on its leaderboard. Manual start/end only exists for
/// *creating* a brand new track, where there's no existing target to detect
/// arrival at in the first place — see TrackCreationService.
enum RaceState: Equatable {
    case idle
    case navigatingToStart
    case readyToStart
    case countingDown(Int)
    case racing(elapsed: TimeInterval, distanceToFinish: Double)
    case finished(duration: TimeInterval)
    case cancelled
}

class TrackRaceService: NSObject, ObservableObject {
    static let shared = TrackRaceService()

    @Published var state: RaceState = .idle
    @Published var distanceToStart: Double = 0
    /// The current record holder's telemetry for this track, decoded once
    /// when the race begins — nil/empty if nobody's set a record yet (or
    /// it was set before telemetry capture existed). Both live delta and
    /// the ghost marker read from this.
    @Published private(set) var ghostTelemetry: [TelemetryPoint] = []
    /// Positive = behind the ghost's pace at this point in the run,
    /// negative = ahead. Nil when there's no ghost to compare against.
    @Published private(set) var liveDeltaSeconds: Double?
    /// Where the ghost currently is on the map, interpolated from
    /// ghostTelemetry at the current elapsed time — nil with no ghost data.
    @Published private(set) var ghostPosition: CLLocationCoordinate2D?

    private var track: Track?
    private var raceStartDate: Date?
    private var countdownTimer: Timer?
    private var raceTimer: Timer?
    private var locationCancellable: AnyCancellable?
    private var topSpeedKmh: Double = 0
    /// Cumulative distance actually traveled since the race started —
    /// distinct from distanceToFinish (which shrinks toward the finish
    /// line); this only ever grows, and is what live delta timing indexes
    /// against in the ghost's telemetry.
    private var distanceCoveredMeters: Double = 0
    private var lastSampleLocation: CLLocation?
    private var telemetrySamples: [TelemetryPoint] = []
    private var lastTelemetrySampleTime: Date?
    /// Sampling this often is frequent enough for smooth ghost movement
    /// and accurate delta timing without storing an excessive number of
    /// points for a run that might last a couple of minutes.
    private let telemetrySampleInterval: TimeInterval = 1.5

    /// How close (meters) the user must be to trigger arrival/finish detection.
    /// GPS accuracy in cities is typically 5-15m, so this gives reasonable
    /// tolerance without being so wide that it triggers early.
    private let proximityRadiusMeters: Double = 20
    /// Exposed so CompeteView's countdown UI can compute F1-style light
    /// progression proportionally, without duplicating this number.
    static let countdownDurationSeconds = 10
    private let countdownSeconds = countdownDurationSeconds

    func beginApproaching(track: Track) {
        self.track = track
        ghostTelemetry = TelemetryCodec.decode(track.bestTimeTelemetry)
        state = .navigatingToStart
        LocationService.shared.startUpdating()
        locationCancellable = LocationService.shared.$currentLocation
            .compactMap { $0 }
            .sink { [weak self] location in
                self?.handleLocationUpdate(location)
            }
    }

    private func handleLocationUpdate(_ location: CLLocation) {
        guard let track = track else { return }

        switch state {
        case .navigatingToStart:
            let startLocation = CLLocation(latitude: track.startCoordinate.latitude, longitude: track.startCoordinate.longitude)
            let distance = location.distance(from: startLocation)
            distanceToStart = distance
            if distance <= proximityRadiusMeters {
                state = .readyToStart
            }

        case .racing(let elapsed, _):
            let finishLocation = CLLocation(latitude: track.endCoordinate.latitude, longitude: track.endCoordinate.longitude)
            let distanceToFinish = location.distance(from: finishLocation)
            topSpeedKmh = max(topSpeedKmh, max(0, location.speed * 3.6))

            if let last = lastSampleLocation {
                distanceCoveredMeters += location.distance(from: last)
            }
            lastSampleLocation = location

            if !ghostTelemetry.isEmpty {
                if let ghostElapsed = TelemetryCodec.elapsedTime(atDistance: distanceCoveredMeters, in: ghostTelemetry) {
                    // Positive means the ghost reached this same distance
                    // faster than we did — i.e. we're behind.
                    liveDeltaSeconds = elapsed - ghostElapsed
                }
                ghostPosition = TelemetryCodec.position(atElapsed: elapsed, in: ghostTelemetry)
            }

            if lastTelemetrySampleTime == nil || Date().timeIntervalSince(lastTelemetrySampleTime!) >= telemetrySampleInterval {
                lastTelemetrySampleTime = Date()
                telemetrySamples.append(TelemetryPoint(
                    d: distanceCoveredMeters, t: elapsed,
                    lat: location.coordinate.latitude, lng: location.coordinate.longitude,
                    s: max(0, location.speed * 3.6)
                ))
            }

            state = .racing(elapsed: elapsed, distanceToFinish: distanceToFinish)
            if distanceToFinish <= proximityRadiusMeters {
                finishRace()
            }

        default:
            break
        }
    }

    /// Called when the user taps "Start" after arriving at the start line.
    func userTappedStart() {
        guard case .readyToStart = state else { return }
        var remaining = countdownSeconds
        state = .countingDown(remaining)
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            remaining -= 1
            if remaining > 0 {
                self?.state = .countingDown(remaining)
            } else {
                timer.invalidate()
                self?.startRace()
            }
        }
    }

    private func startRace() {
        raceStartDate = Date()
        topSpeedKmh = 0
        distanceCoveredMeters = 0
        lastSampleLocation = nil
        telemetrySamples = []
        lastTelemetrySampleTime = nil
        liveDeltaSeconds = nil
        ghostPosition = ghostTelemetry.first.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
        state = .racing(elapsed: 0, distanceToFinish: distanceToStart)
        raceTimer?.invalidate()
        raceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.raceStartDate else { return }
            let elapsed = Date().timeIntervalSince(start)
            if case .racing(_, let distanceToFinish) = self.state {
                self.state = .racing(elapsed: elapsed, distanceToFinish: distanceToFinish)
            }
        }
    }

    private func finishRace() {
        guard case .racing = state,
              let start = raceStartDate, let track = track, let uid = AuthService.shared.currentUser?.uid else { return }
        let duration = Date().timeIntervalSince(start)
        raceTimer?.invalidate()
        state = .finished(duration: duration)

        Task {
            let username = (try? await FirebaseService.shared.getUser(uid: uid))?.username
                ?? NSLocalizedString("general.defaultUsername", comment: "")
            let carName = await Self.resolveActiveCarName(uid: uid)
            let result = TrackResult(trackId: track.id ?? "", uid: uid, username: username, duration: duration,
                                      topSpeed: topSpeedKmh, carName: carName)
            try? await FirebaseService.shared.saveTrackResult(result, telemetry: telemetrySamples)
        }
    }

    /// Looks up the car currently marked active in the Garage so it can be
    /// denormalized onto the TrackResult — this is what lets the track's
    /// share card show "which car" without an extra async lookup at
    /// display time. Returns nil if no car is set as active, which the
    /// share card handles by simply omitting the car line.
    static func resolveActiveCarName(uid: String) async -> String? {
        guard let carId = UserDefaults.standard.string(forKey: "activeCarId"), !carId.isEmpty else { return nil }
        let cars = (try? await FirebaseService.shared.getCars(uid: uid)) ?? []
        return cars.first(where: { $0.id == carId })?.displayName
    }

    func reset() {
        countdownTimer?.invalidate()
        raceTimer?.invalidate()
        locationCancellable?.cancel()
        state = .idle
        track = nil
        raceStartDate = nil
        distanceToStart = 0
        ghostTelemetry = []
        liveDeltaSeconds = nil
        ghostPosition = nil
        distanceCoveredMeters = 0
        lastSampleLocation = nil
        telemetrySamples = []
        lastTelemetrySampleTime = nil
    }
}



