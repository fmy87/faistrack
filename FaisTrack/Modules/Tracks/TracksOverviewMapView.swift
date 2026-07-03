import SwiftUI
import MapKit

/// Shows all published tracks as routes on a single map for browsing.
struct TracksOverviewMapView: UIViewRepresentable {
    let tracks: [Track]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.pointOfInterestFilter = .excludingAll
        mapView.isRotateEnabled = false
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        var allCoordinates: [CLLocationCoordinate2D] = []
        for track in tracks {
            let coordinates = PolylineCodec.decode(track.polylineEncoded)
            guard coordinates.count > 1 else { continue }
            mapView.addOverlay(MKPolyline(coordinates: coordinates, count: coordinates.count))
            if let first = coordinates.first { allCoordinates.append(first) }
            if let last = coordinates.last { allCoordinates.append(last) }
        }

        guard !allCoordinates.isEmpty else { return }
        var zoomRect = MKMapRect.null
        for coordinate in allCoordinates {
            let point = MKMapPoint(coordinate)
            zoomRect = zoomRect.union(MKMapRect(x: point.x, y: point.y, width: 0, height: 0))
        }
        let padding = UIEdgeInsets(top: 32, left: 32, bottom: 32, right: 32)
        mapView.setVisibleMapRect(zoomRect, edgePadding: padding, animated: false)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor(red: 1.0, green: 0.176, blue: 0.176, alpha: 0.85)
            renderer.lineWidth = 3
            return renderer
        }
    }
}
