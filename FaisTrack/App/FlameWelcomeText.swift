import SwiftUI

/// A premium, animated "flame text" treatment for the intro's welcome
/// message — each letter ignites into place individually rather than the
/// whole word just appearing, the flame-colored fill actually shifts over
/// time (not a static print), and it sits inside an ambient glow halo with
/// a denser, more varied field of embers than a plain caption would have.
struct FlameWelcomeText: View {
    let text: String
    @State private var hasIgnited = false

    private var letters: [Character] { Array(text) }

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            // Two overlapping sine waves at different frequencies produce an
            // irregular flicker instead of a smooth, obviously-looping pulse.
            let flicker = 0.6 + 0.4 * (sin(time * 5.3) * 0.6 + sin(time * 9.1) * 0.4)
            // A very slight "breathing" scale keeps the whole word feeling
            // alive even once every letter has finished igniting.
            let breathe = 1.0 + 0.018 * sin(time * 2.4)

            ZStack {
                // Soft ambient glow behind the whole word — distinct from
                // the per-letter shadow and the embers, giving the effect
                // some depth rather than one flat glow source.
                Circle()
                    .fill(RadialGradient(
                        colors: [Color.orange.opacity(0.35 * flicker), .clear],
                        center: .center, startRadius: 4, endRadius: 130
                    ))
                    .frame(width: 260, height: 260)
                    .blur(radius: 10)

                EmberParticlesView()
                    .frame(height: 120)

                HStack(spacing: 0) {
                    ForEach(Array(letters.enumerated()), id: \.offset) { index, letter in
                        Text(String(letter))
                            // .rounded design + a slight italic slant reads
                            // as far more "branded racing" than the plain
                            // system sans-serif this replaced.
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .italic()
                            .kerning(0.5)
                            .foregroundStyle(flameGradient(time: time, letterIndex: index))
                            .scaleEffect(hasIgnited ? breathe : 0.2)
                            .opacity(hasIgnited ? 1 : 0)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.55)
                                    .delay(Double(index) * 0.045),
                                value: hasIgnited
                            )
                    }
                }
                .shadow(color: Color.yellow.opacity(flicker * 0.5), radius: 6)
                .shadow(color: Color.orange.opacity(flicker), radius: 14)
                .shadow(color: Color.red.opacity(flicker * 0.7), radius: 30)
            }
        }
        .onAppear { hasIgnited = true }
        .accessibilityLabel(text)
    }

    /// A gradient whose stops drift slightly over time and per-letter, so
    /// the flame fill looks like it's actually licking/moving rather than a
    /// static 3-color print — the per-letter phase offset keeps it from
    /// reading as one uniform wave sweeping the whole word in lockstep.
    private func flameGradient(time: Double, letterIndex: Int) -> LinearGradient {
        let phase = time * 1.6 + Double(letterIndex) * 0.3
        let shift = sin(phase) * 0.15
        return LinearGradient(
            stops: [
                Gradient.Stop(color: .yellow, location: max(0, 0.0 + shift)),
                Gradient.Stop(color: .ftAccentOrange, location: min(max(0, 0.5 + shift), 1)),
                Gradient.Stop(color: .speedRed, location: min(1, 1.0 + shift))
            ],
            startPoint: .top, endPoint: .bottom
        )
    }
}

/// Embers rising from roughly where the text sits and fading out — denser
/// and more varied than a simple two-color loop, each with its own cycle
/// length, horizontal drift, and size so the field doesn't read as a
/// repeating pattern.
private struct EmberParticlesView: View {
    private let particleCount = 28

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<particleCount {
                    let seed = Double(i) / Double(particleCount)
                    let cycle = 2.0 + seed * 1.8
                    let progress = (time / cycle + seed).truncatingRemainder(dividingBy: 1.0)
                    let drift = sin(seed * 17) * 14 // per-particle horizontal drift direction/amount
                    let x = size.width * (0.06 + seed * 0.88)
                        + CGFloat(sin(progress * .pi * 3 + seed * 10)) * 8
                        + CGFloat(drift) * CGFloat(progress)
                    let y = size.height * (1 - progress)
                    let fade = sin(progress * .pi) // fades in, peaks, fades out
                    guard fade > 0.02 else { continue }
                    let radius: CGFloat = 1.5 + CGFloat(seed) * 3.5
                    let colorPick = i % 3
                    let color: Color = colorPick == 0 ? .yellow : (colorPick == 1 ? .orange : .speedRed)
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
