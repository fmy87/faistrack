import SwiftUI

/// A row of 5 lights mirroring a real Formula 1 start sequence, housed in a
/// gantry-style panel with a checkered-flag accent stripe — lights
/// illuminate one at a time as a countdown progresses, all going out
/// together the instant the countdown reaches zero. Shared by CompeteView
/// (competing on an existing track) and CreateTrackView (manually creating
/// a new one) so every countdown in the app looks and feels the same,
/// regardless of how long that particular countdown runs.
struct F1StartingLightsView: View {
    /// How many of the 5 lights are currently lit, 0...5.
    let litCount: Int

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                ForEach(0..<5, id: \.self) { index in
                    lightBulb(lit: litCount > index)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(LinearGradient(colors: [Color.black.opacity(0.9), Color.black.opacity(0.65)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(LinearGradient(colors: [.white.opacity(0.3), .clear],
                                                   startPoint: .top, endPoint: .bottom), lineWidth: 1)
                    )
            )

            CheckeredStripe()
                .frame(width: 180, height: 10)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .opacity(0.55)
        }
    }

    private func lightBulb(lit: Bool) -> some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [lit ? Color.speedRed : Color.speedRed.opacity(0.1),
                             lit ? Color.speedRed.opacity(0.65) : Color.speedRed.opacity(0.04)],
                    center: .center, startRadius: 2, endRadius: 26
                ))
                .frame(width: 48, height: 48)
            Circle()
                .stroke(Color.black.opacity(0.7), lineWidth: 3)
                .frame(width: 48, height: 48)
            if lit {
                // A small bright highlight makes the lit bulb read as an
                // actual glowing light rather than a flat filled circle.
                Circle()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: 10, height: 10)
                    .offset(x: -8, y: -8)
                    .blur(radius: 2)
            }
        }
        .scaleEffect(lit ? 1.0 : 0.85)
        .shadow(color: lit ? Color.speedRed.opacity(0.9) : .clear, radius: lit ? 18 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: lit)
    }

    /// Maps a countdown's current remaining value against its total
    /// duration proportionally onto 5 lights — this is what lets the same
    /// visual work correctly whether the countdown is 3 seconds (creating a
    /// track) or 10 seconds (competing on one), always finishing with all 5
    /// lit on the final tick before go.
    static func litCount(remaining: Int, total: Int) -> Int {
        guard total > 0 else { return 5 }
        let elapsed = total - remaining + 1
        return min(5, Int(ceil(5.0 * Double(elapsed) / Double(total))))
    }
}

private struct CheckeredStripe: View {
    private let columns = 14
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(0..<columns, id: \.self) { i in
                    Rectangle().fill(i.isMultiple(of: 2) ? Color.white : Color.black)
                }
            }
        }
    }
}
