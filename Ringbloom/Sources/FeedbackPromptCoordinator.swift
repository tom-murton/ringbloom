import Combine
import Foundation

@MainActor
final class FeedbackPromptCoordinator: ObservableObject {
    enum Prompt: Equatable {
        case feedback
        case review
    }

    static let firstNudgeMinimumCompletions = 3
    static let firstNudgeMinimumDistinctDays = 3
    static let feedbackAskCooldown: TimeInterval = 30 * 24 * 60 * 60
    static let feedbackSubmissionCooldown: TimeInterval = 90 * 24 * 60 * 60
    static let reviewGateDelay: TimeInterval = 7 * 24 * 60 * 60
    static let reviewAttemptCooldown: TimeInterval = 120 * 24 * 60 * 60
    static let sessionBackgroundThreshold: TimeInterval = 30 * 60

    private enum Key {
        static let meaningfulRunIDs = "ringbloom.feedbackPrompt.meaningfulRunIDs"
        static let meaningfulUseDates = "ringbloom.feedbackPrompt.meaningfulUseDates"
        static let firstOpportunityAt = "ringbloom.feedbackPrompt.firstOpportunityAt"
        static let firstOpportunitySessionID = "ringbloom.feedbackPrompt.firstOpportunitySessionID"
        static let lastShownAt = "ringbloom.feedbackPrompt.lastShownAt"
        static let lastOpenedAt = "ringbloom.feedbackPrompt.lastOpenedAt"
        static let lastDismissedAt = "ringbloom.feedbackPrompt.lastDismissedAt"
        static let lastSubmittedAt = "ringbloom.feedbackPrompt.lastSubmittedAt"
        static let nudgesDisabled = "ringbloom.feedbackPrompt.nudgesDisabled"
        static let lastReviewAttemptAt = "ringbloom.feedbackPrompt.lastReviewAttemptAt"
        static let lastReviewAttemptVersion = "ringbloom.feedbackPrompt.lastReviewAttemptVersion"
    }

    @Published private(set) var pendingPrompt: Prompt?
    @Published private(set) var promptSessionGeneration = 0
    @Published private(set) var feedbackNudgesDisabled: Bool
    @Published private(set) var firstFeedbackOpportunityAt: Date?
    @Published private(set) var lastFeedbackShownAt: Date?
    @Published private(set) var lastFeedbackDismissedAt: Date?
    @Published private(set) var lastFeedbackSubmittedAt: Date?
    @Published private(set) var lastReviewAttemptAt: Date?
    @Published private(set) var lastReviewAttemptVersion: String?

    var feedbackRemindersEnabled: Bool { !feedbackNudgesDisabled }
    var meaningfulUseCount: Int { meaningfulRunIDs.count }
    var distinctMeaningfulUseDayCount: Int {
        Set(meaningfulUseDates.map { calendar.startOfDay(for: $0) }).count
    }

    private let defaults: UserDefaults
    private let now: () -> Date
    private let appVersion: () -> String
    private let calendar: Calendar
    private let makeSessionID: () -> String

    private var meaningfulRunIDs: [String]
    private var meaningfulUseDates: [Date]
    private var firstOpportunitySessionID: String?
    private var lastFeedbackOpenedAt: Date?
    private var sessionID: String
    private var askMadeInSession = false
    private var backgroundedAt: Date?
    private var reservedRunID: UUID?

    init(
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = { .now },
        appVersion: @escaping () -> String = {
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        },
        calendar: Calendar = .autoupdatingCurrent,
        sessionID: @escaping () -> String = { UUID().uuidString }
    ) {
        self.defaults = defaults
        self.now = now
        self.appVersion = appVersion
        self.calendar = calendar
        makeSessionID = sessionID
        self.sessionID = sessionID()

        meaningfulRunIDs = defaults.stringArray(forKey: Key.meaningfulRunIDs) ?? []
        meaningfulUseDates = (defaults.array(forKey: Key.meaningfulUseDates) as? [Double] ?? [])
            .map(Date.init(timeIntervalSince1970:))
        feedbackNudgesDisabled = defaults.bool(forKey: Key.nudgesDisabled)
        firstFeedbackOpportunityAt = Self.date(forKey: Key.firstOpportunityAt, in: defaults)
        firstOpportunitySessionID = defaults.string(forKey: Key.firstOpportunitySessionID)
        lastFeedbackShownAt = Self.date(forKey: Key.lastShownAt, in: defaults)
        lastFeedbackOpenedAt = Self.date(forKey: Key.lastOpenedAt, in: defaults)
        lastFeedbackDismissedAt = Self.date(forKey: Key.lastDismissedAt, in: defaults)
        lastFeedbackSubmittedAt = Self.date(forKey: Key.lastSubmittedAt, in: defaults)
        lastReviewAttemptAt = Self.date(forKey: Key.lastReviewAttemptAt, in: defaults)
        lastReviewAttemptVersion = defaults.string(forKey: Key.lastReviewAttemptVersion)
    }

