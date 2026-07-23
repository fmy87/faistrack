import SwiftUI
import MapKit

/// A map for actively racing a track — distinct from RouteMapView (used for
/// static after-the-fact route display) because the behavior needed here is
/// different: follow the user's live position rather than re-fitting the
/// camera to bounds on every single update (which would feel jittery during
/// a live race), and show the ghost — the record holder's position at this
/// same moment in the run — as a separate moving marker.
struct RaceMapView: UIViewRepresentable {
    let routeCoordinates: [CLLocationCoordinate2D]
    let ghostPosition: CLLocationCoordinate2D?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.pointOfInterestFilter = .excludingAll
        mapView.isRotateEnabled = false
        mapView.showsUserLocation = true
        // .followWithHeading rotates both the map and the user's location
        // marker to face the direction of travel — the same behavior
        // Waze/Google Maps use in driving mode, rather than a static dot
        // that doesn't communicate which way you're actually pointed.
        mapView.userTrackingMode = .followWithHeading
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        if context.coordinator.lastRouteCount != routeCoordinates.count {
            mapView.overlays.forEach(mapView.removeOverlay)
            if routeCoordinates.count > 1 {
                mapView.addOverlay(MKPolyline(coordinates: routeCoordinates, count: routeCoordinates.count))
            }
            context.coordinator.lastRouteCount = routeCoordinates.count
        }

        mapView.annotations.filter { $0 is GhostAnnotation }.forEach(mapView.removeAnnotation)
        if let ghostPosition {
            let annotation = GhostAnnotation()
            annotation.coordinate = ghostPosition
            mapView.addAnnotation(annotation)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private final class GhostAnnotation: MKPointAnnotation {}

    final class Coordinator: NSObject, MKMapViewDelegate {
        var lastRouteCount = 0

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKPolylineRenderer(polyline: polyline)
            // Dim/translucent — this is just the reference line for the
            // track, not something that should compete visually with the
            // user's own live blue dot or the ghost marker.
            renderer.strokeColor = UIColor.white.withAlphaComponent(0.35)
            renderer.lineWidth = 4
            renderer.lineCap = .round
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation is GhostAnnotation else { return nil }
            let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "ghost")
            view.markerTintColor = .systemPurple
            view.glyphImage = UIImage(systemName: "circle.dashed")
            view.canShowCallout = false
            return view
        }
    }
}

