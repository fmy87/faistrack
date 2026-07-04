import SwiftUI
import CoreLocation

/// Full-screen preview + share sheet for a Track, following the same
/// pattern as ShareCarCardView and MonthlyRecapView: a branded card
/// rendered off-screen to an image, then handed to UIActivityViewController
/// so it can be posted anywhere (Instagram, Messages, etc.) as a real image
/// rather than just a link or plain text.
struct TrackShareCardView: View {
    let track: Track
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.ftBackground.ignoresSafeArea()
            VStack(spacing: 24) {
                Text(NSLocalizedString("tracks.shareCard", comment: ""))
                    .font(.system(size: 22, weight: .bold))
                TrackShareCard(track: track)
                FTPrimaryButton(title: NSLocalizedString("general.share", comment: "")) {
                    shareCard()
                }
                .padding(.horizontal, 40)
            }.padding(24)
        }
    }

    private func shareCard() {
        // UIGraphicsImageRenderer rather than iOS 16+'s ImageRenderer, to
        // match this app's iOS 15 deployment target (same approach as
        // ShareCarCardView and MonthlyRecapView).
        let cardView = TrackShareCard(track: track)
        let controller = UIHostingController(rootView: cardView)
        controller.view.bounds = CGRect(x: 0, y: 0, width: 340, height: 460)
        controller.view.backgroundColor = .clear

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 340, height: 460))
        let image = renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }

        let av = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.rootViewController?
            .present(av, animated: true)
    }
}

/// The actual card design: track name, a drawn miniature of the real route
/// (not a generic icon — traced from the track's own recorded coordinates),
/// distance, best time and its holder, and who published the track.
struct TrackShareCard: View {
    let track: Track
    @AppStorage("unitsPreference") private var unitsPreference: String = "km"

    private var routeCoordinates: [CLLocationCoordinate2D] {
        PolylineCodec.decode(track.polylineEncoded)
    }

    private var useMetric: Bool { unitsPreference == "km" }

    private var topSpeedFormatted: String? {
        guard let kmh = track.bestTimeTopSpeed, kmh > 0 else { return nil }
        return useMetric ? String(format: "%.0f km/h", kmh) : String(format: "%.0f mph", kmh * 0.621371)
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, Color(hex: "#1A0000")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("FaisTrack").font(.system(size: 14, weight: .bold)).foregroundColor(.ftAccent)
                    Spacer()
                    Image(systemName: "flag.checkered.circle.fill")
                        .font(.system(size: 20)).foregroundColor(.ftAccent)
                }

                Text(track.name)
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(.white)
                    .lineLimit(2)

                if routeCoordinates.count > 1 {
                    RouteTraceShape(coordinates: routeCoordinates)
                        .stroke(Color.ftAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                        .frame(height: 120)
                        .padding(.vertical, 4)
                }

                HStack(spacing: 28) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.distanceFormatted)
                            .font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                        Text(NSLocalizedString("tracks.distance", comment: ""))
                            .font(.system(size: 11)).foregroundColor(.gray)
                    }
                    if let bestTime = track.bestTime {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "%.1fs", bestTime))
                                .font(.system(size: 22, weight: .bold)).foregroundColor(.ftAccentOrange)
                            Text(track.bestTimeUsername.map { "@\($0)" } ?? NSLocalizedString("tracks.bestTime", comment: ""))
                                .font(.system(size: 11)).foregroundColor(.gray)
                        }
                    }
                    if let topSpeedFormatted {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(topSpeedFormatted)
                                .font(.system(size: 22, weight: .bold)).foregroundColor(.ftAccent)
                            Text(NSLocalizedString("stats.topSpeed", comment: ""))
                                .font(.system(size: 11)).foregroundColor(.gray)
                        }
                    }
                }

                if let carName = track.bestTimeCarName {
                    HStack(spacing: 6) {
                        Image(systemName: "car.fill").font(.system(size: 12)).foregroundColor(.ftAccentOrange)
                        Text(carName).font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.85))
                    }
                }

                Spacer()

                Text(String(format: NSLocalizedString("tracks.createdBy", comment: ""), track.ownerUsername))
                    .font(.system(size: 12)).foregroundColor(.gray)
            }
            .padding(24)
        }
        .cornerRadius(24)
        .frame(width: 340, height: 460)
    }
}

/// Traces the track's actual recorded route into a small drawing area,
/// normalizing lat/lng into the shape's bounds. This is what makes each
/// card visually distinct per track instead of every share looking
/// identical with a generic flag icon.
private struct RouteTraceShape: Shape {
    let coordinates: [CLLocationCoordinate2D]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard coordinates.count > 1 else { return path }

        let lats = coordinates.map(\.latitude)
        let lngs = coordinates.map(\.longitude)
        let minLat = lats.min() ?? 0, maxLat = lats.max() ?? 0
        let minLng = lngs.min() ?? 0, maxLng = lngs.max() ?? 0
        // Guards against a division by zero for a perfectly straight
        // north-south or east-west route, where one range would be 0.
        let latRange = max(maxLat - minLat, 0.00001)
        let lngRange = max(maxLng - minLng, 0.00001)
        let padding: CGFloat = 10

        func point(for coordinate: CLLocationCoordinate2D) -> CGPoint {
            let x = padding + CGFloat((coordinate.longitude - minLng) / lngRange) * (rect.width - padding * 2)
            // Latitude increases northward, but SwiftUI's y-axis increases
            // downward — flip so the route isn't drawn upside down.
            let y = padding + CGFloat(1 - (coordinate.latitude - minLat) / latRange) * (rect.height - padding * 2)
            return CGPoint(x: x, y: y)
        }

        path.move(to: point(for: coordinates[0]))
        for coordinate in coordinates.dropFirst() {
            path.addLine(to: point(for: coordinate))
        }
        return path
    }
}