    @discardableResult
    func considerPromptAfterMeaningfulUse(
        runID: UUID?,
        reviewMomentEarned: Bool
    ) -> Prompt? {
        guard let runID else { return nil }
        if reservedRunID == runID { return pendingPrompt }

        pendingPrompt = nil
        reservedRunID = nil

        let completedAt = now()
        let recorded = recordMeaningfulUse(runID: runID, at: completedAt)
        guard recorded || meaningfulRunIDs.last == runID.uuidString else { return nil }
        guard !askMadeInSession else { return nil }

        let decision: Prompt? = if feedbackNudgeIsEligible(at: completedAt) {
            .feedback
        } else if reviewIsEligible(at: completedAt, reviewMomentEarned: reviewMomentEarned) {
            .review
        } else {
            nil
        }

        pendingPrompt = decision
        reservedRunID = decision == nil ? nil : runID
        return decision
    }

    @discardableResult
    func markFeedbackNudgeShown() -> Bool {
        guard pendingPrompt == .feedback, !askMadeInSession else { return false }
        let shownAt = now()
        lastFeedbackShownAt = shownAt
        defaults.set(shownAt.timeIntervalSince1970, forKey: Key.lastShownAt)
        recordFirstOpportunityIfNeeded(at: shownAt)
        consumeSessionAsk()
        return true
    }

    func recordFeedbackOpened() {
        let openedAt = now()
        lastFeedbackOpenedAt = openedAt
        defaults.set(openedAt.timeIntervalSince1970, forKey: Key.lastOpenedAt)
        recordFirstOpportunityIfNeeded(at: openedAt)
    }

    func dismissFeedbackNudge() {
        let dismissedAt = now()
        lastFeedbackDismissedAt = dismissedAt
        defaults.set(dismissedAt.timeIntervalSince1970, forKey: Key.lastDismissedAt)
        recordFirstOpportunityIfNeeded(at: dismissedAt)
        consumeSessionAsk()
    }

    func recordFeedbackSubmitted() {
        let submittedAt = now()
        lastFeedbackSubmittedAt = submittedAt
        defaults.set(submittedAt.timeIntervalSince1970, forKey: Key.lastSubmittedAt)
        recordFirstOpportunityIfNeeded(at: submittedAt)
    }

    func setFeedbackRemindersEnabled(_ enabled: Bool) {
        feedbackNudgesDisabled = !enabled
        defaults.set(!enabled, forKey: Key.nudgesDisabled)
        if !enabled {
            // Choosing not to receive feedback reminders must not silently opt the
            // player out of the independent App Store review journey forever.
            recordFirstOpportunityIfNeeded(at: now())
            if pendingPrompt == .feedback {
                pendingPrompt = nil
                reservedRunID = nil
            }
        }
    }

    func reviewReservationIsCurrent(runID: UUID?) -> Bool {
        guard let runID else { return false }
        return pendingPrompt == .review && reservedRunID == runID && !askMadeInSession
    }

    func recordReviewAttempt() {
        let attemptedAt = now()
        lastReviewAttemptAt = attemptedAt
        lastReviewAttemptVersion = appVersion()
        defaults.set(attemptedAt.timeIntervalSince1970, forKey: Key.lastReviewAttemptAt)
        defaults.set(lastReviewAttemptVersion, forKey: Key.lastReviewAttemptVersion)
        consumeSessionAsk()
    }

    func abandonPendingPrompt() {
        pendingPrompt = nil
        reservedRunID = nil
    }

    func sceneDidEnterBackground() {
        backgroundedAt = now()
    }

    func sceneDidBecomeActive() {
        guard let backgroundedAt else { return }
        defer { self.backgroundedAt = nil }
        guard now().timeIntervalSince(backgroundedAt) >= Self.sessionBackgroundThreshold else {
            return
        }
        sessionID = makeSessionID()
        askMadeInSession = false
        abandonPendingPrompt()
        promptSessionGeneration += 1
    }

