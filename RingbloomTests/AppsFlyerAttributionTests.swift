import Foundation
import StoreKit
import StoreKitTest
import Testing
@testable import Ringbloom

@MainActor
struct AppsFlyerAttributionTests {
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
