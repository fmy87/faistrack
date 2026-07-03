import SwiftUI

/// Full-screen HUD shown automatically while DriveDetectionService has
/// detected an in-progress drive — live map of the route so far, current
/// speed, elapsed time, and distance. None of the reference screenshots
/// actually showed this screen (they were all Stats/Leaderboard/Settings),
/// so this is an original design in FaisTrack's own red/orange theme rather
/// than a copy of anything from those photos.
struct LiveDriveView: View {
    @ObservedObject private var driveDetection = DriveDetectionService.shared
    @AppStorage("unitsPreference") private var unitsPreference: String = "km"
    var onMinimize: (() -> Void)?

    private var useMetric: Bool { unitsPreference == "km" }
    private var speedUnit: String { useMetric ? "km/h" : "mph" }
    private var distanceUnit: String { useMetric ? "km" : "mi" }

    private var displaySpeed: Double {
        useMetric ? driveDetection.currentSpeedKmh : driveDetection.currentSpeedKmh * 0.621371
    }
    private var displayDistance: Double {
        useMetric ? driveDetection.liveDistanceKm : driveDetection.liveDistanceKm * 0.621371
    }

    var body: some View {
        ZStack(alignment: .top) {
            if driveDetection.liveRouteCoordinates.count > 1 {
                RouteMapView(coordinates: driveDetection.liveRouteCoordinates)
                    .ignoresSafeArea()
            } else {
                Color.ftBackground.ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                    Text(NSLocalizedString("liveDrive.locating", comment: ""))
                        .foregroundColor(.ftTextSecondary)
                }
            }

            VStack {
                topBar
                Spacer()
                hud
            }
        }
    }

    private var topBar: some View {
        HStack {
            Label(NSLocalizedString("liveDrive.recording", comment: ""), systemImage: "record.circle")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.speedRed)
                .cornerRadius(14)
            Spacer()
            if let onMinimize {
                Button(action: onMinimize) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
            }
        }
        .padding()
        .padding(.top, 8)
    }

    private var hud: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 20) {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(String(format: "%.0f", displaySpeed))
                        .font(.system(size: 72, weight: .black))
                        .foregroundColor(.white)
                    Text(speedUnit)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }

                HStack(spacing: 32) {
                    VStack(spacing: 2) {
                        Text(elapsedText(at: context.date))
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text(NSLocalizedString("liveDrive.elapsed", comment: ""))
                            .font(.system(size: 11)).foregroundColor(.white.opacity(0.6))
                    }
                    Divider().frame(height: 30).background(Color.white.opacity(0.3))
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f %@", displayDistance, distanceUnit))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        Text(NSLocalizedString("liveDrive.distance", comment: ""))
                            .font(.system(size: 11)).foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [.black.opacity(0), .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
            )
        }
    }

    private func elapsedText(at now: Date) -> String {
        guard let start = driveDetection.driveStartTime else { return "0:00" }
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
