import SwiftUI

struct BehaviorScoreView: View {
    let score: Int
    var scoreColor: Color {
        if score >= 80 { return .green }
        if score >= 60 { return .orange }
        return .red
    }
    var body: some View {
        FTCard {
            VStack(spacing: 12) {
                Text(NSLocalizedString("stats.behaviorScore", comment: ""))
                    .font(.system(size: 16, weight: .bold))
                ZStack {
                    Circle().stroke(Color.ftCard, lineWidth: 12).frame(width: 100)
                    Circle().trim(from: 0, to: CGFloat(score) / 100)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90)).frame(width: 100)
                    Text("\(score)").font(.system(size: 28, weight: .black)).foregroundColor(scoreColor)
                }
            }
        }
    }
}
