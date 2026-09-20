import Combine
import Foundation
import PostHog
import StoreKit

@MainActor
protocol PurchaseBoundaryAnalyticsTracking: AnyObject {
    func purchaseVerifiedNew(source: String, environment: String, moneyStatus: String)
}
import SwiftUI

enum AnalyticsDistributionEnvironment: String, Equatable, Sendable {
    case production, sandbox, xcode, unknown
}

enum AnalyticsDataTier: String, Equatable, Sendable {
    case production, test, unknown, disabled
}

struct AnalyticsRoute: Equatable, Sendable {
    let distribution: AnalyticsDistributionEnvironment
    let tier: AnalyticsDataTier

    static func resolve(
        verifiedStoreKit: AnalyticsDistributionEnvironment?,
        receiptName: String?,
        isDebug: Bool,
        isDeterministic: Bool,
        isHostedUnitTest: Bool,
        testIngestionOptIn: Bool
    ) -> Self {
        let distribution: AnalyticsDistributionEnvironment
        if let verifiedStoreKit {
            distribution = verifiedStoreKit
        } else if isDebug {
            distribution = .xcode
        } else if receiptName == "sandboxReceipt" {
            distribution = .sandbox
        } else if receiptName == "receipt" {
            distribution = .production
        } else {
            distribution = .unknown
        }

        let tier: AnalyticsDataTier
        if isHostedUnitTest {
            tier = .disabled
        } else if testIngestionOptIn {
            tier = .test
        } else if isDeterministic || isDebug || distribution == .sandbox || distribution == .xcode {
            tier = .disabled
        } else {
            tier = distribution == .production ? .production : .unknown
        }
        return Self(distribution: distribution, tier: tier)
    }
}

enum AnalyticsLifecycleEvent: String {
    case appSessionStarted = "app_session_started"
    case appForegrounded = "app_foregrounded"
    case attemptStarted = "attempt_started"
    case attemptResumed = "attempt_resumed"
    case attemptAbandoned = "attempt_abandoned"
    case attemptFinished = "attempt_finished"
    case firstBloomAchieved = "first_bloom_achieved"
    case firstGardenWinAchieved = "first_garden_win_achieved"
    case sampleAccessUnlocked = "sample_access_unlocked"
    case flowerShowMilestone = "flower_show_milestone"
    case reviewRequestEligible = "review_request_eligible"
    case reviewRequestAttempted = "review_request_attempted"
}

enum AnalyticsCommerceOutcome {
    static func purchase(verifiedNewPurchase: Bool, state: FlowerShowPurchaseState) -> String {
        if verifiedNewPurchase { return "success" }
        return switch state {
        case .pending: "pending"
        case .idle: "cancelled"
        case .disabled: "disabled"
        case .failed, .purchasing, .restoring, .success: "failed"
        }
    }

    static func restore(state: FlowerShowPurchaseState, hasFullAccess: Bool) -> String {
        if hasFullAccess && state == .success { return "restored" }
        if state == .idle { return "no_entitlement" }
        return "failed"
    }
}

@MainActor
final class ProductAnalytics: ObservableObject, PurchaseBoundaryAnalyticsTracking {
    typealias CaptureHandler = (_ event: String, _ properties: [String: Any]) -> Void

    static let shared = ProductAnalytics()
    static let schemaVersion = 2
    private static let lifecycleKeys: Set<String> = [
        "launch_kind", "progress_load_reason_code", "analytics_eligibility",
        "foreground_reason", "foreground_index",
        "attempt_id", "attempt_id_origin", "mode", "attempt_kind", "garden",
        "class_number", "access_state", "resume_source", "abandon_reason",
        "outcome", "turns", "blooms", "score", "moves_remaining",
        "did_use_hint", "did_use_undo", "rating", "bloom_count_after_turn",
        "milestone_basis", "first_eligible_start", "unlock_reason", "milestone",
        "successful_garden_completions", "meaningful_session_count", "request_reason", "event_id",
    ]

    func ratingLinkTapped() {
        capture("rating_link_tapped", properties: [
            "destination": RatingLink.destinationIdentifier,
            "screen": "home",
        ])
    }

    private var captureHandler: CaptureHandler?
    private var usesPostHogSDK = false
    private var hasObservedActiveScene = false
    private var hasBackgroundedSinceActive = false
    private var foregroundIndex = 0
    private var baseProperties: [String: Any]
    private var pendingEvents: [(String, [String: Any])] = []
    private var hasResolvedRoute: Bool
    private(set) var isConfigured: Bool
    private(set) var route: AnalyticsRoute
    private let sessionUUID: UUID
    private(set) var sessionID: String
    var processSessionID: String { sessionUUID.uuidString }

