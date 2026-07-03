import SwiftUI

struct OnboardingView: View {
    @State private var page = 0
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Color.ftBackground.ignoresSafeArea()
            SpeedLinesBackground()
            TabView(selection: $page) {
                OnboardingPage1().tag(0)
                OnboardingPage2().tag(1)
                OnboardingPage3().tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            VStack {
                Spacer()
                FTPrimaryButton(title: NSLocalizedString("onboarding.continue", comment: "")) {
                    if page < 2 { withAnimation { page += 1 } }
                    else { appState.currentScreen = .auth }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

struct OnboardingPage1: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("FaisTrack").font(.system(size: 36, weight: .black)).foregroundStyle(
                LinearGradient(colors: [.ftAccent, .ftAccentOrange], startPoint: .leading, endPoint: .trailing)
            )
            Text(NSLocalizedString("onboarding.page1.title", comment: ""))
                .font(.system(size: 28, weight: .bold)).multilineTextAlignment(.center)
            Text(NSLocalizedString("onboarding.page1.subtitle", comment: ""))
                .font(.system(size: 16)).foregroundColor(.ftTextSecondary).multilineTextAlignment(.center)
        }.padding(32)
    }
}

struct OnboardingPage2: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2.fill").font(.system(size: 80)).foregroundColor(.ftAccent)
            Text(NSLocalizedString("onboarding.page2.title", comment: ""))
                .font(.system(size: 28, weight: .bold)).multilineTextAlignment(.center)
            Text(NSLocalizedString("onboarding.page2.subtitle", comment: ""))
                .font(.system(size: 16)).foregroundColor(.ftTextSecondary).multilineTextAlignment(.center)
        }.padding(32)
    }
}

struct OnboardingPage3: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "trophy.fill").font(.system(size: 80)).foregroundColor(.ftAccent)
            Text(NSLocalizedString("onboarding.page3.title", comment: ""))
                .font(.system(size: 28, weight: .bold)).multilineTextAlignment(.center)
            Text(NSLocalizedString("onboarding.page3.subtitle", comment: ""))
                .font(.system(size: 16)).foregroundColor(.ftTextSecondary).multilineTextAlignment(.center)
        }.padding(32)
    }
}
