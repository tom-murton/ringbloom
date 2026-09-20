import Combine
import StoreKit

@MainActor
private final class FlowerShowTransactionUpdateStream {
    let stream: AsyncStream<FlowerShowPurchaseTransaction>
    let continuation: AsyncStream<FlowerShowPurchaseTransaction>.Continuation

    init() {
        var capturedContinuation: AsyncStream<FlowerShowPurchaseTransaction>.Continuation?
        stream = AsyncStream { continuation in
            capturedContinuation = continuation
        }
        guard let capturedContinuation else {
            preconditionFailure("Failed to create the StoreKit transaction update stream")
        }
        continuation = capturedContinuation
    }
}

@MainActor
final class StoreKitFlowerShowStoreClient: FlowerShowStoreClient {
    private var product: Product?
    private var transactions: [UInt64: StoreKit.Transaction] = [:]
    private var transactionUpdatesTask: Task<Void, Never>?
    private let transactionUpdateStream = FlowerShowTransactionUpdateStream()

    init() {
        transactionUpdateStream.continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.transactionUpdatesTask?.cancel()
            }
        }
    }

    var transactionUpdates: AsyncStream<FlowerShowPurchaseTransaction> {
        if transactionUpdatesTask == nil {
            transactionUpdatesTask = Task { @MainActor [weak self] in
                guard let self else { return }
                for await result in StoreKit.Transaction.updates {
                    guard Task.isCancelled == false else { break }
                    self.transactionUpdateStream.continuation.yield(self.snapshot(for: result))
                }
                self.transactionUpdateStream.continuation.finish()
            }
        }
        return transactionUpdateStream.stream
    }

    deinit { transactionUpdatesTask?.cancel() }

    func loadProduct() async throws -> FlowerShowProductInfo? {
        let products = try await Product.products(for: [FlowerShowAccessPolicy.productID])
        guard let product = products.first(where: {
            $0.id == FlowerShowAccessPolicy.productID && $0.type == .nonConsumable
        }) else {
            self.product = nil
            return nil
        }
        self.product = product
        return FlowerShowProductInfo(productID: product.id, displayPrice: product.displayPrice)
    }

    func loadEntitlementSnapshot() async throws -> FlowerShowEntitlementSnapshot {
        let appTransaction: FlowerShowAppTransactionCheck
        do {
            switch try await AppTransaction.shared {
            case let .verified(transaction):
                appTransaction = .verified(
                    FlowerShowAppTransactionSnapshot(
                        environment: environment(for: transaction.environment),
                        originalPurchaseDate: transaction.originalPurchaseDate,
                        isVerified: true
                    )
                )
            case .unverified:
                appTransaction = .unverified
            }
        } catch {
            appTransaction = .unavailable
        }

        var purchaseTransaction: FlowerShowPurchaseTransaction?
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case let .verified(transaction) = result,
                  transaction.productID == FlowerShowAccessPolicy.productID,
                  transaction.productType == .nonConsumable
            else { continue }
            purchaseTransaction = snapshot(
                for: .verified(transaction)
            )
            break
        }

        return FlowerShowEntitlementSnapshot(
            appTransaction: appTransaction,
            purchaseTransaction: purchaseTransaction
        )
    }

    func purchase() async throws -> FlowerShowPurchaseOutcome {
        guard let product else { throw FlowerShowStoreClientError.productUnavailable }
        do {
            switch try await product.purchase() {
            case let .success(result):
                return .success(snapshot(for: result))
            case .userCancelled:
                return .userCancelled
            case .pending:
                return .pending
            @unknown default:
                throw FlowerShowStoreClientError.failed
            }
        } catch Product.PurchaseError.purchaseNotAllowed {
            throw FlowerShowStoreClientError.purchasesDisabled
        } catch Product.PurchaseError.productUnavailable {
            throw FlowerShowStoreClientError.productUnavailable
        } catch {
            throw FlowerShowStoreClientError.failed
        }
    }

    func sync() async throws {
        try await AppStore.sync()
    }

    func finish(transactionID: UInt64) async {
        guard let transaction = transactions.removeValue(forKey: transactionID) else { return }
        await transaction.finish()
    }

    private func snapshot(
        for result: VerificationResult<StoreKit.Transaction>
    ) -> FlowerShowPurchaseTransaction {
        switch result {
        case let .verified(transaction):
            transactions[transaction.id] = transaction
            return FlowerShowPurchaseTransaction(
                id: transaction.id,
                productID: transaction.productID,
                isVerified: true,
                isRevoked: transaction.revocationDate != nil,
                price: transaction.price,
                currencyCode: transaction.currency?.identifier,
                purchaseDate: transaction.purchaseDate,
                originalPurchaseDate: transaction.originalPurchaseDate,
                environment: environment(for: transaction.environment),
                ownership: ownership(for: transaction.ownershipType)
            )
        case let .unverified(transaction, _):
            transactions[transaction.id] = transaction
            return FlowerShowPurchaseTransaction(
                id: transaction.id,
                productID: transaction.productID,
                isVerified: false,
                isRevoked: transaction.revocationDate != nil,
                price: transaction.price,
                currencyCode: transaction.currency?.identifier,
                purchaseDate: transaction.purchaseDate,
                originalPurchaseDate: transaction.originalPurchaseDate,
                environment: environment(for: transaction.environment),
                ownership: ownership(for: transaction.ownershipType)
            )
        }
    }

    private func environment(for environment: AppStore.Environment) -> FlowerShowTransactionEnvironment {
        switch environment {
        case .production: .production
        case .sandbox: .sandbox
        case .xcode: .xcode
        default: .unknown
        }
    }

    private func ownership(for ownership: StoreKit.Transaction.OwnershipType) -> FlowerShowPurchaseOwnership {
        switch ownership {
        case .purchased: .purchased
        case .familyShared: .familyShared
        default: .unknown
        }
    }
}

