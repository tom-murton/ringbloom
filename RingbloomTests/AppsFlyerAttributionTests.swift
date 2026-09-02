import Foundation
import Testing
@testable import Ringbloom

@MainActor
struct AppsFlyerAttributionTests {
    @Test func purchaseReporterLogsEachStoreKitTransactionAtMostOnce() throws {
        let suiteName = "AppsFlyerAttributionTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        var events: [(name: String, values: [AnyHashable: Any])] = []
        let reporter = IdempotentAppsFlyerPurchaseReporter(defaults: defaults) { name, values in
            events.append((name, values))
        }

        reporter.reportUnlockPurchase(transactionID: 42)
        reporter.reportUnlockPurchase(transactionID: 42)

        let event = try #require(events.first)
        #expect(events.count == 1)
        #expect(event.name == "af_purchase")
        #expect(event.values["af_revenue"] as? Double == 2.99)
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
        firstReporter.reportUnlockPurchase(transactionID: 99)

        let relaunchedReporter = IdempotentAppsFlyerPurchaseReporter(defaults: defaults) { _, _ in
            eventCount += 1
        }
        relaunchedReporter.reportUnlockPurchase(transactionID: 99)

        #expect(eventCount == 1)
    }
}
