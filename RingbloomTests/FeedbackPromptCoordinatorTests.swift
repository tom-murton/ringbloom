import Foundation
@testable import Ringbloom
import Testing

@MainActor
struct FeedbackPromptCoordinatorTests {
    @Test func firstNudgeNeedsThreeCompletionsAcrossThreeDays() {
        withDefaults { defaults in
            let clock = TestClock()
            let coordinator = makeCoordinator(defaults: defaults, clock: clock, session: "session-a")

            #expect(coordinator.considerPromptAfterMeaningfulUse(runID: UUID(), reviewMomentEarned: false) == nil)
            clock.advance(days: 1)
            #expect(coordinator.considerPromptAfterMeaningfulUse(runID: UUID(), reviewMomentEarned: false) == nil)
            clock.advance(days: 1)
            #expect(coordinator.considerPromptAfterMeaningfulUse(runID: UUID(), reviewMomentEarned: false) == .feedback)
            #expect(coordinator.meaningfulUseCount == 3)
            #expect(coordinator.distinctMeaningfulUseDayCount == 3)
        }
    }

    @Test func dismissalUsesThirtyDayCooldownAndManualEntryStillWorks() {
        withDefaults { defaults in
            let clock = TestClock()
            let first = makeEligibleCoordinator(defaults: defaults, clock: clock, session: "session-a")
            #expect(first.markFeedbackNudgeShown())
            first.dismissFeedbackNudge()

            clock.advance(days: 29)
            let duringCooldown = makeCoordinator(defaults: defaults, clock: clock, session: "session-b")
            #expect(duringCooldown.considerPromptAfterMeaningfulUse(runID: UUID(), reviewMomentEarned: false) == nil)

            // Home and Settings call this path directly; cooldowns only suppress proactive nudges.
            duringCooldown.recordFeedbackOpened()
            #expect(duringCooldown.firstFeedbackOpportunityAt != nil)

            clock.advance(days: 30)
            let afterCooldown = makeCoordinator(defaults: defaults, clock: clock, session: "session-c")
            #expect(afterCooldown.considerPromptAfterMeaningfulUse(runID: UUID(), reviewMomentEarned: false) == .feedback)
        }
    }

    @Test func successfulSubmissionUsesNinetyDayCooldown() {
        withDefaults { defaults in
            let clock = TestClock()
            let first = makeEligibleCoordinator(defaults: defaults, clock: clock, session: "session-a")
            #expect(first.markFeedbackNudgeShown())
            first.recordFeedbackSubmitted()

            clock.advance(days: 89)
            let tooSoon = makeCoordinator(defaults: defaults, clock: clock, session: "session-b")
            #expect(tooSoon.considerPromptAfterMeaningfulUse(runID: UUID(), reviewMomentEarned: false) == nil)

            clock.advance(days: 1)
            let eligibleAgain = makeCoordinator(defaults: defaults, clock: clock, session: "session-c")
            #expect(eligibleAgain.considerPromptAfterMeaningfulUse(runID: UUID(), reviewMomentEarned: false) == .feedback)
        }
    }

    @Test func disablingRemindersDoesNotDisableManualFeedback() {
        withDefaults { defaults in
            let clock = TestClock()
            let coordinator = makeCoordinator(defaults: defaults, clock: clock, session: "session-a")
            coordinator.setFeedbackRemindersEnabled(false)
            coordinator.recordFeedbackOpened()
            coordinator.recordFeedbackSubmitted()

            #expect(coordinator.feedbackRemindersEnabled == false)
            #expect(coordinator.firstFeedbackOpportunityAt == clock.date)
            #expect(coordinator.lastFeedbackSubmittedAt == clock.date)

            clock.advance(days: 120)
            let reloaded = makeCoordinator(defaults: defaults, clock: clock, session: "session-b")
            #expect(reloaded.feedbackRemindersEnabled == false)
            #expect(reloaded.considerPromptAfterMeaningfulUse(runID: UUID(), reviewMomentEarned: false) == nil)
        }
    }

    @Test func disablingRemindersStillAllowsALaterIndependentReviewAsk() {
        withDefaults { defaults in
            let clock = TestClock()
            let first = makeCoordinator(defaults: defaults, clock: clock, session: "session-a")
            first.setFeedbackRemindersEnabled(false)

            clock.advance(days: 7)
            let laterSession = makeCoordinator(defaults: defaults, clock: clock, session: "session-b")
            #expect(laterSession.considerPromptAfterMeaningfulUse(runID: UUID(), reviewMomentEarned: true) == .review)
        }
    }

