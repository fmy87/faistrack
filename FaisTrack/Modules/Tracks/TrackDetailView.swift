import SwiftUI
import CoreLocation

struct TrackDetailView: View {
    let track: Track
    @State private var results: [TrackResult] = []
    @State private var showShareCard = false

    /// The record holder's telemetry decoded once — powers the speed
    /// heatmap below. Empty for tracks where nobody's set a record with
    /// telemetry yet (e.g. tracks created before this existed).
    private var telemetry: [TelemetryPoint] {
        TelemetryCodec.decode(track.bestTimeTelemetry)
    }

    /// Falls back to the plain route (from polylineEncoded) when there's
    /// no telemetry to color by speed — every track still shows *a* map,
    /// just without the heatmap treatment.
    private var routeCoordinates: [CLLocationCoordinate2D] {
        if !telemetry.isEmpty {
            return telemetry.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
        }
        return PolylineCodec.decode(track.polylineEncoded)
    }

    private var speedSegmentsKmh: [Double]? {
        telemetry.isEmpty ? nil : telemetry.map(\.s)
    }

    /// Results are fetched with a generous limit (see loadLeaderboard) so
    /// this can find the user's own best attempt even if they're not
    /// ranked in the visible top of the list.
    private var myBestResult: TrackResult? {
        guard let uid = AuthService.shared.currentUser?.uid else { return nil }
        return results.first { $0.uid == uid } // already sorted ascending by duration
    }

    private var myMedal: TrackMedal {
        TrackMedal.evaluate(myBestDuration: myBestResult?.duration, trackBestDuration: track.bestTime)
    }

