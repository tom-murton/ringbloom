import Foundation
import StoreKit
import StoreKitTest
import Testing
@testable import Ringbloom

@MainActor
struct AppsFlyerAttributionTests {
    @Test func releaseAndTestFlightSessionsAreEnabledWithoutAPromptGate() {
        let policy = AppsFlyerEmissionPolicy.resolve(isDebug: false, environment: [:], arguments: ["app"])
        #expect(policy.allowsSDK)
        #expect(policy.allowsPurchase(.production))
        #expect(!policy.allowsPurchase(.sandbox))
        #expect(!policy.allowsPurchase(.xcode))
        #expect(!policy.allowsPurchase(.unknown))
    }

    @Test func developmentIngestionRequiresExplicitOptInAndHostedUnitsNeverSend() {
        for (debug, arguments) in [(true, ["app"]), (false, ["app", "--ui-testing"])] {
            #expect(!AppsFlyerEmissionPolicy.resolve(isDebug: debug, environment: [:], arguments: arguments).allowsSDK)
            let optedIn = AppsFlyerEmissionPolicy.resolve(
                isDebug: debug, environment: ["RINGBLOOM_APPSFLYER_TEST_INGESTION": "1"], arguments: arguments
            )
            #expect(optedIn.allowsSDK)
            #expect(optedIn.allowsPurchase(.sandbox))
            #expect(optedIn.allowsPurchase(.xcode))
            #expect(!optedIn.allowsPurchase(.unknown))
        }
        for key in ["XCInjectBundle", "XCTestBundlePath"] {
            let hosted = AppsFlyerEmissionPolicy.resolve(isDebug: false, environment: [
                key: "/tmp/RingbloomTests.xctest", "RINGBLOOM_APPSFLYER_TEST_INGESTION": "1",
            ], arguments: ["app"])
            #expect(!hosted.allowsSDK)
            #expect(!hosted.allowsPurchase(.production))
        }
    }

    @Test func adapterQueuesOnlyVerifiedProductionRevenueByDefault() throws {
        let suite = "AppsFlyerAdapter.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var calls = 0
        let adapter = AppsFlyerAttribution(defaults: defaults, environment: [:], arguments: ["app"], isDebug: false) { _, _ in
            calls += 1
        }
        for (id, environment, verified, revoked, ownership) in [
            (UInt64(90), FlowerShowTransactionEnvironment.production, true, false, FlowerShowPurchaseOwnership.purchased),
            (91, .sandbox, true, false, .purchased), (92, .xcode, true, false, .purchased),
            (93, .unknown, true, false, .purchased), (94, .production, false, false, .purchased),
            (95, .production, true, true, .purchased), (96, .production, true, false, .familyShared),
        ] {
            adapter.trackVerifiedNewPurchase(FlowerShowPurchaseTransaction(
                id: id, productID: FlowerShowAccessPolicy.productID, isVerified: verified, isRevoked: revoked,
                price: 2.99, currencyCode: "GBP", environment: environment, ownership: ownership
            ))
        }
        let pending = try #require(defaults.dictionary(forKey: "AppsFlyerPendingVerifiedPurchasesV2"))
        #expect(Set(pending.keys) == ["90"])
        #expect(calls == 0) // No SDK initialisation/network traffic in this unit test.
    }