    @Test func reEnablingRemindersDoesNotBypassTheMeaningfulUseThreshold() {
        withDefaults { defaults in
            let clock = TestClock()
            let coordinator = makeCoordinator(defaults: defaults, clock: clock, session: "session-a")
            coordinator.setFeedbackRemindersEnabled(false)
            coordinator.setFeedbackRemindersEnabled(true)

            #expect(coordinator.considerPromptAfterMeaningfulUse(runID: UUID(), reviewMomentEarned: false) == nil)
            clock.advance(days: 1)
            #expect(coordinator.considerPromptAfterMeaningfulUse(runID: UUID(), reviewMomentEarned: false) == nil)
            clock.advance(days: 1)
            #expect(coordinator.considerPromptAfterMeaningfulUse(runID: UUID(), reviewMomentEarned: false) == .feedback)
        }
    }

    @Test func manualFeedbackDoesNotBypassTheMeaningfulUseThreshold() {
        withDefaults { defaults in
            let clock = TestClock()
            let first = makeCoordinator(defaults: defaults, clock: clock, session: "session-a")
            first.recordFeedbackOpened()

            let laterSession = makeCoordinator(defaults: defaults, clock: clock, session: "session-b")
            #expect(laterSession.considerPromptAfterMeaningfulUse(runID: UUID(), reviewMomentEarned: false) == nil)
            clock.advance(days: 1)
            #expect(laterSession.considerPromptAfterMeaningfulUse(runID: UUID(), reviewMomentEarned: false) == nil)
            clock.advance(days: 1)
            #expect(laterSession.considerPromptAfterMeaningfulUse(runID: UUID(), reviewMomentEarned: false) == nil)

            clock.advance(days: 29)
            #expect(laterSession.considerPromptAfterMeaningfulUse(runID: UUID(), reviewMomentEarned: false) == .feedback)
        }
    }

    @Test func manualFeedbackDoesNotConsumeTheSessionsProactiveAsk() {
        withDefaults { defaults in
            let clock = TestClock()
            let coordinator = makeEligibleCoordinator(defaults: defaults, clock: clock, session: "session-a")
            coordinator.recordFeedbackOpened()

            clock.advance(days: 31)
            #expect(coordinator.considerPromptAfterMeaningfulUse(runID: UUID(), reviewMomentEarned: false) == .feedback)
        }
    }

    @Test func onePromptIsConsumedPerSession() {
        withDefaults { defaults in
            let clock = TestClock()
            let coordinator = makeEligibleCoordinator(defaults: defaults, clock: clock, session: "session-a")
            #expect(coordinator.markFeedbackNudgeShown())

            clock.advance(days: 31)
            #expect(coordinator.considerPromptAfterMeaningfulUse(runID: UUID(), reviewMomentEarned: true) == nil)
        }
    }

    @Test func reviewWaitsForLaterSessionSevenDaysAndAnotherMeaningfulUse() {
        withDefaults { defaults in
            let clock = TestClock()
            let first = makeCoordinator(defaults: defaults, clock: clock, session: "session-a")
            first.recordFeedbackOpened()

            clock.advance(days: 6)
            let laterSession = makeCoordinator(defaults: defaults, clock: clock, session: "session-b")
            #expect(laterSession.considerPromptAfterMeaningfulUse(runID: UUID(), reviewMomentEarned: true) == nil)

            clock.advance(days: 1)
            #expect(laterSession.considerPromptAfterMeaningfulUse(runID: UUID(), reviewMomentEarned: true) == .review)
        }
    }

    @Test func reviewAttemptPersistsAndDoesNotRepeatForTheVersion() {
        withDefaults { defaults in
            let clock = TestClock()
            let first = makeCoordinator(defaults: defaults, clock: clock, session: "session-a")
            first.recordFeedbackOpened()
            clock.advance(days: 7)

            let review = makeCoordinator(defaults: defaults, clock: clock, session: "session-b")
            let runID = UUID()
            #expect(review.considerPromptAfterMeaningfulUse(runID: runID, reviewMomentEarned: true) == .review)
            #expect(review.reviewReservationIsCurrent(runID: runID))
            review.recordReviewAttempt()

            clock.advance(days: 121)
            let reloaded = makeCoordinator(defaults: defaults, clock: clock, session: "session-c")
            #expect(reloaded.lastReviewAttemptVersion == "1.6")
            #expect(reloaded.considerPromptAfterMeaningfulUse(runID: UUID(), reviewMomentEarned: true) != .review)
        }
    }

