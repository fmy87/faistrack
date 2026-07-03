import SwiftUI

/// A continuously animated backdrop of diagonal motion-blur streaks,
/// evoking the app's racing theme. Purely decorative — sits behind content,
/// never intercepts touches.
struct SpeedLinesBackground: View {
    private let lineCount = 16

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<lineCount {
                    let seed = Double(i) / Double(lineCount)
                    let speed = 0.12 + seed * 0.22
                    let progress = (time * speed + seed).truncatingRemainder(dividingBy: 1.0)
                    let y = seed * size.height
                    let length = 70 + seed * 180
                    let x = progress * (size.width + length * 2) - length

                    var path = Path()
                    path.move(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x + length, y: y - length * 0.12))

                    let opacity = 0.04 + (1 - seed) * 0.10
                    context.stroke(
                        path,
                        with: .color(Color.ftAccent.opacity(opacity)),
                        lineWidth: 1.5 + seed * 2.5
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