@MainActor
protocol FlowerShowPurchaseProvenanceStoring: AnyObject {
    func hasPendingIntent(at date: Date) -> Bool
    func beginIntent(for productID: String, at date: Date)
    func markIntentPending()
    func cancelIntent()
    func matchingIntentSource(for transaction: FlowerShowPurchaseTransaction, now: Date) -> String?
    func qualifiedSource(for transactionID: UInt64) -> String?
    func recordQualified(transactionID: UInt64, source: String)
}

/// Local provenance only. It cannot prove network delivery or distinguish every clock anomaly;
/// it prevents entitlement/bootstrap ownership from becoming revenue without a local flow.
@MainActor
final class UserDefaultsFlowerShowPurchaseProvenanceStore: FlowerShowPurchaseProvenanceStoring {
    private static let intentKey = "FlowerShowPendingPurchaseIntentV1"
    private static let qualifiedKey = "FlowerShowQualifiedPurchaseSourcesV1"
    private static let maximumIntentAge: TimeInterval = 7 * 24 * 60 * 60
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func hasPendingIntent(at date: Date) -> Bool {
        guard let intent = defaults.dictionary(forKey: Self.intentKey),
              let started = intent["startedAt"] as? Double,
              intent["state"] as? String == "pending"
        else { return false }
        guard date.timeIntervalSince(Date(timeIntervalSince1970: started)) <= Self.maximumIntentAge else {
            cancelIntent()
            return false
        }
        return true
    }

    func beginIntent(for productID: String, at date: Date) {
        defaults.set(
            ["productID": productID, "startedAt": date.timeIntervalSince1970, "state": "initiated"],
            forKey: Self.intentKey
        )
    }

    func markIntentPending() {
        guard var intent = defaults.dictionary(forKey: Self.intentKey) else { return }
        intent["state"] = "pending"
        defaults.set(intent, forKey: Self.intentKey)
    }

    func cancelIntent() { defaults.removeObject(forKey: Self.intentKey) }

