import Foundation

struct PersistedFlowerShowAttempt: Codable, Equatable, Sendable {
    let contentVersion: Int
    let context: FlowerShowAttemptContext
    let engine: FlowerShowEngine
}

struct FlowerShowResultSummary: Codable, Equatable, Identifiable, Sendable {
    let attemptID: UUID
    let context: FlowerShowAttemptContext
    let rating: FlowerShowRating
    let movesUsed: Int
    let radiantPar: Int
    let didUseHint: Bool
    let didUseUndo: Bool
    let isNewBest: Bool
    let milestone: FlowerShowMilestone?

    var id: UUID { attemptID }
}

struct FlowerShowProgressV3: Codable, Equatable, Sendable {
    /// A deliberately generous persisted cursor ceiling. Flower Show content repeats its
    /// 128 authored endless scenarios, so larger values add no content variety and only
    /// expose arithmetic overflow in subsequent `nextCircuitClass += 1` operations.
    static let maximumCircuitClass = 1_000_000

    var bestCampaignRatings: [Int: FlowerShowRating]
    var nextCircuitClass: Int
    var activeAttempt: PersistedFlowerShowAttempt?
    var pendingResult: FlowerShowResultSummary?
    var seenIntroductions: Set<FlowerShowIntroductionID>
    var pendingNoticeVersion: Int?
    var committedAttemptIDs: Set<UUID>

    init(
        bestCampaignRatings: [Int: FlowerShowRating] = [:],
        nextCircuitClass: Int = 31,
        activeAttempt: PersistedFlowerShowAttempt? = nil,
        pendingResult: FlowerShowResultSummary? = nil,
        seenIntroductions: Set<FlowerShowIntroductionID> = [],
        pendingNoticeVersion: Int? = nil,
        committedAttemptIDs: Set<UUID> = []
    ) {
        self.bestCampaignRatings = bestCampaignRatings
        self.nextCircuitClass = min(
            Self.maximumCircuitClass,
            max(FlowerShowContent.circuitStartClass, nextCircuitClass)
        )
        self.activeAttempt = activeAttempt
        self.pendingResult = pendingResult
        self.seenIntroductions = seenIntroductions
        self.pendingNoticeVersion = pendingNoticeVersion
        self.committedAttemptIDs = committedAttemptIDs
    }

    var completedCampaignClasses: Set<Int> {
        Set(bestCampaignRatings.keys.filter { (1 ... 30).contains($0) })
    }

    var nextCampaignClass: Int {
        (1 ... 30).first { bestCampaignRatings[$0] == nil } ?? 31
    }

    var isGrandChampion: Bool { nextCampaignClass == 31 }

    var isPerfectShow: Bool {
        (1 ... 30).allSatisfy { bestCampaignRatings[$0] == .radiant }
    }

    var radiantCount: Int {
        bestCampaignRatings.values.filter { $0 == .radiant }.count
    }

    mutating func recordCampaignRating(_ rating: FlowerShowRating, for classNumber: Int) -> Bool {
        guard (1 ... 30).contains(classNumber) else { return false }
        let previous = bestCampaignRatings[classNumber]
        if previous.map({ rating > $0 }) ?? true {
            bestCampaignRatings[classNumber] = rating
            return true
        }
        return false
    }

    /// Sanitises untrusted decoded progress before `GameModel` can resolve content from it.
    /// Valid values are preserved exactly. Invalid optional attempts/results are discarded;
    /// durable ratings and committed IDs are retained wherever their own domains are valid.
    /// The operation is deterministic and idempotent so a repaired file has one stable form.
    @discardableResult
    mutating func sanitiseDecodedState() -> Bool {
        let original = self

        bestCampaignRatings = bestCampaignRatings.filter {
            (1 ... FlowerShowContent.campaignClassCount).contains($0.key)
        }
        nextCircuitClass = min(
            Self.maximumCircuitClass,
            max(FlowerShowContent.circuitStartClass, nextCircuitClass)
        )

        if let attempt = activeAttempt, isValidActiveAttempt(attempt) == false {
            activeAttempt = nil
        }
        if let result = pendingResult, isValidPendingResult(result) == false {
            pendingResult = nil
        }

        // A completed result and a resumable attempt are mutually exclusive. Prefer the
        // already-committed result, which preserves the earned rating shown to the player.
        if pendingResult != nil {
            activeAttempt = nil
        }

        return self != original
    }

