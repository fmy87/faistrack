import SwiftUI

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
                    List(viewModel.drives) { drive in
                        NavigationLink(destination: DriveDetailView(drive: drive)) {
                            DriveRowView(drive: drive)
                        }
                        .listRowBackground(Color.ftCard)
                    }
                    .listStyle(.insetGrouped)
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
