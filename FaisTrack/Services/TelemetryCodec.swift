import Foundation
import CoreLocation

/// Encodes/decodes [TelemetryPoint] to/from a compact JSON string for
/// storage on a Track document, plus the lookup math shared by live delta
/// timing and ghost racing — both are really the same operation (find two
/// bracketing samples and interpolate) just indexed on a different axis
/// (distance vs. elapsed time).
enum TelemetryCodec {
    static func encode(_ points: [TelemetryPoint]) -> String? {
        guard let data = try? JSONEncoder().encode(points) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode(_ string: String?) -> [TelemetryPoint] {
        guard let string, let data = string.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([TelemetryPoint].self, from: data)) ?? []
    }

    /// For live delta timing: given how far the current attempt has
    /// traveled, what elapsed time had the reference run (usually the
    /// record holder) reached at that same distance? Interpolates between
    /// the two bracketing samples rather than snapping to the nearest one,
    /// since samples are only taken every couple of seconds.
    static func elapsedTime(atDistance distance: Double, in points: [TelemetryPoint]) -> Double? {
        guard !points.isEmpty else { return nil }
        if distance <= points[0].d { return points[0].t }
        if distance >= points[points.count - 1].d { return points[points.count - 1].t }
        for i in 1..<points.count {
            let a = points[i - 1], b = points[i]
            if distance >= a.d && distance <= b.d {
                guard b.d > a.d else { return a.t }
                let fraction = (distance - a.d) / (b.d - a.d)
                return a.t + (b.t - a.t) * fraction
            }
        }
        return nil
    }

    /// For ghost racing: given how much time has elapsed in the current
    /// attempt, where was the reference run at that same elapsed time?
    /// Interpolates position between the two bracketing samples so the
    /// ghost marker moves smoothly rather than jumping sample-to-sample.
    static func position(atElapsed elapsed: Double, in points: [TelemetryPoint]) -> CLLocationCoordinate2D? {
        guard !points.isEmpty else { return nil }
        if elapsed <= points[0].t { return CLLocationCoordinate2D(latitude: points[0].lat, longitude: points[0].lng) }
        let last = points[points.count - 1]
        if elapsed >= last.t { return CLLocationCoordinate2D(latitude: last.lat, longitude: last.lng) }
        for i in 1..<points.count {
            let a = points[i - 1], b = points[i]
            if elapsed >= a.t && elapsed <= b.t {
                guard b.t > a.t else { return CLLocationCoordinate2D(latitude: a.lat, longitude: a.lng) }
                let fraction = (elapsed - a.t) / (b.t - a.t)
                return CLLocationCoordinate2D(
                    latitude: a.lat + (b.lat - a.lat) * fraction,
                    longitude: a.lng + (b.lng - a.lng) * fraction
                )
            }
        }
        return nil
    }
}
