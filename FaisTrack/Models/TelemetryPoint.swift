import Foundation

/// A single sample captured periodically during a track attempt — distance
/// covered, elapsed time, position, and speed at that moment. This one
/// structure is what powers four separate features: live delta timing
/// (compare elapsed time at the same distance), ghost racing (find position
/// at the same elapsed time), the speed heatmap (color the route by speed),
/// and — indirectly — the Track Legend badge (needs to know when the
/// current record was set, stored alongside this).
///
/// Only ever persisted for the *current record holder's* run on a given
/// track (see Track.bestTimeTelemetry) — storing this for every single
/// attempt ever made would bloat Firestore for no real benefit, since only
/// the record run is what anyone races against.
struct TelemetryPoint: Codable {
    /// Meters covered since the start of this attempt.
    let d: Double
    /// Seconds elapsed since the start of this attempt.
    let t: Double
    let lat: Double
    let lng: Double
    /// km/h at this sample.
    let s: Double
    /// Meters above sea level, for the elevation profile chart. Optional
    /// (not just given a default) because telemetry saved before this
    /// field existed has no value for it at all — a plain default doesn't
    /// help a synthesized Decodable when the key is genuinely missing,
    /// only Optional does. Old records simply won't have an elevation
    /// chart; nothing breaks decoding the rest of the point.
    let alt: Double?
}

