import SwiftUI
import MapKit

/// Lets the admin tap directly on a map to place a track's start and end
/// points — first tap sets start (green), second sets end (red), a third
/// tap starts over. This is what makes AdminCreateTrackView possible
/// without anyone physically driving the route.
struct AdminTrackMapPicker: UIViewRepresentable {
    @Binding var startCoordinate: CLLocationCoordinate2D?
    @Binding var endCoordinate: CLLocationCoordinate2D?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        if let userLocation = LocationService.shared.currentLocation?.coordinate {
            mapView.setRegion(MKCoordinateRegion(center: userLocation, latitudinalMeters: 3000, longitudinalMeters: 3000), animated: false)
        }
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tap)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        mapView.removeAnnotations(mapView.annotations)
        if let start = startCoordinate {
            let annotation = MKPointAnnotation()
            annotation.coordinate = start
            annotation.title = "Start"
            mapView.addAnnotation(annotation)
        }
        if let end = endCoordinate {
            let annotation = MKPointAnnotation()
            annotation.coordinate = end
            annotation.title = "End"
            mapView.addAnnotation(annotation)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: AdminTrackMapPicker
        init(_ parent: AdminTrackMapPicker) { self.parent = parent }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            // First tap places start, second places end, a third tap
            // starts the selection over rather than requiring a separate
            // "clear" control.
            if parent.startCoordinate == nil {
                parent.startCoordinate = coordinate
            } else if parent.endCoordinate == nil {
                parent.endCoordinate = coordinate
            } else {
                parent.startCoordinate = coordinate
                parent.endCoordinate = nil
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let title = annotation.title ?? nil else { return nil }
            let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: title)
            view.markerTintColor = title == "Start" ? .systemGreen : .systemRed
            view.glyphImage = UIImage(systemName: title == "Start" ? "flag.fill" : "flag.checkered")
            return view
        }
    }
}
