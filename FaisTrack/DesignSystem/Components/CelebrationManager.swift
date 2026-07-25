import SwiftUI

struct CelebrationMessage: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    /// True only for "you just set a new track record" — gets the
    /// checkered-flag, black-and-white racing treatment instead of the
    /// generic colorful confetti used for achievement unlocks. Not every
    /// celebration should look like a race finish (an achievement like
    /// "night owl" 🌙 doesn't want a checkered flag slapped on it), so this
    /// is opt-in per message rather than a blanket redesign.
    var isRacingRecord: Bool = false
}

/// A full-screen celebration for moments that took real effort — a new
/// track record or an unlocked achievement deserve more than the same
/// small toast used for routine saves. Separate from ToastManager
/// deliberately: mixing "quiet confirmation" and "this is a big deal"
/// into one system would mean either every toast needs to compete for
/// attention, or big moments get underplayed.
@MainActor
class CelebrationManager: ObservableObject {
    static let shared = CelebrationManager()
    @Published private(set) var current: CelebrationMessage?

    func celebrate(icon: String, title: String, subtitle: String, isRacingRecord: Bool = false) {
        current = CelebrationMessage(icon: icon, title: title, subtitle: subtitle, isRacingRecord: isRacingRecord)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    func dismiss() {
        current = nil
    }
}

/// Mounted once at the root of the authenticated app (see MainTabView),
/// same pattern as ToastOverlayView, so it can appear over any screen
/// regardless of where the triggering event happened.
struct CelebrationOverlayView: View {
    @ObservedObject private var manager = CelebrationManager.shared

    var body: some View {
        Group {
            if let celebration = manager.current {
                CelebrationContent(celebration: celebration, onDismiss: { manager.dismiss() })
                    .id(celebration.id) // forces fresh animation state per celebration
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: manager.current?.id)
    }
}

private struct CelebrationContent: View {
    let celebration: CelebrationMessage
    let onDismiss: () -> Void
    @State private var badgeScale: CGFloat = 0.3
    @State private var badgeOpacity: Double = 0
    @State private var flagWave: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            if celebration.isRacingRecord {
                // A checkered band flashing behind everything else — the
                // same black-and-white racing motif used on the finish
                // line/countdown lights elsewhere in the app, rather than
                // the same colorful confetti used for every other
                // celebration. A new track record is the single most
                // "racing" moment in the app; it should look like one.
                CheckeredFlashView()
                    .ignoresSafeArea()
                    .opacity(0.35)
            }

            ConfettiBurstView(monochrome: celebration.isRacingRecord)

            VStack(spacing: 16) {
                if celebration.isRacingRecord {
                    // A large waving checkered flag instead of the small
                    // trophy emoji every other celebration uses — this is
                    // the moment the whole app is themed around, so it
                    // gets the biggest, most literal racing symbol there
                    // is rather than sharing the generic emoji-icon
                    // treatment.
                    Image(systemName: "flag.checkered.2.crossed")
                        .font(.system(size: 96, weight: .black))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(flagWave))
                        .scaleEffect(badgeScale)
                        .opacity(badgeOpacity)
                        .shadow(color: .black.opacity(0.5), radius: 12)
                } else {
                    Text(celebration.icon)
                        .font(.system(size: 88))
                        .scaleEffect(badgeScale)
                        .opacity(badgeOpacity)
                }
                Text(celebration.title)
                    .font(.system(size: celebration.isRacingRecord ? 32 : 26, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .textCase(celebration.isRacingRecord ? .uppercase : nil)
                Text(celebration.subtitle)
                    .font(.system(size: celebration.isRacingRecord ? 20 : 15, weight: celebration.isRacingRecord ? .bold : .regular))
                    .foregroundColor(.white.opacity(celebration.isRacingRecord ? 0.9 : 0.75))
                    .multilineTextAlignment(.center)
                Button(action: onDismiss) {
                    Text(NSLocalizedString("general.ok", comment: ""))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 36).padding(.vertical, 12)
                        .background(celebration.isRacingRecord ? AnyShapeStyle(Color.black) : AnyShapeStyle(Color.ftGradient))
                        .overlay(
                            Capsule().stroke(Color.white.opacity(celebration.isRacingRecord ? 0.6 : 0), lineWidth: 1.5)
                        )
                        .cornerRadius(20)
                }
                .padding(.top, 8)
            }
            .padding(32)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                badgeScale = 1.0
                badgeOpacity = 1.0
            }
            if celebration.isRacingRecord {
                withAnimation(.easeInOut(duration: 0.35).repeatCount(5, autoreverses: true)) {
                    flagWave = 12
                }
            }
            Task {
                try? await Task.sleep(nanoseconds: 4_500_000_000)
                onDismiss()
            }
        }
    }
}

/// Alternating black/white diagonal bands sweeping across the screen once —
/// the same checkered-flag language as the flag icon itself, just large
/// enough to read as a background flash rather than a literal flag.
private struct CheckeredFlashView: View {
    @State private var sweep: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(0..<10, id: \.self) { i in
                    Rectangle().fill(i % 2 == 0 ? Color.white : Color.black)
                }
            }
            .frame(width: geo.size.width * 2)
            .rotationEffect(.degrees(-20))
            .offset(x: sweep * geo.size.width)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                sweep = 0.1
            }
        }
    }
}

/// A repeating radial burst of colored particles behind the badge — same
/// Canvas/TimelineView technique already used for embers and speed action
/// lines elsewhere in the app, applied here as a celebratory confetti burst
/// rather than a rising or radiating effect.
private struct ConfettiBurstView: View {
    var monochrome: Bool = false
    private let particleCount = 40
    private let cycleDuration: Double = 3.0

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let center = CGPoint(x: size.width / 2, y: size.height * 0.32)
                let progress = (time.truncatingRemainder(dividingBy: cycleDuration)) / cycleDuration

                for i in 0..<particleCount {
                    let seed = Double(i) / Double(particleCount)
                    let angle = seed * 2 * .pi * 3.7
                    let speed = 90.0 + seed * 240
                    let distance = speed * progress
                    let gravityDrop = progress * progress * 180
                    let x = center.x + CGFloat(cos(angle)) * CGFloat(distance)
                    let y = center.y + CGFloat(sin(angle)) * CGFloat(distance) * 0.5 + CGFloat(gravityDrop)
                    let fade = 1 - progress
                    guard fade > 0.03 else { continue }

                    let colors: [Color] = monochrome
                        ? [.white, .white.opacity(0.7), Color(white: 0.15), .ftAccent]
                        : [.ftAccent, .ftAccentOrange, .yellow, .speedGreen]
                    let color = colors[i % colors.count]
                    let particleSize: CGFloat = 5 + CGFloat(seed) * 4
                    context.opacity = fade
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - particleSize / 2, y: y - particleSize / 2,
                                                width: particleSize, height: particleSize)),
                        with: .color(color)
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
