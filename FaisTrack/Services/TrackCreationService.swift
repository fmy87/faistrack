import Foundation
import CoreLocation
import Combine

enum TrackCreationState: Equatable {
    case idle
    case countingDown(Int)
    case recording(elapsed: TimeInterval, distance: Double)
    case finished(distance: Double, duration: TimeInterval)
}

/// Lets a user manually record a brand new Track live by driving it
/// themselves — start with a countdown, drive, then manually end when they
/// reach their finish point.
///
/// This is deliberately separate from TrackRaceService (competing on an
/// *existing* track): there, GPS must be the only source of truth so results
/// are fair and comparable against that track's real recorded coordinates.
/// Here, there's no existing track to match yet — the user's own start/end
/// taps are what *define* the new track's start and finish points, with GPS
/// supplying the coordinates recorded along the way.
class TrackCreationService: NSObject, ObservableObject {
    static let shared = TrackCreationService()

    @Published var state: TrackCreationState = .idle
    @Published var errorMessage: String?

    private var coordinates: [CLLocationCoordinate2D] = []
    private var recordingStartDate: Date?
    private var countdownTimer: Timer?
    private var recordingTimer: Timer?
    private var locationCancellable: AnyCancellable?
    private let countdownSeconds = 3

    func beginCountdown() {
        coordinates = []
        errorMessage = nil
        var remaining = countdownSeconds
        state = .countingDown(remaining)
        LocationService.shared.startUpdating()
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            remaining -= 1
            if remaining > 0 {
                self?.state = .countingDown(remaining)
            } else {
                timer.invalidate()
                self?.startRecording()
            }
        }
    }

    private func startRecording() {
        recordingStartDate = Date()
        state = .recording(elapsed: 0, distance: 0)
        locationCancellable = LocationService.shared.$currentLocation
            .compactMap { $0 }
            .sink { [weak self] location in
                self?.appendLocation(location)
            }
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, let start = self.recordingStartDate,
                  case .recording(_, let distance) = self.state else { return }
            self.state = .recording(elapsed: Date().timeIntervalSince(start), distance: distance)
        }
    }

    private func appendLocation(_ location: CLLocation) {
        guard case .recording(let elapsed, var distance) = state else { return }
        if let last = coordinates.last {
            let lastLocation = CLLocation(latitude: last.latitude, longitude: last.longitude)
            distance += location.distance(from: lastLocation)
        }
        coordinates.append(location.coordinate)
        state = .recording(elapsed: elapsed, distance: distance)
    }

    /// Ends recording. Unlike TrackRaceService, there's no automatic
    /// GPS-proximity trigger here — this is the only way this flow finishes,
    /// since there's no pre-existing finish point to detect arrival at.
    func endRecording() {
        guard case .recording(let elapsed, let distance) = state, coordinates.count > 1 else {
            errorMessage = NSLocalizedString("createTrack.tooShort", comment: "")
            reset()
            return
        }
        recordingTimer?.invalidate()
        locationCancellable?.cancel()
        state = .finished(distance: distance, duration: elapsed)
    }

    /// Saves the just-recorded run as a new Track, seeded with the creator's
    /// own run as its first leaderboard result.
    @discardableResult
    func saveTrack(name: String) async -> Bool {
        guard case .finished(let distance, let duration) = state,
              let first = coordinates.first, let last = coordinates.last,
              let uid = AuthService.shared.currentUser?.uid else {
            errorMessage = NSLocalizedString("createTrack.tooShort", comment: "")
            return false
        }
        guard distance >= Track.minimumDistanceMeters else {
            errorMessage = NSLocalizedString("createTrack.tooShort", comment: "")
            return false
        }
        do {
            let username = (try? await FirebaseService.shared.getUser(uid: uid))?.username
                ?? NSLocalizedString("general.defaultUsername", comment: "")
            let track = Track(
                ownerUID: uid,
                ownerUsername: username,
                name: name.isEmpty ? NSLocalizedString("tracks.defaultName", comment: "") : name,
                startLatitude: first.latitude,
                startLongitude: first.longitude,
                endLatitude: last.latitude,
                endLongitude: last.longitude,
                distance: distance,
                polylineEncoded: PolylineCodec.encode(coordinates)
            )
            let trackId = try await FirebaseService.shared.createTrack(track)
            let result = TrackResult(trackId: trackId, uid: uid, username: username, duration: duration)
            try await FirebaseService.shared.saveTrackResult(result)
            reset()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func reset() {
        countdownTimer?.invalidate()
        recordingTimer?.invalidate()
        locationCancellable?.cancel()
        coordinates = []
        recordingStartDate = nil
        state = .idle
    }
}
