import CoreLocation
import Combine

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
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        manager.requestAlwaysAuthorization()
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
        // Start updating for either authorization level — iOS often grants
        // "When In Use" first even when Always was requested, only upgrading
        // to Always later. Waiting for .authorizedAlways alone meant location
        // detection silently never started for users on that common path.
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            startUpdating()
        default:
            break
        }
    }
}