    /// Held for 30+ consecutive days — Strava-KOM style recognition for
    /// the current record holder. False for anyone else, or if the record
    /// is too recent, or if recordSetAt is missing (records set before
    /// this field existed).
    private var isTrackLegend: Bool {
        guard let uid = AuthService.shared.currentUser?.uid, track.bestTimeUid == uid,
              let recordSetAt = track.recordSetAt else { return false }
        return Date().timeIntervalSince(recordSetAt.dateValue()) >= 30 * 24 * 60 * 60
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if routeCoordinates.count > 1 {
                    RouteMapView(coordinates: routeCoordinates, speedSegmentsKmh: speedSegmentsKmh)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    if speedSegmentsKmh != nil {
                        heatmapLegend
                    }
                }

                if !telemetry.isEmpty {
                    ElevationProfileView(points: telemetry)
                }

                // Makes it explicit this track (and every other one in the
                // Tracks list) can belong to anyone, not just you — the list
                // shows every user's published tracks and this one is
                // fully competable regardless of who created it.
                Text(String(format: NSLocalizedString("tracks.createdBy", comment: ""), track.ownerUsername))
                    .font(.system(size: 13)).foregroundColor(.ftTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                recordHolderCard

                if isTrackLegend {
                    trackLegendCard
                }

                if myMedal != .none {
                    myMedalCard
                }

                FTCard {
                    HStack {
                        FTStatBadge(value: track.distanceFormatted, label: NSLocalizedString("tracks.distance", comment: ""))
                        Divider()
                        FTStatBadge(value: "\(track.attemptCount)", label: NSLocalizedString("tracks.attempts", comment: ""))
                    }
                }

                NavigationLink(destination: CompeteView(track: track)) {
                    Text(NSLocalizedString("tracks.compete", comment: ""))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.ftGradient)
                        .cornerRadius(16)
                }

                FTSecondaryButton(title: NSLocalizedString("tracks.shareCard", comment: "")) {
                    showShareCard = true
                }

                if !results.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(NSLocalizedString("tracks.leaderboard", comment: ""))
                            .font(.system(size: 16, weight: .bold))
                        ForEach(Array(results.prefix(20).enumerated()), id: \.1.id) { index, result in
                            HStack {
                                Text("#\(index + 1)").font(.system(size: 14, weight: .bold))
                                    .foregroundColor(index == 0 ? .ftAccent : .ftTextSecondary)
                                    .frame(width: 32)
                                Text(result.username).font(.system(size: 14))
                                Spacer()
                                Text(result.durationFormatted).font(.system(size: 14, weight: .semibold))
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.ftCard)
                    .cornerRadius(16)
                }
            }.padding(16)
        }
        .background(Color.ftBackground.ignoresSafeArea())
        .navigationTitle(track.name)
        .task { await loadLeaderboard() }
        .sheet(isPresented: $showShareCard) {
            TrackShareCardView(track: track)
        }
    }

    /// Explains the heatmap's color scale with the actual speed thresholds
    /// it uses — without this, a green-to-red route is just decoration with
    /// no way to know what any given color actually means.
    private var heatmapLegend: some View {
        HStack(spacing: 16) {
            legendSwatch(color: .speedGreen, label: "< 60 km/h")
            legendSwatch(color: .yellow, label: "60-100 km/h")
            legendSwatch(color: .speedRed, label: "100+ km/h")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendSwatch(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.system(size: 11)).foregroundColor(.ftTextSecondary)
        }
    }

    /// A distinct, trophy-styled card for whoever currently holds this
    /// track's best time — previously the best time was just another
    /// number in a plain stat row, easy to miss as "the thing everyone's
    /// actually competing for." Reuses bestTimeTopSpeed/bestTimeCarName
    /// (already captured whenever a new record is set) so this can show
    /// the record holder's speed and car with no extra lookup.
    private var recordHolderCard: some View {
        Group {
            if let bestTime = track.bestTime, let holder = track.bestTimeUsername {
                ZStack {
                    LinearGradient(colors: [.black, Color(hex: "#1A0000")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    VStack(spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "trophy.fill").foregroundColor(.yellow)
                            Text(NSLocalizedString("tracks.recordHolder", comment: ""))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.yellow)
                        }
                        Text("@\(holder)")
                            .font(.system(size: 20, weight: .black))
                            .foregroundColor(.white)
                        Text(String(format: "%.2fs", bestTime))
                            .font(.system(size: 44, weight: .black))
                            .foregroundColor(.ftAccent)
                        HStack(spacing: 16) {
                            if let topSpeed = track.bestTimeTopSpeed, topSpeed > 0 {
                                Label(String(format: "%.0f km/h", topSpeed), systemImage: "gauge.with.dots.needle.67percent")
                            }
                            if let carName = track.bestTimeCarName {
                                Label(carName, systemImage: "car.fill")
                            }
                        }
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(20)
                }
                .cornerRadius(20)
            } else {
                FTCard {
                    VStack(spacing: 8) {
                        Image(systemName: "flag.checkered").font(.system(size: 28)).foregroundColor(.ftTextSecondary)
                        Text(NSLocalizedString("tracks.noRecordYet", comment: ""))
                            .font(.system(size: 14)).foregroundColor(.ftTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    /// Only ever shown to the record holder themselves, once they've held
    /// it a full 30 days — a small nod to Strava's "Local Legend," giving
    /// long-held records their own recognition beyond just being #1 today.
    private var trackLegendCard: some View {
        HStack(spacing: 14) {
            Text("🏛️").font(.system(size: 32))
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("trackLegend.title", comment: ""))
                    .font(.system(size: 15, weight: .bold)).foregroundColor(.yellow)
                Text(NSLocalizedString("trackLegend.subtitle", comment: ""))
                    .font(.system(size: 12)).foregroundColor(.ftTextSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.yellow.opacity(0.12))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.yellow.opacity(0.4), lineWidth: 1))
    }

    /// Shown only once the user has actually attempted this track — no
    /// medal card at all before that, rather than showing a "locked" state,
    /// since there's nothing to chase yet without a first attempt.
    private var myMedalCard: some View {
        HStack(spacing: 14) {
            Text(myMedal.icon).font(.system(size: 32))
            VStack(alignment: .leading, spacing: 2) {
                Text(myMedal.label).font(.system(size: 15, weight: .bold)).foregroundColor(myMedal.color)
                if let mine = myBestResult?.duration {
                    Text(String(format: "%.2fs", mine)).font(.system(size: 13)).foregroundColor(.ftTextSecondary)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(Color.ftCard)
        .cornerRadius(16)
    }

    private func loadLeaderboard() async {
        guard let id = track.id else { return }
        // A generous limit here (not the small number actually displayed)
        // is what lets myBestResult find the user's own attempt even if
        // they're not ranked near the top — filtering client-side avoids
        // needing a second query (and the composite index that would
        // require) just to look up one person's own result.
        results = (try? await FirebaseService.shared.getTrackLeaderboard(trackId: id, limit: 500)) ?? []
    }
}