    private func recordMeaningfulUse(runID: UUID, at date: Date) -> Bool {
        let identifier = runID.uuidString
        guard !meaningfulRunIDs.contains(identifier) else { return false }
        meaningfulRunIDs.append(identifier)
        meaningfulUseDates.append(date)
        defaults.set(meaningfulRunIDs, forKey: Key.meaningfulRunIDs)
        defaults.set(meaningfulUseDates.map(\.timeIntervalSince1970), forKey: Key.meaningfulUseDates)
        return true
    }

    private func feedbackNudgeIsEligible(at date: Date) -> Bool {
        guard !feedbackNudgesDisabled else { return false }
        guard meaningfulUseCount >= Self.firstNudgeMinimumCompletions,
              distinctMeaningfulUseDayCount >= Self.firstNudgeMinimumDistinctDays
        else { return false }
        if let lastReviewAttemptAt,
           date.timeIntervalSince(lastReviewAttemptAt) < Self.reviewGateDelay
        {
            return false
        }

        guard firstFeedbackOpportunityAt != nil else { return true }

        if let lastFeedbackSubmittedAt,
           date.timeIntervalSince(lastFeedbackSubmittedAt) < Self.feedbackSubmissionCooldown
        {
            return false
        }
        if let lastFeedbackDismissedAt,
           date.timeIntervalSince(lastFeedbackDismissedAt) < Self.feedbackAskCooldown
        {
            return false
        }
        if let lastAskAt = Self.latest(lastFeedbackShownAt, lastFeedbackOpenedAt),
           date.timeIntervalSince(lastAskAt) < Self.feedbackAskCooldown
        {
            return false
        }
        return true
    }

    private func reviewIsEligible(at date: Date, reviewMomentEarned: Bool) -> Bool {
        guard reviewMomentEarned,
              let firstFeedbackOpportunityAt,
              firstOpportunitySessionID != sessionID,
              date.timeIntervalSince(firstFeedbackOpportunityAt) >= Self.reviewGateDelay,
              meaningfulUseDates.contains(where: { $0 > firstFeedbackOpportunityAt })
        else { return false }

        if let lastFeedbackAskAt = Self.latest(lastFeedbackShownAt, lastFeedbackOpenedAt),
           date.timeIntervalSince(lastFeedbackAskAt) < Self.reviewGateDelay
        {
            return false
        }
        if lastReviewAttemptVersion == appVersion() { return false }
        if let lastReviewAttemptAt,
           date.timeIntervalSince(lastReviewAttemptAt) < Self.reviewAttemptCooldown
        {
            return false
        }
        return true
    }

    private func recordFirstOpportunityIfNeeded(at date: Date) {
        guard firstFeedbackOpportunityAt == nil else { return }
        firstFeedbackOpportunityAt = date
        firstOpportunitySessionID = sessionID
        defaults.set(date.timeIntervalSince1970, forKey: Key.firstOpportunityAt)
        defaults.set(sessionID, forKey: Key.firstOpportunitySessionID)
    }

    private func consumeSessionAsk() {
        askMadeInSession = true
        abandonPendingPrompt()
    }

    private static func date(forKey key: String, in defaults: UserDefaults) -> Date? {
        guard defaults.object(forKey: key) != nil else { return nil }
        return Date(timeIntervalSince1970: defaults.double(forKey: key))
    }

    private static func latest(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?): max(lhs, rhs)
        case let (lhs?, nil): lhs
        case let (nil, rhs?): rhs
        case (nil, nil): nil
        }
    }

    #if DEBUG
        static func seedNudgeDueForTesting(
            defaults: UserDefaults,
            now: Date = .now,
            calendar: Calendar = .autoupdatingCurrent
        ) {
            let today = calendar.startOfDay(for: now)
            let priorDates = [2.0, 1.0].map {
                today.addingTimeInterval(-$0 * 24 * 60 * 60)
            }
            defaults.set(priorDates.map { _ in UUID().uuidString }, forKey: Key.meaningfulRunIDs)
            defaults.set(priorDates.map(\.timeIntervalSince1970), forKey: Key.meaningfulUseDates)
            defaults.set(false, forKey: Key.nudgesDisabled)
            for key in [
                Key.firstOpportunityAt, Key.firstOpportunitySessionID,
                Key.lastShownAt, Key.lastOpenedAt, Key.lastDismissedAt, Key.lastSubmittedAt,
            ] {
                defaults.removeObject(forKey: key)
            }
        }
    #endif
}
