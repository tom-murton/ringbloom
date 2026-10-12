import Combine
import Foundation
import PostHog
import StoreKit
import SwiftUI

@MainActor
protocol PurchaseBoundaryAnalyticsTracking: AnyObject {
    func purchaseVerifiedNew(source: String, environment: String, moneyStatus: String)
}

/// The SDK calls beforeSend synchronously on the capturing thread, which need not be main.
/// Keep automatic events in the same environment and named screens as explicit events.
final class AnalyticsSDKContext: @unchecked Sendable {
    private let lock = NSLock()
    private let commonProperties: [String: Any]
    private var screen: String?

    init(commonProperties: [String: Any]) {
        self.commonProperties = commonProperties
    }

    func setScreen(_ screen: String) {
        lock.withLock { self.screen = screen }
    }

    func prepare(_ event: String, properties: [String: Any]) -> [String: Any]? {
        let screen = lock.withLock { self.screen }
        var properties = properties
        if event == "$autocapture" || event == "$rageclick" {
            // FeedbackKit's text, category and error UI must never enter product analytics.
            // Check captured element IDs too, covering callbacks after sheet dismissal.
            let chain = (properties["$elements_chain"] as? String ?? "").lowercased()
            guard screen != "feedback",
                  !chain.contains("feedback-"), !chain.contains("ph-no-capture") else { return nil }
            if let screen { properties["$screen_name"] = screen }
        }
        if event == "$exception", properties["$exception_level"] as? String == "fatal" {
            // Native crashes are sent on the next launch. Keep the SDK's persisted
            // crash-time release, route and session, even after an app update.
            properties["product"] = "ringbloom"
            properties["platform"] = "ios"
            if properties["analytics_data_tier"] == nil {
                properties["analytics_data_tier"] = AnalyticsDataTier.unknown.rawValue
            }
        } else {
            properties.merge(commonProperties) { _, common in common }
        }
        if event == "$exception" {
            Self.removeExceptionMessages(from: &properties)
            if var images = properties["$debug_images"] as? [[String: Any]] {
                for index in images.indices {
                    if let path = images[index]["code_file"] as? String {
                        images[index]["code_file"] = (path as NSString).lastPathComponent
                    }
                }
                properties["$debug_images"] = images
            }
        }
        properties["$geoip_disable"] = true
        return properties
    }

    private static func removeExceptionMessages(from properties: inout [String: Any]) {
        // Native exception reasons can interpolate file paths or private text.
        // Keep the exception type, mechanism and frames needed for symbolication.
        guard var exceptions = properties["$exception_list"] as? [[String: Any]] else { return }
        for index in exceptions.indices {
            exceptions[index]["value"] = "Exception message omitted"
            if var mechanism = exceptions[index]["mechanism"] as? [String: Any],
               var metadata = mechanism["meta"] as? [String: Any],
               var signal = metadata["signal"] as? [String: Any] {
                signal.removeValue(forKey: "crash_info_message")
                metadata["signal"] = signal
                mechanism["meta"] = metadata
                exceptions[index]["mechanism"] = mechanism
            }
        }
        properties["$exception_list"] = exceptions
    }
}

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
    typealias ProgressionHandler = (_ event: String, _ properties: [AnyHashable: Any]) -> Void

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
    private let progressionHandler: ProgressionHandler
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

    convenience init(
        captureHandler: CaptureHandler? = nil,
        route: AnalyticsRoute = .init(distribution: .xcode, tier: .test),
        sessionUUID: UUID = UUID()
    ) {
        self.init(progressionHandler: { event, properties in
            AppsFlyerAttribution.shared.trackProgression(event, properties: properties)
        }, captureHandler: captureHandler, route: route, sessionUUID: sessionUUID)
    }

    init(
        progressionHandler: @escaping ProgressionHandler,
        captureHandler: CaptureHandler?,
        route: AnalyticsRoute = .init(distribution: .xcode, tier: .test),
        sessionUUID: UUID = UUID()
    ) {
        self.captureHandler = captureHandler
        self.progressionHandler = progressionHandler
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

        let context = AnalyticsSDKContext(commonProperties: baseProperties)
        let config = Self.sdkConfiguration(projectToken: projectToken, host: host, context: context)
        PostHogSDK.shared.setup(config)
        // SDK super properties are included in its persisted native crash context.
        PostHogSDK.shared.register(baseProperties)
        usesPostHogSDK = true
        captureHandler = { event, properties in
            if event == "$screen", let screen = properties["$screen_name"] as? String {
                context.setScreen(screen)
                PostHogSDK.shared.screen(screen, properties: properties)
                PostHogSDK.shared.addExceptionStep("Screen viewed", properties: ["screen": screen])
            } else {
                PostHogSDK.shared.capture(event, properties: properties)
            }
        }
        isConfigured = true
        let buffered = pendingEvents
        pendingEvents.removeAll()
        for (event, properties) in buffered { capture(event, properties: properties) }
    }

    static func sdkConfiguration(projectToken: String, host: String, context: AnalyticsSDKContext) -> PostHogConfig {
        let config = PostHogConfig(projectToken: projectToken, host: host)
        config.captureApplicationLifecycleEvents = true
        // PostHog recommends named screen() / postHogScreenView() calls for SwiftUI.
        config.captureScreenViews = false
        config.captureElementInteractions = true
        config.captureSwiftUIElementInteractions = true
        // Keep element identifiers, without reading control text or selected values.
        config.captureAutocaptureElementText = false
        config.errorTrackingConfig.autoCapture = true
        config.sessionReplay = false
        config.surveys = false
        config.setBeforeSend { event in
            guard let properties = context.prepare(event.event, properties: event.properties) else { return nil }
            event.properties = properties
            return event
        }
        #if DEBUG
            config.debug = true
        #endif
        return config
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
        let bounded = properties.filter { Self.lifecycleKeys.contains($0.key) }
        capture(event.rawValue, properties: bounded)
        // Only genuine game milestones reach acquisition reporting. The AppsFlyer
        // adapter owns its independent build/test policy, including TestFlight.
        if event == .firstGardenWinAchieved,
           bounded["milestone_basis"] as? String == "fresh_instrumented_progress" {
            progressionHandler("af_achievement_unlocked", ["af_description": "first_garden_win"])
        } else if event == .attemptFinished,
                  bounded["mode"] as? String == "flower_show",
                  bounded["attempt_kind"] as? String == "campaign",
                  bounded["outcome"] as? String == "won",
                  let level = bounded["class_number"] as? Int,
                  (1...FlowerShowContent.campaignClassCount).contains(level) {
            progressionHandler("af_level_achieved", [
                "af_level": level, "af_content_type": "flower_show",
            ])
        }
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
        capture("$screen", properties: properties.merging(["$screen_name": screen]) { _, screenValue in screenValue })
        // Preserve the existing dashboard contract while adopting the SDK's standard event.
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
