import StoreKit

/// Manages App Store subscriptions using StoreKit 2.
/// Product ID: in.co.vlspro.rental.monthly  (₹1500/month plan, auto-renewing)
/// New subscribers get a 2-month free trial (introductory offer, configured in
/// App Store Connect / the local .storekit file — see `isEligibleForIntroOffer`).
/// Price and payout banking/tax details are configured in App Store Connect, not here —
/// this file only reads back whatever price is live there via Product.products(for:).
@MainActor
class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()

    @Published var products: [Product] = []
    @Published var isSubscribed: Bool = false
    @Published var isPurchasing: Bool = false
    @Published var isLoading: Bool = true
    @Published var errorMessage: String = ""

    /// True if the current Apple ID has never redeemed this subscription's intro/free-trial
    /// offer — used to decide whether the paywall shows "2 Months Free" or the plain price.
    @Published var isEligibleForIntroOffer: Bool = false

    private let productIDs: Set<String> = ["in.co.vlspro.rental.monthly"]
    private var transactionListenerTask: Task<Void, Error>?

    init() {
        transactionListenerTask = startTransactionListener()
        Task {
            await loadProducts()
            await refreshSubscriptionStatus()
            await refreshIntroOfferEligibility()
            isLoading = false
        }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - Load Products from App Store

    func loadProducts() async {
        do {
            products = try await Product.products(for: productIDs)
        } catch {
            print("[StoreKit] Failed to load products: \(error)")
        }
    }

    // MARK: - Free Trial Eligibility

    func refreshIntroOfferEligibility() async {
        guard let subscription = products.first?.subscription else {
            isEligibleForIntroOffer = false
            return
        }
        isEligibleForIntroOffer = await subscription.isEligibleForIntroOffer
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        isPurchasing = true
        errorMessage = ""
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await refreshSubscriptionStatus()
                await transaction.finish()

            case .pending:
                errorMessage = "Purchase is pending. Check your payment method in Settings."

            case .userCancelled:
                break   // user tapped cancel — no error needed

            @unknown default:
                break
            }
        } catch {
            errorMessage = "Purchase failed. Please try again."
            print("[StoreKit] Purchase error: \(error)")
        }
    }

    // MARK: - Restore Purchases

    func restore() async {
        isPurchasing = true
        errorMessage = ""
        defer { isPurchasing = false }

        do {
            try await AppStore.sync()
            await refreshSubscriptionStatus()
            await refreshIntroOfferEligibility()
            if !isSubscribed {
                errorMessage = "No active subscription found for this Apple ID."
            }
        } catch {
            errorMessage = "Restore failed. Please try again."
            print("[StoreKit] Restore error: \(error)")
        }
    }

    // MARK: - Subscription Status Check

    func refreshSubscriptionStatus() async {
        var hasActive = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result else { continue }
            guard productIDs.contains(tx.productID) else { continue }
            if let exp = tx.expirationDate {
                if exp > Date() { hasActive = true }
            } else {
                hasActive = true   // non-expiring (shouldn't occur for subscriptions)
            }
        }
        isSubscribed = hasActive
    }

    // MARK: - Background Transaction Listener
    // Handles renewals, refunds, and billing retry successes even when app is open.

    private func startTransactionListener() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { return }
                guard case .verified(let tx) = result else { continue }
                await self.refreshSubscriptionStatus()
                await tx.finish()
            }
        }
    }

    // MARK: - Verification Helper

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
