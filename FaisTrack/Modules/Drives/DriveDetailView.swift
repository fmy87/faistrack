import SwiftUI
import CoreLocation

struct DriveDetailView: View {
    @State var drive: Drive
    @AppStorage("unitsPreference") private var unitsPreference: String = "km"
    @State private var isSavingRole = false

    private var routeCoordinates: [CLLocationCoordinate2D] {
        guard let encoded = drive.polylineEncoded, !encoded.isEmpty else { return [] }
        return PolylineCodec.decode(encoded)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if routeCoordinates.count > 1 {
                    RouteMapView(coordinates: routeCoordinates)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                FTCard {
                    HStack {
                        FTStatBadge(value: drive.topSpeedFormatted(useMetric: unitsPreference == "km"), label: NSLocalizedString("drive.topSpeed", comment: ""), color: Color.speedColor(for: drive.topSpeed))
                        Divider()
                        FTStatBadge(value: drive.distanceFormatted(useMetric: unitsPreference == "km"), label: NSLocalizedString("drive.distance", comment: ""))
                        Divider()
                        FTStatBadge(value: drive.durationFormatted, label: NSLocalizedString("drive.duration", comment: ""))
                    }
                }
                if let score = drive.behaviorScore {
                    BehaviorScoreView(score: score)
                }

                // Auto-detection can't tell who was actually driving, so this
                // lets the user correct the record after the fact. Marking a
                // drive as passenger excludes it from all driving stats
                // (distance, top speed, personal bests, etc.) on the Stats
                // tab and instead counts it toward "Passenger Princess."
                Button(action: { Task { await toggleRole() } }) {
                    HStack {
                        if isSavingRole { ProgressView() }
                        Image(systemName: drive.isPassenger ? "checkmark.circle.fill" : "person.fill.questionmark")
                        Text(drive.isPassenger
                             ? NSLocalizedString("drive.wasPassengerConfirmed", comment: "")
                             : NSLocalizedString("drive.markAsPassenger", comment: ""))
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(drive.isPassenger ? .speedGreen : .ftTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.ftTextSecondary.opacity(0.3), lineWidth: 1))
                }
                .disabled(isSavingRole)

                // Publishing an auto-detected Drive as a Track was
                // intentionally removed — Tracks are now only ever created
                // through the explicit "+ → Start" flow in the Tracks tab
                // (see CreateTrackView/TrackCreationService), never from
                // passive drive detection. A track someone didn't
                // deliberately set out to create isn't a track worth racing.
            }.padding(16)
        }
        .background(Color.ftBackground.ignoresSafeArea())
        .navigationTitle(NSLocalizedString("drive.detail", comment: ""))
    }

    private func toggleRole() async {
        guard let uid = AuthService.shared.currentUser?.uid else { return }
        isSavingRole = true
        var updated = drive
        updated.isPassenger.toggle()
        do {
            try await FirebaseService.shared.saveDrive(updated, uid: uid)
            // Keep the leaderboard consistent with the reclassification —
            // otherwise a drive counted while marked "driving" would keep
            // inflating the user's leaderboard numbers even after being
            // corrected to "passenger", or vice versa.
            if updated.isPassenger {
                await LeaderboardService.shared.reverseContribution(drive: updated, uid: uid)
            } else {
                await LeaderboardService.shared.updateLeaderboard(drive: updated, uid: uid)
            }
            drive = updated
        } catch {
            // Leave the drive's role unchanged in the UI if the save failed,
            // rather than showing a state that isn't actually persisted.
        }
        isSavingRole = false
    }
}
