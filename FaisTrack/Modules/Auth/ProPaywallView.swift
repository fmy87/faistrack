import SwiftUI
import StoreKit

struct ProPaywallView: View {
    @ObservedObject private var store = StoreKitService.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.ftBackground.ignoresSafeArea()
            VStack(spacing: 24) {
                Text("FaisTrack Pro").font(.system(size: 32, weight: .black))
                    .foregroundStyle(LinearGradient(colors: [.ftAccent, .ftAccentOrange],
                                                    startPoint: .leading, endPoint: .trailing))
                VStack(alignment: .leading, spacing: 12) {
                    ProFeatureRow(icon: "car.2.fill", text: NSLocalizedString("pro.feature.garage", comment: ""))
                    ProFeatureRow(icon: "shield.fill", text: NSLocalizedString("pro.feature.score", comment: ""))
                }
                HStack(spacing: 12) {
                    ForEach(store.products) { product in
                        Button {
                            Task { try? await store.purchase(product) }
                        } label: {
                            VStack {
                                Text(product.displayName).font(.caption).foregroundColor(.ftTextSecondary)
                                Text(product.displayPrice).font(.system(size: 18, weight: .bold))
                            }
                            .frame(maxWidth: .infinity).padding().background(Color.ftCard).cornerRadius(12)
                        }
                    }
                }
                FTPrimaryButton(title: NSLocalizedString("pro.startTrial", comment: "")) {
                    if let yearly = store.products.first(where: { $0.id.contains("yearly") }) {
                        Task { try? await store.purchase(yearly) }
                    }
                }
                Button(NSLocalizedString("general.cancel", comment: "")) { dismiss() }
                    .foregroundColor(.ftTextSecondary)
            }.padding(24)
        }
    }
}

struct ProFeatureRow: View {
    let icon: String; let text: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(.ftAccent)
            Text(text).font(.system(size: 15))
        }
    }
}
