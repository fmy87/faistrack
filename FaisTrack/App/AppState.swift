import SwiftUI
import Combine

enum AppScreen {
    case onboarding
    case auth
    case permissions
    case main
}

class AppState: ObservableObject {
    @Published var currentScreen: AppScreen = .onboarding
    @Published var currentUser: FTUser?
    @Published var isProUser: Bool = false
    @Published var selectedLanguage: String = LocalizationManager.shared.currentLanguage
    /// Changing this forces the whole view tree under RootView to rebuild,
    /// which is necessary for already-rendered Text views to pick up
    /// strings from the newly selected language bundle.
    @Published var languageRefreshID = UUID()

    var isArabic: Bool { selectedLanguage == "ar" }

    init() {
        checkAuthState()
    }

    func checkAuthState() {
        if AuthService.shared.isLoggedIn {
            currentScreen = .main
        } else {
            currentScreen = .onboarding
        }
    }

    func setLanguage(_ language: String) {
        guard language != selectedLanguage else { return }
        LocalizationManager.shared.setLanguage(language)
        selectedLanguage = language
        languageRefreshID = UUID()
    }
}
