import Foundation
import Testing
@testable import Ringbloom

@MainActor
struct ProductAnalyticsTests {
    private final class CaptureBox {
        var event: String?
        var properties: [String: Any] = [:]
        var events: [(String, [String: Any])] = []

        func records(_ name: String) -> [[String: Any]] {
            events.filter { $0.0 == name }.map(\.1)
        }
    }

    private final class FullAccess: FlowerShowAccessProviding {
        let accessState: FlowerShowAccessState = .full(.storePurchase)
        var hasFullFlowerShowAccess: Bool { true }
    }

    private final class ToggleStore: GameProgressStoring {
        var progress: GameProgress
        var acceptsWrites = false
        var saveReasonCode = "write_failed"

        init(progress: GameProgress) { self.progress = progress }
        func load() -> GameProgress { progress }
        func save(_ progress: GameProgress) -> Bool {
            guard acceptsWrites else { return false }
            self.progress = progress
            saveReasonCode = "saved"
            return true
        }
    }

    private func captureHarness() -> (ProductAnalytics, CaptureBox) {
        let box = CaptureBox()
        let analytics = ProductAnalytics { event, properties in
            box.event = event
            box.properties = properties
            box.events.append((event, properties))
        }
        return (analytics, box)
    }

    @Test
    func captureAddsStableSchemaProperties() {
        let capture = CaptureBox()
        let analytics = ProductAnalytics { event, properties in
            capture.event = event
            capture.properties = properties
        }

        analytics.capture("paywall_viewed", properties: [
            "origin": "home",
            "analytics_data_tier": "production",
            "distribution_environment": "production",
        ])

        #expect(capture.event == "paywall_viewed")
        #expect(capture.properties["origin"] as? String == "home")
        #expect(capture.properties["analytics_schema_version"] as? Int == 2)
        #expect(capture.properties["platform"] as? String == "ios")
        #expect(capture.properties["product"] as? String == "ringbloom")
        #expect(capture.properties["analytics_data_tier"] as? String == "test")
        #expect(capture.properties["distribution_environment"] as? String == "xcode")
    }

