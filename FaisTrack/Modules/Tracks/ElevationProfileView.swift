import SwiftUI

/// A simple filled line chart of elevation vs. distance along a track's
/// recorded route — built with Canvas/Path rather than Apple's Charts
/// framework, which needs iOS 16+ while this app targets iOS 15. Renders
/// nothing at all when there's no altitude data (telemetry captured before
/// TelemetryPoint.alt existed, or fewer than 2 usable points).
struct ElevationProfileView: View {
    let points: [TelemetryPoint]

    private var elevations: [Double] { points.compactMap(\.alt) }

    var body: some View {
        Group {
            if elevations.count > 1 {
                let minAlt = elevations.min() ?? 0
                let maxAlt = elevations.max() ?? 0
                // Guards against dividing by zero on a perfectly flat
                // route, where max and min would otherwise be equal.
                let range = max(maxAlt - minAlt, 1)
                let maxDistance = max(points.last?.d ?? 1, 1)

                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("track.elevation", comment: ""))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.ftTextSecondary)

                    GeometryReader { geo in
                        ZStack(alignment: .bottomLeading) {
                            // Filled area under the line for an actual
                            // "profile" silhouette rather than just a line.
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: geo.size.height))
                                for point in points {
                                    guard let alt = point.alt else { continue }
                                    let x = CGFloat(point.d / maxDistance) * geo.size.width
                                    let normalized = (alt - minAlt) / range
                                    let y = geo.size.height - CGFloat(normalized) * geo.size.height
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                                path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                                path.closeSubpath()
                            }
                            .fill(LinearGradient(
                                colors: [Color.ftAccent.opacity(0.35), Color.ftAccent.opacity(0.03)],
                                startPoint: .top, endPoint: .bottom
                            ))

                            Path { path in
                                var started = false
                                for point in points {
                                    guard let alt = point.alt else { continue }
                                    let x = CGFloat(point.d / maxDistance) * geo.size.width
                                    let normalized = (alt - minAlt) / range
                                    let y = geo.size.height - CGFloat(normalized) * geo.size.height
                                    if started { path.addLine(to: CGPoint(x: x, y: y)) }
                                    else { path.move(to: CGPoint(x: x, y: y)); started = true }
                                }
                            }
                            .stroke(Color.ftAccent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        }
                    }
                    .frame(height: 70)

                    HStack {
                        Text(String(format: "%.0f m", minAlt))
                        Spacer()
                        Text(String(format: "%.0f m", maxAlt))
                    }
                    .font(.system(size: 11)).foregroundColor(.ftTextSecondary)
                }
            }
        }
    }
}
