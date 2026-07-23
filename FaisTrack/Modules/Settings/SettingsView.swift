import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SettingsViewModel()
    @AppStorage("unitsPreference") private var unitsPreference: String = "km"
    @AppStorage("introPlayEveryLaunch") private var introPlayEveryLaunch: Bool = false
    @State private var currentIcon: String? = UIApplication.shared.alternateIconName

    var body: some View {
        ZStack {
            Color.ftBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    FTCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(NSLocalizedString("settings.appIcon", comment: ""))
                                .font(.system(size: 15, weight: .semibold))
                            HStack(spacing: 16) {
                                ForEach(AppIconOption.allCases, id: \.self) { option in
                                    AppIconOptionButton(option: option, currentIcon: $currentIcon)
                                }
                            }
                        }
                    }

                    FTCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(NSLocalizedString("settings.language", comment: ""))
                                .font(.system(size: 15, weight: .semibold))
                            Picker("", selection: Binding(
                                get: { appState.selectedLanguage },
                                set: { appState.setLanguage($0) }
                            )) {
                                Text(NSLocalizedString("settings.language.english", comment: "")).tag("en")
                                Text(NSLocalizedString("settings.language.arabic", comment: "")).tag("ar")
                                Text(NSLocalizedString("settings.language.spanish", comment: "")).tag("es")
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    FTCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(NSLocalizedString("settings.units", comment: ""))
                                .font(.system(size: 15, weight: .semibold))
                            Picker("", selection: Binding(
                                get: { unitsPreference },
                                set: { newValue in
                                    unitsPreference = newValue
                                    Task { await viewModel.setUnits(newValue) }
                                }
                            )) {
                                Text(NSLocalizedString("settings.units.km", comment: "")).tag("km")
                                Text(NSLocalizedString("settings.units.mi", comment: "")).tag("mi")
                            }
                            .pickerStyle(.segmented)
                            if let error = viewModel.errorMessage {
                                Text(error).font(.system(size: 12)).foregroundColor(.speedRed)
                            }
                        }
                    }

                    FTCard {
                        Toggle(isOn: $introPlayEveryLaunch) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("settings.introVideo", comment: ""))
                                    .font(.system(size: 15, weight: .semibold))
                                Text(introPlayEveryLaunch
                                     ? NSLocalizedString("settings.introVideo.everyLaunch", comment: "")
                                     : NSLocalizedString("settings.introVideo.onceOnly", comment: ""))
                                    .font(.system(size: 12))
                                    .foregroundColor(.ftTextSecondary)
                            }
                        }
                        .tint(.ftAccent)
                    }
                }.padding(20)
            }
        }
        .navigationTitle(NSLocalizedString("settings.title", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
            // Sync local display preference from the server the first time
            // Settings is opened, so a fresh install / reinstall picks up
            // whatever was last saved to the account.
            unitsPreference = viewModel.units
        }
    }
}

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var units: String = "km"
    @Published var errorMessage: String?
    private var user: FTUser?

    func load() async {
        guard let uid = AuthService.shared.currentUser?.uid else { return }
        do {
            if let existing = try await FirebaseService.shared.getUser(uid: uid) {
                user = existing
            } else {
                // Same fallback as ProfileViewModel — a profile that
                // somehow never got created (or was deleted) shouldn't
                // leave Settings permanently broken with no way to set
                // units at all.
                let fallbackName = AuthService.shared.currentUser?.displayName ?? ""
                user = try await FirebaseService.shared.ensureUserProfile(
                    uid: uid, name: fallbackName, email: AuthService.shared.currentUser?.email
                )
            }
            units = user?.units ?? "km"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setUnits(_ newValue: String) async {
        guard var user = user else { return }
        errorMessage = nil
        let previous = units
        units = newValue
        user.units = newValue
        do {
            try await FirebaseService.shared.saveUser(user)
            self.user = user
        } catch {
            units = previous
            errorMessage = error.localizedDescription
        }
    }
}

/// A racing "livery" for the home screen icon — Classic is the actual
/// primary icon; the other two are recolors/overlays derived from that
/// same artwork (see AppIconMidnight-*.png / AppIconCheckered-*.png),
/// not separately designed icons.
enum AppIconOption: String, CaseIterable {
    case classic, midnight, checkered

    /// UIApplication.setAlternateIconName expects nil to mean "reset to
    /// the primary icon" — passing the string "AppIcon" does not work for
    /// that purpose, it specifically has to be nil.
    var iconName: String? {
        switch self {
        case .classic: return nil
        case .midnight: return "Midnight"
        case .checkered: return "Checkered"
        }
    }

    /// Name of a bundled loose PNG usable as a small preview thumbnail in
    /// the picker itself — UIImage(named:) resolves loose bundle files by
    /// exact filename, not just Asset Catalog entries, so this works
    /// without needing separate preview images added to Assets.xcassets.
    var previewAssetName: String {
        switch self {
        case .classic: return "AppIconClassic-180"
        case .midnight: return "AppIconMidnight-180"
        case .checkered: return "AppIconCheckered-180"
        }
    }

    var label: String {
        switch self {
        case .classic: return NSLocalizedString("settings.icon.classic", comment: "")
        case .midnight: return NSLocalizedString("settings.icon.midnight", comment: "")
        case .checkered: return NSLocalizedString("settings.icon.checkered", comment: "")
        }
    }
}

private struct AppIconOptionButton: View {
    let option: AppIconOption
    @Binding var currentIcon: String?

    private var isCurrent: Bool { currentIcon == option.iconName }

    var body: some View {
        Button(action: select) {
            VStack(spacing: 6) {
                if let uiImage = UIImage(named: option.previewAssetName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isCurrent ? Color.ftAccent : Color.clear, lineWidth: 2.5)
                        )
                }
                Text(option.label)
                    .font(.system(size: 11, weight: isCurrent ? .bold : .regular))
                    .foregroundColor(isCurrent ? .ftAccent : .ftTextSecondary)
            }
        }
    }

    private func select() {
        guard !isCurrent else { return }
        UIApplication.shared.setAlternateIconName(option.iconName) { error in
            if let error {
                ToastManager.shared.showError(error.localizedDescription)
            } else {
                currentIcon = option.iconName
            }
        }
    }
}




