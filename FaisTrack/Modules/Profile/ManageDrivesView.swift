import SwiftUI

/// Lets the user review and delete their own recorded drives.
struct ManageDrivesView: View {
    @StateObject private var viewModel = DrivesViewModel()

    var body: some View {
        ZStack {
            Color.ftBackground.ignoresSafeArea()
            if viewModel.drives.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "car.fill").font(.system(size: 48)).foregroundColor(.ftAccent)
                    Text(NSLocalizedString("drives.empty.title", comment: ""))
                        .foregroundColor(.ftTextSecondary)
                }
            } else {
                List {
                    ForEach(viewModel.drives) { drive in
                        DriveRowView(drive: drive)
                            .listRowBackground(Color.ftCard)
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(NSLocalizedString("profile.manageDrives", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .task { await viewModel.load() }
    }

    private func delete(at offsets: IndexSet) {
        guard let uid = AuthService.shared.currentUser?.uid else { return }
        let toDelete = offsets.map { viewModel.drives[$0] }
        viewModel.drives.remove(atOffsets: offsets)
        Task {
            for drive in toDelete {
                guard let id = drive.id else { continue }
                try? await FirebaseService.shared.deleteDrive(driveId: id, uid: uid)
            }
        }
    }
}
