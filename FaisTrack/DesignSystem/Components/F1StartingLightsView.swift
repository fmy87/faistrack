import SwiftUI

/// A row of 5 lights mirroring a real Formula 1 start sequence — lights
/// illuminate one at a time as a countdown progresses, all going out
/// together the instant the countdown reaches zero. Shared by CompeteView
/// (competing on an existing track) and CreateTrackView (manually creating
/// a new one) so every countdown in the app looks and feels the same,
/// regardless of how long that particular countdown runs.
struct F1StartingLightsView: View {
    /// How many of the 5 lights are currently lit, 0...5.
    let litCount: Int

    var body: some View {
        HStack(spacing: 14) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(litCount > index ? Color.speedRed : Color.speedRed.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(Color.speedRed.opacity(0.5), lineWidth: 2))
                    .shadow(color: litCount > index ? Color.speedRed.opacity(0.8) : .clear, radius: 10)
            }
        }
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
