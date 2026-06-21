import StoreKit
import FirebaseFirestore

class StoreKitService: ObservableObject {
    static let shared = StoreKitService()
    @Published var products: [Product] = []
    @Published var isPro: Bool = false

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

    @MainActor
    private func updateProStatus(expiry: Date?) async {
        isPro = true
        guard let uid = AuthService.shared.currentUser?.uid, let expiry = expiry else { return }
        try? await FirebaseService.shared.db.collection("users").document(uid)
            .updateData(["isPro": true, "proExpiry": Timestamp(date: expiry)])
    }
}
