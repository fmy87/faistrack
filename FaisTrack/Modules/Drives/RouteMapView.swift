import SwiftUI
import MapKit

/// A friend's last-shared location, shown as a pin alongside the user's own
/// route. Only ever populated with friends who are both (a) mutually
/// accepted friends and (b) currently driving with Ghost Mode off — see
/// FirebaseService.getFriendsLiveLocations and the `liveStatus` Firestore
/// rule, which is what actually enforces that restriction server-side.
struct FriendMapPin: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let username: String
}

/// Renders a drive's route on a map using Apple's native MapKit — free,
/// requires no API key, and needs no billing account (unlike the Google
/// Maps SDK this app previously depended on).
struct RouteMapView: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]
    var friendPins: [FriendMapPin] = []

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.pointOfInterestFilter = .excludingAll
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        var boundingPoints: [MKMapPoint] = []

        if coordinates.count > 1 {
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline)
            boundingPoints.append(contentsOf: coordinates.map { MKMapPoint($0) })

            if let start = coordinates.first {
                let startPin = LabeledAnnotation()
                startPin.coordinate = start
                startPin.kind = .start
                mapView.addAnnotation(startPin)
            }
            if let end = coordinates.last {
                let endPin = LabeledAnnotation()
                endPin.coordinate = end
                endPin.kind = .end
                mapView.addAnnotation(endPin)
            }
        }

        for pin in friendPins {
            let annotation = LabeledAnnotation()
            annotation.coordinate = pin.coordinate
            annotation.kind = .friend
            annotation.title = pin.username
            mapView.addAnnotation(annotation)
            boundingPoints.append(MKMapPoint(pin.coordinate))
        }

        guard !boundingPoints.isEmpty else { return }
        let rect = boundingPoints.reduce(MKMapRect.null) { partial, point in
            partial.union(MKMapRect(x: point.x, y: point.y, width: 0, height: 0))
        }
        let padding = UIEdgeInsets(top: 60, left: 40, bottom: 40, right: 40)
        mapView.setVisibleMapRect(rect, edgePadding: padding, animated: false)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private class LabeledAnnotation: MKPointAnnotation {
        enum Kind { case start, end, friend }
        var kind: Kind = .start
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor(red: 1.0, green: 0.176, blue: 0.176, alpha: 1.0) // matches AccentRed #FF2D2D
            renderer.lineWidth = 4
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let point = annotation as? LabeledAnnotation else { return nil }
            switch point.kind {
            case .start, .end:
                let identifier = point.kind == .start ? "start" : "end"
                let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view.markerTintColor = point.kind == .start ? .systemGreen : .systemRed
                view.glyphImage = UIImage(systemName: point.kind == .start ? "flag.fill" : "flag.checkered")
                view.canShowCallout = false
                return view
            case .friend:
                let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "friend")
                view.markerTintColor = .systemBlue
                view.glyphImage = UIImage(systemName: "car.fill")
                view.canShowCallout = true
                return view
            }
        }
    }
}
