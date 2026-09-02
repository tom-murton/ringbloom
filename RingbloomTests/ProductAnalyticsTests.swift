import Testing
@testable import Ringbloom

@MainActor
struct ProductAnalyticsTests {
    private final class CaptureBox {
        var event: String?
        var properties: [String: Any] = [:]
    }

    @Test
    func captureAddsStableSchemaProperties() {
        let capture = CaptureBox()
        let analytics = ProductAnalytics { event, properties in
            capture.event = event
            capture.properties = properties
        }

        analytics.capture("paywall_viewed", properties: ["origin": "home"])

        #expect(capture.event == "paywall_viewed")
        #expect(capture.properties["origin"] as? String == "home")
        #expect(capture.properties["analytics_schema_version"] as? Int == 1)
        #expect(capture.properties["platform"] as? String == "ios")
        #expect(capture.properties["product"] as? String == "ringbloom")
    }

    @Test
    func deterministicAndHostedTestLaunchesDoNotSendAnalytics() {
        #expect(ProductAnalytics.shouldEnable(environment: [:], arguments: ["app"]))
        #expect(ProductAnalytics.shouldEnable(environment: [:], arguments: ["app", "--ui-testing"]) == false)
        #expect(ProductAnalytics.shouldEnable(environment: [:], arguments: ["app", "--screenshot-mode"]) == false)
        #expect(
            ProductAnalytics.shouldEnable(
                environment: ["XCInjectBundle": "/tmp/RingbloomTests.xctest"],
                arguments: ["app"]
            ) == false
        )
    }

    @Test
    func paywallContextUsesStableNames() {
        let context = FlowerShowPurchaseContext.lockedClass(12)

        #expect(context.analyticsProperties["origin"] as? String == "locked_class")
        #expect(context.analyticsProperties["target_class"] as? Int == 12)
    }
}