    func matchingIntentSource(for transaction: FlowerShowPurchaseTransaction, now: Date) -> String? {
        guard transaction.ownership == .purchased,
              let intent = defaults.dictionary(forKey: Self.intentKey),
              let productID = intent["productID"] as? String,
              let started = intent["startedAt"] as? Double,
              transaction.productID == productID
        else { return nil }
        let startedAt = Date(timeIntervalSince1970: started)
        guard now.timeIntervalSince(startedAt) <= Self.maximumIntentAge else {
            cancelIntent()
            return nil
        }
        // A historic entitlement returned by product.purchase is not evidence of a new charge.
        guard let purchaseDate = transaction.purchaseDate,
              purchaseDate >= startedAt,
              (transaction.originalPurchaseDate ?? purchaseDate) >= startedAt
        else { return nil }
        return intent["state"] as? String == "pending" ? "pending_approved" : "direct_purchase"
    }

    func qualifiedSource(for transactionID: UInt64) -> String? {
        (defaults.dictionary(forKey: Self.qualifiedKey)?[String(transactionID)] as? String)
    }

    func recordQualified(transactionID: UInt64, source: String) {
        var sources = defaults.dictionary(forKey: Self.qualifiedKey) ?? [:]
        sources[String(transactionID)] = source
        defaults.set(sources, forKey: Self.qualifiedKey)
        cancelIntent()
    }
}

@MainActor
final class FlowerShowStore: ObservableObject, FlowerShowAccessProviding {
    @Published private(set) var accessState: FlowerShowAccessState
    @Published private(set) var productState: FlowerShowProductState
    @Published private(set) var purchaseState: FlowerShowPurchaseState = .idle

    private let client: any FlowerShowStoreClient
    private let launchOverrides: FlowerShowLaunchOverrides
    private let purchaseAttribution: any PurchaseAttributionTracking
    private let purchaseAnalytics: any PurchaseBoundaryAnalyticsTracking
    private let purchaseProvenance: any FlowerShowPurchaseProvenanceStoring
    private let now: () -> Date
    private var bootstrapProductTask: Task<Void, Never>?
    private var bootstrapAccessTask: Task<Void, Never>?
    private var transactionTask: Task<Void, Never>?
    private var finishedTransactionIDs: Set<UInt64> = []
    private var revokedTransactionIDs: Set<UInt64> = []
    private var activePurchaseTransactionIDs: Set<UInt64> = []
    private var verifiedSources: Set<FlowerShowEntitlementSource>
    private var accessRefreshGeneration: UInt64 = 0
    private var storefrontOperation: StorefrontOperation?

    private enum StorefrontOperation {
        case purchase
        case restore
    }

    /// Refreshes establish sources, but authority to remove a source is deliberately narrower.
    ///
    /// - Bootstrap, restore and post-purchase snapshots are additive. StoreKit views can lag a
    ///   verified transaction, so an empty ordinary snapshot must not erase access delivered in
    ///   this process, regardless of request start or completion order.
    /// - A verified revocation removes only its transaction ID. The IAP source is removed only
    ///   when no verified active purchase IDs remain, so a late or duplicate old-ID revocation
    ///   cannot erase a newer grant. Stale current-entitlements views cannot re-add a revoked ID.
    ///   The reserved revocation refresh may still recover verified legacy ownership.
    /// - Errors and unavailable AppTransactions preserve sources already verified in-process.
    /// - Generation ordering prevents an older request from publishing after a newer request or
    ///   verified transaction. Wrapping is safe because equality is only relevant while a finite
    ///   set of in-flight requests exists.
    private enum AccessRefreshReason: Equatable {
        case bootstrap
        case restore
        case postPurchase
        case revocation
    }

    private struct AccessRefreshRequest {
        let generation: UInt64
        let reason: AccessRefreshReason
    }

    var hasFullFlowerShowAccess: Bool {
        if case .full = accessState { return true }
        return false
    }

