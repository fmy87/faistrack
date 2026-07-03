import SwiftUI
import CoreLocation

struct DriveDetailView: View {
    let drive: Drive
    @State private var isPublishing = false
    @State private var publishedTrackId: String?
    @State private var publishError: String?

    private var routeCoordinates: [CLLocationCoordinate2D] {
        guard let encoded = drive.polylineEncoded, !encoded.isEmpty else { return [] }
        return PolylineCodec.decode(encoded)
    }

    private var canPublishAsTrack: Bool {
        routeCoordinates.count > 1 && (drive.distance * 1000) >= Track.minimumDistanceMeters
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

                if canPublishAsTrack {
                    if publishedTrackId != nil {
                        Label(NSLocalizedString("drive.trackPublished", comment: ""), systemImage: "checkmark.circle.fill")
                            .foregroundColor(.speedGreen)
                    } else {
                        Button(action: { Task { await publishTrack() } }) {
                            HStack {
                                if isPublishing { ProgressView().tint(.white) }
                                Text(NSLocalizedString("drive.publishTrack", comment: ""))
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.ftGradient)
                            .cornerRadius(16)
                        }
                        .disabled(isPublishing)

                        if let publishError {
                            Text(publishError).font(.system(size: 12)).foregroundColor(.speedRed)
                        }
                    }
                }
            }.padding(16)
        }
        .background(Color.ftBackground.ignoresSafeArea())
        .navigationTitle(NSLocalizedString("drive.detail", comment: ""))
    }

    private func publishTrack() async {
        guard let uid = AuthService.shared.currentUser?.uid else { return }
        isPublishing = true
        publishError = nil
        do {
            let username = (try? await FirebaseService.shared.getUser(uid: uid))?.username ?? "Driver"
            let id = try await FirebaseService.shared.publishTrack(
                from: drive, coordinates: routeCoordinates, ownerUID: uid, ownerUsername: username
            )
            publishedTrackId = id
        } catch {
            publishError = error.localizedDescription
        }
        isPublishing = false
    }
}
