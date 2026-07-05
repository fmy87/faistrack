import SwiftUI
import Combine

enum AppScreen {
    case intro
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

    private static let hasSeenIntroKey = "hasSeenIntroVideo"
    /// Same key SettingsView's toggle writes to — checked directly here
    /// rather than duplicating the preference, so the two always agree.
    private static let playEveryLaunchKey = "introPlayEveryLaunch"

    var isArabic: Bool { selectedLanguage == "ar" }

    init() {
        let playEveryLaunch = UserDefaults.standard.bool(forKey: Self.playEveryLaunchKey)
        let hasSeenIntro = UserDefaults.standard.bool(forKey: Self.hasSeenIntroKey)
        if playEveryLaunch || !hasSeenIntro {
            currentScreen = .intro
        } else {
            checkAuthState()
        }
    }

    /// Called once the intro video finishes playing or is skipped —
    /// records that it's been seen so it never shows again on this device,
    /// then proceeds to whatever screen the person would normally land on.
    func finishIntro() {
        UserDefaults.standard.set(true, forKey: Self.hasSeenIntroKey)
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


