import SwiftUI

/// Lets the user review and delete their own recorded drives.
struct ManageDrivesView: View {
    @StateObject private var viewModel = DrivesViewModel()
    @State private var deleteError: String?

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
        .alert(NSLocalizedString("general.error", comment: ""), isPresented: Binding(
            get: { deleteError != nil }, set: { if !$0 { deleteError = nil } }
        )) {
            Button(NSLocalizedString("general.ok", comment: ""), role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
        }
    }

    private func delete(at offsets: IndexSet) {
        guard let uid = AuthService.shared.currentUser?.uid else { return }
        let toDelete = offsets.map { viewModel.drives[$0] }
        viewModel.drives.remove(atOffsets: offsets)
        Task {
            for drive in toDelete {
                guard let id = drive.id else { continue }
                do {
                    try await FirebaseService.shared.deleteDrive(driveId: id, uid: uid)
                } catch {
                    // Put it back — previously a failed delete silently
                    // vanished from the list while still existing on the
                    // server, which could resurface later or double-count
                    // in stats with no indication anything went wrong.
                    viewModel.drives.append(drive)
                    deleteError = error.localizedDescription
                }
            }
        }
    }
}

