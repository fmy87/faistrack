import SwiftUI
import CoreLocation

struct DrivesView: View {
    @StateObject private var viewModel = DrivesViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                Color.ftBackground.ignoresSafeArea()
                // Same subtle animated speed-line texture used on the
                // onboarding/intro screens — ties the main tab back to the
                // app's racing identity instead of sitting on a flat,
                // generic list background.
                SpeedLinesBackground().ignoresSafeArea()

                VStack(spacing: 0) {
                    // Renders nothing at all if no rival is set — see
                    // RivalCardView's own body.
                    RivalCardView()

                    if !viewModel.drives.isEmpty {
                        DriveDashboardHeader(
                            totalDrives: viewModel.drives.count,
                            totalDistance: viewModel.totalDistance,
                            bestSpeed: viewModel.bestTopSpeed
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }

                    if viewModel.drives.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "car.fill").font(.system(size: 64)).foregroundColor(.ftAccent)
                            Text(NSLocalizedString("drives.empty.title", comment: ""))
                                .font(.system(size: 22, weight: .bold))
                            Text(NSLocalizedString("drives.empty.subtitle", comment: ""))
                                .foregroundColor(.ftTextSecondary).multilineTextAlignment(.center)
                        }.padding(32)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 14) {
                                ForEach(Array(viewModel.drives.enumerated()), id: \.1.id) { index, drive in
                                    StaggeredAppear(index: index) {
                                        NavigationLink(destination: DriveDetailView(drive: drive)) {
                                            DriveCardView(drive: drive, isPersonalBest: drive.topSpeed == viewModel.bestTopSpeed && drive.topSpeed > 0)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(16)
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("tab.drives", comment: ""))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isTracking {
                        HStack {
                            Circle().fill(Color.red).frame(width: 8, height: 8)
                            Text(NSLocalizedString("drives.tracking", comment: ""))
                                .font(.caption).foregroundColor(.ftAccent)
                        }
                    }
                }
            }
        }
        .task { await viewModel.load() }
    }
}

/// A compact dashboard strip above the drive list — three stat pills
/// (drives, distance, best speed) on the same red-orange gradient used
/// throughout the app, giving the tab an instrument-cluster feel rather
/// than opening straight into a plain list.
struct DriveDashboardHeader: View {
    let totalDrives: Int
    let totalDistance: Double
    let bestSpeed: Double
    @AppStorage("unitsPreference") private var unitsPreference: String = "km"
    private var useMetric: Bool { unitsPreference == "km" }

    private var distanceText: String {
        let value = useMetric ? totalDistance : totalDistance * 0.621371
        return String(format: "%.0f %@", value, useMetric ? "km" : "mi")
    }
    private var speedText: String {
        let value = useMetric ? bestSpeed : bestSpeed * 0.621371
        return String(format: "%.0f", value)
    }

