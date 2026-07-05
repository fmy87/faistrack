import SwiftUI

/// A car silhouette that drifts across the screen on a loop, trailing tire
/// smoke and exhaust flame — purely decorative atmosphere for the login
/// screen, layered on top of SpeedLinesBackground. Built from an SF Symbol
/// plus a hand-animated particle trail rather than image assets, since none
/// were provided for this.
struct DriftingCarEffectView: View {
    private let cycleDuration = 6.0

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let progress = (time.truncatingRemainder(dividingBy: cycleDuration)) / cycleDuration

            GeometryReader { geo in
                let travel = geo.size.width + 160
                let x = progress * travel - 80
                let laneY = geo.size.height * 0.6
                // A wobble that fades in partway through the loop and back
                // out near the end, so the car reads as "drifting through a
                // turn" rather than sliding sideways the whole time.
                let wobblePhase = sin(progress * .pi)
                let wobble = sin(progress * .pi * 5) * 7 * wobblePhase
                let rotation = -6 + wobble

                ZStack {
                    trailCanvas(progress: progress, size: geo.size, laneY: laneY, travel: travel)

                    Image(systemName: "car.side.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 74, height: 74)
                        .foregroundStyle(
                            LinearGradient(colors: [.ftAccent, .ftAccentOrange], startPoint: .leading, endPoint: .trailing)
                        )
                        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                        .rotationEffect(.degrees(rotation))
                        .shadow(color: .ftAccent.opacity(0.55), radius: 14)
                        .position(x: x, y: laneY + wobble * 0.4)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Tire smoke (gray, wide) and exhaust flame (orange/red, tight) trailing
    /// behind the car's recent positions — approximated by re-deriving where
    /// the car was a few animation frames ago rather than tracking real state.
    private func trailCanvas(progress: Double, size: CGSize, laneY: CGFloat, travel: CGFloat) -> some View {
        Canvas { context, canvasSize in
            for i in 0..<16 {
                let trailProgress = progress - Double(i) * 0.008
                guard trailProgress > 0 else { continue }
                let trailX = trailProgress * travel - 80 - CGFloat(i) * 2
                let wobblePhase = sin(trailProgress * .pi)
                let trailWobble = sin(trailProgress * .pi * 5) * 7 * wobblePhase
                let trailY = laneY + trailWobble * 0.4 + 14

                let fade = 1 - Double(i) / 16
                let isFlame = i < 5
                let radius: CGFloat = isFlame ? 5 + CGFloat(i) : 8 + CGFloat(i) * 1.4
                let color: Color = isFlame ? (i.isMultiple(of: 2) ? .orange : .red) : .gray
                context.opacity = fade * (isFlame ? 0.5 : 0.28)
                context.fill(
                    Path(ellipseIn: CGRect(x: trailX - radius / 2, y: trailY - radius / 2, width: radius, height: radius)),
                    with: .color(color)
                )
            }
        }
    }
}