    mutating func validateActiveAttempt() {
        _ = sanitiseDecodedState()
    }

    private func isValidActiveAttempt(_ attempt: PersistedFlowerShowAttempt) -> Bool {
        guard attempt.contentVersion == FlowerShowContent.contentVersion,
              isValidActiveContext(attempt.context),
              committedAttemptIDs.contains(attempt.engine.attemptID) == false,
              attempt.engine.state.phase == .playing
                || (attempt.engine.state.phase == .lost && attempt.engine.canUndo),
              isValidEngine(attempt.engine, for: attempt.context.classNumber)
        else { return false }

        let resolved = FlowerShowContent.resolve(classNumber: attempt.context.classNumber)
        return resolved.scenario.scenarioID == attempt.engine.scenarioID
            && resolved.scenario.scenarioDigest == attempt.engine.scenarioDigest
    }

    /// Codable can construct board and transition values that the normal initialisers reject.
    /// Validate every persisted state that can become current through resume or Undo before any
    /// board subscript, reducer, solver or view reads it.
    private func isValidEngine(_ engine: FlowerShowEngine, for classNumber: Int) -> Bool {
        let scenario = FlowerShowContent.resolve(classNumber: classNumber).scenario
        guard isValidEngineState(engine.state, for: scenario),
              engine.lastTransition.map({
                  isValidTransition($0, for: scenario) && $0.stateAfter == engine.state
              }) ?? true
        else { return false }

        guard let undo = engine.undoSnapshot else { return true }
        return engine.didUseUndo == false
            && undo.state.phase == .playing
            && isValidEngineState(undo.state, for: scenario)
            && (undo.lastTransition.map({
                isValidTransition($0, for: scenario) && $0.stateAfter == undo.state
            }) ?? true)
    }

    private func isValidEngineState(
        _ state: FlowerShowState,
        for scenario: FlowerShowScenario
    ) -> Bool {
        let maximumBlooms = state.turnNumber.multipliedReportingOverflow(
            by: GameBoard.slotsPerRing
        )
        let maximumScore = state.turnNumber.multipliedReportingOverflow(
            by: 100 * GameBoard.slotsPerRing * GameBoard.slotsPerRing
        )
        guard state.board.hasValidDimensions,
              state.board.isStable,
              (0 ... scenario.moveBudget).contains(state.movesRemaining),
              (0 ... scenario.moveBudget).contains(state.turnNumber),
              state.movesRemaining + state.turnNumber == scenario.moveBudget,
              maximumBlooms.overflow == false,
              (0 ... maximumBlooms.partialValue).contains(state.blooms),
              maximumScore.overflow == false,
              (0 ... maximumScore.partialValue).contains(state.score),
              state.unbroken.current >= 0,
              state.unbroken.best >= state.unbroken.current,
              state.unbroken.best <= state.turnNumber,
              (0 ... scenario.objectives.harmonyCreditsPerRing).contains(state.harmonyCredits.inner),
              (0 ... scenario.objectives.harmonyCreditsPerRing).contains(state.harmonyCredits.middle),
              (0 ... scenario.objectives.harmonyCreditsPerRing).contains(state.harmonyCredits.outer),
              state.infectedSpokes.allSatisfy({
                  (0 ..< GameBoard.slotsPerRing).contains($0)
              }),
              (0 ... scenario.objectives.twinBloomTurns).contains(state.twinBloomTurns),
              state.bouquetKinds.rawValue & ~PetalKindMask.all.rawValue == 0,
              state.judgesOrderIndex >= 0,
              state.judgesOrderIndex <= scenario.objectives.judgesOrder.count
        else { return false }

        if scenario.objectives.bindweed == nil {
            guard state.infectedSpokes.isEmpty, state.bindweedCountdown == nil else { return false }
        } else if state.infectedSpokes.isEmpty {
            guard state.bindweedCountdown == nil else { return false }
        } else {
            guard let countdown = state.bindweedCountdown,
                  let spreadInterval = scenario.objectives.bindweed?.spreadInterval,
                  (1 ... spreadInterval).contains(countdown)
            else { return false }
        }

        return switch state.phase {
        case .playing:
            state.movesRemaining > 0 && state.isComplete(for: scenario) == false
        case .won:
            state.isComplete(for: scenario)
        case .lost:
            state.movesRemaining == 0 && state.isComplete(for: scenario) == false
        }
    }