    init(
        captureHandler: CaptureHandler? = nil,
        route: AnalyticsRoute = .init(distribution: .xcode, tier: .test),
        sessionUUID: UUID = UUID()
    ) {
        self.captureHandler = captureHandler
        self.route = route
        self.sessionUUID = sessionUUID
        sessionID = route.tier == .test ? "test-\(sessionUUID.uuidString)" : sessionUUID.uuidString
        isConfigured = captureHandler != nil
        hasResolvedRoute = captureHandler != nil
        baseProperties = Self.baseProperties(bundle: .main, route: route, sessionID: sessionID)
    }

    func configure(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        receiptName: String? = Bundle.main.appStoreReceiptURL?.lastPathComponent,
        verifiedStoreKit: (@Sendable () async -> AnalyticsDistributionEnvironment?)? = nil
    ) {
        guard !hasResolvedRoute else { return }
        let isDebug: Bool = {
            #if DEBUG
            true
            #else
            false
            #endif
        }()
        let optedIn = environment["RINGBLOOM_ANALYTICS_TEST_INGESTION"] == "1"
        let hosted = Self.isHostedUnitTest(environment)
        let deterministic = GameLaunchMode.detect(arguments: arguments) != .production

        if (isDebug || deterministic || hosted) && !optedIn {
            finishConfiguration(
                route: .resolve(verifiedStoreKit: nil, receiptName: receiptName,
                                isDebug: isDebug, isDeterministic: deterministic,
                                isHostedUnitTest: hosted, testIngestionOptIn: false),
                bundle: bundle
            )
            return
        }

        Task { @MainActor in
            let verified: AnalyticsDistributionEnvironment?
            if let verifiedStoreKit {
                verified = await verifiedStoreKit()
            } else {
                verified = await Self.verifiedStoreKitEnvironment()
            }
            let route = AnalyticsRoute.resolve(
                verifiedStoreKit: verified,
                receiptName: receiptName,
                isDebug: isDebug,
                isDeterministic: deterministic,
                isHostedUnitTest: hosted,
                testIngestionOptIn: optedIn
            )
            finishConfiguration(route: route, bundle: bundle)
        }
    }

    private func finishConfiguration(route: AnalyticsRoute, bundle: Bundle) {
        guard !hasResolvedRoute else { return }
        self.route = route
        sessionID = route.tier == .test ? "test-\(sessionUUID.uuidString)" : sessionUUID.uuidString
        hasResolvedRoute = true
        baseProperties = Self.baseProperties(bundle: bundle, route: route, sessionID: sessionID)
        guard route.tier != .disabled,
              let projectToken = Self.configuredString(for: "PostHogProjectToken", in: bundle),
              let host = Self.configuredString(for: "PostHogHost", in: bundle)
        else {
            pendingEvents.removeAll()
            return
        }

        let config = PostHogConfig(projectToken: projectToken, host: host)
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = false
        config.captureElementInteractions = false
        config.sessionReplay = false
        config.surveys = false
        config.setDefaultPersonProperties = false
        config.setBeforeSend { event in
            event.properties["$geoip_disable"] = true
            return event
        }
        #if DEBUG
            config.debug = true
        #endif
        PostHogSDK.shared.setup(config)
        usesPostHogSDK = true
        captureHandler = { event, properties in
            PostHogSDK.shared.capture(event, properties: properties)
        }
        isConfigured = true
        let buffered = pendingEvents
        pendingEvents.removeAll()
        for (event, properties) in buffered { capture(event, properties: properties) }
    }

    func capture(_ event: String, properties: [String: Any] = [:]) {
        guard let captureHandler else {
            if !hasResolvedRoute && pendingEvents.count < 128 {
                pendingEvents.append((event, properties))
            }
            return
        }
        var properties = properties
        if event == AnalyticsLifecycleEvent.appSessionStarted.rawValue {
            properties["analytics_eligibility"] = route.tier.rawValue
        }
        captureHandler(event, properties.merging(baseProperties) { _, commonValue in commonValue })
        let isTestFlushBoundary = event == AnalyticsLifecycleEvent.attemptFinished.rawValue
            || event == AnalyticsLifecycleEvent.appSessionStarted.rawValue
            || event == AnalyticsLifecycleEvent.appForegrounded.rawValue
        if usesPostHogSDK, route.tier == .test, isTestFlushBoundary {
            PostHogSDK.shared.flush()
        }
    }

