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

    /// Single source of truth for the free-tier cap — CreateTrackView
    /// reads this same constant for its UI gate, so the two can't drift
    /// out of sync with each other.
    static let freeTrackLimit = 3

    @Published var state: TrackCreationState = .idle
    @Published var errorMessage: String?
    /// Live instantaneous speed, feeding the same SpeedGaugeView used on
    /// LiveDriveView so this screen shares that visual language instead of
    /// being a bare text readout.
    @Published private(set) var currentSpeedKmh: Double = 0
    @Published private(set) var routeCoordinates: [CLLocationCoordinate2D] = []

    private var coordinates: [CLLocationCoordinate2D] = []
    private var recordingStartDate: Date?
    private var countdownTimer: Timer?
    private var recordingTimer: Timer?
    private var locationCancellable: AnyCancellable?
    /// Exposed so CreateTrackView's countdown UI can compute F1-style light
    /// progression proportionally, without duplicating this number.
    static let countdownDurationSeconds = 3
    private let countdownSeconds = countdownDurationSeconds
    /// Max of currentSpeedKmh over the whole recording — currentSpeedKmh
    /// itself is instantaneous and gets reset when recording ends, so this
    /// is the only place the actual top speed for the run is captured.
    private var topSpeedKmh: Double = 0
    /// The creator's own run becomes the track's first record by
    /// definition, so it needs the same telemetry sampling TrackRaceService
    /// does — this is what seeds the very first ghost/heatmap/delta data
    /// for a brand new track, before anyone else has ever attempted it.
    private var telemetrySamples: [TelemetryPoint] = []
    private var lastTelemetrySampleTime: Date?
    private let telemetrySampleInterval: TimeInterval = 1.5

    func beginCountdown() {
        coordinates = []
        routeCoordinates = []
        currentSpeedKmh = 0
        topSpeedKmh = 0
        telemetrySamples = []
        lastTelemetrySampleTime = nil
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
        routeCoordinates = coordinates
        currentSpeedKmh = max(0, location.speed * 3.6)
        topSpeedKmh = max(topSpeedKmh, currentSpeedKmh)

        if lastTelemetrySampleTime == nil || Date().timeIntervalSince(lastTelemetrySampleTime!) >= telemetrySampleInterval {
            lastTelemetrySampleTime = Date()
            telemetrySamples.append(TelemetryPoint(
                d: distance, t: elapsed,
                lat: location.coordinate.latitude, lng: location.coordinate.longitude,
                s: currentSpeedKmh, alt: location.altitude
            ))
        }

        state = .recording(elapsed: elapsed, distance: distance)
    }

    /// Ends recording. Unlike TrackRaceService, there's no automatic
    /// GPS-proximity trigger here — this is the only way this flow finishes,
    /// since there's no pre-existing finish point to detect arrival at.
    func endRecording() {
        guard case .recording(let elapsed, let distance) = state, coordinates.count > 1 else {
            errorMessage = NSLocalizedString("createTrack.tooFewPoints", comment: "")
            reset()
            return
        }
        recordingTimer?.invalidate()
        locationCancellable?.cancel()
        currentSpeedKmh = 0
        state = .finished(distance: distance, duration: elapsed)
    }

    /// Saves the just-recorded run as a new Track, seeded with the creator's
    /// own run as its first leaderboard result.
    @discardableResult
    func saveTrack(name: String) async -> Bool {
        guard case .finished(let distance, let duration) = state,
              let first = coordinates.first, let last = coordinates.last,
              let uid = AuthService.shared.currentUser?.uid else {
            errorMessage = NSLocalizedString("createTrack.tooFewPoints", comment: "")
            return false
        }
        // CreateTrackView already disables its Start button once a free
        // account hits the cap, but that's only a UI-level gate — anything
        // else that could reach this method directly (or a future screen
        // that forgets to check first) would bypass it entirely. This is
        // the actual enforcement point the cap can't be skipped past.
        if !StoreKitService.shared.isPro && !AdminConfig.isCurrentUserAdmin {
            let ownedCount = (try? await FirebaseService.shared.getTrackCount(ownerUID: uid)) ?? 0
            guard ownedCount < Self.freeTrackLimit else {
                errorMessage = String(format: NSLocalizedString("createTrack.limitReached.subtitle", comment: ""), Self.freeTrackLimit)
                return false
            }
        }
        // Enforced here too, not just in the UI's disabled-button state —
        // a track's name should always come from the person who created
        // it, never silently fall back to a generic default.
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = NSLocalizedString("createTrack.nameRequired", comment: "")
            return false
        }
        guard distance >= Track.minimumDistanceMeters else {
            // Previously this just said "too short" with no numbers — if
            // someone recorded a real drive and it still failed (weak GPS
            // undercounting distance, or a genuinely short lap), they had
            // no way to tell whether they were close or way off. Showing
            // both numbers makes the actual gap obvious instead of feeling
            // like the save is silently broken.
            let recorded = distance >= 1000 ? String(format: "%.2f km", distance / 1000) : String(format: "%.0f m", distance)
            let required = String(format: "%.0f m", Track.minimumDistanceMeters)
            errorMessage = String(format: NSLocalizedString("createTrack.tooShort", comment: ""), required, recorded)
            return false
        }
        do {
            let username = (try? await FirebaseService.shared.getUser(uid: uid))?.username
                ?? NSLocalizedString("general.defaultUsername", comment: "")
            let track = Track(
                ownerUID: uid,
                ownerUsername: username,
                name: name,
                startLatitude: first.latitude,
                startLongitude: first.longitude,
                endLatitude: last.latitude,
                endLongitude: last.longitude,
                distance: distance,
                polylineEncoded: PolylineCodec.encode(coordinates)
            )
            let trackId = try await FirebaseService.shared.createTrack(track)
            let carName = await TrackRaceService.resolveActiveCarName(uid: uid)
            let result = TrackResult(trackId: trackId, uid: uid, username: username, duration: duration,
                                      topSpeed: topSpeedKmh, carName: carName)
            try await FirebaseService.shared.saveTrackResult(result, telemetry: telemetrySamples)
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
        telemetrySamples = []
        lastTelemetrySampleTime = nil
        recordingStartDate = nil
        state = .idle
    }
}







