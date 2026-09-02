import SwiftUI

enum FlowerShowStoreClientComposition: Equatable {
    case production
    #if DEBUG
        case hostedUnitTests

        private static let hostedUnitTestBundleName = "RingbloomTests.xctest"
    #endif

    static func resolve(environment: [String: String]) -> Self {
        #if DEBUG
            let testBundlePath = environment["XCInjectBundle"]
                ?? environment["XCTestBundlePath"]
            if testBundlePath?.hasSuffix(hostedUnitTestBundleName) == true {
                return .hostedUnitTests
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
        #endif
        }
    }
}

#if DEBUG
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
    @StateObject private var analytics = ProductAnalytics.shared

    init() {
        let environment = ProcessInfo.processInfo.environment
        let launchMode = GameLaunchMode.current
        let launchOverrides = FlowerShowLaunchOverrides.resolve(
            arguments: ProcessInfo.processInfo.arguments,
            launchMode: launchMode
        )
        let clientComposition = FlowerShowStoreClientComposition.resolve(environment: environment)
        let store = FlowerShowStore(
            client: clientComposition.makeStoreClient(),
            launchOverrides: launchOverrides,
            purchaseAttribution: clientComposition == .production
                ? AppsFlyerAttribution.shared
                : NoOpPurchaseAttributionTracker()
        )
        let arguments = ProcessInfo.processInfo.arguments
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
                .environmentObject(analytics)
                .preferredColorScheme(.dark)
        }
    }
}
