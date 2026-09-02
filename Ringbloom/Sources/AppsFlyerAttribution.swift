import AppsFlyerLib
import Foundation
import UIKit

@MainActor
protocol PurchaseAttributionTracking: AnyObject {
    func trackUnlockPurchase(transactionID: UInt64)
}

@MainActor
final class NoOpPurchaseAttributionTracker: PurchaseAttributionTracking {
    func trackUnlockPurchase(transactionID _: UInt64) {}
}

@MainActor
final class IdempotentAppsFlyerPurchaseReporter {
    private static let reportedTransactionIDsKey = "AppsFlyerReportedPurchaseTransactionIDs"

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
    func reportUnlockPurchase(transactionID: UInt64) {
        let transactionIDString = String(transactionID)
        var reportedIDs = Set(defaults.stringArray(forKey: Self.reportedTransactionIDsKey) ?? [])
        guard reportedIDs.insert(transactionIDString).inserted else { return }
        defaults.set(reportedIDs.sorted(), forKey: Self.reportedTransactionIDsKey)

        eventLogger(
            AFEventPurchase,
            [
                AFEventParamRevenue: 2.99,
                AFEventParamCurrency: "GBP",
                AFEventParamContentId: FlowerShowAccessPolicy.productID,
                AFEventParamOrderId: transactionIDString,
            ]
        )
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
    }

    func trackUnlockPurchase(transactionID: UInt64) {
        guard isInitialised else { return }
        purchaseReporter.reportUnlockPurchase(transactionID: transactionID)
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