    init(
        client: any FlowerShowStoreClient = StoreKitFlowerShowStoreClient(),
        launchOverrides: FlowerShowLaunchOverrides = .production,
        purchaseAttribution: any PurchaseAttributionTracking = NoOpPurchaseAttributionTracker(),
        purchaseAnalytics: any PurchaseBoundaryAnalyticsTracking = ProductAnalytics.shared,
        purchaseProvenance: any FlowerShowPurchaseProvenanceStoring = UserDefaultsFlowerShowPurchaseProvenanceStore(),
        now: @escaping () -> Date = Date.init
    ) {
        self.client = client
        self.launchOverrides = launchOverrides
        self.purchaseAttribution = purchaseAttribution
        self.purchaseAnalytics = purchaseAnalytics
        self.purchaseProvenance = purchaseProvenance
        self.now = now
        self.accessState = Self.accessState(for: launchOverrides.access)
        self.verifiedSources = Self.verifiedSources(for: launchOverrides.access)
        self.productState = if launchOverrides.productUnavailable {
            .unavailable
        } else if launchOverrides.access != nil,
                  let displayPrice = launchOverrides.displayPrice
        {
            .available(
                FlowerShowProductInfo(
                    productID: FlowerShowAccessPolicy.productID,
                    displayPrice: displayPrice
                )
            )
        } else {
            .loading
        }
        if launchOverrides.access == nil, purchaseProvenance.hasPendingIntent(at: now()) {
            purchaseState = .pending
        }

        if launchOverrides.access == nil {
            startTransactionListener()
            startBootstrapTasks()
        }
    }

    deinit {
        bootstrapProductTask?.cancel()
        bootstrapAccessTask?.cancel()
        transactionTask?.cancel()
    }

    func resetPurchaseState() {
        guard storefrontOperation == nil else { return }
        purchaseState = purchaseProvenance.hasPendingIntent(at: now()) ? .pending : .idle
    }

    func refreshPendingPurchaseState() {
        guard storefrontOperation == nil, hasFullFlowerShowAccess == false else { return }
        if purchaseProvenance.hasPendingIntent(at: now()) {
            purchaseState = .pending
        } else if purchaseState == .pending, launchOverrides.purchase != .pending {
            purchaseState = .idle
        }
    }

    func startTransactionListener() {
        guard launchOverrides.access == nil, transactionTask == nil else { return }
        let client = self.client
        transactionTask = Task { @MainActor [weak self, client] in
            for await transaction in client.transactionUpdates {
                guard Task.isCancelled == false else { return }
                guard let self else { return }
                await self.handle(transaction)
            }
        }
    }

    func stopTransactionListener() {
        transactionTask?.cancel()
        transactionTask = nil
    }

    func retryProductLoad() async {
        guard launchOverrides.productUnavailable == false else {
            productState = .unavailable
            return
        }
        await loadProduct()
    }

    /// Retries entitlement recovery without loading storefront product metadata.
    func retryAccessCheck() async {
        switch launchOverrides.access {
        case .checkingThenFull:
            verifiedSources.insert(.storePurchase)
            publishAccessState()
        case .checkingThenSample:
            publishAccessState()
        case .sample, .fullPurchase, .legacy, .checking:
            return
        case nil:
            await refreshAccess(reason: .bootstrap)
        }
    }

