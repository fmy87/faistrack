import StoreKit
import FirebaseFirestore

class StoreKitService: ObservableObject {
    static let shared = StoreKitService()
    @Published var products: [Product] = []
    @Published var isPro: Bool = false
    /// Set when the purchase succeeded with Apple but the Firestore write
    /// recording it failed even after a retry — surfaced so the paywall UI
    /// can tell the person their purchase went through and will sync
    /// shortly, rather than them wondering if they were charged for nothing.
    @Published var proSyncError: String?

    let productIDs = [
        "com.faistrack.app.pro.weekly",
        "com.faistrack.app.pro.monthly",
        "com.faistrack.app.pro.yearly"
    ]

    init() {
        Task { await loadProducts() }
    }

    @MainActor
    func loadProducts() async {
        products = (try? await Product.products(for: productIDs)) ?? []
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verification.payloadValue
            await updateProStatus(expiry: transaction.expirationDate)
            await transaction.finish()
        default: break
        }
    }

    func restorePurchases() async {
        for await result in Transaction.currentEntitlements {
            if let transaction = try? result.payloadValue {
                await updateProStatus(expiry: transaction.expirationDate)
            }
        }
    }

    /// The App Store transaction is always the real source of truth for
    /// entitlement (StoreKit re-verifies it locally every launch), so
    /// `isPro` is set immediately regardless of Firestore. But other parts
    /// of the app (leaderboards, another device, a future web dashboard)
    /// only know about Pro status via the Firestore field — previously a
    /// failed write here was swallowed with `try?`, so someone could pay,
    /// see Pro features unlock, and still show as non-Pro everywhere else
    /// that reads from Firestore. This retries once and surfaces the error
    /// if it still fails, instead of pretending it succeeded.
    @MainActor
    private func updateProStatus(expiry: Date?) async {
        isPro = true
        proSyncError = nil
        guard let uid = AuthService.shared.currentUser?.uid, let expiry = expiry else { return }
        let data: [String: Any] = ["isPro": true, "proExpiry": Timestamp(date: expiry)]
        do {
            try await FirebaseService.shared.db.collection("users").document(uid).updateData(data)
        } catch {
            do {
                try await FirebaseService.shared.db.collection("users").document(uid).updateData(data)
            } catch {
                proSyncError = NSLocalizedString("store.proSyncError", comment: "")
            }
        }
    }
}

