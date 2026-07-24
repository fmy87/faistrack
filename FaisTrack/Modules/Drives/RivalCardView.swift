import SwiftUI

/// A head-to-head comparison card against whichever friend the user has
/// picked as their Rival (see FriendsView) — Need for Speed-style rivalry
/// rather than an anonymous leaderboard rank. Shown at the top of the
/// Drives tab whenever a rival is set; nothing renders at all otherwise.
struct RivalCardView: View {
    @StateObject private var viewModel = RivalViewModel()
    @AppStorage("unitsPreference") private var unitsPreference: String = "km"

    private var useMetric: Bool { unitsPreference == "km" }

    var body: some View {
        Group {
            if let rivalUsername = viewModel.rivalUsername, let mine = viewModel.myTotals, let theirs = viewModel.rivalTotals {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "flag.2.crossed.fill").foregroundColor(.ftAccentOrange)
                        Text(NSLocalizedString("rival.title", comment: ""))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.ftAccentOrange)
                        Spacer()
                        Text("@\(rivalUsername)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.ftTextSecondary)
                    }

                    comparisonRow(
                        label: NSLocalizedString("rival.distance", comment: ""),
                        mine: useMetric ? mine.distanceKm : mine.distanceKm * 0.621371,
                        theirs: useMetric ? theirs.distanceKm : theirs.distanceKm * 0.621371,
                        unit: useMetric ? "km" : "mi"
                    )
                    comparisonRow(
                        label: NSLocalizedString("rival.topSpeed", comment: ""),
                        mine: useMetric ? mine.topSpeedKmh : mine.topSpeedKmh * 0.621371,
                        theirs: useMetric ? theirs.topSpeedKmh : theirs.topSpeedKmh * 0.621371,
                        unit: useMetric ? "km/h" : "mph"
                    )
                    comparisonRow(
                        label: NSLocalizedString("rival.trackRecords", comment: ""),
                        mine: Double(viewModel.myTrackRecords),
                        theirs: Double(viewModel.rivalTrackRecords),
                        unit: ""
                    )
                }
                .padding(16)
                .background(Color.ftCard)
                .cornerRadius(18)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .task { await viewModel.load() }
    }

    private func comparisonRow(label: String, mine: Double, theirs: Double, unit: String) -> some View {
        let iAmAhead = mine > theirs
        let tied = mine == theirs
        return VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 11)).foregroundColor(.ftTextSecondary)
            HStack {
                Text(formatted(mine, unit: unit))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(tied ? .ftTextPrimary : (iAmAhead ? .speedGreen : .ftTextSecondary))
                Spacer()
                if !tied {
                    Image(systemName: iAmAhead ? "chevron.left" : "chevron.right")
                        .font(.system(size: 11))
                        .foregroundColor(.ftTextSecondary)
                }
                Spacer()
                Text(formatted(theirs, unit: unit))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(tied ? .ftTextPrimary : (!iAmAhead ? .speedGreen : .ftTextSecondary))
            }
        }
    }

    private func formatted(_ value: Double, unit: String) -> String {
        let numberText = value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
        return unit.isEmpty ? numberText : "\(numberText) \(unit)"
    }
}

@MainActor
private class RivalViewModel: ObservableObject {
    @Published var rivalUsername: String?
    @Published var myTotals: RivalTotals?
    @Published var rivalTotals: RivalTotals?
    @Published var myTrackRecords = 0
    @Published var rivalTrackRecords = 0

    func load() async {
        guard let uid = AuthService.shared.currentUser?.uid,
              let me = try? await FirebaseService.shared.getUser(uid: uid),
              let rivalUID = me.rivalUID,
              // The rival is another user, not self — users/{uid} reads are
              // self-only now (see Firestore rules), so this has to go
              // through the public profile mirror instead of getUser().
              let rival = try? await FirebaseService.shared.getPublicProfile(uid: rivalUID) else {
            return
        }
        rivalUsername = rival.username
        async let mine = FirebaseService.shared.getAllTimeTotals(uid: uid)
        async let theirs = FirebaseService.shared.getAllTimeTotals(uid: rivalUID)
        async let myRecords = FirebaseService.shared.getTrackRecordCount(uid: uid)
        async let rivalRecords = FirebaseService.shared.getTrackRecordCount(uid: rivalUID)
        myTotals = try? await mine
        rivalTotals = try? await theirs
        myTrackRecords = (try? await myRecords) ?? 0
        rivalTrackRecords = (try? await rivalRecords) ?? 0
    }
}
