import SwiftUI

struct LeaderboardView: View {
    @State private var metric: LeaderboardMetric = .distance
    @State private var period: LeaderboardPeriod = .monthly
    @State private var entries: [LeaderboardEntry] = []

    var body: some View {
        NavigationView {
            ZStack {
                Color.ftBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    Picker("", selection: $period) {
                        ForEach(LeaderboardPeriod.allCases, id: \.self) {
                            Text($0.displayName).tag($0)
                        }
                    }.pickerStyle(.segmented).padding()

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(LeaderboardMetric.allCases, id: \.self) { m in
                                Button(m.displayName) { metric = m }
                                    .padding(.horizontal, 16).padding(.vertical, 8)
                                    .background(metric == m ? Color.ftAccent : Color.ftCard)
                                    .foregroundColor(metric == m ? .white : .ftTextPrimary)
                                    .cornerRadius(20)
                            }
                        }.padding(.horizontal)
                    }

                    if entries.isEmpty {
                        Spacer()
                        Image(systemName: "trophy.fill").font(.system(size: 64)).foregroundColor(.ftAccent)
                        Text(NSLocalizedString("leaderboard.empty", comment: ""))
                            .foregroundColor(.ftTextSecondary).padding()
                        Spacer()
                    } else {
                        List(Array(entries.enumerated()), id: \.1.id) { index, entry in
                            LeaderboardRowView(rank: index + 1, entry: entry)
                                .listRowBackground(Color.ftCard)
                        }.listStyle(.insetGrouped)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("tab.leaderboard", comment: ""))
            .task { await loadEntries() }
            .onChange(of: metric) { _, _ in Task { await loadEntries() } }
            .onChange(of: period) { _, _ in Task { await loadEntries() } }
        }
    }

    func loadEntries() async {
        entries = (try? await LeaderboardService.shared.getLeaderboard(metric: metric, period: period)) ?? []
    }
}

struct LeaderboardRowView: View {
    let rank: Int
    let entry: LeaderboardEntry
    var body: some View {
        HStack(spacing: 16) {
            Text("#\(rank)").font(.system(size: 18, weight: .bold))
                .foregroundColor(rank <= 3 ? .ftAccent : .ftTextSecondary)
                .frame(width: 36)
            Text(entry.username).font(.system(size: 16, weight: .semibold))
            Spacer()
            Text(String(format: "%.1f", entry.value))
                .font(.system(size: 18, weight: .bold)).foregroundColor(.ftAccent)
        }
    }
}