    var body: some View {
        HStack(spacing: 0) {
            statBlock(value: "\(totalDrives)", label: NSLocalizedString("drives.dashboard.drives", comment: ""))
            divider
            statBlock(value: distanceText, label: NSLocalizedString("drives.dashboard.distance", comment: ""))
            divider
            statBlock(value: speedText, label: useMetric ? "km/h \(NSLocalizedString("drives.dashboard.best", comment: ""))" : "mph \(NSLocalizedString("drives.dashboard.best", comment: ""))")
        }
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.ftGradient)
        )
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.25)).frame(width: 1, height: 30)
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DriveCardView: View {
    let drive: Drive
    var isPersonalBest: Bool = false
    @AppStorage("unitsPreference") private var unitsPreference: String = "km"

    private var useMetric: Bool { unitsPreference == "km" }
    private var routeCoordinates: [CLLocationCoordinate2D] {
        PolylineCodec.decode(drive.polylineEncoded ?? "")
    }
    private var accentColor: Color { Color.speedColor(for: drive.topSpeed) }
    // Speedometer-style arc fill — how close this drive's top speed got to
    // a nominal 240 km/h redline, so the gauge reads as "how hard was this
    // drive" at a glance instead of just printing a number.
    private var gaugeProgress: Double { min(drive.topSpeed / 240.0, 1.0) }

    var body: some View {
        HStack(spacing: 14) {
            // A small trace of the drive's actual route rather than a
            // generic car icon — every card looks distinct at a glance
            // instead of the whole list being identical rows of text.
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(accentColor.opacity(0.12))
                if routeCoordinates.count > 1 {
                    RouteTraceShape(coordinates: routeCoordinates)
                        .stroke(accentColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .padding(8)
                } else {
                    Image(systemName: "car.fill").font(.system(size: 22)).foregroundColor(accentColor)
                }
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(drive.startPlaceName ?? NSLocalizedString("drives.unknownLocation", comment: ""))
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                    if drive.isNight {
                        Image(systemName: "moon.fill").font(.system(size: 11)).foregroundColor(.ftTextSecondary)
                    }
                    if drive.isPassenger {
                        Text(NSLocalizedString("drive.passengerBadge", comment: ""))
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.ftTextSecondary.opacity(0.2))
                            .cornerRadius(6)
                    }
                    if isPersonalBest {
                        HStack(spacing: 2) {
                            Image(systemName: "crown.fill").font(.system(size: 9))
                            Text(NSLocalizedString("drives.personalBest", comment: ""))
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.ftGradient)
                        .cornerRadius(6)
                    }
                }
                Text(dateFormatter.string(from: drive.startTime.dateValue()))
                    .font(.system(size: 12)).foregroundColor(.ftTextSecondary)
                HStack(spacing: 12) {
                    statPill(icon: "arrow.left.and.right", text: drive.distanceFormatted(useMetric: useMetric))
                    statPill(icon: "clock", text: drive.durationFormatted)
                }
            }

            Spacer()

            // A partial ring gauge behind the top-speed number, like a
            // mini rev counter, filled proportionally to how fast this
            // drive got relative to a 240 km/h redline.
            ZStack {
                Circle()
                    .stroke(accentColor.opacity(0.15), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: gaugeProgress)
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(drive.topSpeedFormatted(useMetric: useMetric).components(separatedBy: " ").first ?? "")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(accentColor)
                    Text(useMetric ? "km/h" : "mph")
                        .font(.system(size: 8)).foregroundColor(.ftTextSecondary)
                }
            }
            .frame(width: 56, height: 56)
        }
        .padding(14)
        .background(Color.ftCard)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(accentColor.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 6, y: 3)
    }

    private func statPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10))
            Text(text).font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(.ftTextSecondary)
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f
    }
}

/// Compact single-line variant used by ManageDrivesView's swipe-to-delete
/// list, where the space and interaction model favor a simple row over the
/// full DriveCardView treatment used on the main Drives tab.
struct DriveRowView: View {
    let drive: Drive
    @AppStorage("unitsPreference") private var unitsPreference: String = "km"

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(drive.startPlaceName ?? NSLocalizedString("drives.unknownLocation", comment: ""))
                    .font(.system(size: 16, weight: .semibold))
                Text(drive.durationFormatted + " • " + drive.distanceFormatted(useMetric: unitsPreference == "km"))
                    .font(.system(size: 13)).foregroundColor(.ftTextSecondary)
            }
            Spacer()
            Text(drive.topSpeedFormatted(useMetric: unitsPreference == "km"))
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color.speedColor(for: drive.topSpeed))
        }.padding(.vertical, 4)
    }
}

class DrivesViewModel: ObservableObject {
    @Published var drives: [Drive] = []
    @Published var isTracking = false
    @Published var errorMessage: String?

    var totalDistance: Double { drives.reduce(0) { $0 + $1.distance } }
    var bestTopSpeed: Double { drives.map(\.topSpeed).max() ?? 0 }

    func load() async {
        guard let uid = AuthService.shared.currentUser?.uid else { return }
        do {
            drives = try await FirebaseService.shared.getDrives(uid: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
        isTracking = DriveDetectionService.shared.isDriving
    }
}

