import SwiftUI

enum FlowerShowStoreClientComposition: Equatable {
    case production
    #if DEBUG
        case hostedUnitTests
        case analyticsUIVerification

        private static let hostedUnitTestBundleName = "RingbloomTests.xctest"
    #endif

    static func resolve(environment: [String: String], arguments: [String] = []) -> Self {
        #if DEBUG
            let testBundlePath = environment["XCInjectBundle"]
                ?? environment["XCTestBundlePath"]
            if testBundlePath?.hasSuffix(hostedUnitTestBundleName) == true {
                return .hostedUnitTests
            }
            if environment["RINGBLOOM_ANALYTICS_TEST_INGESTION"] == "1",
               arguments.contains("--ui-testing"), arguments.contains("--analytics-purchase-fixture") {
                return .analyticsUIVerification
            }
        #endif
        return .production
    }

    @MainActor
    func makeStoreClient() -> any FlowerShowStoreClient {
        switch self {
        case .production:
            StoreKitFlowerShowStoreClient()
        #if DEBUG
            case .hostedUnitTests:
                HostedUnitTestFlowerShowStoreClient()
            case .analyticsUIVerification:
                AnalyticsVerificationFlowerShowStoreClient()
        #endif
        }
    }
}

#if DEBUG
    /// Explicit test-tier UI fixture. It traverses purchase qualification without contacting
    /// StoreKit or claiming a monetary amount. The app composition supplies a no-op AF tracker.
    @MainActor
    final class AnalyticsVerificationFlowerShowStoreClient: FlowerShowStoreClient {
        let transactionUpdates = AsyncStream<FlowerShowPurchaseTransaction> { $0.finish() }
        private var purchased: FlowerShowPurchaseTransaction?
        func loadProduct() async throws -> FlowerShowProductInfo? {
            FlowerShowProductInfo(productID: FlowerShowAccessPolicy.productID, displayPrice: "Test purchase")
        }
        func loadEntitlementSnapshot() async throws -> FlowerShowEntitlementSnapshot {
            FlowerShowEntitlementSnapshot(appTransaction: .unavailable, purchaseTransaction: purchased)
        }
        func purchase() async throws -> FlowerShowPurchaseOutcome {
            let date = Date()
            let transaction = FlowerShowPurchaseTransaction(
                id: UInt64.random(in: 1 ... UInt64.max), productID: FlowerShowAccessPolicy.productID,
                isVerified: true, isRevoked: false, price: nil, currencyCode: nil,
                purchaseDate: date, originalPurchaseDate: date, environment: .xcode, ownership: .purchased
            )
            purchased = transaction
            return .success(transaction)
        }
        func sync() async throws {}
        func finish(transactionID _: UInt64) async {}
    }

    @MainActor
    final class HostedUnitTestFlowerShowStoreClient: FlowerShowStoreClient {
        let transactionUpdates = AsyncStream<FlowerShowPurchaseTransaction> { continuation in
            continuation.finish()
        }

        func loadProduct() async throws -> FlowerShowProductInfo? { nil }

        func loadEntitlementSnapshot() async throws -> FlowerShowEntitlementSnapshot {
            FlowerShowEntitlementSnapshot(appTransaction: .unavailable, purchaseTransaction: nil)
        }

        func purchase() async throws -> FlowerShowPurchaseOutcome {
            throw FlowerShowStoreClientError.purchasesDisabled
        }

        func sync() async throws {}

        func finish(transactionID _: UInt64) async {}
    }
#endif

@main
struct RingbloomApp: App {
    @UIApplicationDelegateAdaptor(RingbloomAppDelegate.self) private var appDelegate
    @StateObject private var game: GameModel
    @StateObject private var flowerShowStore: FlowerShowStore
    @StateObject private var audio = AudioService.shared
    @StateObject private var feedback = FeedbackService.shared
    @StateObject private var feedbackPrompts: FeedbackPromptCoordinator
    @StateObject private var analytics = ProductAnalytics.shared

    init() {
        let environment = ProcessInfo.processInfo.environment
        let launchMode = GameLaunchMode.current
        let arguments = ProcessInfo.processInfo.arguments
        let launchOverrides = FlowerShowLaunchOverrides.resolve(
            arguments: ProcessInfo.processInfo.arguments,
            launchMode: launchMode
        )
        let clientComposition = FlowerShowStoreClientComposition.resolve(environment: environment, arguments: ProcessInfo.processInfo.arguments)
        let provenanceDefaults: UserDefaults
        if launchMode.isDeterministic || clientComposition != .production {
            guard let isolatedDefaults = UserDefaults(suiteName: "RingbloomTestPurchase.\(UUID().uuidString)") else {
                preconditionFailure("Cannot create isolated test purchase state")
            }
            provenanceDefaults = isolatedDefaults
        } else {
            provenanceDefaults = .standard
        }
        let store = FlowerShowStore(
            client: clientComposition.makeStoreClient(),
            launchOverrides: launchOverrides,
            purchaseAttribution: clientComposition == .production
                ? AppsFlyerAttribution.shared
                : NoOpPurchaseAttributionTracker(),
            purchaseProvenance: UserDefaultsFlowerShowPurchaseProvenanceStore(defaults: provenanceDefaults)
        )
        let feedbackDefaults: UserDefaults
        if launchMode.isDeterministic {
            guard let isolatedDefaults = UserDefaults(suiteName: "RingbloomFeedbackTests.\(UUID().uuidString)") else {
                preconditionFailure("Cannot create isolated feedback prompt state")
            }
            feedbackDefaults = isolatedDefaults
        } else {
            feedbackDefaults = .standard
        }
        #if DEBUG
            if arguments.contains("--feedback-nudge-due") {
                FeedbackPromptCoordinator.seedNudgeDueForTesting(defaults: feedbackDefaults)
            }
        #endif
        _feedbackPrompts = StateObject(
            wrappedValue: FeedbackPromptCoordinator(defaults: feedbackDefaults)
        )
        _flowerShowStore = StateObject(wrappedValue: store)
        _game = StateObject(
            wrappedValue: GameModel(
                launchMode: launchMode,
                progressStore: launchMode.isDeterministic
                    ? InMemoryGameProgressStore(progress: GameModel.previewProgress(arguments: arguments))
                    : FileGameProgressStore(),
                flowerShowAccess: store
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(game)
                .environmentObject(flowerShowStore)
                .environmentObject(audio)
                .environmentObject(feedback)
                .environmentObject(feedbackPrompts)
                .environmentObject(analytics)
                .preferredColorScheme(.dark)
        }
    }
}
