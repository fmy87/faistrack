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
    /// When provided (same count/order as `coordinates`), renders the route
    /// as a series of short color-coded segments (green = slow, red = fast)
    /// instead of one solid color — the speed heatmap used on
    /// TrackDetailView. Every other call site (drives, friend live map)
    /// leaves this nil and keeps the plain single-color route exactly as
    /// it was.
    var speedSegmentsKmh: [Double]? = nil
    /// When true, shows the user's live location with a heading-rotating
    /// arrow (Waze/Google Maps driving-mode style) and lets the camera
    /// follow it, instead of repeatedly re-fitting the camera to the whole
    /// route's bounding box — which is what LiveDriveView's map mode wants
    /// (a live, moving view) versus every other call site (a fixed
    /// after-the-fact route to look at in full).
    var liveFollow: Bool = false

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.pointOfInterestFilter = .excludingAll
        mapView.isRotateEnabled = liveFollow
        mapView.isPitchEnabled = false
        if liveFollow {
            mapView.showsUserLocation = true
            mapView.userTrackingMode = .followWithHeading
        }
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        var boundingPoints: [MKMapPoint] = []

        if coordinates.count > 1 {
            if let speeds = speedSegmentsKmh, speeds.count == coordinates.count {
                for i in 1..<coordinates.count {
                    let segment = SpeedSegmentPolyline(coordinates: [coordinates[i - 1], coordinates[i]], count: 2)
                    segment.color = UIColor(SpeedGaugeView.colorForSpeed((speeds[i - 1] + speeds[i]) / 2))
                    mapView.addOverlay(segment)
                }
            } else {
                let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                mapView.addOverlay(polyline)
            }
            boundingPoints.append(contentsOf: coordinates.map { MKMapPoint($0) })

            // In live-follow mode the start/end pins would just clutter a
            // camera that's tracking the user's current position, not
            // looking at the route as a whole — skip them there.
            if !liveFollow {
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
        }

        for pin in friendPins {
            let annotation = LabeledAnnotation()
            annotation.coordinate = pin.coordinate
            annotation.kind = .friend
            annotation.title = pin.username
            mapView.addAnnotation(annotation)
            boundingPoints.append(MKMapPoint(pin.coordinate))
        }

        // Live-follow mode manages its own camera via userTrackingMode —
        // repeatedly re-fitting bounds here would fight that and make the
        // map jitter between "look at the route" and "follow the user."
        guard !liveFollow, !boundingPoints.isEmpty else { return }
        let rect = boundingPoints.reduce(MKMapRect.null) { partial, point in
            partial.union(MKMapRect(x: point.x, y: point.y, width: 0, height: 0))
        }
        let padding = UIEdgeInsets(top: 60, left: 40, bottom: 40, right: 40)
        mapView.setVisibleMapRect(rect, edgePadding: padding, animated: false)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// Carries its own color so the renderer can paint each short segment
    /// differently — a plain MKPolyline has no room for per-overlay data,
    /// which is why the heatmap needs many small polylines instead of one.
    private final class SpeedSegmentPolyline: MKPolyline {
        var color: UIColor = .white
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
            if let segment = overlay as? SpeedSegmentPolyline {
                renderer.strokeColor = segment.color
                renderer.lineWidth = 5
            } else {
                renderer.strokeColor = UIColor(red: 1.0, green: 0.176, blue: 0.176, alpha: 1.0) // matches AccentRed #FF2D2D
                renderer.lineWidth = 4
            }
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


