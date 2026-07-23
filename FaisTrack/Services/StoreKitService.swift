import StoreKit
import FirebaseFirestore

class StoreKitService: ObservableObject {
    static let shared = StoreKitService()
    @Published var products: [Product] = []
    @Published var isPro: Bool = false
    @Published var isLoadingProducts = true
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

    private var transactionListener: Task<Void, Never>?

    init() {
        // Previously isPro only ever got set to true (inside purchase/
        // restore), and nothing ever checked whether an existing
        // subscription was still valid on a fresh launch — meaning a
        // paying subscriber would look like a free user every time they
        // restarted the app, until they happened to tap Restore or buy
        // again. This is what actually keeps isPro correct across launches.
        transactionListener = listenForTransactionUpdates()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    @MainActor
    func loadProducts() async {
        isLoadingProducts = true
        products = (try? await Product.products(for: productIDs)) ?? []
        isLoadingProducts = false
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verification.payloadValue
            await updateProStatus(isPro: true, expiry: transaction.expirationDate)
            await transaction.finish()
        default: break
        }
    }

    /// Apple's App Review guidelines (3.1.2) require a restore mechanism
    /// for any subscription — this was previously implemented here but
    /// never actually surfaced anywhere in the paywall UI, which is a
    /// rejection risk on its own regardless of the other fixes below.
    func restorePurchases() async {
        await refreshEntitlements()
    }

    /// Continuously listens for transaction changes — renewals, refunds,
    /// revocations, and purchases made on another device — so isPro stays
    /// correct for the whole time the app is running, not just at the
    /// moment of a purchase. This was entirely missing before.
    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self, let transaction = try? result.payloadValue else { continue }
                await self.refreshEntitlements()
                await transaction.finish()
            }
        }
    }

    /// The actual source of truth: check every current entitlement and
    /// set isPro based on whether at least one is still valid, rather than
    /// only ever setting isPro = true and never re-checking. Without this,
    /// someone whose subscription lapsed, got refunded, or was revoked
    /// would stay "Pro" in the app forever once they'd ever subscribed once.
    @MainActor
    func refreshEntitlements() async {
        var activeExpiry: Date?
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? result.payloadValue,
                  productIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            if let expiry = transaction.expirationDate {
                if expiry > Date() { activeExpiry = expiry }
            } else {
                // Non-expiring entitlement (shouldn't normally apply to an
                // auto-renewable subscription, but handled defensively).
                activeExpiry = .distantFuture
            }
        }
        await updateProStatus(isPro: activeExpiry != nil, expiry: activeExpiry)
    }

    /// `expiry` is only meaningful when `isPro` is true — passed through
    /// as nil when clearing Pro status so Firestore doesn't keep a stale
    /// future date around for an account that's no longer actually subscribed.
    @MainActor
    private func updateProStatus(isPro: Bool, expiry: Date?) async {
        self.isPro = isPro
        proSyncError = nil
        guard let uid = AuthService.shared.currentUser?.uid else { return }
        var data: [String: Any] = ["isPro": isPro]
        data["proExpiry"] = isPro ? (expiry.map { Timestamp(date: $0) } ?? NSNull()) : FieldValue.delete()
        // setData(merge:) rather than updateData() — updateData() throws
        // "No document to update" outright for an account whose profile
        // document doesn't exist yet, the same missing-document class of
        // bug already fixed elsewhere in this app. A failed sync here
        // would incorrectly tell a paying subscriber their purchase didn't
        // go through everywhere else in the app that reads Firestore.
        do {
            try await FirebaseService.shared.db.collection("users").document(uid).setData(data, merge: true)
        } catch {
            do {
                try await FirebaseService.shared.db.collection("users").document(uid).setData(data, merge: true)
            } catch {
                proSyncError = NSLocalizedString("store.proSyncError", comment: "")
            }
        }
    }
}
