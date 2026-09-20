import XCTest

@MainActor
final class RingbloomUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testFreshPlayerCanCompleteTutorialPauseAndResume() {
        let app = launch(tutorialSeen: false)

        let flowerShowUnlock = app.staticTexts["flowerShowButtonDetail"]
        XCTAssertTrue(flowerShowUnlock.waitForExistence(timeout: 3))
        XCTAssertEqual(
            flowerShowUnlock.label,
            "Win your first Garden to qualify."
        )

        let flowerShowProgress = app.otherElements["flowerShowButtonProgress"]
        XCTAssertTrue(flowerShowProgress.waitForExistence(timeout: 3))
        XCTAssertEqual(flowerShowProgress.value as? String, "0 of 1 Garden won")

        tap(app.buttons["playButton"], in: app)
        XCTAssertTrue(app.buttons["tutorialBeginButton"].waitForExistence(timeout: 3))
        tap(app.buttons["tutorialBeginButton"], in: app)

        let board = app.staticTexts["gameBoard"].firstMatch
        XCTAssertTrue(board.waitForExistence(timeout: 4))
        tap(app.buttons["homeButton"], in: app)
        XCTAssertTrue(app.otherElements["gamePause"].waitForExistence(timeout: 3))
        tap(app.buttons["resumeButton"], in: app)
        XCTAssertTrue(board.waitForExistence(timeout: 3))
    }

    func testExplicitAnalyticsIngestionFreshGardenWin() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RINGBLOOM_ANALYTICS_TEST_INGESTION"] == "1",
            "Remote test ingestion requires explicit runner opt-in."
        )
        let app = launch(arguments: ["--screenshot-win", "--analytics-fresh-progress"])
        XCTAssertTrue(app.otherElements["gameOutcome"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.staticTexts["GARDEN COMPLETE"].exists)
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 1)
        app.activate()
        XCTAssertTrue(app.otherElements["gameOutcome"].waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 5)
    }

    func testFirstWinOfferUsesAccessibleLabelsAtLargeText() {
        let app = launch(arguments: [
            "--screenshot-win",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
        ])
        let offer = app.buttons["tryFlowerShowButton"]
        XCTAssertTrue(offer.waitForExistence(timeout: 8))
        XCTAssertEqual(offer.label, "Try Flower Show, 5 free Classes")
        XCTAssertTrue(app.buttons["nextGardenButton"].label.contains("CONTINUE GARDEN"))
        tap(offer, in: app)
        let rules = app.staticTexts["flowerShowRulesTitle"]
        XCTAssertTrue(rules.waitForExistence(timeout: 5))
        XCTAssertEqual(rules.label, "NEW RULE · RING HARMONY")
        XCTAssertFalse(app.otherElements["flowerShowPurchaseView"].exists)
    }

    func testCheckingKeepsClassOneRouteFreeOfThePaywall() {
        let app = launch(arguments: [
            "--flower-show-access=checking",
            "--flower-show-class=1",
        ])
        tap(app.buttons["flowerShowButton"], in: app)
        XCTAssertTrue(app.staticTexts["flowerShowRulesTitle"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["flowerShowPurchaseView"].exists)
    }

    func testCompletedSamplerResumesSavedFreeReplayInsteadOfOpeningPaywall() {
        let app = launch(arguments: [
            "--flower-show-access=sample",
            "--flower-show-class=6",
            "--flower-show-saved-class=1",
        ])

        let flowerShow = app.buttons["flowerShowButton"]
        XCTAssertTrue(flowerShow.waitForExistence(timeout: 5))
        XCTAssertEqual(flowerShow.label, "RESUME REPLAY · CLASS 1")
        tap(flowerShow, in: app)
        XCTAssertTrue(app.staticTexts["gameBoard"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["flowerShowPurchaseView"].exists)
    }

    func testExplicitAnalyticsIngestionSampleClassFiveAndSyntheticPurchase() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RINGBLOOM_ANALYTICS_TEST_INGESTION"] == "1",
            "Remote test ingestion requires explicit runner opt-in."
        )
        let app = launch(arguments: [
            "--flower-show-access=sample", "--flower-show-class=5",
            "--screenshot-flower-show-rules", "--flower-show-display-price=Test purchase",
            "--analytics-purchase-fixture",
        ])
        tap(app.buttons["flowerShowBeginButton"], in: app)
        let result = app.otherElements["flowerShowResult"]
        // The exact solver route for campaign-05, digest
        // 4168748ddcbc2d5541f59a9a7f92c38a9f45269550c4addb0a44738ea4743ca7.
        let route: [(ring: String, rotation: String)] = [
            ("ringOuter", "rotateCounterClockwise"),
            ("ringOuter", "rotateClockwise"),
            ("ringInner", "rotateCounterClockwise"),
            ("ringInner", "rotateCounterClockwise"),
            ("ringMiddle", "rotateClockwise"),
        ]
        for move in route {
            tap(app.buttons[move.ring], in: app)
            tap(app.buttons[move.rotation], in: app)
            Thread.sleep(forTimeInterval: 1.55)
        }
        XCTAssertTrue(result.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["flowerShowResultTitle"].label.contains("CLASS 5 COMPLETE"))
        tap(app.buttons["nextGardenButton"], in: app)
        XCTAssertTrue(app.otherElements["flowerShowPurchaseView"].waitForExistence(timeout: 5))
        tap(app.buttons["flowerShowPurchaseButton"], in: app)
        XCTAssertTrue(app.staticTexts["FLOWER SHOW UNLOCKED"].waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 1)
        app.activate()
        Thread.sleep(forTimeInterval: 5)
    }

    func testFreshHomeShowsQualificationProgressDuringProductionEquivalentChecking() {
        let app = launch(arguments: ["--flower-show-access=checking"])

        let detail = app.staticTexts["flowerShowButtonDetail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 3))
        XCTAssertEqual(detail.label, "Win your first Garden to qualify.")

        let progress = app.otherElements["flowerShowButtonProgress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 3))
        XCTAssertEqual(progress.label, "Flower Show unlock progress")
        XCTAssertEqual(progress.value as? String, "0 of 1 Garden won")
        XCTAssertFalse(app.buttons["flowerShowButton"].isEnabled)
        XCTAssertFalse(app.otherElements["flowerShowPurchaseView"].exists)
    }

    func testQualifiedHomeKeepsOneOfOneTransitionVisibleWhileAccessChecks() {
        let app = launch(arguments: [
            "--flower-show-access=checking",
            "--flower-show-class=1",
        ])

        let progress = app.otherElements["flowerShowButtonProgress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 3))
        XCTAssertEqual(progress.value as? String, "1 of 1 Garden won")
        XCTAssertEqual(
            app.staticTexts["flowerShowButtonDetail"].label,
            "Checking your Flower Show access…"
        )
    }

    func testCompactHomeKeepsBothGameModesAboveTheFold() {
        let app = launch(tutorialSeen: false)

        let garden = app.buttons["playButton"]
        let flowerShow = app.buttons["flowerShowButton"]
        XCTAssertTrue(garden.waitForExistence(timeout: 3))
        XCTAssertTrue(flowerShow.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["settingsButton"].exists)
        XCTAssertTrue(app.buttons["home.feedback"].exists)
        XCTAssertLessThanOrEqual(
            flowerShow.frame.maxY,
            app.frame.maxY,
            "The complete Flower Show action should be visible without scrolling."
        )
    }

    func testHomeAndSettingsKeepFeedbackAvailable() {
        let app = launch(arguments: ["--feedback-offline"])

        tap(app.buttons["home.feedback"], in: app)
        XCTAssertTrue(app.navigationBars["Send feedback"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["What would make Ringbloom better for you?"].exists)
        tap(app.navigationBars["Send feedback"].buttons["Close"], in: app)
        app.terminate()

        let settingsApp = launch(arguments: ["--feedback-offline"])
        tap(settingsApp.buttons["settingsButton"], in: settingsApp)
        XCTAssertTrue(settingsApp.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(settingsApp.switches["feedbackRemindersToggle"].exists)
        tap(settingsApp.buttons["settings.feedback"], in: settingsApp)
        XCTAssertTrue(settingsApp.navigationBars["Send feedback"].waitForExistence(timeout: 5))
        XCTAssertTrue(settingsApp.staticTexts["What would make Ringbloom better for you?"].exists)
    }

    func testEligibleResultShowsNonInterruptiveFeedbackNudge() {
        let app = launch(arguments: ["--screenshot-win", "--feedback-nudge-due"])

        XCTAssertTrue(app.otherElements["gameOutcome"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.otherElements["feedbackNudge"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["nextGardenButton"].isHittable)
        tap(app.buttons["feedbackNudge.notNow"], in: app)
        XCTAssertTrue(app.otherElements["feedbackNudge"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons["nextGardenButton"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["nextGardenButton"].isHittable)
    }

    func testQualifiedPlayerSeesFreeSamplerAndClassBook() {
        let app = launch(arguments: [
            "--flower-show-access=sample",
            "--flower-show-class=1",
        ])

        let detail = app.staticTexts["flowerShowButtonDetail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 3))
        XCTAssertTrue(detail.label.contains("Classes 1–5 are free."))
        XCTAssertTrue(app.buttons["classBookButton"].exists)
        tap(app.buttons["flowerShowButton"], in: app)
        XCTAssertTrue(app.staticTexts["flowerShowRulesTitle"].waitForExistence(timeout: 3))
    }

    func testSamplerOpensPurchaseAtClassSix() {
        let app = launch(arguments: [
            "--flower-show-access=sample",
            "--flower-show-display-price=£2.99",
            "--flower-show-class=6",
        ])

        tap(app.buttons["flowerShowButton"], in: app)
        XCTAssertTrue(app.staticTexts["CONTINUE THE SHOW"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["flowerShowPurchaseButton"].exists)
        XCTAssertTrue(app.buttons["flowerShowPurchaseButton"].label.contains("£2.99"))
        XCTAssertTrue(app.staticTexts["NEXT · CLASS 6"].exists)
    }

    func testFlowerShowResultOpensAndCancelsTheOptionalNativeShareSheet() {
        let app = launch(arguments: [
            "--flower-show-access=full-purchase",
            "--flower-show-class=6",
            "--screenshot-flower-show-win",
        ])

        let result = app.otherElements["flowerShowResult"]
        XCTAssertTrue(result.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["nextGardenButton"].isHittable)
        let share = app.buttons["flowerShowShareButton"]
        XCTAssertTrue(share.isHittable)
        tap(share, in: app)
        let nativeSheet = app.navigationBars["UIActivityContentView"]
        XCTAssertTrue(nativeSheet.waitForExistence(timeout: 4))
        let close = app.buttons["header.closeButton"]
        XCTAssertTrue(close.isHittable)
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 3))
        XCTAssertTrue(result.waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["nextGardenButton"].isHittable)
    }

    func testFlowerShowShareActionRemainsReachableAtLargeText() {
        let app = launch(arguments: [
            "--flower-show-access=full-purchase",
            "--flower-show-class=6",
            "--screenshot-flower-show-win",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
        ])

        XCTAssertTrue(app.otherElements["flowerShowResult"].waitForExistence(timeout: 8))
        reveal(app.buttons["nextGardenButton"], in: app)
        XCTAssertTrue(app.buttons["nextGardenButton"].isHittable)
        reveal(app.buttons["flowerShowShareButton"], in: app)
        XCTAssertTrue(app.buttons["flowerShowShareButton"].isHittable)
        XCTAssertEqual(app.buttons["flowerShowShareButton"].label, "Share Flower Show achievement")
    }

    func testClassSixPurchasePreviewKeepsControlsReachableAtLargeTextOnASmallPhone() {
        let app = launch(arguments: [
            "--flower-show-access=sample",
            "--flower-show-display-price=CHF 1’234.50 (FAMILY PRICE)",
            "--flower-show-class=6",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
        ])

        tap(app.buttons["flowerShowButton"], in: app)
        let preview = app.otherElements["flowerShowClass6Preview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 4))
        XCTAssertTrue(app.otherElements["flowerShowClass6PreviewAnimated"].exists)
        reveal(app.buttons["flowerShowClass6PreviewPauseButton"], in: app)
        XCTAssertTrue(app.buttons["flowerShowClass6PreviewPauseButton"].isHittable)
        XCTAssertEqual(app.buttons["flowerShowClass6PreviewPauseButton"].label, "Play Class 6 demonstration")
        XCTAssertTrue(app.buttons["flowerShowClass6PreviewReplayButton"].isHittable)
        reveal(app.buttons["flowerShowPurchaseButton"], in: app)
        XCTAssertTrue(app.buttons["flowerShowPurchaseButton"].label.contains("CHF 1’234.50 (FAMILY PRICE)"))
        reveal(app.buttons["flowerShowKeepPlayingButton"], in: app)
        XCTAssertTrue(app.buttons["flowerShowKeepPlayingButton"].isHittable)
        reveal(app.buttons["flowerShowRestoreButton"], in: app)
        XCTAssertTrue(app.buttons["flowerShowRestoreButton"].isHittable)
        reveal(app.buttons["flowerShowPurchaseCloseButton"], in: app)
        XCTAssertTrue(app.buttons["flowerShowPurchaseCloseButton"].isHittable)
    }

    func testReducedMotionPurchasePreviewShowsStaticBeforeAndAfterBoards() {
        let app = launch(arguments: [
            "--flower-show-access=sample",
            "--flower-show-display-price=£2.99",
            "--flower-show-class=8",
            "--screenshot-flower-show-class-book",
            // This is Ringbloom's DEBUG-only override. It proves the static
            // preview branch without claiming that an XCTest launch argument
            // changed the simulator's native Reduce Motion setting.
            "--ui-test-reduce-motion",
        ])

        let classEight = app.buttons["classBookClass8"]
        revealLazy(classEight, in: app)
        tap(classEight, in: app)
        XCTAssertTrue(app.otherElements["flowerShowClass6PreviewStatic"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["CLASS 6 RULE EXAMPLE"].exists)
        XCTAssertTrue(app.staticTexts["TARGET · CLASS 8 · UNBROKEN HEATS"].exists)
        let summary = app.staticTexts["flowerShowClass6StaticSummary"]
        XCTAssertTrue(summary.label.contains("two scoring turns in a row"))
        XCTAssertTrue(summary.label.contains("middle ring clockwise, then the inner ring counter-clockwise"))
        XCTAssertFalse(app.buttons["flowerShowClass6PreviewPauseButton"].exists)
        reveal(app.buttons["flowerShowPurchaseButton"], in: app)
        XCTAssertTrue(app.buttons["flowerShowPurchaseButton"].isHittable)
        reveal(app.buttons["flowerShowRestoreButton"], in: app)
        XCTAssertTrue(app.buttons["flowerShowRestoreButton"].isHittable)
    }

    func testClassSixPreviewStartsPausedAndReplayRestoresTheStableOpeningState() {
        let app = launch(arguments: [
            "--flower-show-access=sample",
            "--flower-show-display-price=£2.99",
            "--flower-show-class=6",
        ])

        tap(app.buttons["flowerShowButton"], in: app)
        let play = app.buttons["flowerShowClass6PreviewPauseButton"]
        XCTAssertTrue(play.waitForExistence(timeout: 3))
        XCTAssertEqual(play.label, "Play Class 6 demonstration")
        tap(play, in: app)
        pauseForCapture(3.4)
        let replay = app.buttons["flowerShowClass6PreviewReplayButton"]
        XCTAssertTrue(replay.isHittable)
        tap(replay, in: app)
        XCTAssertTrue(play.waitForExistence(timeout: 2))
        XCTAssertEqual(play.label, "Play Class 6 demonstration")
    }

    func testPremiumClassBookTileOpensPurchaseWithoutStartingGame() {
        let app = launch(arguments: [
            "--flower-show-access=sample",
            "--flower-show-display-price=£2.99",
            "--screenshot-flower-show-class-book",
            "--flower-show-class=8",
        ])

        let class8 = app.buttons["classBookClass8"]
        revealLazy(class8, in: app)
        XCTAssertTrue(class8.label.contains("Full Flower Show required"))
        tap(class8, in: app)
        XCTAssertTrue(app.staticTexts["CONTINUE THE SHOW"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.otherElements["flowerShowObjectives"].exists)
    }

    func testClosingPurchaseFromClassBookReturnsToClassBook() {
        let app = launch(arguments: [
            "--flower-show-access=sample",
            "--flower-show-display-price=£2.99",
            "--screenshot-flower-show-class-book",
            "--flower-show-class=8",
        ])

        let class8 = app.buttons["classBookClass8"]
        revealLazy(class8, in: app)
        tap(class8, in: app)
        XCTAssertTrue(app.staticTexts["CONTINUE THE SHOW"].waitForExistence(timeout: 8))
        tap(app.buttons["flowerShowPurchaseCloseButton"], in: app)
        XCTAssertTrue(app.descendants(matching: .any)["flowerShowClassBook"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.otherElements["flowerShowPurchaseView"].exists)
    }

    func testSamplerRetainsHistoricalPremiumRatingWhileGated() {
        let app = launch(arguments: [
            "--flower-show-access=sample",
            "--flower-show-display-price=£2.99",
            "--screenshot-flower-show-class-book",
            "--flower-show-class=8",
        ])

        let class6 = app.buttons["classBookClass6"]
        revealLazy(class6, in: app)
        XCTAssertTrue(class6.label.contains("Seedling"))
        XCTAssertTrue(class6.label.contains("Full Flower Show required"))
    }

    func testCheckingAccessDoesNotOpenPurchaseFromClassBook() {
        let app = launch(arguments: [
            "--flower-show-access=checking",
            "--flower-show-display-price=£2.99",
            "--screenshot-flower-show-class-book",
            "--flower-show-class=8",
        ])

        let class8 = app.buttons["classBookClass8"]
        revealLazy(class8, in: app)
        XCTAssertTrue(class8.label.contains("access is being checked"))
        XCTAssertFalse(class8.isEnabled)
        class8.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.descendants(matching: .any)["flowerShowClassBook"].exists)
        XCTAssertFalse(app.otherElements["flowerShowPurchaseView"].exists)
        XCTAssertFalse(app.otherElements["flowerShowObjectives"].exists)
    }

    func testResultCheckingDisablesContinueAndRetryKeepsTheEarnedResult() {
        let app = launch(arguments: [
            "--flower-show-access=checking",
            "--flower-show-class=5",
            "--screenshot-flower-show-win",
        ])

        let result = app.otherElements["flowerShowResult"]
        let rating = app.descendants(matching: .any)["flowerShowRating"]
        XCTAssertTrue(result.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["flowerShowResultTitle"].label.contains("CLASS 5 COMPLETE"))
        XCTAssertTrue(rating.waitForExistence(timeout: 3))

        let next = app.buttons["nextGardenButton"]
        XCTAssertEqual(next.label, "Checking Flower Show access")
        XCTAssertEqual(next.value as? String, "Waiting for access check to finish")
        XCTAssertFalse(next.isEnabled)
        XCTAssertFalse(app.otherElements["flowerShowPurchaseView"].exists)

        let retry = app.buttons["resultAccessRetryButton"]
        XCTAssertTrue(retry.isEnabled)
        tap(retry, in: app)
        XCTAssertTrue(result.exists)
        XCTAssertTrue(rating.exists)
        XCTAssertFalse(next.isEnabled)
        XCTAssertFalse(app.otherElements["flowerShowPurchaseView"].exists)
    }

    func testResultCheckingThenFullStartsClassSixOnlyAfterExplicitRetryAndContinue() {
        let app = launch(arguments: [
            "--flower-show-access=checking-then-full",
            "--flower-show-class=5",
            "--screenshot-flower-show-win",
        ])

        let result = app.otherElements["flowerShowResult"]
        let rating = app.descendants(matching: .any)["flowerShowRating"]
        XCTAssertTrue(result.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["flowerShowResultTitle"].label.contains("CLASS 5 COMPLETE"))
        XCTAssertTrue(rating.waitForExistence(timeout: 3))
        let next = app.buttons["nextGardenButton"]
        XCTAssertFalse(next.isEnabled)
        tap(app.buttons["resultAccessRetryButton"], in: app)

        let enabled = NSPredicate(format: "isEnabled == true")
        expectation(for: enabled, evaluatedWith: next)
        waitForExpectations(timeout: 3)
        XCTAssertEqual(next.label, "NEXT CLASS")
        XCTAssertTrue(result.exists)
        tap(next, in: app)
        let rulesTitle = app.staticTexts["flowerShowRulesTitle"]
        XCTAssertTrue(rulesTitle.waitForExistence(timeout: 3))
        XCTAssertTrue(rulesTitle.label.contains("UNBROKEN"))
        XCTAssertFalse(app.otherElements["flowerShowPurchaseView"].exists)
    }

    func testResultCheckingThenSamplePreservesResultBeforeContinueOpensPurchase() {
        let app = launch(arguments: [
            "--flower-show-access=checking-then-sample",
            "--flower-show-display-price=£2.99",
            "--flower-show-class=5",
            "--screenshot-flower-show-win",
        ])

        let result = app.otherElements["flowerShowResult"]
        let rating = app.descendants(matching: .any)["flowerShowRating"]
        XCTAssertTrue(result.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["flowerShowResultTitle"].label.contains("CLASS 5 COMPLETE"))
        XCTAssertTrue(rating.waitForExistence(timeout: 3))
        tap(app.buttons["resultAccessRetryButton"], in: app)
        let next = app.buttons["nextGardenButton"]
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: next)
        waitForExpectations(timeout: 3)
        XCTAssertTrue(result.exists)
        XCTAssertTrue(rating.exists)
        XCTAssertFalse(app.otherElements["flowerShowPurchaseView"].exists)

        tap(next, in: app)
        XCTAssertTrue(app.otherElements["flowerShowPurchaseView"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["NEXT · CLASS 6"].exists)
    }

    func testPremiumReplayResultCheckingThenFullKeepsResultUntilReplayStarts() {
        let app = launch(arguments: [
            "--flower-show-access=checking-then-full",
            "--flower-show-class=6",
            "--flower-show-replay-result",
            "--screenshot-flower-show-win",
        ])

        let result = app.otherElements["flowerShowResult"]
        let rating = app.descendants(matching: .any)["flowerShowRating"]
        XCTAssertTrue(result.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["flowerShowResultTitle"].label.contains("CLASS COMPLETE"))
        XCTAssertTrue(rating.waitForExistence(timeout: 3))
        let replay = app.buttons["resultReplayButton"]
        XCTAssertEqual(replay.label, "Checking Flower Show access")
        XCTAssertEqual(replay.value as? String, "Waiting for access check to finish")
        XCTAssertFalse(replay.isEnabled)

        tap(app.buttons["resultAccessRetryButton"], in: app)
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: replay)
        waitForExpectations(timeout: 3)
        XCTAssertTrue(result.exists)
        XCTAssertTrue(rating.exists)
        XCTAssertEqual(replay.label, "Replay Class")
        tap(replay, in: app)
        XCTAssertTrue(app.otherElements["flowerShowObjectives"].waitForExistence(timeout: 5))
        XCTAssertFalse(result.exists)
        XCTAssertFalse(app.otherElements["flowerShowPurchaseView"].exists)
    }

    func testPremiumReplayResultCheckingThenSampleKeepsResultBeforePurchase() {
        let app = launch(arguments: [
            "--flower-show-access=checking-then-sample",
            "--flower-show-display-price=£2.99",
            "--flower-show-class=6",
            "--flower-show-replay-result",
            "--screenshot-flower-show-win",
        ])

        let result = app.otherElements["flowerShowResult"]
        let rating = app.descendants(matching: .any)["flowerShowRating"]
        XCTAssertTrue(result.waitForExistence(timeout: 8))
        XCTAssertTrue(rating.waitForExistence(timeout: 3))
        let replay = app.buttons["resultReplayButton"]
        XCTAssertFalse(replay.isEnabled)
        tap(app.buttons["resultAccessRetryButton"], in: app)
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: replay)
        waitForExpectations(timeout: 3)
        XCTAssertTrue(result.exists)
        XCTAssertTrue(rating.exists)
        tap(replay, in: app)
        XCTAssertTrue(app.otherElements["flowerShowPurchaseView"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["NEXT · CLASS 6"].exists)
        XCTAssertFalse(app.otherElements["flowerShowObjectives"].exists)
    }

    func testSampleAccessCanEnterAndReplayEveryFreeClassBoundary() {
        let app = launch(arguments: [
            "--flower-show-access=sample",
            "--flower-show-class=6",
            "--screenshot-flower-show-class-book",
        ])

        for classNumber in 1 ... 5 {
            let tile = app.buttons["classBookClass\(classNumber)"]
            revealLazy(tile, in: app)
            XCTAssertTrue(tile.isEnabled, "Expected Class \(classNumber) replay to remain enabled")
            tap(tile, in: app)
            XCTAssertTrue(app.staticTexts["flowerShowRulesTitle"].waitForExistence(timeout: 3))
            tap(app.buttons["flowerShowRulesCloseButton"], in: app)
            XCTAssertTrue(
                app.descendants(matching: .any)["flowerShowClassBook"].waitForExistence(timeout: 3)
            )
        }
    }

    func testSavedPremiumAttemptCannotResumeUnderSampleAccess() {
        let app = launch(arguments: [
            "--flower-show-access=sample",
            "--flower-show-display-price=£2.99",
            "--flower-show-class=6",
            "--flower-show-saved-class=6",
        ])

        tap(app.buttons["flowerShowButton"], in: app)
        XCTAssertTrue(app.otherElements["flowerShowPurchaseView"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.otherElements["flowerShowObjectives"].exists)
    }

    func testPremiumClassRetryCannotBeginUnderSampleAccess() {
        let app = launch(arguments: [
            "--flower-show-access=sample",
            "--flower-show-display-price=£2.99",
            "--flower-show-class=6",
            "--flower-show-premium-retry-fixture",
            "--screenshot-flower-show-loss",
        ])

        XCTAssertTrue(app.otherElements["flowerShowResult"].waitForExistence(timeout: 5))
        let retry = app.buttons["retryButton"]
        XCTAssertTrue(retry.isEnabled)
        tap(retry, in: app)
        XCTAssertTrue(app.otherElements["flowerShowPurchaseView"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.otherElements["flowerShowObjectives"].exists)
        XCTAssertTrue(app.staticTexts["NEXT · CLASS 6"].exists)
    }

    func testPaywallPromisesFullContentAndSupportsLongStorePrice() {
        let longPrice = "CHF 1’234.50 (FAMILY PRICE)"
        let app = launch(arguments: [
            "--flower-show-access=sample",
            "--flower-show-display-price=\(longPrice)",
            "--flower-show-class=6",
        ])

        tap(app.buttons["flowerShowButton"], in: app)
        XCTAssertTrue(app.staticTexts["Unlock 25 additional Classes and the Champion Circuit."].waitForExistence(timeout: 3))
        let purchase = app.buttons["flowerShowPurchaseButton"]
        XCTAssertEqual(purchase.label, "UNLOCK FOR \(longPrice.uppercased())")
        XCTAssertTrue(app.buttons["flowerShowKeepPlayingButton"].isEnabled)
        XCTAssertTrue(app.buttons["flowerShowRestoreButton"].isEnabled)
    }

    func testPendingFailedAndUnavailablePurchaseStatesShowExactRecoveryCopy() {
        let cases: [(arguments: [String], heading: String, body: String)] = [
            (["--flower-show-purchase=pending", "--flower-show-display-price=£2.99"], "PURCHASE PENDING", "Flower Show will unlock when the purchase is approved."),
            (["--flower-show-purchase=failed", "--flower-show-display-price=£2.99"], "PURCHASE NOT COMPLETED", "Check your connection and try again."),
            (["--flower-show-product-unavailable"], "FLOWER SHOW UNAVAILABLE", "The full Flower Show can’t be loaded right now. Garden and Classes 1–5 are still available."),
        ]

        for testCase in cases {
            let app = launch(arguments: [
                "--flower-show-access=sample",
                "--flower-show-class=6",
            ] + testCase.arguments)
            tap(app.buttons["flowerShowButton"], in: app)
            if testCase.heading != "FLOWER SHOW UNAVAILABLE" {
                tap(app.buttons["flowerShowPurchaseButton"], in: app)
            }
            XCTAssertTrue(app.staticTexts[testCase.heading].waitForExistence(timeout: 8))
            XCTAssertTrue(app.staticTexts[testCase.body].exists)
            app.terminate()
        }
    }

    func testCancelledPurchasePreservesFreeAccessWithoutShowingAnError() {
        let app = launch(arguments: [
            "--flower-show-access=sample",
            "--flower-show-purchase=user-cancelled",
            "--flower-show-display-price=£2.99",
            "--flower-show-class=6",
            "--screenshot-flower-show-purchase",
        ])

        tap(app.buttons["flowerShowPurchaseButton"], in: app)
        XCTAssertTrue(app.staticTexts["CONTINUE THE SHOW"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["PURCHASE NOT COMPLETED"].exists)
        XCTAssertFalse(app.staticTexts["PURCHASES UNAVAILABLE"].exists)
        XCTAssertTrue(app.buttons["flowerShowKeepPlayingButton"].isEnabled)
        tap(app.buttons["flowerShowKeepPlayingButton"], in: app)
        XCTAssertTrue(app.buttons["flowerShowButton"].waitForExistence(timeout: 3))
        XCTAssertEqual(
            app.otherElements["flowerShowButtonProgress"].value as? String,
            "5 of 5 free Classes complete"
        )
    }

    func testSimulatedPurchaseUnlocksAndRoutesToClassSixAndSelectedTarget() {
        var app = launch(arguments: [
            "--flower-show-access=sample",
            "--flower-show-purchase=success",
            "--flower-show-display-price=£2.99",
            "--flower-show-class=6",
            "--screenshot-flower-show-purchase",
        ])

        tap(app.buttons["flowerShowPurchaseButton"], in: app)
        XCTAssertTrue(app.staticTexts["FLOWER SHOW UNLOCKED"].waitForExistence(timeout: 3))
        let startSix = app.buttons["flowerShowPurchaseSuccessButton"]
        XCTAssertEqual(startSix.label, "START CLASS 6")
        tap(startSix, in: app)
        XCTAssertTrue(app.staticTexts["flowerShowRulesTitle"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["UNBROKEN"].exists)
        app.terminate()

        app = launch(arguments: [
            "--flower-show-access=sample",
            "--flower-show-purchase=success",
            "--flower-show-display-price=£2.99",
            "--flower-show-class=8",
            "--screenshot-flower-show-purchase",
            "--flower-show-purchase-target=8",
        ])
        XCTAssertTrue(app.otherElements["flowerShowPurchaseView"].waitForExistence(timeout: 3))
        tap(app.buttons["flowerShowPurchaseButton"], in: app)
        XCTAssertTrue(app.staticTexts["FLOWER SHOW UNLOCKED"].waitForExistence(timeout: 3))
        let continueEight = app.buttons["flowerShowPurchaseSuccessButton"]
        XCTAssertEqual(continueEight.label, "CONTINUE CLASS 8")
        tap(continueEight, in: app)
        XCTAssertTrue(app.staticTexts["flowerShowRulesTitle"].waitForExistence(timeout: 3))
    }

    func testPurchasesDisabledShowsExactCopyAndFreeAndRestoreActions() {
        let app = launch(arguments: [
            "--flower-show-access=sample",
            "--flower-show-purchase=disabled",
            "--flower-show-display-price=£2.99",
            "--flower-show-class=6",
            "--screenshot-flower-show-purchase",
        ])

        tap(app.buttons["flowerShowPurchaseButton"], in: app)
        XCTAssertTrue(app.staticTexts["PURCHASES UNAVAILABLE"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Purchases aren’t available on this device."].exists)
        XCTAssertTrue(app.buttons["flowerShowKeepPlayingButton"].isEnabled)
        XCTAssertTrue(app.buttons["flowerShowRestoreButton"].isEnabled)
    }

    func testRestoreSuccessUnlocksAndRoutesToClassSix() {
        let app = launch(arguments: [
            "--flower-show-access=sample",
            "--flower-show-restore=success",
            "--flower-show-display-price=£2.99",
            "--flower-show-class=6",
            "--screenshot-flower-show-purchase",
        ])

        tap(app.buttons["flowerShowRestoreButton"], in: app)
        XCTAssertTrue(app.staticTexts["FLOWER SHOW UNLOCKED"].waitForExistence(timeout: 3))
        let startSix = app.buttons["flowerShowPurchaseSuccessButton"]
        XCTAssertEqual(startSix.label, "START CLASS 6")
        tap(startSix, in: app)
        XCTAssertTrue(app.staticTexts["flowerShowRulesTitle"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["UNBROKEN"].exists)
    }

    func testPurchaseAndRestoreInFlightDisableBothStorefrontControlsAndExposeFeedback() {
        let cases: [(override: String, button: String, progress: String, label: String)] = [
            ("--flower-show-purchase=purchasing", "flowerShowPurchaseButton", "flowerShowPurchaseProgress", "Purchase in progress"),
            ("--flower-show-restore=restoring", "flowerShowRestoreButton", "flowerShowRestoreProgress", "Restore in progress"),
        ]

        for testCase in cases {
            let app = launch(arguments: [
                "--flower-show-access=sample",
                testCase.override,
                "--flower-show-display-price=£2.99",
                "--flower-show-class=6",
                "--screenshot-flower-show-purchase",
            ])
            tap(app.buttons[testCase.button], in: app)
            let progress = app.descendants(matching: .any)[testCase.progress]
            XCTAssertTrue(progress.waitForExistence(timeout: 3))
            XCTAssertEqual(progress.label, testCase.label)
            XCTAssertFalse(app.buttons["flowerShowPurchaseButton"].isEnabled)
            XCTAssertFalse(app.buttons["flowerShowRestoreButton"].isEnabled)
            app.terminate()
        }
    }

    func testLegacyAccessBypassesPaywallAtClassSix() {
        let app = launch(arguments: [
            "--flower-show-access=legacy",
            "--flower-show-class=6",
        ])

        tap(app.buttons["flowerShowButton"], in: app)
        XCTAssertTrue(app.staticTexts["flowerShowRulesTitle"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["UNBROKEN"].exists)
        XCTAssertFalse(app.otherElements["flowerShowPurchaseView"].exists)
    }

    func testFlowerShowRulesReturnAndUndoPreserveTheActiveClass() {
        let app = launch(arguments: ["--flower-show-access=full-purchase", "--flower-show-class=1"])

        tap(app.buttons["flowerShowButton"], in: app)
        XCTAssertTrue(app.staticTexts["flowerShowRulesTitle"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["flowerShowRulesTitle"].label, "NEW RULE · RING HARMONY")
        tap(app.buttons["flowerShowBeginButton"], in: app)

        XCTAssertTrue(app.otherElements["flowerShowObjectives"].waitForExistence(timeout: 8))
        tap(app.buttons["flowerShowRulesButton"], in: app)
        XCTAssertEqual(app.staticTexts["flowerShowRulesTitle"].label, "HOW TO WIN")
        tap(app.buttons["flowerShowBeginButton"], in: app)

        tap(app.buttons["ringInner"], in: app)
        tap(app.buttons["rotateClockwise"], in: app)
        let undo = app.buttons["flowerShowUndoButton"]
        XCTAssertTrue(undo.waitForExistence(timeout: 8))
        XCTAssertTrue(undo.isEnabled)
        tap(undo, in: app)
        XCTAssertFalse(undo.isEnabled)
        XCTAssertTrue(app.otherElements["flowerShowObjectives"].exists)
    }

    func testEveryNewRuleAppearsAtItsIntroductionClass() {
        let introductions = [
            (1, "RING HARMONY"),
            (6, "UNBROKEN"),
            (11, "BINDWEED"),
            (16, "TWIN BLOOM"),
            (21, "PRIZE BOUQUET"),
            (24, "DOUBLE HARMONY"),
            (33, "JUDGES' ORDER"),
        ]

        for (classNumber, ruleTitle) in introductions {
            let app = launch(arguments: [
                "--flower-show-access=full-purchase",
                "--flower-show-class=\(classNumber)",
            ])

            tap(app.buttons["flowerShowButton"], in: app)
            XCTAssertTrue(app.staticTexts["flowerShowRulesTitle"].waitForExistence(timeout: 8))
            XCTAssertTrue(
                app.staticTexts[ruleTitle].waitForExistence(timeout: 5),
                "Expected \(ruleTitle) introduction at Class \(classNumber)"
            )
            app.terminate()
        }
    }

    func testOrdinaryClassBriefingMakesTheChangeObvious() {
        let app = launch(arguments: [
            "--flower-show-access=full-purchase",
            "--flower-show-class=2",
        ])

        tap(app.buttons["flowerShowButton"], in: app)
        let title = app.staticTexts["flowerShowRulesTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        XCTAssertEqual(title.label, "ONE MORE BLOOM")

        let change = app.descendants(matching: .any)["flowerShowChange_target"]
        XCTAssertTrue(change.waitForExistence(timeout: 3))
        XCTAssertTrue(change.label.contains("ONE MORE BLOOM"))
        XCTAssertTrue(app.descendants(matching: .any)["flowerShowClassStats"].exists)
    }

    func testFifthClassIsPresentedAsARosetteClass() {
        let app = launch(arguments: [
            "--flower-show-access=full-purchase",
            "--flower-show-class=5",
        ])

        tap(app.buttons["flowerShowButton"], in: app)
        XCTAssertTrue(app.staticTexts["flowerShowRulesTitle"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["ROSETTE CLASS"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.otherElements["flowerShowRosetteProgress"].exists)
    }

    func testBindweedObjectiveShowsItsLiveSpreadCountdown() {
        let app = launch(arguments: [
            "--screenshot-flower-show-game",
            "--flower-show-access=full-purchase",
            "--flower-show-class=11",
        ])

        let bindweed = app.descendants(matching: .any)["bindweedProgress"]
        XCTAssertTrue(bindweed.waitForExistence(timeout: 4))
        XCTAssertEqual(bindweed.label, "CLEAR BINDWEED objective")
        XCTAssertEqual(
            bindweed.value as? String,
            "1 tangled stem left. Clear all Bindweed to win. Spreads in 3 turns"
        )
        XCTAssertTrue(app.staticTexts["gameBoard"].firstMatch.exists)
    }

    func testBindweedSpreadExplainsItsConsequence() {
        let app = launch(arguments: [
            "--screenshot-flower-show-game",
            "--screenshot-bindweed-spread",
            "--flower-show-access=full-purchase",
            "--flower-show-class=11",
        ])

        let warning = app.descendants(matching: .any)["flowerShowAttention"]
        XCTAssertTrue(warning.waitForExistence(timeout: 4))
        XCTAssertEqual(warning.label, "BINDWEED SPREAD")
        XCTAssertEqual(warning.value as? String, "2 tangled stems now need clearing.")

        let bindweed = app.descendants(matching: .any)["bindweedProgress"]
        XCTAssertEqual(bindweed.label, "CLEAR BINDWEED objective")
        XCTAssertTrue((bindweed.value as? String)?.contains("2 tangled stems left") == true)
    }

    func testGrandChampionContinuesIntoChampionCircuit() {
        let app = launch(arguments: [
            "--screenshot-champion-home",
            "--flower-show-access=full-purchase",
            "--flower-show-class=31",
        ])

        let flowerShow = app.buttons["flowerShowButton"]
        reveal(flowerShow, in: app)
        XCTAssertTrue(flowerShow.exists)
        XCTAssertTrue(flowerShow.label.contains("CONTINUE CIRCUIT"))
        XCTAssertTrue(app.staticTexts["Champion Circuit · Class 31"].exists)
        XCTAssertTrue(app.staticTexts["GRAND CHAMPION"].exists)
    }

    func testClassBookShowsStagesRatingsAndReplayableTiles() {
        let app = launch(arguments: [
            "--flower-show-access=full-purchase",
            "--flower-show-class=8",
        ])

        tap(app.buttons["classBookButton"], in: app)
        XCTAssertTrue(app.descendants(matching: .any)["flowerShowClassBook"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["HARMONY HEATS"].exists)
        let class1 = app.descendants(matching: .any)["classBookClass1"]
        let class8 = app.descendants(matching: .any)["classBookClass8"]
        revealLazy(class1, in: app)
        XCTAssertTrue(class1.exists)
        XCTAssertTrue(class1.label.contains("Seedling"))
        revealLazy(class8, in: app)
        XCTAssertTrue(app.staticTexts["UNBROKEN HEATS"].exists)
        XCTAssertTrue(class8.exists)
        XCTAssertTrue(class8.label.contains("current"))
    }

    func testStartingAnotherClassConfirmsSavedAttemptReplacement() {
        let app = launch(arguments: [
            "--flower-show-access=full-purchase",
            "--flower-show-class=11",
            "--flower-show-saved-class=8",
            "--screenshot-flower-show-class-book",
        ])

        let class11 = app.buttons["classBookClass11"]
        revealLazy(class11, in: app)
        tap(class11, in: app)
        XCTAssertTrue(app.alerts["Replace saved Class 8 attempt?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["KEEP CLASS 8"].exists)
        XCTAssertTrue(app.buttons["START CLASS 11"].exists)
        XCTAssertTrue(app.staticTexts["Progress in the saved Class 8 attempt will be lost."].exists)
    }

    func testMigrationNoticeAppearsOnlyWhenOpeningFlowerShow() {
        let app = launch(arguments: [
            "--flower-show-access=full-purchase",
            "--flower-show-v3-migration-notice",
        ])

        XCTAssertFalse(app.alerts["FLOWER SHOW REDESIGNED"].exists)
        tap(app.buttons["flowerShowButton"], in: app)
        XCTAssertTrue(app.alerts["FLOWER SHOW REDESIGNED"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["CONTINUE"].exists)
    }

    func testFlowerShowHUDOmitsScoreAndGlobalChain() {
        let app = launch(arguments: [
            "--screenshot-flower-show-game",
            "--flower-show-access=full-purchase",
            "--flower-show-class=29",
        ])

        XCTAssertTrue(app.descendants(matching: .any)["flowerShowCompactHeader"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.descendants(matching: .any)["scoreLabel"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["streakLabel"].exists)
        XCTAssertTrue(app.buttons["rotateClockwise"].exists)
        XCTAssertTrue(app.buttons["rotateCounterClockwise"].exists)
    }

    func testAccessibilityTextUsesGoalsSummaryWithoutSeparatingControls() {
        let app = launch(arguments: [
            "--screenshot-flower-show-game",
            "--flower-show-access=full-purchase",
            "--flower-show-class=29",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
        ])

        let goals = app.descendants(matching: .any)["flowerShowGoalsButton"]
        XCTAssertTrue(goals.waitForExistence(timeout: 4))
        reveal(app.buttons["rotateClockwise"], in: app)
        XCTAssertTrue(app.buttons["rotateClockwise"].isHittable)
        XCTAssertTrue(app.buttons["rotateCounterClockwise"].exists)
    }

    func testReducedMotionAndIncreasedContrastKeepLateClassControlsReachable() {
        let app = launch(arguments: [
            "--screenshot-flower-show-game",
            "--flower-show-access=full-purchase",
            "--flower-show-class=30",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
            "-UIAccessibilityReduceMotionEnabled",
            "YES",
            "-UIAccessibilityDarkerSystemColorsEnabled",
            "YES",
        ])

        XCTAssertTrue(app.descendants(matching: .any)["flowerShowGoalsButton"].waitForExistence(timeout: 4))
        reveal(app.buttons["rotateClockwise"], in: app)
        XCTAssertTrue(app.buttons["ringInner"].exists)
        XCTAssertTrue(app.buttons["ringMiddle"].exists)
        XCTAssertTrue(app.buttons["ringOuter"].exists)
        XCTAssertTrue(app.buttons["rotateClockwise"].isHittable)
        XCTAssertTrue(app.buttons["rotateCounterClockwise"].exists)
    }

    // These journeys are intentionally deterministic and paced for App Store preview capture.
    // They exercise the real game UI; the marketing video is assembled from the resulting
    // Simulator recording rather than from rendered or mocked gameplay.
    func testAppPreviewGardenCapture() {
        let app = launch(arguments: ["--screenshot-game"])
        XCTAssertTrue(app.staticTexts["gameBoard"].firstMatch.waitForExistence(timeout: 8))
        pauseForCapture(1.4)

        for _ in 0 ..< 3 {
            performHintedMove(in: app)
            pauseForCapture(1.8)
        }
    }

    func testAppPreviewFlowerShowCapture() {
        let app = launch(arguments: [
            "--screenshot-flower-show-rules",
            "--flower-show-access=full-purchase",
            "--flower-show-class=11",
        ])

        let rulesTitle = app.staticTexts["flowerShowRulesTitle"]
        XCTAssertTrue(rulesTitle.waitForExistence(timeout: 8))
        XCTAssertTrue(rulesTitle.label.contains("BINDWEED"))
        pauseForCapture(2.8)

        tap(app.buttons["flowerShowBeginButton"], in: app)
        XCTAssertTrue(app.otherElements["flowerShowObjectives"].waitForExistence(timeout: 8))
        pauseForCapture(1.5)

        let route: [(ring: String, rotation: String)] = [
            ("ringOuter", "rotateClockwise"),
            ("ringOuter", "rotateClockwise"),
            ("ringMiddle", "rotateClockwise"),
            ("ringMiddle", "rotateClockwise"),
        ]
        for (index, move) in route.enumerated() {
            let ring = app.buttons[move.ring]
            XCTAssertTrue(ring.waitForExistence(timeout: 8))
            ring.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            pauseForCapture(0.35)

            let rotation = app.buttons[move.rotation]
            XCTAssertTrue(rotation.waitForExistence(timeout: 8))
            rotation.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            pauseForCapture(index == route.indices.last ? 1.0 : 1.55)
        }

        XCTAssertTrue(app.otherElements["flowerShowResult"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["flowerShowResultTitle"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Class 11 is complete."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["flowerShowRating"].waitForExistence(timeout: 3))
        pauseForCapture(3.4)
    }

    func testAppPreviewClassBookCapture() {
        let app = launch(arguments: [
            "--screenshot-flower-show-class-book",
            "--flower-show-access=full-purchase",
            "--flower-show-class=30",
        ])
        let classBook = app.descendants(matching: .any)["flowerShowClassBook"]
        XCTAssertTrue(classBook.waitForExistence(timeout: 8))
        pauseForCapture(1.2)

        for _ in 0 ..< 4 {
            let start = classBook.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.82))
            let end = classBook.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.30))
            start.press(forDuration: 0.12, thenDragTo: end)
            pauseForCapture(0.65)
        }
        pauseForCapture(1.2)
    }

    private func launch(
        arguments: [String] = [],
        tutorialSeen: Bool = true
    ) -> XCUIApplication {
        let app = XCUIApplication()
        var launchArguments = [
            "--ui-testing",
            "--seed=424242",
            "-ringbloom.tutorialSeen",
            tutorialSeen ? "YES" : "NO",
        ] + arguments
        // UI accessibility preferences persist in the simulator.  Set the
        // standard values per launch unless this test deliberately overrides
        // one, so large-text and Reduce Motion coverage cannot affect a later
        // normal-layout assertion.
        if arguments.contains("-UIPreferredContentSizeCategoryName") == false {
            launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        }
        if arguments.contains("-UIAccessibilityReduceMotionEnabled") == false {
            launchArguments += ["-UIAccessibilityReduceMotionEnabled", "NO"]
        }
        if arguments.contains("-UIAccessibilityDarkerSystemColorsEnabled") == false {
            launchArguments += ["-UIAccessibilityDarkerSystemColorsEnabled", "NO"]
        }
        app.launchArguments = launchArguments
        if ProcessInfo.processInfo.environment["RINGBLOOM_ANALYTICS_TEST_INGESTION"] == "1" {
            app.launchEnvironment["RINGBLOOM_ANALYTICS_TEST_INGESTION"] = "1"
            NSLog("RINGBLOOM_ANALYTICS_TEST_OPT_IN_FORWARDED")
        }
        app.launch()
        // The physical iPhone SE takes materially longer than the simulator to
        // settle after a cold launch.  Waiting here keeps subsequent element
        // queries from racing the first SwiftUI layout pass.
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 12))
        return app
    }

    private func tap(
        _ element: XCUIElement,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        reveal(element, in: app)
        XCTAssertTrue(element.waitForExistence(timeout: 8), "Expected element to exist", file: file, line: line)
        // A scroll or an asynchronous entitlement transition can invalidate a
        // previously resolved query.  Re-reveal immediately before tapping so
        // we act on the current hierarchy rather than a stale snapshot.
        reveal(element, in: app)
        XCTAssertTrue(element.exists, "Expected element to exist", file: file, line: line)
        XCTAssertTrue(element.isHittable, "Expected element to be hittable", file: file, line: line)
        element.tap()
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        _ = element.waitForExistence(timeout: 8)
        for _ in 0 ..< 8 where element.exists && element.isHittable == false {
            app.swipeUp()
        }
        for _ in 0 ..< 4 where element.exists && element.frame.maxY > app.frame.maxY - 44 {
            app.swipeUp()
        }
        for _ in 0 ..< 12 where element.exists && element.isHittable == false {
            app.swipeDown()
        }
        for _ in 0 ..< 4 where element.exists && element.frame.minY < app.frame.minY + 44 {
            app.swipeDown()
        }
    }

    private func revealLazy(_ element: XCUIElement, in app: XCUIApplication) {
        // Class Book is a SwiftUI ScrollView.  Drag inside that view rather
        // than swiping the application window: window-level swipes can land on
        // a tile and accidentally open its rules/purchase route on a device.
        // SwiftUI exposes this identifier as a generic accessibility element
        // on physical devices (and as an `otherElement` in some simulator
        // hierarchies), so keep the query type-agnostic.
        let classBook = app.descendants(matching: .any)["flowerShowClassBook"]
        _ = classBook.waitForExistence(timeout: 8)
        for _ in 0 ..< 20 where element.exists == false {
            if classBook.exists {
                let start = classBook.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.82))
                let end = classBook.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.24))
                start.press(forDuration: 0.08, thenDragTo: end)
            } else {
                app.swipeUp()
            }
        }
        reveal(element, in: app)
    }

    private func performHintedMove(in app: XCUIApplication) {
        let hintButton = app.buttons["hintButton"]
        XCTAssertTrue(hintButton.waitForExistence(timeout: 8))
        hintButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let hint = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'Hint: choose '")
        ).firstMatch
        XCTAssertTrue(hint.waitForExistence(timeout: 12))

        let normalizedHint = hint.label.lowercased()
        let ringIdentifier: String
        if normalizedHint.contains("choose inner") {
            ringIdentifier = "ringInner"
        } else if normalizedHint.contains("choose middle") {
            ringIdentifier = "ringMiddle"
        } else {
            XCTAssertTrue(normalizedHint.contains("choose outer"), "Unexpected hint: \(hint.label)")
            ringIdentifier = "ringOuter"
        }

        let ringButton = app.buttons[ringIdentifier]
        XCTAssertTrue(ringButton.waitForExistence(timeout: 8))
        ringButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        pauseForCapture(0.35)
        let rotationIdentifier = normalizedHint.contains("turn right")
            ? "rotateClockwise"
            : "rotateCounterClockwise"
        let rotationButton = app.buttons[rotationIdentifier]
        XCTAssertTrue(rotationButton.waitForExistence(timeout: 8))
        rotationButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func pauseForCapture(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }
}
