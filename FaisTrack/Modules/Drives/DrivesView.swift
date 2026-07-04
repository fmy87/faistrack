import SwiftUI
import CoreLocation

struct DrivesView: View {
    @StateObject private var viewModel = DrivesViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                Color.ftBackground.ignoresSafeArea()
                if viewModel.drives.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "car.fill").font(.system(size: 64)).foregroundColor(.ftAccent)
                        Text(NSLocalizedString("drives.empty.title", comment: ""))
                            .font(.system(size: 22, weight: .bold))
                        Text(NSLocalizedString("drives.empty.subtitle", comment: ""))
                            .foregroundColor(.ftTextSecondary).multilineTextAlignment(.center)
                    }.padding(32)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(Array(viewModel.drives.enumerated()), id: \.1.id) { index, drive in
                                StaggeredAppear(index: index) {
                                    NavigationLink(destination: DriveDetailView(drive: drive)) {
                                        DriveCardView(drive: drive)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(16)
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

struct DriveCardView: View {
    let drive: Drive
    @AppStorage("unitsPreference") private var unitsPreference: String = "km"

    private var useMetric: Bool { unitsPreference == "km" }
    private var routeCoordinates: [CLLocationCoordinate2D] {
        PolylineCodec.decode(drive.polylineEncoded ?? "")
    }
    private var accentColor: Color { Color.speedColor(for: drive.topSpeed) }

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
                }
                Text(dateFormatter.string(from: drive.startTime.dateValue()))
                    .font(.system(size: 12)).foregroundColor(.ftTextSecondary)
                HStack(spacing: 12) {
                    statPill(icon: "arrow.left.and.right", text: drive.distanceFormatted(useMetric: useMetric))
                    statPill(icon: "clock", text: drive.durationFormatted)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(drive.topSpeedFormatted(useMetric: useMetric))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(accentColor)
                Text(useMetric ? "km/h" : "mph")
                    .font(.system(size: 10)).foregroundColor(.ftTextSecondary)
            }
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
