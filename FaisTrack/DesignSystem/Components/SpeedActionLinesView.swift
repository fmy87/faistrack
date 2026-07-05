import SwiftUI

/// Radiating motion lines behind the speed gauge that spin faster and grow
/// brighter/longer as speed increases — the "action" feel behind an
/// otherwise static gauge readout during a live drive or race. Purely
/// decorative, sits behind SpeedGaugeView.
struct SpeedActionLinesView: View {
    let speedKmh: Double
    let color: Color

    /// Speed at which the effect is at full intensity — deliberately below
    /// most real top speeds so the effect is clearly visible well before
    /// someone's going dangerously fast, not just at the very top of the gauge.
    private let maxEffectSpeed: Double = 120
    private let lineCount = 28

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let intensity = min(speedKmh / maxEffectSpeed, 1.0)
                guard intensity > 0.02 else { return }

                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let rotationSpeed = 0.35 + intensity * 2.4
                let baseAngle = time * rotationSpeed
                let innerRadius = min(size.width, size.height) * 0.42
                let outerRadius = innerRadius + 12 + intensity * 46

                for i in 0..<lineCount {
                    let angle = baseAngle + (Double(i) / Double(lineCount)) * 2 * .pi
                    let x1 = center.x + CGFloat(cos(angle)) * innerRadius
                    let y1 = center.y + CGFloat(sin(angle)) * innerRadius
                    let x2 = center.x + CGFloat(cos(angle)) * outerRadius
                    let y2 = center.y + CGFloat(sin(angle)) * outerRadius

                    var path = Path()
                    path.move(to: CGPoint(x: x1, y: y1))
                    path.addLine(to: CGPoint(x: x2, y: y2))

                    context.stroke(
                        path,
                        with: .color(color.opacity(0.12 + intensity * 0.38)),
                        lineWidth: 1.5 + intensity * 2.5
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
