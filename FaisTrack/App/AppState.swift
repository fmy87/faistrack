import SwiftUI
import Combine

enum AppScreen {
    case onboarding
    case auth
    case main
}

class AppState: ObservableObject {
    @Published var currentScreen: AppScreen = .onboarding
    @Published var currentUser: FTUser?
    @Published var isProUser: Bool = false
    @Published var selectedLanguage: String = Locale.current.languageCode == "ar" ? "ar" : "en"

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
}