    @discardableResult
    func purchase() async -> Bool {
        guard storefrontOperation == nil else { return false }
        if purchaseProvenance.hasPendingIntent(at: now()) {
            purchaseState = .pending
            return false
        }
        if purchaseState == .pending {
            guard launchOverrides.purchase != .pending else { return false }
            // The durable request expired while this process remained alive.
            purchaseState = .idle
        }
        guard case .available = productState else {
            purchaseState = .failed
            return false
        }
        guard beginStorefrontOperation(.purchase) else { return false }
        defer { endStorefrontOperation(.purchase) }
        let knownTransactionIDs = activePurchaseTransactionIDs
            .union(finishedTransactionIDs)
            .union(revokedTransactionIDs)

        if launchOverrides.purchase == .pending {
            purchaseState = .pending
            return false
        }
        if launchOverrides.purchase == .failed {
            purchaseState = .failed
            return false
        }
        if launchOverrides.purchase == .userCancelled {
            purchaseState = .idle
            return false
        }
        if launchOverrides.purchase == .success {
            verifiedSources.insert(.storePurchase)
            publishAccessState()
            purchaseState = .success
            return true
        }
        if launchOverrides.purchase == .disabled {
            purchaseState = .disabled
            return false
        }

        purchaseState = .purchasing
        // Persist before awaiting StoreKit: an update may arrive before purchase() returns.
        purchaseProvenance.beginIntent(for: FlowerShowAccessPolicy.productID, at: now())
        if launchOverrides.purchase == .purchasing {
            await waitUntilCancelled()
            return false
        }
        do {
            switch try await client.purchase() {
            case let .success(transaction):
                let delivered = await deliver(transaction)
                return delivered && !knownTransactionIDs.contains(transaction.id)
            case .pending:
                purchaseProvenance.markIntentPending()
                purchaseState = .pending
                return false
            case .userCancelled:
                purchaseProvenance.cancelIntent()
                purchaseState = .idle
                return false
            }
        } catch FlowerShowStoreClientError.productUnavailable {
            purchaseProvenance.cancelIntent()
            productState = .unavailable
            purchaseState = .idle
        } catch FlowerShowStoreClientError.purchasesDisabled {
            purchaseProvenance.cancelIntent()
            purchaseState = .disabled
        } catch {
            purchaseProvenance.cancelIntent()
            purchaseState = .failed
        }
        return false
    }

