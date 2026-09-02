import Combine
import Foundation
import PostHog

@MainActor
final class ProductAnalytics: ObservableObject {
    typealias CaptureHandler = (_ event: String, _ properties: [String: Any]) -> Void

    static let shared = ProductAnalytics()
    static let schemaVersion = 1

    private var captureHandler: CaptureHandler?
    private var baseProperties: [String: Any] = [:]
    private(set) var isConfigured = false

    init(captureHandler: CaptureHandler? = nil) {
        self.captureHandler = captureHandler
        isConfigured = captureHandler != nil
        baseProperties = Self.defaultBaseProperties(bundle: .main)
    }

    func configure(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        guard isConfigured == false,
              Self.shouldEnable(environment: environment, arguments: arguments),
              let projectToken = Self.configuredString(for: "PostHogProjectToken", in: bundle),
              let host = Self.configuredString(for: "PostHogHost", in: bundle)
        else { return }

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

        baseProperties = Self.defaultBaseProperties(bundle: bundle)
        captureHandler = { event, properties in
            PostHogSDK.shared.capture(event, properties: properties)
        }
        isConfigured = true
    }

    func capture(_ event: String, properties: [String: Any] = [:]) {
        guard let captureHandler else { return }
        captureHandler(event, baseProperties.merging(properties) { _, eventValue in eventValue })
    }

    func screenViewed(_ screen: String, properties: [String: Any] = [:]) {
        capture("screen_viewed", properties: properties.merging(["screen": screen]) { _, screenValue in screenValue })
    }

    func buttonTapped(_ button: String, screen: String, properties: [String: Any] = [:]) {
        capture(
            "button_tapped",
            properties: properties.merging(
                [
                    "button": button,
                    "screen": screen,
                ]
            ) { _, buttonValue in buttonValue }
        )
    }

    static func shouldEnable(environment: [String: String], arguments: [String]) -> Bool {
        guard GameLaunchMode.detect(arguments: arguments) == .production else { return false }
        let testBundlePath = environment["XCInjectBundle"] ?? environment["XCTestBundlePath"]
        return testBundlePath?.hasSuffix("RingbloomTests.xctest") != true
    }

    private static func configuredString(for key: String, in bundle: Bundle) -> String? {
        guard let value = bundle.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false, trimmed.contains("$(") == false else { return nil }
        return trimmed
    }

    private static func defaultBaseProperties(bundle: Bundle) -> [String: Any] {
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
        if let targetClass {
            properties["target_class"] = targetClass
        }
        return properties
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
