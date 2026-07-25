import CoreLocation
import Combine

/// Deliberately foreground-only now — see the docs on allowsBackgroundLocationUpdates
/// below for the reasoning and the tradeoff this accepts.
class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()
    private let manager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 10
        // Previously this ran continuously in the background (Always
        // authorization + allowsBackgroundLocationUpdates + never actually
        // stopped once started at app launch) — the tradeoff being
        // continuous best-accuracy GPS running 24/7 regardless of whether
        // a drive was even happening, which is real, measurable battery
        // drain. This is now foreground-only by design: updates only run
        // while the app itself is open (see MainTabView's scenePhase
        // handling for start/stop), at the cost of no longer being able to
        // detect a drive starting while the app is backgrounded or closed.
        // That's a real capability being traded away, not a side effect —
        // it's the whole point of the change.
        manager.allowsBackgroundLocationUpdates = false
        manager.pausesLocationUpdatesAutomatically = true
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdating() {
        manager.startUpdatingLocation()
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
        DriveDetectionService.shared.processLocation(locations.last)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse {
            startUpdating()
        }
    }
}
