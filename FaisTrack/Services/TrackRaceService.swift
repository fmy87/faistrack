import Foundation
import CoreLocation
import Combine

/// Drives the full "compete" flow: approach the start line, detect arrival,
/// run a 10-second countdown once the user taps Start, time the race, and
/// automatically detect the finish line via GPS to stop the clock.
///
/// Manual "start now" / "end race" controls exist as a fallback for when GPS
/// proximity detection is slow or unreliable, but they don't replace GPS
/// tracking — location updates keep flowing and can still trigger the same
/// transitions automatically. See skipToReadyToStart() and endRaceManually().
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

    private var track: Track?
    private var raceStartDate: Date?
    private var countdownTimer: Timer?
    private var raceTimer: Timer?
    private var locationCancellable: AnyCancellable?

    /// How close (meters) the user must be to trigger arrival/finish detection.
    /// GPS accuracy in cities is typically 5-15m, so this gives reasonable
    /// tolerance without being so wide that it triggers early.
    private let proximityRadiusMeters: Double = 20
    private let countdownSeconds = 10

    func beginApproaching(track: Track) {
        self.track = track
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
            state = .racing(elapsed: elapsed, distanceToFinish: distanceToFinish)
            if distanceToFinish <= proximityRadiusMeters {
                finishRace()
            }

        default:
            break
        }
    }

    /// Lets the user skip *waiting* for GPS proximity to unlock the
    /// countdown — GPS tracking itself keeps running underneath exactly as
    /// before (handleLocationUpdate still fires on every location update),
    /// this just removes the requirement to be within proximityRadiusMeters
    /// before the "Start" button becomes available. Useful when GPS accuracy
    /// near the recorded start point is poor.
    func skipToReadyToStart() {
        guard case .navigatingToStart = state else { return }
        state = .readyToStart
    }

    /// Lets the user manually end the race. GPS-based finish detection stays
    /// active the whole time this is available (handleLocationUpdate's
    /// `.racing` case keeps computing distanceToFinish and can still trigger
    /// finishRace() automatically) — this is just an additional way to reach
    /// the same finishRace() call, guarded there so only one of the two
    /// (automatic or manual) can actually complete the race.
    func endRaceManually() {
        guard case .racing = state else { return }
        finishRace()
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

    /// Ends the race and submits the result. Guarded on `.racing` so that if
    /// GPS crosses the finish radius at the same moment the user taps "End
    /// Race" manually, only the first of the two calls actually runs —
    /// otherwise both paths could fire within the same location-update tick
    /// and submit two results for one race.
    private func finishRace() {
        guard case .racing = state,
              let start = raceStartDate, let track = track, let uid = AuthService.shared.currentUser?.uid else { return }
        let duration = Date().timeIntervalSince(start)
        raceTimer?.invalidate()
        state = .finished(duration: duration)

        Task {
            let username = (try? await FirebaseService.shared.getUser(uid: uid))?.username
                ?? NSLocalizedString("general.defaultUsername", comment: "")
            let result = TrackResult(trackId: track.id ?? "", uid: uid, username: username, duration: duration)
            try? await FirebaseService.shared.saveTrackResult(result)
        }
    }

    func reset() {
        countdownTimer?.invalidate()
        raceTimer?.invalidate()
        locationCancellable?.cancel()
        state = .idle
        track = nil
        raceStartDate = nil
        distanceToStart = 0
    }
}

