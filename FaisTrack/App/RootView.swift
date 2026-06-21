import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            switch appState.currentScreen {
            case .onboarding: OnboardingView()
            case .auth:       AuthView()
            case .main:       MainTabView()
            }
        }
        .environment(\.layoutDirection, appState.isArabic ? .rightToLeft : .leftToRight)
    }
}
