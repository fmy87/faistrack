import SwiftUI

/// The user's own times on one specific track, charted across their
/// attempts in order — "am I getting faster at this one?" answered with an
/// actual trend line instead of just a single best-time number. Built with
/// plain SwiftUI Path (not Apple's Charts framework, which needs iOS 16+
/// while this app targets 15) — same approach as ElevationProfileView.
///
/// The line is drawn so faster times sit higher on the chart — an upward
/// slope reads as "getting faster," which matches how people intuitively
/// expect a progress chart to look, rather than a literal plot of duration
/// where improvement would confusingly trend downward.
struct LapProgressionChartView: View {
    /// Chronological order (oldest attempt first) — the caller is
    /// responsible for sorting/filtering to just this user's own results.
    let durations: [Double]

    var body: some View {
        Group {
            if durations.count > 1 {
                let maxDuration = durations.max() ?? 1
                let minDuration = durations.min() ?? 0
                // Guards against dividing by zero if every attempt was
                // exactly the same time.
                let range = max(maxDuration - minDuration, 0.01)

                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("track.progression", comment: ""))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.ftTextSecondary)

                    GeometryReader { geo in
                        let stepX = durations.count > 1 ? geo.size.width / CGFloat(durations.count - 1) : 0

                        ZStack {
                            Path { path in
                                for (index, duration) in durations.enumerated() {
                                    let x = CGFloat(index) * stepX
                                    // Inverted: a faster (lower) duration
                                    // maps higher up the chart.
                                    let normalized = (maxDuration - duration) / range
                                    let y = geo.size.height - CGFloat(normalized) * geo.size.height
                                    if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                                }
                            }
                            .stroke(Color.ftAccent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                            ForEach(Array(durations.enumerated()), id: \.offset) { index, duration in
                                let x = CGFloat(index) * stepX
                                let normalized = (maxDuration - duration) / range
                                let y = geo.size.height - CGFloat(normalized) * geo.size.height
                                Circle()
                                    .fill(index == durations.count - 1 ? Color.ftAccentOrange : Color.ftAccent)
                                    .frame(width: 6, height: 6)
                                    .position(x: x, y: y)
                            }
                        }
                    }
                    .frame(height: 70)

                    HStack {
                        Text(String(format: "%.1fs", minDuration))
                        Spacer()
                        Text(String(format: NSLocalizedString("track.progression.attempts", comment: ""), durations.count))
                        Spacer()
                        Text(String(format: "%.1fs", maxDuration))
                    }
                    .font(.system(size: 11)).foregroundColor(.ftTextSecondary)
                }
            }
        }
    }
}
