import SwiftUI

/// "Welcome to FaisTrack" styled like text on fire — bigger and more
/// dramatic than a plain caption: a flame-colored gradient fill that
/// actually shifts over time, a periodic white shine sweep across the
/// letters, a layered flickering glow, and embers rising behind it. Each
/// letter ignites into place individually rather than the whole phrase
/// just appearing.
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
            let breathe = 1.0 + 0.02 * sin(time * 2.4)
            // A bright highlight sweeps left-to-right across the word every
            // few seconds — a classic premium-brand wordmark treatment,
            // distinct from the flame flicker itself.
            let shinePhase = (time / 3.2).truncatingRemainder(dividingBy: 1.0)

            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [Color.orange.opacity(0.4 * flicker), .clear],
                        center: .center, startRadius: 4, endRadius: 170
                    ))
                    .frame(width: 340, height: 340)
                    .blur(radius: 14)

                EmberParticlesView()
                    .frame(height: 150)

                HStack(spacing: 1) {
                    ForEach(Array(letters.enumerated()), id: \.offset) { index, letter in
                        Text(String(letter))
                            .font(.system(size: 46, weight: .black, design: .rounded))
                            .italic()
                            .kerning(0.5)
                            .foregroundStyle(flameGradient(time: time, letterIndex: index))
                            .overlay(
                                // The shine sweep — a narrow bright band that
                                // crosses the word, masked to only ever show
                                // through the letter shapes themselves.
                                shineOverlay(letterIndex: index, totalLetters: letters.count, shinePhase: shinePhase)
                                    .mask(
                                        Text(String(letter))
                                            .font(.system(size: 46, weight: .black, design: .rounded))
                                            .italic()
                                            .kerning(0.5)
                                    )
                            )
                            .scaleEffect(hasIgnited ? breathe : 0.2)
                            .opacity(hasIgnited ? 1 : 0)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.55)
                                    .delay(Double(index) * 0.045),
                                value: hasIgnited
                            )
                    }
                }
                .shadow(color: Color.yellow.opacity(flicker * 0.6), radius: 8)
                .shadow(color: Color.orange.opacity(flicker), radius: 18)
                .shadow(color: Color.red.opacity(flicker * 0.8), radius: 36)
                .shadow(color: Color.red.opacity(flicker * 0.4), radius: 60)
            }
        }
        .onAppear { hasIgnited = true }
        .accessibilityLabel(text)
    }

    private func shineOverlay(letterIndex: Int, totalLetters: Int, shinePhase: Double) -> some View {
        // The sweep travels the width of the whole word; each letter's
        // brightness depends on how close the current sweep position is to
        // that letter's position in the word.
        let letterPosition = Double(letterIndex) / Double(max(totalLetters - 1, 1))
        let distance = abs(shinePhase - letterPosition)
        let intensity = max(0, 1 - distance * 6)
        return Color.white.opacity(intensity * 0.85)
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
    private let particleCount = 34

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<particleCount {
                    let seed = Double(i) / Double(particleCount)
                    let cycle = 2.0 + seed * 1.8
                    let progress = (time / cycle + seed).truncatingRemainder(dividingBy: 1.0)
                    let drift = sin(seed * 17) * 16 // per-particle horizontal drift direction/amount
                    let x = size.width * (0.04 + seed * 0.92)
                        + CGFloat(sin(progress * .pi * 3 + seed * 10)) * 9
                        + CGFloat(drift) * CGFloat(progress)
                    let y = size.height * (1 - progress)
                    let fade = sin(progress * .pi) // fades in, peaks, fades out
                    guard fade > 0.02 else { continue }
                    let radius: CGFloat = 1.5 + CGFloat(seed) * 4
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
