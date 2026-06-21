import SwiftUI

struct DriveDetailView: View {
    let drive: Drive
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                FTCard {
                    HStack {
                        FTStatBadge(value: drive.topSpeedKmh, label: NSLocalizedString("drive.topSpeed", comment: ""), color: Color.speedColor(for: drive.topSpeed))
                        Divider()
                        FTStatBadge(value: drive.distanceKm, label: NSLocalizedString("drive.distance", comment: ""))
                        Divider()
                        FTStatBadge(value: drive.durationFormatted, label: NSLocalizedString("drive.duration", comment: ""))
                    }
                }
                if let score = drive.behaviorScore {
                    BehaviorScoreView(score: score)
                }
            }.padding(16)
        }
        .background(Color.ftBackground.ignoresSafeArea())
        .navigationTitle(NSLocalizedString("drive.detail", comment: ""))
    }
}
