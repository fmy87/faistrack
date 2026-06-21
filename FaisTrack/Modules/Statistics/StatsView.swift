import SwiftUI

struct StatsView: View {
    var body: some View {
        NavigationView {
            ZStack {
                Color.ftBackground.ignoresSafeArea()
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar.fill").font(.system(size: 64)).foregroundColor(.ftAccent)
                    Text(NSLocalizedString("stats.empty.title", comment: ""))
                        .font(.system(size: 22, weight: .bold))
                    Text(NSLocalizedString("stats.empty.subtitle", comment: ""))
                        .foregroundColor(.ftTextSecondary).multilineTextAlignment(.center)
                }.padding(32)
            }
            .navigationTitle(NSLocalizedString("tab.stats", comment: ""))
        }
    }
}
