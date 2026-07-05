import SwiftUI

/// "Welcome to FaisTrack" styled like text on fire — a flame-colored
/// gradient fill with a flickering glow that shifts intensity irregularly
/// (not a single smooth pulse, which would read as an obvious loop), plus
/// small embers rising and fading behind it.
struct FlameWelcomeText: View {
    let text: String

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            // Two overlapping sine waves at different frequencies produce an
            // irregular flicker instead of a smooth, obviously-looping pulse.
            let flicker = 0.6 + 0.4 * (sin(time * 5.3) * 0.6 + sin(time * 9.1) * 0.4)

            ZStack {
                EmberParticlesView()
                    .frame(height: 100)

                Text(text)
                    .font(.system(size: 30, weight: .black))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(
                        LinearGradient(colors: [.yellow, .ftAccentOrange, .speedRed],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: Color.orange.opacity(flicker), radius: 12)
                    .shadow(color: Color.red.opacity(flicker * 0.6), radius: 26)
            }
        }
        .accessibilityLabel(text)
    }
}

/// Small embers rising from roughly where the text sits and fading out —
/// each one loops on its own cycle length/offset so they don't all pulse in
/// unison.
private struct EmberParticlesView: View {
    private let particleCount = 18

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<particleCount {
                    let seed = Double(i) / Double(particleCount)
                    let cycle = 2.2 + seed * 1.4
                    let progress = (time / cycle + seed).truncatingRemainder(dividingBy: 1.0)
                    let x = size.width * (0.08 + seed * 0.84) + CGFloat(sin(progress * .pi * 3 + seed * 10)) * 8
                    let y = size.height * (1 - progress)
                    let fade = sin(progress * .pi) // fades in, peaks, fades out
                    guard fade > 0.02 else { continue }
                    let radius: CGFloat = 2 + CGFloat(seed) * 3
                    let color: Color = i.isMultiple(of: 2) ? .orange : .yellow
                    context.opacity = fade * 0.85
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - radius / 2, y: y - radius / 2, width: radius, height: radius)),
                        with: .color(color)
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