    @Test func aThirtyMinuteBackgroundStartsANewPromptSession() {
        withDefaults { defaults in
            let clock = TestClock()
            let coordinator = makeEligibleCoordinator(defaults: defaults, clock: clock, session: "session-a")
            #expect(coordinator.markFeedbackNudgeShown())

            clock.advance(days: 31)
            coordinator.sceneDidEnterBackground()
            clock.advance(seconds: 29 * 60)
            coordinator.sceneDidBecomeActive()
            #expect(coordinator.considerPromptAfterMeaningfulUse(runID: UUID(), reviewMomentEarned: false) == nil)

            coordinator.sceneDidEnterBackground()
            clock.advance(seconds: 30 * 60)
            coordinator.sceneDidBecomeActive()
            #expect(coordinator.considerPromptAfterMeaningfulUse(runID: UUID(), reviewMomentEarned: false) == .feedback)
        }
    }

    @Test func anUnshownNudgeIsReReservedAfterALongBackground() {
        withDefaults { defaults in
            let clock = TestClock()
            let coordinator = makeEligibleCoordinator(defaults: defaults, clock: clock, session: "session-a")
            let runID = UUID()
            #expect(coordinator.considerPromptAfterMeaningfulUse(runID: runID, reviewMomentEarned: false) == .feedback)
            #expect(coordinator.promptSessionGeneration == 0)

            coordinator.sceneDidEnterBackground()
            clock.advance(seconds: 30 * 60)
            coordinator.sceneDidBecomeActive()

            #expect(coordinator.promptSessionGeneration == 1)
            #expect(coordinator.pendingPrompt == nil)
            #expect(coordinator.considerPromptAfterMeaningfulUse(runID: runID, reviewMomentEarned: false) == .feedback)
            #expect(coordinator.markFeedbackNudgeShown())
        }
    }

    @Test func repeatedReservationReturnsTheSamePromptWithoutDuplicatingUse() {
        withDefaults { defaults in
            let clock = TestClock()
            let coordinator = makeCoordinator(defaults: defaults, clock: clock, session: "session-a")
            #expect(coordinator.considerPromptAfterMeaningfulUse(runID: UUID(), reviewMomentEarned: false) == nil)
            clock.advance(days: 1)
            #expect(coordinator.considerPromptAfterMeaningfulUse(runID: UUID(), reviewMomentEarned: false) == nil)
            clock.advance(days: 1)

            let runID = UUID()
            #expect(coordinator.considerPromptAfterMeaningfulUse(runID: runID, reviewMomentEarned: false) == .feedback)
            #expect(coordinator.considerPromptAfterMeaningfulUse(runID: runID, reviewMomentEarned: true) == .feedback)
            #expect(coordinator.meaningfulUseCount == 3)
        }
    }

    @Test func meaningfulRunDeduplicationPersistsAcrossCoordinatorInstances() {
        withDefaults { defaults in
            let clock = TestClock()
            let runID = UUID()
            let first = makeCoordinator(defaults: defaults, clock: clock, session: "session-a")
            #expect(first.considerPromptAfterMeaningfulUse(runID: runID, reviewMomentEarned: false) == nil)

            let reloaded = makeCoordinator(defaults: defaults, clock: clock, session: "session-b")
            #expect(reloaded.considerPromptAfterMeaningfulUse(runID: runID, reviewMomentEarned: false) == nil)
            #expect(reloaded.meaningfulUseCount == 1)
            #expect(reloaded.considerPromptAfterMeaningfulUse(runID: UUID(), reviewMomentEarned: false) == nil)
            #expect(reloaded.meaningfulUseCount == 2)
        }
    }

    private func makeEligibleCoordinator(
        defaults: UserDefaults,
        clock: TestClock,
        session: String
    ) -> FeedbackPromptCoordinator {
        let coordinator = makeCoordinator(defaults: defaults, clock: clock, session: session)
        #expect(coordinator.considerPromptAfterMeaningfulUse(runID: UUID(), reviewMomentEarned: false) == nil)
        clock.advance(days: 1)
        #expect(coordinator.considerPromptAfterMeaningfulUse(runID: UUID(), reviewMomentEarned: false) == nil)
        clock.advance(days: 1)
        #expect(coordinator.considerPromptAfterMeaningfulUse(runID: UUID(), reviewMomentEarned: false) == .feedback)
        return coordinator
    }

    private func makeCoordinator(
        defaults: UserDefaults,
        clock: TestClock,
        session: String
    ) -> FeedbackPromptCoordinator {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return FeedbackPromptCoordinator(
            defaults: defaults,
            now: { clock.date },
            appVersion: { "1.6" },
            calendar: calendar,
            sessionID: { session }
        )
    }

    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suiteName = "FeedbackPromptCoordinatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        body(defaults)
    }
}

private final class TestClock: @unchecked Sendable {
    var date = Date(timeIntervalSince1970: 1_800_000_000)

    func advance(days: Double) {
        date = date.addingTimeInterval(days * 24 * 60 * 60)
    }

    func advance(seconds: TimeInterval) {
        date = date.addingTimeInterval(seconds)
    }
}