    func captureLifecycle(_ event: AnalyticsLifecycleEvent, properties: [String: Any]) {
        capture(event.rawValue, properties: properties.filter { Self.lifecycleKeys.contains($0.key) })
    }

    func purchaseVerifiedNew(source: String, environment: String, moneyStatus: String) {
        capture("purchase_verified_new", properties: [
            "source": source,
            "environment": environment,
            "money_status": moneyStatus,
        ])
    }

    func observeScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            let reason: String
            if !hasObservedActiveScene {
                hasObservedActiveScene = true
                reason = "cold_launch"
            } else if hasBackgroundedSinceActive {
                hasBackgroundedSinceActive = false
                reason = "return_from_background"
            } else {
                return
            }
            foregroundIndex += 1
            captureLifecycle(.appForegrounded, properties: [
                "foreground_reason": reason,
                "foreground_index": foregroundIndex,
                "event_id": "\(sessionUUID.uuidString)-foreground-\(foregroundIndex)",
            ])
        case .background:
            if hasObservedActiveScene { hasBackgroundedSinceActive = true }
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    func screenViewed(_ screen: String, properties: [String: Any] = [:]) {
        capture("screen_viewed", properties: properties.merging(["screen": screen]) { _, screenValue in screenValue })
    }

    func buttonTapped(_ button: String, screen: String, properties: [String: Any] = [:]) {
        capture("button_tapped", properties: properties.merging([
            "button": button,
            "screen": screen,
        ]) { _, buttonValue in buttonValue })
    }

    static func shouldEnable(environment: [String: String], arguments: [String]) -> Bool {
        let isDebug: Bool = {
            #if DEBUG
            true
            #else
            false
            #endif
        }()
        return AnalyticsRoute.resolve(
            verifiedStoreKit: nil,
            receiptName: nil,
            isDebug: isDebug,
            isDeterministic: GameLaunchMode.detect(arguments: arguments) != .production,
            isHostedUnitTest: isHostedUnitTest(environment),
            testIngestionOptIn: environment["RINGBLOOM_ANALYTICS_TEST_INGESTION"] == "1"
        ).tier != .disabled
    }

    private static func isHostedUnitTest(_ environment: [String: String]) -> Bool {
        let path = environment["XCInjectBundle"] ?? environment["XCTestBundlePath"]
        return path?.hasSuffix("RingbloomTests.xctest") == true
    }

    private static func verifiedStoreKitEnvironment() async -> AnalyticsDistributionEnvironment? {
        guard let result = try? await AppTransaction.shared else { return nil }
        guard case let .verified(transaction) = result else { return nil }
        switch transaction.environment {
        case .production: return .production
        case .sandbox: return .sandbox
        case .xcode: return .xcode
        default: return .unknown
        }
    }

    private static func configuredString(for key: String, in bundle: Bundle) -> String? {
        guard let value = bundle.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("$(") else { return nil }
        return trimmed
    }

    private static func baseProperties(bundle: Bundle, route: AnalyticsRoute, sessionID: String) -> [String: Any] {
        [
            "analytics_schema_version": schemaVersion,
            "app_version": bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            "build_number": bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            "build_configuration": {
                #if DEBUG
                    "debug"
                #else
                    "release"
                #endif
            }(),
            "platform": "ios",
            "product": "ringbloom",
            "session_id": sessionID,
            "distribution_environment": route.distribution.rawValue,
            "analytics_data_tier": route.tier.rawValue,
        ]
    }
}

extension FlowerShowPurchaseContext.Origin {
    var analyticsName: String {
        switch self {
        case .afterClassFive: "after_class_five"
        case .lockedClass: "locked_class"
        case .home: "home"
        }
    }
}

extension FlowerShowPurchaseContext {
    var analyticsProperties: [String: Any] {
        var properties: [String: Any] = ["origin": origin.analyticsName]
        if let targetClass { properties["target_class"] = targetClass }
        return properties
    }
}

extension FlowerShowAccessState {
    var analyticsName: String {
        switch self {
        case .checking: "checking"
        case .sample: "sample"
        case .full(.legacyPaidApp): "legacy_paid_app"
        case .full(.storePurchase): "store_purchase"
        }
    }
}

extension GameMode {
    var analyticsName: String {
        switch self {
        case .garden: "garden"
        case .flowerShow: "flower_show"
        }
    }
}

extension Ring {
    var analyticsName: String {
        switch self {
        case .inner: "inner"
        case .middle: "middle"
        case .outer: "outer"
        }
    }
}

extension RotationDirection {
    var analyticsName: String {
        switch self {
        case .clockwise: "clockwise"
        case .counterClockwise: "counter_clockwise"
        }
    }
}