    func restorePurchases() async {
        guard beginStorefrontOperation(.restore) else { return }
        defer { endStorefrontOperation(.restore) }

        if let access = launchOverrides.access {
            if launchOverrides.restore == .restoring {
                purchaseState = .restoring
                await waitUntilCancelled()
                return
            }
            if launchOverrides.restore == .success {
                verifiedSources.insert(.storePurchase)
                publishAccessState()
                purchaseState = .success
                return
            }
            if access == .fullPurchase || access == .legacy {
                accessState = Self.accessState(for: access)
                purchaseState = .success
            }
            return
        }
        purchaseState = .restoring
        do {
            try await client.sync()
            await refreshAccess(reason: .restore)
            if hasFullFlowerShowAccess {
                purchaseState = .success
            } else {
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed
        }
    }

    private func startBootstrapTasks() {
        let client = client
        let accessRequest = beginAccessRefresh(reason: .bootstrap)

        if launchOverrides.productUnavailable == false {
            bootstrapProductTask = Task { @MainActor [weak self, client] in
                let result = await Self.loadProduct(using: client)
                guard Task.isCancelled == false else { return }
                self?.applyProductResult(result)
            }
        }

        bootstrapAccessTask = Task { @MainActor [weak self, client] in
            let result = await Self.loadEntitlementSnapshot(using: client)
            guard Task.isCancelled == false else { return }
            self?.applyAccessResult(result, for: accessRequest)
        }
    }

    private func loadProduct() async {
        productState = .loading
        let result = await Self.loadProduct(using: client)
        guard Task.isCancelled == false else { return }
        applyProductResult(result)
    }

    private func refreshAccess(reason: AccessRefreshReason) async {
        await completeAccessRefresh(beginAccessRefresh(reason: reason))
    }

    private func completeAccessRefresh(_ request: AccessRefreshRequest) async {
        guard request.generation == accessRefreshGeneration else { return }
        let result = await Self.loadEntitlementSnapshot(using: client)
        guard Task.isCancelled == false else { return }
        applyAccessResult(result, for: request)
    }

    private func handle(_ transaction: FlowerShowPurchaseTransaction) async {
        guard transaction.productID == FlowerShowAccessPolicy.productID else { return }
        guard transaction.isVerified else {
            if hasFullFlowerShowAccess { return }
            await refreshAccess(reason: .bootstrap)
            return
        }
        guard transaction.isRevoked == false else {
            revokedTransactionIDs.insert(transaction.id)
            activePurchaseTransactionIDs.remove(transaction.id)
            if activePurchaseTransactionIDs.isEmpty {
                verifiedSources.remove(.storePurchase)
            }
            publishAccessState()
            let refreshRequest = beginAccessRefresh(reason: .revocation)
            await finishIfNeeded(transaction)
            await completeAccessRefresh(refreshRequest)
            if storefrontOperation == nil {
                purchaseState = hasFullFlowerShowAccess ? .success : .idle
            }
            return
        }
        guard revokedTransactionIDs.contains(transaction.id) == false else {
            await finishIfNeeded(transaction)
            return
        }
        activePurchaseTransactionIDs.insert(transaction.id)
        verifiedSources.insert(.storePurchase)
        publishAccessState()
        let qualifiedSource = purchaseProvenance.qualifiedSource(for: transaction.id)
        let matchingSource = purchaseProvenance.matchingIntentSource(for: transaction, now: now())
        if let source = qualifiedSource ?? matchingSource,
           storefrontOperation != .restore || qualifiedSource != nil || source == "pending_approved" {
            // A matching locally pending request remains revenue evidence even during Restore.
            qualifyVerifiedNewPurchase(transaction, source: source)
        }
        if storefrontOperation == nil {
            purchaseState = .success
        }
        let refreshRequest = beginAccessRefresh(reason: .postPurchase)
        await finishIfNeeded(transaction)
        await completeAccessRefresh(refreshRequest)
    }

    private func deliver(_ transaction: FlowerShowPurchaseTransaction) async -> Bool {
        guard FlowerShowAccessPolicy.hasPurchaseAccess(transaction) else {
            purchaseProvenance.cancelIntent()
            purchaseState = .failed
            return false
        }
        guard revokedTransactionIDs.contains(transaction.id) == false else {
            await finishIfNeeded(transaction)
            purchaseState = hasFullFlowerShowAccess ? .success : .idle
            return false
        }
        activePurchaseTransactionIDs.insert(transaction.id)
        verifiedSources.insert(.storePurchase)
        publishAccessState()
        let qualifiedNewPurchase = qualifyVerifiedNewPurchase(transaction, source: "direct_purchase")
        purchaseState = .success
        let refreshRequest = beginAccessRefresh(reason: .postPurchase)
        await finishIfNeeded(transaction)
        await completeAccessRefresh(refreshRequest)
        if revokedTransactionIDs.contains(transaction.id) {
            purchaseState = hasFullFlowerShowAccess ? .success : .idle
            return false
        }
        return qualifiedNewPurchase
    }

    private func finishIfNeeded(_ transaction: FlowerShowPurchaseTransaction) async {
        guard finishedTransactionIDs.insert(transaction.id).inserted else { return }
        await client.finish(transactionID: transaction.id)
    }

    private func qualifyVerifiedNewPurchase(
        _ transaction: FlowerShowPurchaseTransaction,
        source: String
    ) -> Bool {
        guard transaction.ownership == .purchased else { return false }
        if let knownSource = purchaseProvenance.qualifiedSource(for: transaction.id) {
            // A moneyless first copy may later arrive with price/currency. The reporter owns
            // revenue deduplication; the PostHog boundary event remains one per transaction.
            purchaseAttribution.trackVerifiedNewPurchase(transaction)
            return knownSource == source
        }
        guard let matchedSource = purchaseProvenance.matchingIntentSource(for: transaction, now: now()),
              matchedSource == source
        else { return false }
        purchaseProvenance.recordQualified(transactionID: transaction.id, source: source)
        purchaseAttribution.trackVerifiedNewPurchase(transaction)
        purchaseAnalytics.purchaseVerifiedNew(
            source: source,
            environment: analyticsEnvironment(for: transaction.environment),
            moneyStatus: moneyStatus(for: transaction)
        )
        return true
    }

    private func analyticsEnvironment(for environment: FlowerShowTransactionEnvironment) -> String {
        switch environment {
        case .production: "production"
        case .sandbox: "sandbox"
        case .xcode: "xcode"
        case .unknown: "unknown"
        }
    }

    private func moneyStatus(for transaction: FlowerShowPurchaseTransaction) -> String {
        guard isValidStoreKitMoney(price: transaction.price, currencyCode: transaction.currencyCode),
              let price = transaction.price
        else {
            return "unavailable"
        }
        return price > 0 ? "positive" : "zero"
    }

    private func beginAccessRefresh(reason: AccessRefreshReason) -> AccessRefreshRequest {
        accessRefreshGeneration &+= 1
        return AccessRefreshRequest(generation: accessRefreshGeneration, reason: reason)
    }

    private func applyAccessResult(
        _ result: Result<FlowerShowEntitlementSnapshot, Error>,
        for request: AccessRefreshRequest
    ) {
        guard request.generation == accessRefreshGeneration else { return }

        switch result {
        case let .success(snapshot):
            if FlowerShowAccessPolicy.hasLegacyAccess(snapshot.appTransaction) {
                verifiedSources.insert(.legacyPaidApp)
            }
            if request.reason != .revocation,
               let purchase = snapshot.purchaseTransaction,
               revokedTransactionIDs.contains(purchase.id) == false,
               FlowerShowAccessPolicy.hasPurchaseAccess(purchase)
            {
                activePurchaseTransactionIDs.insert(purchase.id)
                verifiedSources.insert(.storePurchase)
            }
            publishAccessState()
        case .failure:
            if accessState == .checking {
                accessState = .sample
            }
        }
    }

    private func publishAccessState() {
        if verifiedSources.contains(.storePurchase) {
            accessState = .full(.storePurchase)
        } else if verifiedSources.contains(.legacyPaidApp) {
            accessState = .full(.legacyPaidApp)
        } else {
            accessState = .sample
        }
    }

    private func beginStorefrontOperation(_ operation: StorefrontOperation) -> Bool {
        guard storefrontOperation == nil else { return false }
        storefrontOperation = operation
        return true
    }

    private func endStorefrontOperation(_ operation: StorefrontOperation) {
        guard storefrontOperation == operation else { return }
        storefrontOperation = nil
    }

    private func applyProductResult(_ result: Result<FlowerShowProductInfo?, Error>) {
        switch result {
        case let .success(product?):
            productState = .available(product)
        case .success(nil), .failure:
            productState = .unavailable
        }
    }

    private static func loadProduct(
        using client: any FlowerShowStoreClient
    ) async -> Result<FlowerShowProductInfo?, Error> {
        do {
            return .success(try await client.loadProduct())
        } catch {
            return .failure(error)
        }
    }

    private static func loadEntitlementSnapshot(
        using client: any FlowerShowStoreClient
    ) async -> Result<FlowerShowEntitlementSnapshot, Error> {
        do {
            return .success(try await client.loadEntitlementSnapshot())
        } catch {
            return .failure(error)
        }
    }

    private func waitUntilCancelled() async {
        let stream = AsyncStream<Void> { _ in }
        for await _ in stream {
            // Deterministic launch overrides intentionally remain in flight until cancellation.
        }
    }

    private static func accessState(for override: FlowerShowLaunchAccessOverride?) -> FlowerShowAccessState {
        switch override {
        case .sample: .sample
        case .fullPurchase: .full(.storePurchase)
        case .legacy: .full(.legacyPaidApp)
        case .checking, .checkingThenFull, .checkingThenSample: .checking
        case nil: .checking
        }
    }

    private static func verifiedSources(
        for override: FlowerShowLaunchAccessOverride?
    ) -> Set<FlowerShowEntitlementSource> {
        switch override {
        case .fullPurchase: [.storePurchase]
        case .legacy: [.legacyPaidApp]
        case .sample, .checking, .checkingThenFull, .checkingThenSample, nil: []
        }
    }
}

extension FlowerShowLaunchOverrides {
    static let production = Self(access: nil, productUnavailable: false, purchase: nil)
}
