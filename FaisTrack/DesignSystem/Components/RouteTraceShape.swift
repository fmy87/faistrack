import SwiftUI
import CoreLocation

/// Traces a recorded route (from any polyline-decoded coordinate array)
/// into a small drawing area, normalizing lat/lng into the shape's bounds.
/// Originally built just for TrackShareCard, now shared with DriveRowView
/// so every drive/track card can show its own actual route shape instead of
/// a generic icon — makes each card visually distinct at a glance.
struct RouteTraceShape: Shape {
    let coordinates: [CLLocationCoordinate2D]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard coordinates.count > 1 else { return path }

        let lats = coordinates.map(\.latitude)
        let lngs = coordinates.map(\.longitude)
        let minLat = lats.min() ?? 0, maxLat = lats.max() ?? 0
        let minLng = lngs.min() ?? 0, maxLng = lngs.max() ?? 0
        // Guards against a division by zero for a perfectly straight
        // north-south or east-west route, where one range would be 0.
        let latRange = max(maxLat - minLat, 0.00001)
        let lngRange = max(maxLng - minLng, 0.00001)
        let padding: CGFloat = 8

        func point(for coordinate: CLLocationCoordinate2D) -> CGPoint {
            let x = padding + CGFloat((coordinate.longitude - minLng) / lngRange) * (rect.width - padding * 2)
            // Latitude increases northward, but SwiftUI's y-axis increases
            // downward — flip so the route isn't drawn upside down.
            let y = padding + CGFloat(1 - (coordinate.latitude - minLat) / latRange) * (rect.height - padding * 2)
            return CGPoint(x: x, y: y)
        }

        path.move(to: point(for: coordinates[0]))
        for coordinate in coordinates.dropFirst() {
            path.addLine(to: point(for: coordinate))
        }
        return path
    }
}
