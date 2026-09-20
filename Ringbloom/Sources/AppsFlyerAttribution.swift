import AppsFlyerLib
import Foundation
import UIKit

func isValidStoreKitMoney(price: Decimal?, currencyCode: String?) -> Bool {
    guard let price,
          price >= 0,
          NSDecimalNumber(decimal: price) != .notANumber,
          let currencyCode = currencyCode?.uppercased(),
          Locale.isoCurrencyCodes.contains(currencyCode)
    else { return false }
    return true
}

@MainActor
protocol PurchaseAttributionTracking: AnyObject {
    func trackVerifiedNewPurchase(_ transaction: FlowerShowPurchaseTransaction)
}

@MainActor
final class NoOpPurchaseAttributionTracker: PurchaseAttributionTracking {
    func trackVerifiedNewPurchase(_: FlowerShowPurchaseTransaction) {}
}

struct VerifiedNewPurchaseAttribution: Equatable, Sendable {
    let transactionID: UInt64
    let productID: String
    let price: Decimal?
    let currencyCode: String?

    init(_ transaction: FlowerShowPurchaseTransaction) {
        transactionID = transaction.id
        productID = transaction.productID
        price = transaction.price
        currencyCode = transaction.currencyCode
    }
}

@MainActor
final class IdempotentAppsFlyerPurchaseReporter {
    private static let reportedTransactionIDsKey = "AppsFlyerReportedPurchaseTransactionIDs"
    private static let pendingPurchasesKey = "AppsFlyerPendingVerifiedPurchasesV1"

    private let defaults: UserDefaults
    private let eventLogger: (String, [AnyHashable: Any]) -> Void

    init(
        defaults: UserDefaults = .standard,
        eventLogger: @escaping (String, [AnyHashable: Any]) -> Void
    ) {
        self.defaults = defaults
        self.eventLogger = eventLogger
    }

    /// StoreKit transaction IDs are persisted before logging, making purchase reporting
    /// at-most-once across duplicate updates, retries and ordinary restores on this install.
    func reportVerifiedNewPurchase(_ purchase: VerifiedNewPurchaseAttribution) {
        enqueue(purchase)
        flush()
    }

    /// Missing money is deliberately not queued as revenue. A later verified transaction copy
    /// may carry price/currency and will then enter this queue without duplicating PostHog.
    func enqueue(_ purchase: VerifiedNewPurchaseAttribution) {
        guard isValidStoreKitMoney(price: purchase.price, currencyCode: purchase.currencyCode),
              let price = purchase.price,
              let currencyCode = purchase.currencyCode?.uppercased(),
              Locale.isoCurrencyCodes.contains(currencyCode)
        else { return }
        let transactionIDString = String(purchase.transactionID)
        let reportedIDs = Set(defaults.stringArray(forKey: Self.reportedTransactionIDsKey) ?? [])
        guard !reportedIDs.contains(transactionIDString) else { return }
        var pending = defaults.dictionary(forKey: Self.pendingPurchasesKey) ?? [:]
        pending[transactionIDString] = [
            "productID": purchase.productID,
            "price": price.description,
            "currencyCode": currencyCode,
        ]
        defaults.set(pending, forKey: Self.pendingPurchasesKey)
    }

    /// The marker is written before SDK invocation: local reporting is at-most-once, not a
    /// transactional network outbox. A process crash after this point can lose remote delivery.
    func flush() {
        var pending = defaults.dictionary(forKey: Self.pendingPurchasesKey) ?? [:]
        var reportedIDs = Set(defaults.stringArray(forKey: Self.reportedTransactionIDsKey) ?? [])
        for (transactionIDString, rawPayload) in pending {
            guard !reportedIDs.contains(transactionIDString),
                  let payload = rawPayload as? [String: String],
                  let productID = payload["productID"],
                  let priceString = payload["price"],
                  let price = Decimal(string: priceString),
                  let currencyCode = payload["currencyCode"]
            else {
                pending.removeValue(forKey: transactionIDString)
                continue
            }
            reportedIDs.insert(transactionIDString)
            defaults.set(reportedIDs.sorted(), forKey: Self.reportedTransactionIDsKey)
            pending.removeValue(forKey: transactionIDString)
            defaults.set(pending, forKey: Self.pendingPurchasesKey)

            eventLogger(
                AFEventPurchase,
                [
                    AFEventParamRevenue: price,
                    AFEventParamCurrency: currencyCode,
                    AFEventParamContentId: productID,
                    AFEventParamOrderId: transactionIDString,
                ]
            )
        }
    }
}

@MainActor
final class AppsFlyerAttribution: PurchaseAttributionTracking {
    static let shared = AppsFlyerAttribution()

    private enum ConfigurationKey {
        static let appID = "AppsFlyerAppID"
        static let devKey = "AppsFlyerDevKey"
    }

    private let bundle: Bundle
    private let purchaseReporter: IdempotentAppsFlyerPurchaseReporter
    private var isInitialised = false

    init(
        bundle: Bundle = .main,
        defaults: UserDefaults = .standard,
        eventLogger: @escaping (String, [AnyHashable: Any]) -> Void = { name, values in
            AppsFlyerLib.shared().logEvent(name, withValues: values)
        }
    ) {
        self.bundle = bundle
        self.purchaseReporter = IdempotentAppsFlyerPurchaseReporter(
            defaults: defaults,
            eventLogger: eventLogger
        )
    }

    /// Initialises AppsFlyer exactly once. A missing local key deliberately makes
    /// development and hosted test builds a no-op instead of sending bad telemetry.
    func initialise(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        guard isInitialised == false else { return }
        guard let devKey = configuredString(for: ConfigurationKey.devKey),
              let appID = configuredString(for: ConfigurationKey.appID)
        else { return }

        isInitialised = true
        AppsFlyerLib.shared().initialize(devKey: devKey, appId: appID)
        AppsFlyerLib.shared().handleLaunchOptions(launchOptions)
        AppsFlyerLib.shared().registerSessionReadyListener {
            AppsFlyerLib.shared().start()
        }
        purchaseReporter.flush()
    }

    func trackVerifiedNewPurchase(_ transaction: FlowerShowPurchaseTransaction) {
        purchaseReporter.enqueue(.init(transaction))
        if isInitialised { purchaseReporter.flush() }
    }

    private func configuredString(for key: String) -> String? {
        guard let value = bundle.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false, trimmed.contains("$(") == false else { return nil }
        return trimmed
    }
}

@MainActor
final class RingbloomAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        AppsFlyerAttribution.shared.initialise(launchOptions: launchOptions)
        ProductAnalytics.shared.configure()
        return true
    }
}
