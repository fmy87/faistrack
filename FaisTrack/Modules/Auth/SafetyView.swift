import SwiftUI

struct SafetyView: View {
    @State private var agreed = false
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let rules = ["safety.rule1", "safety.rule2", "safety.rule3", "safety.rule4"]

    var body: some View {
        ZStack {
            Color.ftBackground.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 24) {
                Text(NSLocalizedString("safety.title", comment: ""))
                    .font(.system(size: 32, weight: .bold))
                Text(NSLocalizedString("safety.subtitle", comment: ""))
                    .foregroundColor(.ftTextSecondary)
                FTCard {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(rules, id: \.self) { rule in
                            HStack {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.ftAccent)
                                Text(NSLocalizedString(rule, comment: ""))
                            }
                        }
                    }
                }
                Toggle(isOn: $agreed) {
                    Text(NSLocalizedString("safety.agree", comment: "")).font(.system(size: 14))
                }
                Spacer()
                FTPrimaryButton(title: NSLocalizedString("safety.continue", comment: "")) {
                    dismiss()
                    // Location/notification permission prompts happen on the
                    // next screen (PermissionsView) — this used to jump
                    // straight to .main, which meant iOS never showed either
                    // system permission dialog at all.
                    appState.currentScreen = .permissions
                }
                .disabled(!agreed)
                .opacity(agreed ? 1 : 0.5)
            }
            .padding(24)
        }
    }
}
