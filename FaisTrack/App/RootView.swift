import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            switch appState.currentScreen {
            case .onboarding:  OnboardingView()
            case .auth:        AuthView()
            case .permissions: PermissionsView()
            case .main:        MainTabView()
            }
        }
        .id(appState.languageRefreshID)
        .environment(\.layoutDirection, appState.isArabic ? .rightToLeft : .leftToRight)
    }
}
