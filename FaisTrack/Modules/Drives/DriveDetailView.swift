import SwiftUI
import CoreLocation

struct DriveDetailView: View {
    let drive: Drive

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