    private func isValidTransition(
        _ transition: FlowerShowTransition,
        for scenario: FlowerShowScenario
    ) -> Bool {
        let validSpoke = { (spoke: Int) in
            (0 ..< GameBoard.slotsPerRing).contains(spoke)
        }
        return isValidEngineState(transition.stateBeforeFingerprint.state, for: scenario)
            && isValidEngineState(transition.stateAfter, for: scenario)
            && transition.phase == transition.stateAfter.phase
            && transition.blooms.allSatisfy { validSpoke($0.spoke) }
            && transition.clearedBindweedSpokes.allSatisfy(validSpoke)
            && transition.spreadSourceSpoke.map(validSpoke) ?? true
            && transition.newlyInfectedSpoke.map(validSpoke) ?? true
    }

    private func isValidActiveContext(_ context: FlowerShowAttemptContext) -> Bool {
        switch context.kind {
        case .campaign:
            return (1 ... FlowerShowContent.campaignClassCount).contains(context.classNumber)
                && bestCampaignRatings[context.classNumber] == nil
                && context.classNumber == nextCampaignClass
        case .replay:
            return (1 ... FlowerShowContent.campaignClassCount).contains(context.classNumber)
                && bestCampaignRatings[context.classNumber] != nil
        case .circuit:
            return isGrandChampion
                && context.classNumber == nextCircuitClass
                && context.classNumber <= Self.maximumCircuitClass
        }
    }

    private func isValidPendingResult(_ result: FlowerShowResultSummary) -> Bool {
        guard committedAttemptIDs.contains(result.attemptID),
              result.movesUsed >= 0,
              result.radiantPar > 0
        else { return false }

        switch result.context.kind {
        case .campaign, .replay:
            guard (1 ... FlowerShowContent.campaignClassCount).contains(result.context.classNumber),
                  let bestRating = bestCampaignRatings[result.context.classNumber],
                  bestRating >= result.rating
            else { return false }
        case .circuit:
            guard isGrandChampion,
                  result.context.classNumber >= FlowerShowContent.circuitStartClass,
                  result.context.classNumber < nextCircuitClass
            else { return false }
        }

        return switch result.milestone {
        case .rosette:
            result.context.kind == .campaign && result.context.classNumber.isMultiple(of: 5)
        case .grandChampion:
            result.context.kind == .campaign
                && result.context.classNumber == FlowerShowContent.campaignClassCount
        case .circuitCup:
            result.context.kind == .circuit
        case .perfectShow, nil:
            true
        }
    }
}

enum GameProgressLoadOutcome: Equatable, Sendable {
    case fresh
    case loaded(GameProgress)
    case migrated(GameProgress, backupURL: URL)
    case repaired(GameProgress, backupURL: URL)
    case failed(message: String)

    var progress: GameProgress {
        switch self {
        case .fresh, .failed: .fresh
        case let .loaded(progress), let .migrated(progress, _), let .repaired(progress, _): progress
        }
    }
}

enum GameProgressSaveOutcome: Equatable, Sendable {
    case notAttempted
    case saved
    case failed(message: String)
}
