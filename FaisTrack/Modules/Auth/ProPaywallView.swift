import SwiftUI
import StoreKit

struct ProPaywallView: View {
    @ObservedObject private var store = StoreKitService.shared
    @Environment(\.dismiss) var dismiss
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var isRestoring = false

    /// The yearly product is the one the trial button is meant to promote
    /// — but the actual trial (if any) only exists if it's configured as
    /// an introductory offer on that product in App Store Connect. Reading
    /// it from the product itself (rather than a hardcoded "7-Day" label)
    /// means this can never promise a trial that doesn't actually exist.
    private var yearlyProduct: Product? {
        store.products.first(where: { $0.id.contains("yearly") })
    }

    var body: some View {
        ZStack {
            Color.ftBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    Text("FaisTrack Pro").font(.system(size: 32, weight: .black))
                        .foregroundStyle(LinearGradient(colors: [.ftAccent, .ftAccentOrange],
                                                        startPoint: .leading, endPoint: .trailing))

                    VStack(alignment: .leading, spacing: 12) {
                        ProFeatureRow(icon: "flag.checkered", text: NSLocalizedString("pro.feature.tracks", comment: ""))
                        ProFeatureRow(icon: "list.number", text: NSLocalizedString("pro.feature.leaderboard", comment: ""))
                        ProFeatureRow(icon: "chart.bar.fill", text: NSLocalizedString("pro.feature.stats", comment: ""))
                    }

                    if let error = store.proSyncError {
                        Text(error).font(.system(size: 12)).foregroundColor(.speedRed)
                            .multilineTextAlignment(.center)
                    }

                    if store.isLoadingProducts {
                        ProgressView()
                            .padding(.vertical, 20)
                    } else if store.products.isEmpty {
                        // Happens if the products aren't approved/configured
                        // in App Store Connect yet, or there's no network —
                        // showing nothing at all here would look broken with
                        // no explanation.
                        Text(NSLocalizedString("pro.unavailable", comment: ""))
                            .font(.system(size: 13)).foregroundColor(.ftTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 20)
                    } else {
                        HStack(spacing: 12) {
                            ForEach(store.products) { product in
                                Button { selectedProduct = product } label: {
                                    VStack(spacing: 4) {
                                        Text(product.displayName).font(.caption).foregroundColor(.ftTextSecondary)
                                        Text(product.displayPrice).font(.system(size: 18, weight: .bold))
                                        if let trial = product.freeTrialDescription {
                                            Text(trial).font(.system(size: 10, weight: .semibold)).foregroundColor(.ftAccent)
                                        }
                                    }
                                    .frame(maxWidth: .infinity).padding()
                                    .background(selectedProduct?.id == product.id ? Color.ftAccent.opacity(0.15) : Color.ftCard)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedProduct?.id == product.id ? Color.ftAccent : Color.clear, lineWidth: 1.5)
                                    )
                                }
                            }
                        }
                        .onAppear { selectedProduct = selectedProduct ?? yearlyProduct ?? store.products.first }

                        FTPrimaryButton(
                            title: (selectedProduct ?? yearlyProduct)?.freeTrialDescription.map { _ in NSLocalizedString("pro.startTrial", comment: "") }
                                ?? NSLocalizedString("pro.subscribe", comment: ""),
                            isLoading: isPurchasing
                        ) {
                            guard let product = selectedProduct ?? yearlyProduct else { return }
                            Task {
                                isPurchasing = true
                                try? await store.purchase(product)
                                isPurchasing = false
                            }
                        }

                        Button(action: {
                            Task {
                                isRestoring = true
                                await store.restorePurchases()
                                isRestoring = false
                            }
                        }) {
                            HStack {
                                if isRestoring { ProgressView() }
                                Text(NSLocalizedString("pro.restore", comment: ""))
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.ftAccent)
                        }
                        .disabled(isRestoring)
                    }

                    Button(NSLocalizedString("general.cancel", comment: "")) { dismiss() }
                        .foregroundColor(.ftTextSecondary)

                    // Apple requires these two links to be reachable from
                    // any subscription purchase screen.
                    HStack(spacing: 16) {
                        Link(NSLocalizedString("pro.terms", comment: ""), destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                        Link(NSLocalizedString("pro.privacy", comment: ""), destination: URL(string: "https://www.faistrack.app/privacy")!)
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.ftTextSecondary)
                }
                .padding(24)
            }
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

extension Product {
    /// nil if this product has no free-trial introductory offer configured
    /// in App Store Connect — reading this directly from StoreKit rather
    /// than hardcoding "7-Day Free Trial" anywhere means the UI can never
    /// promise a trial that doesn't actually exist on the product.
    var freeTrialDescription: String? {
        guard let offer = subscription?.introductoryOffer, offer.paymentMode == .freeTrial else { return nil }
        let count = offer.period.value
        let unitKey: String
        switch offer.period.unit {
        case .day: unitKey = "pro.trial.days"
        case .week: unitKey = "pro.trial.weeks"
        case .month: unitKey = "pro.trial.months"
        case .year: unitKey = "pro.trial.years"
        @unknown default: unitKey = "pro.trial.days"
        }
        return String(format: NSLocalizedString(unitKey, comment: ""), count)
    }
}