    @Test
    func deterministicAndHostedTestLaunchesDoNotSendAnalytics() {
        #expect(ProductAnalytics.shouldEnable(environment: [:], arguments: ["app"]) == false)
        #expect(ProductAnalytics.shouldEnable(
            environment: ["RINGBLOOM_ANALYTICS_TEST_INGESTION": "1"],
            arguments: ["app"]
        ))
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

    @Test
    func storeKitFirstRouteAndOptInBoundaries() {
        func route(_ verified: AnalyticsDistributionEnvironment?, _ receipt: String?,
                   debug: Bool = false, deterministic: Bool = false,
                   hosted: Bool = false, optIn: Bool = false) -> AnalyticsRoute {
            .resolve(verifiedStoreKit: verified, receiptName: receipt, isDebug: debug,
                     isDeterministic: deterministic, isHostedUnitTest: hosted,
                     testIngestionOptIn: optIn)
        }
        #expect(route(.production, "sandboxReceipt").tier == .production)
        #expect(route(.production, "sandboxReceipt").distribution == .production)
        #expect(route(.sandbox, "receipt").tier == .disabled)
        #expect(route(.sandbox, "receipt", optIn: true).tier == .test)
        #expect(route(.xcode, "receipt", optIn: true).distribution == .xcode)
        #expect(route(nil, nil).tier == .unknown)
        #expect(route(nil, "sandboxReceipt").distribution == .sandbox)
        #expect(route(nil, "receipt").tier == .production)
        #expect(route(nil, nil, debug: true).tier == .disabled)
        #expect(route(nil, nil, debug: true, optIn: true).tier == .test)
        #expect(route(nil, nil, deterministic: true, optIn: true).tier == .test)
        #expect(route(nil, nil, hosted: true, optIn: true).tier == .disabled)
    }

    @Test
    func sessionsChangeAndLifecycleHelperDropsUnapprovedFields() {
        let (first, box) = captureHarness()
        let (second, _) = captureHarness()
        #expect(first.sessionID != second.sessionID)
        #expect(first.sessionID.hasPrefix("test-"))
        first.captureLifecycle(.attemptStarted, properties: [
            "attempt_id": UUID().uuidString,
            "mode": "garden",
            "board": "forbidden",
            "transaction_id": "forbidden",
            "raw_error": "forbidden",
        ])
        let recorded = box.records("attempt_started").first
        #expect(recorded?["board"] == nil)
        #expect(recorded?["transaction_id"] == nil)
        #expect(recorded?["raw_error"] == nil)
        #expect(recorded?["analytics_data_tier"] as? String == "test")
    }

    @Test
    func foregroundEventsCountColdActiveAndBackgroundReturnButIgnoreInactiveOverlay() {
        let (analytics, box) = captureHarness()
        analytics.observeScenePhase(.inactive)
        analytics.observeScenePhase(.background)
        analytics.observeScenePhase(.active)
        analytics.observeScenePhase(.active)
        analytics.observeScenePhase(.inactive)
        analytics.observeScenePhase(.active)
        analytics.observeScenePhase(.background)
        analytics.observeScenePhase(.inactive)
        analytics.observeScenePhase(.active)
        analytics.observeScenePhase(.active)

        let foregrounds = box.records("app_foregrounded")
        #expect(foregrounds.count == 2)
        #expect(foregrounds.compactMap { $0["foreground_reason"] as? String }
                == ["cold_launch", "return_from_background"])
        #expect(foregrounds.compactMap { $0["foreground_index"] as? Int } == [1, 2])
        #expect(foregrounds.allSatisfy { $0["session_id"] as? String == analytics.sessionID })
        #expect(Set(foregrounds.compactMap { $0["event_id"] as? String }).count == 2)
    }

    @Test
    func commerceOutcomesKeepPurchaseAndRestoreSeparate() {
        #expect(AnalyticsCommerceOutcome.purchase(verifiedNewPurchase: true, state: .success) == "success")
        #expect(AnalyticsCommerceOutcome.purchase(verifiedNewPurchase: false, state: .success) == "failed")
        #expect(AnalyticsCommerceOutcome.purchase(verifiedNewPurchase: false, state: .pending) == "pending")
        #expect(AnalyticsCommerceOutcome.purchase(verifiedNewPurchase: false, state: .idle) == "cancelled")
        #expect(AnalyticsCommerceOutcome.restore(state: .success, hasFullAccess: true) == "restored")
        #expect(AnalyticsCommerceOutcome.restore(state: .idle, hasFullAccess: false) == "no_entitlement")
        #expect(AnalyticsCommerceOutcome.restore(state: .failed, hasFullAccess: false) == "failed")
        #expect(FlowerShowAccessState.checking.analyticsName == "checking")
        #expect(FlowerShowAccessState.sample.analyticsName == "sample")
        #expect(FlowerShowAccessState.full(.legacyPaidApp).analyticsName == "legacy_paid_app")
        #expect(FlowerShowAccessState.full(.storePurchase).analyticsName == "store_purchase")
    }

    @Test
    func freshGardenMilestonesAreProspectiveAndFirstStartIsUnique() throws {
        let (analytics, box) = captureHarness()
        let store = InMemoryGameProgressStore(progress: .fresh)
        let model = GameModel(launchMode: .uiTest(seed: 0xB100), progressStore: store,
                              analytics: analytics)
        model.emitSessionStartedIfNeeded()
        model.emitSessionStartedIfNeeded()
        model.startGarden(1)
        while model.phase == .playing {
            let move = try #require(model.suggestedMove)
            model.select(move.ring)
            _ = try #require(model.rotate(move.direction))
        }
        #expect(model.phase == .won)
        #expect(box.records("app_session_started").count == 1)
        #expect(box.records("attempt_started").count == 1)
        #expect(box.records("attempt_started").first?["first_eligible_start"] as? Bool == true)
        #expect(box.records("attempt_started").first?["milestone_basis"] as? String == "fresh_instrumented_progress")
        #expect(box.records("first_bloom_achieved").count == 1)
        #expect(box.records("first_garden_win_achieved").count == 1)
        #expect(box.records("sample_access_unlocked").count == 1)
        #expect(box.records("attempt_finished").count == 1)
        #expect(store.progress.analyticsProgress.firstEligibleStartRecorded)
        #expect(store.progress.analyticsProgress.firstBloomRecorded)
        #expect(store.progress.analyticsProgress.firstGardenWinRecorded)
        model.nextGarden()
        #expect(box.records("attempt_started").count == 2)
        #expect(box.records("attempt_started").last?["first_eligible_start"] as? Bool == false)
        let secondSession = captureHarness()
        let relaunched = GameModel(launchMode: .production, progressStore: store,
                                   analytics: secondSession.0)
        relaunched.resumeGarden()
        #expect(secondSession.1.records("attempt_started").isEmpty)
        #expect(secondSession.1.records("first_bloom_achieved").isEmpty)
        #expect(secondSession.1.records("first_garden_win_achieved").isEmpty)
        #expect(secondSession.1.records("attempt_resumed").count == 1)
    }

    @Test
    func upgradedGardenKeepsItsMigratedIDWithoutRetrospectiveFirsts() throws {
        let existing = GameProgress(bestScore: 0, highestGarden: 1,
            activeGame: GameEngine(seed: 71, garden: 1), activeGardenSeed: 71)
        let store = InMemoryGameProgressStore(progress: existing)
        let (firstAnalytics, firstBox) = captureHarness()
        let first = GameModel(launchMode: .production, progressStore: store,
                              analytics: firstAnalytics)
        first.resumeGarden()
        let migratedID = try #require(store.progress.activeGardenAttemptID)
        #expect(firstBox.records("attempt_resumed").first?["attempt_id_origin"] as? String == "migrated_active_save")
        #expect(firstBox.records("attempt_started").isEmpty)
        let (secondAnalytics, secondBox) = captureHarness()
        let second = GameModel(launchMode: .production, progressStore: store,
                               analytics: secondAnalytics)
        second.resumeGarden()
        second.resumeGarden()
        #expect(second.analyticsAttemptID == migratedID)
        #expect(secondAnalytics.sessionID != firstAnalytics.sessionID)
        #expect(secondBox.records("attempt_resumed").count == 1)
        _ = second.retry()
        #expect(second.analyticsAttemptID != migratedID)
        #expect(secondBox.records("attempt_abandoned").count == 1)
        #expect(secondBox.records("attempt_started").count == 1)
        #expect(secondBox.records("first_bloom_achieved").isEmpty)
        #expect(secondBox.records("first_garden_win_achieved").isEmpty)
    }

    @Test
    func flowerShowAttemptIDsPersistForCampaignReplayAndCircuit() throws {
        let allRatings = Dictionary(uniqueKeysWithValues: (1 ... 30).map {
            ($0, FlowerShowRating.seedling)
        })
        for (classNumber, ratings, expectedKind) in [
            (1, [Int: FlowerShowRating](), FlowerShowAttemptKind.campaign),
            (1, [1: .seedling], .replay),
            (198, allRatings, .circuit),
        ] {
            let store = InMemoryGameProgressStore(progress: GameProgress(
                bestScore: 0, highestGarden: 11,
                flowerShowProgress: FlowerShowProgressV3(
                    bestCampaignRatings: ratings, nextCircuitClass: 198
                )
            ))
            let (analytics, box) = captureHarness()
            let model = GameModel(launchMode: .uiTest(seed: UInt64(classNumber)),
                                  progressStore: store, flowerShowAccess: FullAccess(),
                                  analytics: analytics)
            #expect(model.startFlowerShowClass(classNumber) == .started)
            let id = try #require(model.analyticsAttemptID)
            #expect(model.currentFlowerShowAttemptKind == expectedKind)
            #expect(store.progress.flowerShowProgress.activeAttempt?.engine.attemptID == id)
            let (relaunchAnalytics, relaunchBox) = captureHarness()
            let relaunched = GameModel(launchMode: .uiTest(seed: UInt64(classNumber + 1)),
                                       progressStore: store, flowerShowAccess: FullAccess(),
                                       analytics: relaunchAnalytics)
            #expect(relaunched.resumeFlowerShow() == .started)
            #expect(relaunched.analyticsAttemptID == id)
            #expect(relaunchBox.records("attempt_resumed").count == 1)
            #expect(relaunchBox.records("attempt_started").isEmpty)
            #expect(box.records("attempt_started").first?["attempt_kind"] as? String == expectedKind.rawValue)
            _ = relaunched.retry()
            #expect(relaunched.analyticsAttemptID != id)
            #expect(relaunchBox.records("attempt_abandoned").count == 1)
        }
    }

    @Test
    func flowerShowFinishAndMilestoneEmitOnlyOnce() throws {
        let store = InMemoryGameProgressStore(progress: GameProgress(bestScore: 0, highestGarden: 11))
        let (analytics, box) = captureHarness()
        let model = GameModel(launchMode: .uiTest(seed: 81), progressStore: store,
                              flowerShowAccess: FullAccess(), analytics: analytics)
        #expect(model.startFlowerShowClass(1) == .started)
        while model.phase == .playing {
            let move = try #require(model.suggestedMove)
            model.select(move.ring)
            _ = try #require(model.rotate(move.direction))
        }
        #expect(model.phase == .won)
        #expect(box.records("attempt_finished").count == 1)
        #expect(box.records("flower_show_milestone").count == 1)
        #expect(box.records("flower_show_milestone").first?["milestone"] as? String == "class_completed")
        _ = model.resumeFlowerShow()
        model.dismissPendingFlowerShowResult()
        #expect(box.records("attempt_finished").count == 1)
        #expect(box.records("flower_show_milestone").count == 1)
        let (relaunchAnalytics, relaunchBox) = captureHarness()
        _ = GameModel(launchMode: .uiTest(seed: 82), progressStore: store,
                      flowerShowAccess: FullAccess(), analytics: relaunchAnalytics)
        #expect(relaunchBox.records("attempt_finished").isEmpty)
        #expect(relaunchBox.records("flower_show_milestone").isEmpty)
    }

    @Test
    func failedSaveQueuesLifecycleUntilConfirmedRetry() {
        let store = ToggleStore(progress: .fresh)
        let (analytics, box) = captureHarness()
        let model = GameModel(launchMode: .uiTest(seed: 90), progressStore: store,
                              analytics: analytics)
        model.startGarden(1)
        #expect(model.progressSaveHealth == .pending)
        #expect(box.records("attempt_started").isEmpty)
        let failed = box.records("progress_save_failed")
        #expect(failed.count == 1)
        #expect(failed.first?["reason_code"] as? String == "write_failed")
        #expect(failed.first?["save_health"] as? String == "pending")
        #expect(failed.first?["board"] == nil)
        #expect(failed.first?["error"] == nil)
        store.acceptsWrites = true
        model.retryPendingProgress()
        #expect(model.progressSaveHealth == .saved)
        #expect(box.records("attempt_started").count == 1)
        #expect(box.records("progress_save_recovered").count == 1)
        #expect(store.progress.activeGardenAttemptID == model.analyticsAttemptID)
        #expect(store.progress.analyticsProgress.firstEligibleStartRecorded)
    }

    @Test
    func diskMigrationAddsOnlyAnAnonymousGardenIDAndSuppressesRetrospectiveMilestones() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RingbloomAnalyticsMigration-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("progress.json")
        let old = GameProgress(bestScore: 100, highestGarden: 1,
                               activeGame: GameEngine(seed: 91, garden: 1), activeGardenSeed: 91)
        var root = try #require(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(old)) as? [String: Any])
        root.removeValue(forKey: "analyticsProgress")
        root.removeValue(forKey: "activeGardenAttemptID")
        try JSONSerialization.data(withJSONObject: root).write(to: destination, options: .atomic)
        let (analytics, box) = captureHarness()
        let model = GameModel(launchMode: .production,
                              progressStore: FileGameProgressStore(fileURL: destination),
                              analytics: analytics)
        model.resumeGarden()
        let saved = FileGameProgressStore(fileURL: destination).load()
        #expect(saved.activeGardenAttemptID == model.analyticsAttemptID)
        #expect(saved.analyticsProgress.basis == .existingProgress)
        #expect(saved.bestScore == 100)
        #expect(saved.activeGame != nil)
        #expect(box.records("attempt_resumed").first?["attempt_id_origin"] as? String == "migrated_active_save")
        #expect(box.records("attempt_started").isEmpty)
        #expect(box.records("first_bloom_achieved").isEmpty)
    }

    @Test
    func classFiveAndCircuitCompletionCarryDistinctMilestoneNames() throws {
        let scenarios: [(Int, [Int: FlowerShowRating], [String])] = [
            (5, Dictionary(uniqueKeysWithValues: (1 ... 4).map { ($0, .seedling) }),
             ["class_completed", "class_5_completed"]),
            (198, Dictionary(uniqueKeysWithValues: (1 ... 30).map { ($0, .seedling) }),
             ["circuit_class_completed"]),
        ]
        for (number, ratings, expected) in scenarios {
            let store = InMemoryGameProgressStore(progress: GameProgress(
                bestScore: 0, highestGarden: 11,
                flowerShowProgress: FlowerShowProgressV3(
                    bestCampaignRatings: ratings, nextCircuitClass: 198
                )
            ))
            let (analytics, box) = captureHarness()
            let model = GameModel(launchMode: .uiTest(seed: UInt64(number)),
                                  progressStore: store, flowerShowAccess: FullAccess(),
                                  analytics: analytics)
            #expect(model.startFlowerShowClass(number) == .started)
            while model.phase == .playing {
                let move = try #require(model.suggestedMove)
                model.select(move.ring)
                _ = try #require(model.rotate(move.direction))
            }
            #expect(model.phase == .won)
            #expect(box.records("attempt_finished").count == 1)
            let milestones = box.records("flower_show_milestone")
            #expect(milestones.compactMap { $0["milestone"] as? String } == expected)
            #expect(Set(milestones.compactMap { $0["event_id"] as? String }).count == expected.count)
        }
    }

    @Test
    func reviewRequestAttemptIsRecordedOnlyAfterSuccessfulCommit() throws {
        let store = InMemoryGameProgressStore(progress: .fresh)
        let (firstAnalytics, firstBox) = captureHarness()
        let firstSession = GameModel(launchMode: .uiTest(seed: 0xB100), progressStore: store,
                                     appVersion: "1.5.1", analytics: firstAnalytics)
        firstSession.startGarden(1)
        while firstSession.phase == .playing {
            let move = try #require(firstSession.suggestedMove)
            firstSession.select(move.ring)
            _ = try #require(firstSession.rotate(move.direction))
        }
        #expect(firstSession.reviewRequestTrigger == nil)
        #expect(firstBox.records("review_request_attempted").isEmpty)

        let (analytics, box) = captureHarness()
        let model = GameModel(launchMode: .uiTest(seed: 0xB101), progressStore: store,
                              appVersion: "1.5.1", analytics: analytics)
        for garden in 2 ... 2 {
            model.startGarden(garden)
            while model.phase == .playing {
                let move = try #require(model.suggestedMove)
                model.select(move.ring)
                _ = try #require(model.rotate(move.direction))
            }
            #expect(model.phase == .won)
        }
        let trigger = try #require(model.reviewRequestTrigger)
        #expect(box.records("review_request_eligible").count == 1)
        #expect(box.records("review_request_eligible").first?["request_reason"] as? String == "garden_established_use")
        #expect(model.commitReviewRequestAttempt(trigger: trigger))
        #expect(model.commitReviewRequestAttempt(trigger: trigger) == false)
        #expect(box.records("review_request_attempted").count == 1)
        #expect(box.records("review_request_attempted").first?["request_reason"] as? String == "garden_established_use")
        #expect(box.records("review_request_attempted").first?["meaningful_session_count"] as? Int == 2)
        #expect(store.load().reviewRequestState.attemptedAppVersion == "1.5.1")
        let (laterAnalytics, laterBox) = captureHarness()
        let relaunched = GameModel(launchMode: .uiTest(seed: 0xB102), progressStore: store,
                                   appVersion: "1.5.1", analytics: laterAnalytics)
        relaunched.startGarden(3)
        while relaunched.phase == .playing {
            let move = try #require(relaunched.suggestedMove)
            relaunched.select(move.ring)
            _ = try #require(relaunched.rotate(move.direction))
        }
        #expect(relaunched.reviewRequestTrigger == nil)
        #expect(laterBox.records("review_request_attempted").isEmpty)
    }

    @Test
    func gardenThenCommittedCampaignAcrossProcessesIsEligibleButReplayInOneProcessIsNot() throws {
        let store = InMemoryGameProgressStore(progress: GameProgress(bestScore: 0, highestGarden: 11,
            flowerShowProgress: FlowerShowProgressV3(bestCampaignRatings: [1: .seedling])))
        let (firstAnalytics, _) = captureHarness()
        let firstSession = GameModel(launchMode: .uiTest(seed: 91), progressStore: store,
                                     appVersion: "1.6", flowerShowAccess: FullAccess(), analytics: firstAnalytics)
        firstSession.startGarden(1)
        while firstSession.phase == .playing {
            let move = try #require(firstSession.suggestedMove)
            firstSession.select(move.ring)
            _ = try #require(firstSession.rotate(move.direction))
        }
        #expect(firstSession.startFlowerShowReplay(1) == .started)
        while firstSession.phase == .playing {
            let move = try #require(firstSession.suggestedMove)
            firstSession.select(move.ring)
            _ = try #require(firstSession.rotate(move.direction))
        }
        #expect(firstSession.reviewRequestTrigger == nil)
        #expect(store.load().reviewRequestState.meaningfulSessionIDs.count == 1)

        let (secondAnalytics, secondBox) = captureHarness()
        let secondSession = GameModel(launchMode: .uiTest(seed: 92), progressStore: store,
                                      appVersion: "1.6", flowerShowAccess: FullAccess(), analytics: secondAnalytics)
        #expect(secondSession.startFlowerShowClass(2) == .started)
        while secondSession.phase == .playing {
            let move = try #require(secondSession.suggestedMove)
            secondSession.select(move.ring)
            _ = try #require(secondSession.rotate(move.direction))
        }
        let trigger = try #require(secondSession.reviewRequestTrigger)
        #expect(secondSession.reviewRequestReason == .gardenToFlowerShow)
        #expect(secondBox.records("review_request_eligible").count == 1)
        #expect(secondSession.commitReviewRequestAttempt(trigger: trigger))
        #expect(secondBox.records("review_request_attempted").first?["request_reason"] as? String == "garden_to_flower_show")
        #expect(store.load().reviewRequestState.committedCampaignResults == 1)
    }

    @Test
    func advancingCircuitAcrossProcessesQualifiesOnce() throws {
        let ratings = Dictionary(uniqueKeysWithValues: (1 ... 30).map { ($0, FlowerShowRating.seedling) })
        let store = InMemoryGameProgressStore(progress: GameProgress(
            bestScore: 0, highestGarden: 11,
            flowerShowProgress: FlowerShowProgressV3(bestCampaignRatings: ratings, nextCircuitClass: 31)
        ))
        let (firstAnalytics, _) = captureHarness()
        let first = GameModel(launchMode: .uiTest(seed: 93), progressStore: store,
                              appVersion: "1.6", flowerShowAccess: FullAccess(), analytics: firstAnalytics)
        #expect(first.startFlowerShowClass(31) == .started)
        while first.phase == .playing {
            let move = try #require(first.suggestedMove)
            first.select(move.ring)
            _ = try #require(first.rotate(move.direction))
        }
        #expect(first.reviewRequestTrigger == nil)
        let (secondAnalytics, _) = captureHarness()
        let second = GameModel(launchMode: .uiTest(seed: 94), progressStore: store,
                               appVersion: "1.6", flowerShowAccess: FullAccess(), analytics: secondAnalytics)
        #expect(second.startFlowerShowClass(32) == .started)
        while second.phase == .playing {
            let move = try #require(second.suggestedMove)
            second.select(move.ring)
            _ = try #require(second.rotate(move.direction))
        }
        let trigger = try #require(second.reviewRequestTrigger)
        #expect(second.reviewRequestReason == .establishedCircuit)
        #expect(second.commitReviewRequestAttempt(trigger: trigger))
        #expect(second.commitReviewRequestAttempt(trigger: trigger) == false)
        #expect(store.load().reviewRequestState.committedCircuitResults == 2)
        #expect(second.startFlowerShowClass(33) == .started)
        while second.phase == .playing {
            let move = try #require(second.suggestedMove)
            second.select(move.ring)
            _ = try #require(second.rotate(move.direction))
        }
        #expect(second.reviewRequestTrigger == nil)
    }

    @Test
    func classFiveCompletionNeverTriggersReviewBesidePurchaseHandoff() throws {
        let ratings = Dictionary(uniqueKeysWithValues: (1 ... 4).map { ($0, FlowerShowRating.seedling) })
        let state = ReviewRequestState(successfulGardenCompletions: 1,
            meaningfulSessionIDs: [
                "00000000-0000-0000-0000-000000000571",
                "00000000-0000-0000-0000-000000000572",
            ])
        let store = InMemoryGameProgressStore(progress: GameProgress(
            bestScore: 0, highestGarden: 11,
            flowerShowProgress: FlowerShowProgressV3(bestCampaignRatings: ratings),
            reviewRequestState: state
        ))
        let (analytics, box) = captureHarness()
        let model = GameModel(launchMode: .uiTest(seed: 96), progressStore: store,
                              appVersion: "1.6", flowerShowAccess: FullAccess(), analytics: analytics)
        #expect(model.startFlowerShowClass(5) == .started)
        while model.phase == .playing {
            let move = try #require(model.suggestedMove)
            model.select(move.ring)
            _ = try #require(model.rotate(move.direction))
        }
        #expect(model.phase == .won)
        #expect(model.reviewRequestState.completedClassFive)
        #expect(model.reviewRequestTrigger == nil)
        #expect(box.records("review_request_eligible").isEmpty)
        #expect(box.records("review_request_attempted").isEmpty)
    }

    @Test
    func retryingWonCampaignKeepsGameplayButDoesNotManufactureReviewMilestone() throws {
        let prior = ReviewRequestState(successfulGardenCompletions: 1,
            meaningfulSessionIDs: ["00000000-0000-0000-0000-000000000575"])
        let store = InMemoryGameProgressStore(progress: GameProgress(bestScore: 0, highestGarden: 11,
            reviewRequestState: prior))
        let (analytics, box) = captureHarness()
        let model = GameModel(launchMode: .uiTest(seed: 99), progressStore: store,
                              appVersion: "1.6", flowerShowAccess: FullAccess(), analytics: analytics)
        #expect(model.startFlowerShowClass(1) == .started)
        while model.phase == .playing {
            let move = try #require(model.suggestedMove)
            model.select(move.ring)
            _ = try #require(model.rotate(move.direction))
        }
        #expect(model.reviewRequestState.committedCampaignResults == 1)
        #expect(model.reviewRequestTrigger != nil)
        #expect(model.retry() == .started)
        while model.phase == .playing {
            let move = try #require(model.suggestedMove)
            model.select(move.ring)
            _ = try #require(model.rotate(move.direction))
        }
        #expect(model.phase == .won)
        #expect(model.reviewRequestState.committedCampaignResults == 1)
        #expect(model.reviewRequestTrigger == nil)
        #expect(box.records("review_request_eligible").count == 1)
    }

    @Test
    func retryingWonCircuitClassDoesNotCountAsAnotherAdvancement() throws {
        let ratings = Dictionary(uniqueKeysWithValues: (1 ... 30).map { ($0, FlowerShowRating.seedling) })
        let prior = ReviewRequestState(meaningfulSessionIDs: ["00000000-0000-0000-0000-000000000575"])
        let store = InMemoryGameProgressStore(progress: GameProgress(bestScore: 0, highestGarden: 11,
            flowerShowProgress: FlowerShowProgressV3(bestCampaignRatings: ratings, nextCircuitClass: 31),
            reviewRequestState: prior))
        let (analytics, box) = captureHarness()
        let model = GameModel(launchMode: .uiTest(seed: 100), progressStore: store,
                              appVersion: "1.6", flowerShowAccess: FullAccess(), analytics: analytics)
        #expect(model.startFlowerShowClass(31) == .started)
        while model.phase == .playing {
            let move = try #require(model.suggestedMove)
            model.select(move.ring)
            _ = try #require(model.rotate(move.direction))
        }
        #expect(model.reviewRequestState.committedCircuitResults == 1)
        #expect(model.reviewRequestTrigger != nil)
        #expect(model.retry() == .started)
        // Circuit results have no completed replay route: the result UI offers
        // Continue or Class Book, and the existing progression gate blocks the
        // completed Class after retry is requested.
        #expect(model.canPlayCurrentFlowerShow == false)
        #expect(model.rotate(.clockwise) == nil)
        #expect(model.reviewRequestState.committedCircuitResults == 1)
        #expect(model.reviewRequestTrigger == nil)
        #expect(box.records("review_request_eligible").count == 1)
    }

    @Test
    func failedAttemptPersistenceEmitsNoAttemptAndCanRetryWhenSaved() throws {
        let prior = ReviewRequestState(successfulGardenCompletions: 1,
            meaningfulSessionIDs: ["00000000-0000-0000-0000-000000000575"])
        let store = ToggleStore(progress: GameProgress(bestScore: 0, highestGarden: 2,
                                                       reviewRequestState: prior))
        let (analytics, box) = captureHarness()
        let model = GameModel(launchMode: .uiTest(seed: 95), progressStore: store,
                              appVersion: "1.6", analytics: analytics)
        model.startGarden(2)
        while model.phase == .playing {
            let move = try #require(model.suggestedMove)
            model.select(move.ring)
            _ = try #require(model.rotate(move.direction))
        }
        let trigger = try #require(model.reviewRequestTrigger)
        #expect(model.commitReviewRequestAttempt(trigger: trigger) == false)
        #expect(box.records("review_request_eligible").isEmpty)
        #expect(box.records("review_request_attempted").isEmpty)
        #expect(store.progress.reviewRequestState.attemptedDate == nil)
        store.acceptsWrites = true
        #expect(model.commitReviewRequestAttempt(trigger: trigger))
        #expect(box.records("review_request_eligible").count == 1)
        #expect(box.records("review_request_attempted").count == 1)
        #expect(store.progress.reviewRequestState.attemptedVersions.contains("1.6"))
    }

    @Test
    func leavingResultAbandonsOnlyEphemeralReviewOpportunity() throws {
        let prior = ReviewRequestState(successfulGardenCompletions: 1,
            meaningfulSessionIDs: ["00000000-0000-0000-0000-000000000575"])
        let store = InMemoryGameProgressStore(progress: GameProgress(bestScore: 0, highestGarden: 2,
            reviewRequestState: prior))
        let (analytics, box) = captureHarness()
        let model = GameModel(launchMode: .uiTest(seed: 97), progressStore: store,
                              appVersion: "1.6", analytics: analytics)
        model.startGarden(2)
        while model.phase == .playing {
            let move = try #require(model.suggestedMove)
            model.select(move.ring)
            _ = try #require(model.rotate(move.direction))
        }
        let trigger = try #require(model.reviewRequestTrigger)
        model.abandonReviewRequestOpportunity()
        #expect(model.commitReviewRequestAttempt(trigger: trigger) == false)
        #expect(store.load().reviewRequestState.attemptedDate == nil)
        #expect(box.records("review_request_attempted").isEmpty)
        let (laterAnalytics, _) = captureHarness()
        let relaunch = GameModel(launchMode: .uiTest(seed: 98), progressStore: store,
                                 appVersion: "1.6", analytics: laterAnalytics)
        #expect(relaunch.reviewRequestTrigger == nil)
    }

    @Test
    func ratingLinkTapHasOnlyClosedDestinationAndNoRatingClaim() {
        let (analytics, box) = captureHarness()
        analytics.ratingLinkTapped()
        let event = box.records("rating_link_tapped")
        #expect(event.count == 1)
        #expect(event.first?["destination"] as? String == "app_store_review")
        #expect(event.first?["screen"] as? String == "home")
        #expect(event.first?["rating"] == nil)
        #expect(RatingLink.url.absoluteString == "https://apps.apple.com/app/id6789952808?action=write-review")
    }

    @Test
    func interruptedReviewDelayDoesNotCommitOrRequest() async {
        var commits = 0
        var requests = 0
        let cancelled = makeReviewRequestDelayTask(
            wait: { try await Task.sleep(for: .seconds(5)) },
            stillEligible: { true },
            commit: { commits += 1; return true },
            request: { requests += 1 }
        )
        cancelled.cancel()
        await cancelled.value
        #expect(commits == 0)
        #expect(requests == 0)

        var remainsOnResult = true
        let navigated = makeReviewRequestDelayTask(
            wait: { try await Task.sleep(for: .milliseconds(1)) },
            stillEligible: { remainsOnResult },
            commit: { commits += 1; return true },
            request: { requests += 1 }
        )
        remainsOnResult = false
        await navigated.value
        #expect(commits == 0)
        #expect(requests == 0)

        let unsaved = makeReviewRequestDelayTask(
            wait: { try await Task.sleep(for: .milliseconds(1)) },
            stillEligible: { true },
            commit: { commits += 1; return false },
            request: { requests += 1 }
        )
        await unsaved.value
        #expect(commits == 1)
        #expect(requests == 0)
    }
}
