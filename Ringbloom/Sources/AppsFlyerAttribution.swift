import AppsFlyerLib
import Foundation
import UIKit

/// Development traffic is isolated without gating normal Release/TestFlight sessions.
struct AppsFlyerEmissionPolicy: Equatable {
    let allowsSDK: Bool
    let allowsTestPurchases: Bool

    static func resolve(isDebug: Bool, environment: [String: String], arguments: [String]) -> Self {
        let hostedPath = environment["XCInjectBundle"] ?? environment["XCTestBundlePath"]
        if hostedPath?.hasSuffix("RingbloomTests.xctest") == true {
            return Self(allowsSDK: false, allowsTestPurchases: false)
        }
        let optedIn = environment["RINGBLOOM_APPSFLYER_TEST_INGESTION"] == "1"
        let deterministic = GameLaunchMode.detect(arguments: arguments) != .production
        return Self(allowsSDK: optedIn || (!isDebug && !deterministic), allowsTestPurchases: optedIn)
    }

    func allowsPurchase(_ environment: FlowerShowTransactionEnvironment) -> Bool {
        guard allowsSDK else { return false }
        return environment == .production || (allowsTestPurchases && (environment == .sandbox || environment == .xcode))
    }
}

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
    let environment: FlowerShowTransactionEnvironment

    init(_ transaction: FlowerShowPurchaseTransaction) {
        transactionID = transaction.id
        productID = transaction.productID
        price = transaction.price
        currencyCode = transaction.currencyCode
        environment = transaction.environment
    }
}

@MainActor
final class IdempotentAppsFlyerPurchaseReporter {
    private static let reportedTransactionIDsKey = "AppsFlyerReportedPurchaseTransactionIDs"
    // V1 omitted environment. Keep it untouched, but never replay it as revenue:
    // neither production nor test provenance can be established from those records.
    private static let pendingPurchasesKey = "AppsFlyerPendingVerifiedPurchasesV2"

    private let defaults: UserDefaults
    private let eventLogger: (String, [AnyHashable: Any]) -> Void
    private let allowsEnvironment: (FlowerShowTransactionEnvironment) -> Bool

    convenience init(
        defaults: UserDefaults = .standard,
        eventLogger: @escaping (String, [AnyHashable: Any]) -> Void
    ) {
        self.init(defaults: defaults, allowsEnvironment: { _ in true }, eventLogger: eventLogger)
    }

    init(
        defaults: UserDefaults = .standard,
        allowsEnvironment: @escaping (FlowerShowTransactionEnvironment) -> Bool,
        eventLogger: @escaping (String, [AnyHashable: Any]) -> Void
    ) {
        self.defaults = defaults
        self.eventLogger = eventLogger
        self.allowsEnvironment = allowsEnvironment
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
        guard allowsEnvironment(purchase.environment),
              isValidStoreKitMoney(price: purchase.price, currencyCode: purchase.currencyCode),
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
            "environment": Self.environmentName(purchase.environment),
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
                  let currencyCode = payload["currencyCode"],
                  let environmentName = payload["environment"],
                  let environment = Self.environment(named: environmentName),
                  isValidStoreKitMoney(price: price, currencyCode: currencyCode)
            else {
                pending.removeValue(forKey: transactionIDString)
                continue
            }
            // A queue written by an opted-in test build must not become production
            // revenue on a subsequent ordinary launch. Leave it pending for test replay.
            guard allowsEnvironment(environment) else { continue }
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

    private static func environmentName(_ environment: FlowerShowTransactionEnvironment) -> String {
        switch environment {
        case .production: "production"
        case .sandbox: "sandbox"
        case .xcode: "xcode"
        case .unknown: "unknown"
        }
    }

    private static func environment(named name: String) -> FlowerShowTransactionEnvironment? {
        switch name {
        case "production": .production
        case "sandbox": .sandbox
        case "xcode": .xcode
        case "unknown": .unknown
        default: nil
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
    private let eventLogger: (String, [AnyHashable: Any]) -> Void
    private let emissionPolicy: AppsFlyerEmissionPolicy
    private var isInitialised = false

    init(
        bundle: Bundle = .main,
        defaults: UserDefaults = .standard,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        isDebug: Bool = {
            #if DEBUG
                true
            #else
                false
            #endif
        }(),
        eventLogger: @escaping (String, [AnyHashable: Any]) -> Void = { name, values in
            AppsFlyerLib.shared().logEvent(name, withValues: values)
        }
    ) {
        self.bundle = bundle
        self.eventLogger = eventLogger
        let policy = AppsFlyerEmissionPolicy.resolve(isDebug: isDebug, environment: environment, arguments: arguments)
        emissionPolicy = policy
        self.purchaseReporter = IdempotentAppsFlyerPurchaseReporter(
            defaults: defaults,
            allowsEnvironment: { policy.allowsPurchase($0) },
            eventLogger: eventLogger
        )
    }

    /// Initialises the official v7 SDK once; development ingestion requires an explicit opt-in.
    func initialise(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        guard emissionPolicy.allowsSDK, isInitialised == false else { return }
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
        guard emissionPolicy.allowsPurchase(transaction.environment),
              transaction.isVerified, !transaction.isRevoked, transaction.ownership == .purchased
        else { return }
        purchaseReporter.enqueue(.init(transaction))
        if isInitialised { purchaseReporter.flush() }
    }

    func trackProgression(_ event: String, properties: [AnyHashable: Any]) {
        guard emissionPolicy.allowsSDK, isInitialised else { return }
        eventLogger(event, properties)
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
