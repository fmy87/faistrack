import SwiftUI

struct LeaderboardView: View {
    @State private var scope: LeaderboardScope = .global
    @State private var metric: LeaderboardMetric = .distance
    @State private var period: LeaderboardPeriod = .monthly
    @State private var entries: [LeaderboardEntry] = []
    @State private var myRank: (rank: Int, entry: LeaderboardEntry)?
    @State private var isLoading = true

    enum LeaderboardScope: String, CaseIterable {
        case global, friends
        var displayName: String {
            self == .global ? NSLocalizedString("leaderboard.global", comment: "") : NSLocalizedString("leaderboard.friends", comment: "")
        }
    }

    var body: some View {
        ZStack {
            Color.ftBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Menu {
                        ForEach(LeaderboardScope.allCases, id: \.self) { s in
                            Button(s.displayName) { scope = s }
                        }
                    } label: {
                        filterPill(scope.displayName)
                    }
                    Menu {
                        ForEach(LeaderboardPeriod.allCases, id: \.self) { p in
                            Button(p.displayName) { period = p }
                        }
                    } label: {
                        filterPill(period.displayName)
                    }
                    Spacer()
                }
                .padding(.horizontal).padding(.top, 8)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(LeaderboardMetric.allCases.filter { $0 != .avgSpeed && $0 != .topSpeed }, id: \.self) { m in
                            Button(m.displayName) { metric = m }
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 16).padding(.vertical, 8)
                                .background(metric == m ? Color.ftAccent : Color.ftCard)
                                .foregroundColor(metric == m ? .white : .ftTextPrimary)
                                .cornerRadius(20)
                        }
                    }.padding(.horizontal).padding(.vertical, 10)
                }

                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if entries.isEmpty {
                    Spacer()
                    Image(systemName: "trophy.fill").font(.system(size: 64)).foregroundColor(.ftAccent)
                    Text(NSLocalizedString("leaderboard.empty", comment: ""))
                        .foregroundColor(.ftTextSecondary).padding()
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            if entries.count >= 1 {
                                podium
                            }
                            if let myRank, myRank.rank > 3 {
                                YourRankRow(rank: myRank.rank, entry: myRank.entry, metric: metric)
                                    .padding(.horizontal)
                            }
                            VStack(spacing: 0) {
                                ForEach(Array(entries.enumerated()).filter { $0.0 >= 3 }, id: \.1.id) { index, entry in
                                    LeaderboardRowView(rank: index + 1, entry: entry, metric: metric, isMe: entry.uid == AuthService.shared.currentUser?.uid)
                                    Divider().background(Color.ftTextSecondary.opacity(0.2))
                                }
                            }
                            .background(Color.ftCard)
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 12)
                    }
                }
            }
        }
        .navigationTitle(NSLocalizedString("tab.leaderboard", comment: ""))
        .task { await loadEntries() }
        .onChange(of: metric) { _ in Task { await loadEntries() } }
        .onChange(of: period) { _ in Task { await loadEntries() } }
        .onChange(of: scope) { _ in Task { await loadEntries() } }
    }

    private func filterPill(_ text: String) -> some View {
        HStack(spacing: 4) {
            Text(text).font(.system(size: 14, weight: .semibold))
            Image(systemName: "chevron.down").font(.system(size: 10))
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Color.ftCard)
        .cornerRadius(18)
    }

    private var podium: some View {
        let top3 = Array(entries.prefix(3))
        // Reorder visually as 2nd - 1st - 3rd, matching a race podium.
        let ordered: [(Int, LeaderboardEntry)] = {
            var result: [(Int, LeaderboardEntry)] = []
            if top3.count > 1 { result.append((2, top3[1])) }
            if top3.count > 0 { result.append((1, top3[0])) }
            if top3.count > 2 { result.append((3, top3[2])) }
            return result
        }()

        return HStack(alignment: .bottom, spacing: 12) {
            ForEach(ordered, id: \.1.id) { place, entry in
                VStack(spacing: 8) {
                    if place == 1 {
                        Image(systemName: "crown.fill").foregroundColor(.yellow).font(.system(size: 18))
                    } else {
                        Color.clear.frame(height: 18)
                    }
                    ZStack {
                        Circle()
                            .fill(Color.ftCard)
                            .frame(width: place == 1 ? 84 : 64, height: place == 1 ? 84 : 64)
                            .overlay(
                                Circle().stroke(placeColor(place), lineWidth: place == 1 ? 3 : 2)
                            )
                        Text(String(entry.username.prefix(1)).uppercased())
                            .font(.system(size: place == 1 ? 28 : 20, weight: .bold))
                    }
                    Text(entry.username).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Text(formattedValue(entry.value, metric: metric))
                        .font(.system(size: 13, weight: .bold)).foregroundColor(placeColor(place))
                    Text("\(place)")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(placeColor(place).opacity(place == 1 ? 0.25 : 0.15))
                        .foregroundColor(placeColor(place))
                        .cornerRadius(10)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
    }

    private func placeColor(_ place: Int) -> Color {
        switch place {
        case 1: return .yellow
        case 2: return .gray
        default: return .ftAccentOrange
        }
    }

    private func formattedValue(_ value: Double, metric: LeaderboardMetric) -> String {
        switch metric {
        case .drives: return "\(Int(value))"
        case .hours: return String(format: "%.0f hrs", value)
        default: return String(format: "%.0f km", value)
        }
    }

    func loadEntries() async {
        isLoading = true
        var friendUIDs: [String]? = nil
        if scope == .friends, let uid = AuthService.shared.currentUser?.uid {
            let friends = (try? await FirebaseService.shared.getFriends(uid: uid)) ?? []
            // Include yourself so "Friends" leaderboard still shows your own
            // entry, matching what people expect from a "friends" filter.
            friendUIDs = friends.map(\.uid) + [uid]
        }
        entries = (try? await LeaderboardService.shared.getLeaderboard(metric: metric, period: period, friendUIDs: friendUIDs)) ?? []
        if let uid = AuthService.shared.currentUser?.uid {
            myRank = try? await LeaderboardService.shared.getUserRank(uid: uid, metric: metric, period: period)
        }
        isLoading = false
    }
}

struct LeaderboardRowView: View {
    let rank: Int
    let entry: LeaderboardEntry
    let metric: LeaderboardMetric
    let isMe: Bool

    var body: some View {
        HStack(spacing: 16) {
            Text("\(rank)").font(.system(size: 15, weight: .bold))
                .foregroundColor(.ftTextSecondary)
                .frame(width: 28)
            Circle().fill(Color.ftAccent.opacity(0.25)).frame(width: 32, height: 32)
                .overlay(Text(String(entry.username.prefix(1)).uppercased()).font(.system(size: 13, weight: .bold)))
            Text(entry.username).font(.system(size: 15, weight: .semibold))
            Spacer()
            Text(valueText).font(.system(size: 15, weight: .bold)).foregroundColor(.ftAccent)
        }
        .padding(.horizontal).padding(.vertical, 12)
        .background(isMe ? Color.ftAccent.opacity(0.1) : Color.clear)
    }

    private var valueText: String {
        switch metric {
        case .drives: return "\(Int(entry.value))"
        case .hours: return String(format: "%.1f hrs", entry.value)
        default: return String(format: "%.0f km", entry.value)
        }
    }
}

/// Highlights the current user's own rank/value even when they're outside
/// the visible list — mirrors the reference app always surfacing "your rank"
/// rather than leaving the user to guess where they stand.
struct YourRankRow: View {
    let rank: Int
    let entry: LeaderboardEntry
    let metric: LeaderboardMetric

    var body: some View {
        HStack(spacing: 16) {
            Text(NSLocalizedString("leaderboard.yourRank", comment: ""))
                .font(.system(size: 11, weight: .bold)).foregroundColor(.ftAccent)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.ftAccent.opacity(0.15)).cornerRadius(6)
            Text("#\(rank)").font(.system(size: 15, weight: .bold))
            Text(entry.username).font(.system(size: 15, weight: .semibold))
            Spacer()
            Text(valueText).font(.system(size: 15, weight: .bold)).foregroundColor(.ftAccent)
        }
        .padding(.horizontal).padding(.vertical, 12)
        .background(Color.ftAccent.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.ftAccent, lineWidth: 1))
        .cornerRadius(14)
    }

    private var valueText: String {
        switch metric {
        case .drives: return "\(Int(entry.value))"
        case .hours: return String(format: "%.1f hrs", entry.value)
        default: return String(format: "%.0f km", entry.value)
        }
    }
}


