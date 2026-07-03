import SwiftUI
import MapKit

/// Renders a drive's route on a map using Apple's native MapKit — free,
/// requires no API key, and needs no billing account (unlike the Google
/// Maps SDK this app previously depended on).
struct RouteMapView: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]

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

        guard coordinates.count > 1 else { return }

        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)

        if let start = coordinates.first {
            let startPin = MKPointAnnotation()
            startPin.coordinate = start
            startPin.title = "start"
            mapView.addAnnotation(startPin)
        }
        if let end = coordinates.last {
            let endPin = MKPointAnnotation()
            endPin.coordinate = end
            endPin.title = "end"
            mapView.addAnnotation(endPin)
        }

        let padding = UIEdgeInsets(top: 32, left: 32, bottom: 32, right: 32)
        mapView.setVisibleMapRect(polyline.boundingMapRect, edgePadding: padding, animated: false)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
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
            guard let point = annotation as? MKPointAnnotation else { return nil }
            let isStart = point.title == "start"
            let identifier = isStart ? "start" : "end"
            let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.markerTintColor = isStart ? .systemGreen : .systemRed
            view.glyphImage = UIImage(systemName: isStart ? "flag.fill" : "flag.checkered")
            view.canShowCallout = false
            return view
        }
    }
}