    @Test func debugAdapterDoesNotQueueSyntheticRevenueWithoutOptIn() throws {
        let suite = "AppsFlyerDebugAdapter.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let adapter = AppsFlyerAttribution(defaults: defaults, environment: [:], arguments: ["app"], isDebug: true) { _, _ in
            Issue.record("Disabled debug adapter emitted an event")
        }
        adapter.trackVerifiedNewPurchase(FlowerShowPurchaseTransaction(
            id: 97, productID: FlowerShowAccessPolicy.productID, isVerified: true, isRevoked: false,
            price: 2.99, currencyCode: "GBP", environment: .production, ownership: .purchased
        ))
        #expect(defaults.dictionary(forKey: "AppsFlyerPendingVerifiedPurchasesV2") == nil)
        adapter.trackProgression("af_level_achieved", properties: ["af_level": 1])
    }

    @Test func explicitIntegrationOptInQueuesSandboxMoneyWithoutCallingTheSDK() throws {
        let suite = "AppsFlyerOptedInAdapter.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let adapter = AppsFlyerAttribution(defaults: defaults,
            environment: ["RINGBLOOM_APPSFLYER_TEST_INGESTION": "1"], arguments: ["app", "--ui-testing"], isDebug: true
        ) { _, _ in Issue.record("Uninitialised test adapter emitted an event") }
        adapter.trackVerifiedNewPurchase(FlowerShowPurchaseTransaction(
            id: 98, productID: FlowerShowAccessPolicy.productID, isVerified: true, isRevoked: false,
            price: 2.99, currencyCode: "GBP", environment: .sandbox, ownership: .purchased
        ))
        #expect(defaults.dictionary(forKey: "AppsFlyerPendingVerifiedPurchasesV2")?["98"] != nil)
    }

    @Test func legacyQueueWithoutEnvironmentIsNeverInventedAsProductionRevenue() throws {
        let suite = "AppsFlyerLegacyQueue.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let legacy = ["101": ["productID": FlowerShowAccessPolicy.productID, "price": "2.99", "currencyCode": "GBP"]]
        defaults.set(legacy, forKey: "AppsFlyerPendingVerifiedPurchasesV1")
        let reporter = IdempotentAppsFlyerPurchaseReporter(defaults: defaults, allowsEnvironment: { $0 == .production }) { _, _ in
            Issue.record("Legacy queue emitted revenue without provenance")
        }
        reporter.flush()
        let retained = try #require(defaults.dictionary(forKey: "AppsFlyerPendingVerifiedPurchasesV1") as? [String: [String: String]])
        #expect(retained == legacy)
        #expect(defaults.stringArray(forKey: "AppsFlyerReportedPurchaseTransactionIDs") == nil)
    }

    @Test func persistedTestQueueCannotReplayAsRevenueOnAnOrdinaryProductionLaunch() throws {
        let suite = "AppsFlyerQueueProvenance.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let testWriter = IdempotentAppsFlyerPurchaseReporter(defaults: defaults) { _, _ in
            Issue.record("Queue writer unexpectedly flushed")
        }
        for (id, environment) in [(UInt64(102), FlowerShowTransactionEnvironment.production), (103, .sandbox), (104, .xcode)] {
            testWriter.enqueue(.init(FlowerShowPurchaseTransaction(
                id: id, productID: FlowerShowAccessPolicy.productID, isVerified: true, isRevoked: false,
                price: 2.99, currencyCode: "GBP", environment: environment, ownership: .purchased
            )))
        }
        var received: [String] = []
        let productionReader = IdempotentAppsFlyerPurchaseReporter(defaults: defaults, allowsEnvironment: { $0 == .production }) { _, properties in
            if let id = properties["af_order_id"] as? String { received.append(id) }
        }
        productionReader.flush()
        productionReader.flush()
        #expect(received == ["102"])
        #expect(defaults.stringArray(forKey: "AppsFlyerReportedPurchaseTransactionIDs") == ["102"])
        let remaining = try #require(defaults.dictionary(forKey: "AppsFlyerPendingVerifiedPurchasesV2"))
        #expect(Set(remaining.keys) == ["103", "104"])
        #expect((remaining["103"] as? [String: String])?["environment"] == "sandbox")
    }

    @Test(
        .enabled(if: ProcessInfo.processInfo.environment["RINGBLOOM_LOCAL_STOREKIT_INTEGRATION"] == "1",
                 "Requires an explicitly configured local StoreKit test service; never a normal purchase."),
        .timeLimit(.minutes(1))
    )
    func localStoreKitPurchaseCarriesActualMoneyThroughProductionAdapter() async throws {
        let url = try #require(Bundle(for: StoreKitResourceAnchor.self)
            .url(forResource: "Ringbloom", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.disableDialogs = true
        // Some simulator runtimes log a service error without throwing from the setter.
        // Stop before any product purchase unless the local no-dialog control is confirmed.
        try #require(session.disableDialogs)
        session.storefront = "GBR"
        session.locale = Locale(identifier: "en_GB")
        try #require(session.storefront == "GBR")
        session.clearTransactions()
        defer { session.clearTransactions() }
        let client = StoreKitFlowerShowStoreClient()
        let updates = client.transactionUpdates
        let listener = Task { @MainActor in for await _ in updates {} }
        defer { listener.cancel() }
        let product = try #require(try await client.loadProduct())
        #expect(product.productID == FlowerShowAccessPolicy.productID)
        let beforePurchase = Date()
        let outcome = try await client.purchase()
        guard case let .success(transaction) = outcome else {
            Issue.record("Local StoreKit did not return a successful transaction")
            return
        }
        #expect(transaction.isVerified)
        #expect(transaction.isRevoked == false)
        #expect(transaction.ownership == .purchased)
        #expect(transaction.environment == .xcode)
        #expect(transaction.price == Decimal(string: "2.99"))
        #expect(transaction.currencyCode == "GBP")
        let purchaseDate = try #require(transaction.purchaseDate)
        let originalDate = try #require(transaction.originalPurchaseDate)
        #expect(purchaseDate >= beforePurchase.addingTimeInterval(-1))
        #expect(originalDate == purchaseDate)
        let suite = "LocalStoreKitMoney.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var events: [(String, [AnyHashable: Any])] = []
        let reporter = IdempotentAppsFlyerPurchaseReporter(defaults: defaults) {
            events.append(($0, $1))
        }
        reporter.reportVerifiedNewPurchase(.init(transaction))
        reporter.reportVerifiedNewPurchase(.init(transaction))
        #expect(events.count == 1)
        let event = try #require(events.first)
        #expect(event.0 == "af_purchase")
        #expect(event.1["af_revenue"] as? Decimal == Decimal(string: "2.99"))
        #expect(event.1["af_currency"] as? String == "GBP")
        #expect(event.1["af_order_id"] as? String == String(transaction.id))
        await client.finish(transactionID: transaction.id)
    }

    @Test func purchaseReporterLogsEachStoreKitTransactionAtMostOnce() throws {
        let suiteName = "AppsFlyerAttributionTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        var events: [(name: String, values: [AnyHashable: Any])] = []
        let reporter = IdempotentAppsFlyerPurchaseReporter(defaults: defaults) { name, values in
            events.append((name, values))
        }

        let purchase = VerifiedNewPurchaseAttribution(FlowerShowPurchaseTransaction(
            id: 42, productID: FlowerShowAccessPolicy.productID, isVerified: true, isRevoked: false,
            price: Decimal(string: "2.11"), currencyCode: "GBP"
        ))
        reporter.reportVerifiedNewPurchase(purchase)
        reporter.reportVerifiedNewPurchase(purchase)

        let event = try #require(events.first)
        #expect(events.count == 1)
        #expect(event.name == "af_purchase")
        #expect(event.values["af_revenue"] as? Decimal == Decimal(string: "2.11"))
        #expect(event.values["af_currency"] as? String == "GBP")
        #expect(event.values["af_content_id"] as? String == FlowerShowAccessPolicy.productID)
        #expect(event.values["af_order_id"] as? String == "42")
    }

    @Test func purchaseReporterPersistsDeduplicationAcrossInstances() throws {
        let suiteName = "AppsFlyerAttributionTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        var eventCount = 0
        let firstReporter = IdempotentAppsFlyerPurchaseReporter(defaults: defaults) { _, _ in
            eventCount += 1
        }
        let purchase = VerifiedNewPurchaseAttribution(FlowerShowPurchaseTransaction(
            id: 99, productID: FlowerShowAccessPolicy.productID, isVerified: true, isRevoked: false,
            price: Decimal(string: "2.54"), currencyCode: "USD"
        ))
        firstReporter.reportVerifiedNewPurchase(purchase)

        let relaunchedReporter = IdempotentAppsFlyerPurchaseReporter(defaults: defaults) { _, _ in
            eventCount += 1
        }
        relaunchedReporter.reportVerifiedNewPurchase(purchase)

        #expect(eventCount == 1)
    }

    @Test func unavailableMoneyDefersUntilAPricedCopyWithoutChangingCurrencyUnits() throws {
        let suiteName = "AppsFlyerAttributionTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        var events: [[AnyHashable: Any]] = []
        let reporter = IdempotentAppsFlyerPurchaseReporter(defaults: defaults) { _, values in events.append(values) }
        reporter.reportVerifiedNewPurchase(.init(FlowerShowPurchaseTransaction(
            id: 73, productID: FlowerShowAccessPolicy.productID, isVerified: true, isRevoked: false
        )))
        reporter.reportVerifiedNewPurchase(.init(FlowerShowPurchaseTransaction(
            id: 73, productID: FlowerShowAccessPolicy.productID, isVerified: true, isRevoked: false,
            price: Decimal(string: "2.54"), currencyCode: "USD"
        )))
        #expect(events.count == 1)
        #expect(events[0]["af_revenue"] as? Decimal == Decimal(string: "2.54"))
        #expect(events[0]["af_currency"] as? String == "USD")
    }

    @Test func queuedVerifiedPurchaseFlushesOnce() throws {
        let suiteName = "AppsFlyerAttributionTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        var events: [[AnyHashable: Any]] = []
        let reporter = IdempotentAppsFlyerPurchaseReporter(defaults: defaults) { _, values in events.append(values) }
        let purchase = VerifiedNewPurchaseAttribution(FlowerShowPurchaseTransaction(
            id: 74, productID: FlowerShowAccessPolicy.productID, isVerified: true, isRevoked: false,
            price: Decimal(string: "0"), currencyCode: "JPY"
        ))
        reporter.enqueue(purchase)
        #expect(events.isEmpty)
        reporter.flush()
        reporter.flush()
        #expect(events.count == 1)
        #expect(events[0]["af_revenue"] as? Decimal == 0)
    }

    @Test func invalidMoneyIsDeferredRatherThanReported() throws {
        let suiteName = "AppsFlyerAttributionTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        var count = 0
        let reporter = IdempotentAppsFlyerPurchaseReporter(defaults: defaults) { _, _ in count += 1 }
        for purchase in [
            FlowerShowPurchaseTransaction(id: 81, productID: FlowerShowAccessPolicy.productID, isVerified: true, isRevoked: false, price: Decimal(-1), currencyCode: "GBP"),
            FlowerShowPurchaseTransaction(id: 82, productID: FlowerShowAccessPolicy.productID, isVerified: true, isRevoked: false, price: 1, currencyCode: "ZZZ"),
            FlowerShowPurchaseTransaction(id: 83, productID: FlowerShowAccessPolicy.productID, isVerified: true, isRevoked: false),
        ] { reporter.reportVerifiedNewPurchase(.init(purchase)) }
        #expect(count == 0)
    }
}

private final class StoreKitResourceAnchor: NSObject {}
