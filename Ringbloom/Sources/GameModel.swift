import Combine
import Foundation

@MainActor
final class GameModel: ObservableObject {
    @Published private var gardenEngine = GameEngine(seed: 1)
    @Published private var flowerShowEngine = FlowerShowEngine(
        scenario: FlowerShowContent.resolve(classNumber: 1).scenario
    )
    @Published private(set) var activeMode: GameMode
    @Published private(set) var bestScore: Int
    @Published private(set) var highestGarden: Int
    @Published private(set) var hasActiveGarden = false
    @Published private(set) var globalBestStreak: Int
    @Published private(set) var radiantGardens: Set<Int>
    @Published private(set) var flowerShowIntroduced: Bool
    @Published private(set) var completedFlowerShowClasses: Set<Int>
    @Published private(set) var currentFlowerShowClass: Int
    @Published private(set) var hasActiveFlowerShow = false
    @Published private(set) var seenFlowerShowIntroductionIDs: Set<String>
    @Published private(set) var grandChampionAchieved: Bool
    @Published private(set) var bestCampaignRatings: [Int: FlowerShowRating]
    @Published private(set) var nextCircuitClass: Int
    @Published private(set) var pendingFlowerShowResult: FlowerShowResultSummary?
    @Published private(set) var pendingFlowerShowNoticeVersion: Int?
    @Published private(set) var flowerShowHintMove: GameMove?
    @Published private(set) var flowerShowHintStatus: FlowerShowHintResult?
    @Published private(set) var reviewRequestState: ReviewRequestState
    @Published private(set) var reviewRequestTrigger: Int?

    let launchMode: GameLaunchMode

    private let progressStore: any GameProgressStoring
    private let baseSeed: UInt64
    private var currentGardenSeed: UInt64 = 1
    private let currentDate: () -> Date
    private let appVersion: String
    private let hintSolver: any FlowerShowHintSolving
    private let flowerShowAccess: any FlowerShowAccessProviding
    private var flowerShowProgress: FlowerShowProgressV3
    private var flowerShowAttemptContext = FlowerShowAttemptContext(kind: .campaign, classNumber: 1)
    private var hintTask: Task<Void, Never>? = nil

    private var flowerShowResolvedClass: ResolvedFlowerShowClass {
        FlowerShowContent.resolve(classNumber: flowerShowAttemptContext.classNumber)
    }

    var board: GameBoard {
        activeMode == .garden ? gardenEngine.board : flowerShowEngine.state.board
    }

    var selectedRing: Ring {
        activeMode == .garden ? gardenEngine.selectedRing : flowerShowEngine.state.selectedRing
    }

    var score: Int {
        activeMode == .garden ? gardenEngine.score : flowerShowEngine.state.score
    }

    var garden: Int { gardenEngine.garden }

    var blooms: Int {
        activeMode == .garden ? gardenEngine.blooms : flowerShowEngine.state.blooms
    }

    var targetBlooms: Int {
        activeMode == .garden ? gardenEngine.targetBlooms : flowerShowResolvedClass.scenario.targetBlooms
    }

    var movesRemaining: Int {
        activeMode == .garden ? gardenEngine.movesRemaining : flowerShowEngine.state.movesRemaining
    }

    var phase: GamePhase {
        activeMode == .garden ? gardenEngine.phase : flowerShowEngine.state.phase
    }

    var lastTurn: TurnResult? {
        if activeMode == .garden { return gardenEngine.lastTurn }
        guard let transition = flowerShowEngine.lastTransition else { return nil }
        let state = transition.stateAfter
        return TurnResult(
            turnNumber: state.turnNumber,
            ring: transition.ring,
            direction: transition.direction,
            bloomSpokes: transition.bloomSpokes,
            combo: transition.bloomCount,
            streak: state.unbroken.current,
            streakBonus: 0,
            points: transition.bloomCount * 100,
            phase: transition.phase,
            didReshuffle: transition.didReshuffle
        )
    }

    var suggestedMove: GameMove? {
        if activeMode == .garden { return gardenEngine.suggestedMove }
        if let flowerShowHintMove { return flowerShowHintMove }
        return FlowerShowExactSolver.shortestRoute(
            from: flowerShowEngine.state,
            scenario: flowerShowResolvedClass.scenario
        )?.moves.first
    }

    var streak: Int {
        activeMode == .garden ? gardenEngine.streak : flowerShowEngine.state.unbroken.current
    }

    var bestStreak: Int {
        activeMode == .garden ? gardenEngine.bestStreak : flowerShowEngine.state.unbroken.best
    }

    var hintsRemaining: Int {
        activeMode == .garden ? gardenEngine.hintsRemaining : (flowerShowEngine.hintRemaining ? 1 : 0)
    }

    var hintsUsed: Int {
        activeMode == .garden ? gardenEngine.hintsUsed : (flowerShowEngine.didUseHint ? 1 : 0)
    }

    var completionBonus: Int {
        activeMode == .garden ? gardenEngine.completionBonus : 0
    }

    var gardenRating: GardenRating {
        guard activeMode == .flowerShow else { return gardenEngine.gardenRating }
        return switch flowerShowEngine.earnedRating(for: flowerShowResolvedClass.scenario) {
        case .seedling: .seedling
        case .flourishing: .flourishing
        case .radiant: .radiant
        }
    }

    var flowerShowRating: FlowerShowRating {
        flowerShowEngine.earnedRating(for: flowerShowResolvedClass.scenario)
    }

    var bestAvailableFlowerShowRating: FlowerShowRating {
        flowerShowEngine.bestAvailableRating(for: flowerShowResolvedClass.scenario)
    }

    var harmonyCredits: RingCredits { flowerShowEngine.state.harmonyCredits }
    var harmonyRings: Set<Ring> {
        Set(Ring.allCases.filter { flowerShowEngine.state.harmonyCredits[$0] > 0 })
    }
    var infectedSpokes: Set<Int> {
        activeMode == .garden ? [] : flowerShowEngine.state.infectedSpokes
    }
    var bindweedSpreadCountdown: Int? {
        activeMode == .garden ? nil : flowerShowEngine.state.bindweedCountdown
    }
    var bindweedSpreadPreview: BindweedSpreadPreview? {
        guard activeMode == .flowerShow,
              flowerShowEngine.state.bindweedCountdown == 1,
              let spread = FlowerShowReducer.bindweedSpread(from: flowerShowEngine.state.infectedSpokes)
        else { return nil }
        return BindweedSpreadPreview(source: spread.source, destination: spread.destination)
    }
    var twinBloomTurns: Int { flowerShowEngine.state.twinBloomTurns }
    var twinBloomCompleted: Bool {
        flowerShowEngine.state.twinBloomTurns >= flowerShowResolvedClass.scenario.objectives.twinBloomTurns
    }
    var bouquetKinds: PetalKindMask { flowerShowEngine.state.bouquetKinds }
    var judgesOrderIndex: Int { flowerShowEngine.state.judgesOrderIndex }
    var nextJudgesOrderRing: Ring? {
        let order = flowerShowResolvedClass.scenario.objectives.judgesOrder
        return judgesOrderIndex < order.count ? order[judgesOrderIndex] : nil
    }
    var unfinishedHarmonyRings: Set<Ring> {
        let requirement = flowerShowResolvedClass.scenario.objectives.harmonyCreditsPerRing
        return Set(Ring.allCases.filter { flowerShowEngine.state.harmonyCredits[$0] < requirement })
    }
    var objectivesComplete: Bool {
        activeMode == .garden || flowerShowEngine.state.objectivesComplete(for: flowerShowResolvedClass.scenario)
    }
    var canUndo: Bool { activeMode == .flowerShow && flowerShowEngine.canUndo }
    var didUseUndo: Bool { activeMode == .flowerShow && flowerShowEngine.didUseUndo }
    var flowerShowQualified: Bool {
        FlowerShowAccessPolicy.isQualified(highestGarden: highestGarden)
    }
    var canPlayCurrentFlowerShow: Bool {
        activeMode != .flowerShow
            || flowerShowAccessAction(for: flowerShowAttemptContext.classNumber) == .play
    }
    var flowerShowDefinition: FlowerShowClassDefinition {
        .classNumber(flowerShowAttemptContext.classNumber)
    }
    var currentFlowerShowAttemptKind: FlowerShowAttemptKind { flowerShowAttemptContext.kind }
    var savedFlowerShowAttemptContext: FlowerShowAttemptContext? {
        flowerShowProgress.activeAttempt?.context
    }
    var lastFlowerShowTransition: FlowerShowTransition? {
        activeMode == .flowerShow ? flowerShowEngine.lastTransition : nil
    }
    var nextIncompleteCampaignClass: Int { flowerShowProgress.nextCampaignClass }
    var perfectShowAchieved: Bool { flowerShowProgress.isPerfectShow }
    var radiantClassCount: Int { flowerShowProgress.radiantCount }

    func flowerShowAccessAction(for classNumber: Int) -> FlowerShowAccessAction {
        let requested = max(1, classNumber)
        return FlowerShowAccessPolicy.tileAction(
            highestGarden: highestGarden,
            accessState: flowerShowAccess.accessState,
            classNumber: requested,
            progressionAllowed: flowerShowProgressionAllows(requested)
        )
    }

    func flowerShowProgressionAllows(_ classNumber: Int) -> Bool {
        let requested = max(1, classNumber)
        if requested <= FlowerShowClassDefinition.classCount {
            return flowerShowProgress.bestCampaignRatings[requested] != nil
                || requested == flowerShowProgress.nextCampaignClass
        }
        return flowerShowProgress.isGrandChampion
            && requested == flowerShowProgress.nextCircuitClass
    }

    func flowerShowAttemptKind(for classNumber: Int) -> FlowerShowAttemptKind {
        if classNumber > 30 { return .circuit }
        return flowerShowProgress.bestCampaignRatings[classNumber] == nil ? .campaign : .replay
    }

    func savedFlowerShowAttemptWouldBeReplaced(by classNumber: Int) -> FlowerShowAttemptContext? {
        guard let saved = flowerShowProgress.activeAttempt?.context else { return nil }
        let requestedKind = flowerShowAttemptKind(for: classNumber)
        return saved.classNumber == classNumber && saved.kind == requestedKind ? nil : saved
    }

    var remainingFlowerShowWork: [String] {
        guard activeMode == .flowerShow else { return [] }
        let scenario = flowerShowResolvedClass.scenario
        let objectives = scenario.objectives
        var parts: [String] = []
        let remainingBlooms = max(0, scenario.targetBlooms - flowerShowEngine.state.blooms)
        if remainingBlooms > 0 {
            parts.append("\(remainingBlooms) \(remainingBlooms == 1 ? "bloom" : "blooms")")
        }
        if objectives.harmonyCreditsPerRing > 0 {
            for ring in Ring.allCases {
                let remaining = max(0, objectives.harmonyCreditsPerRing - harmonyCredits[ring])
                if remaining > 0 {
                    parts.append(
                        objectives.harmonyCreditsPerRing == 1
                            ? "\(ring.displayName) Harmony"
                            : "\(remaining) \(ring.displayName) Harmony"
                    )
                }
            }
        }
        if let required = objectives.unbrokenChain, bestStreak < required {
            parts.append("\(required)-turn Unbroken")
        }
        if objectives.bindweed != nil, infectedSpokes.isEmpty == false {
            parts.append("\(infectedSpokes.count) tangled \(infectedSpokes.count == 1 ? "spoke" : "spokes")")
        }
        let remainingTwins = max(0, objectives.twinBloomTurns - twinBloomTurns)
        if remainingTwins > 0 {
            parts.append("\(remainingTwins) Twin Bloom \(remainingTwins == 1 ? "turn" : "turns")")
        }
        let missingKinds = objectives.bouquetKinds.subtracting(bouquetKinds).kinds
        if missingKinds.isEmpty == false {
            parts.append(missingKinds.map(\.displayName).joined(separator: ", ") + " for the Bouquet")
        }
        if judgesOrderIndex < objectives.judgesOrder.count {
            parts.append("Judges' Order")
        }
        return parts
    }

    var seenFlowerShowIntroductions: Set<FlowerShowRule> {
        Set(FlowerShowRule.allCases.filter { seenFlowerShowIntroductionIDs.contains($0.rawValue) })
    }

    static func previewProgress(arguments: [String]) -> GameProgress {
        let normalizedArguments = arguments.map { $0.lowercased() }
        let hasExplicitPreviewClass = normalizedArguments.contains {
            $0.hasPrefix("--flower-show-class=")
        }
        let previewsFlowerShow = normalizedArguments.contains("--flower-show-unlocked")
            || normalizedArguments.contains("--flower-show-access=full-purchase")
            || normalizedArguments.contains("--flower-show-access=legacy")
            || normalizedArguments.contains("--flower-show-access=sample")
            || hasExplicitPreviewClass
            || normalizedArguments.contains { $0.hasPrefix("--screenshot-flower-show") }
            || normalizedArguments.contains("--screenshot-champion-home")
        let previewsReviewTiming = normalizedArguments.contains("--screenshot-review-timing")
        let previewClass = normalizedArguments.lazy.compactMap { argument -> Int? in
            guard argument.hasPrefix("--flower-show-class=") else { return nil }
            return Int(argument.dropFirst("--flower-show-class=".count))
        }.first ?? (normalizedArguments.contains("--screenshot-champion-home") ? 31 : 1)
        let savedFlowerShowClass = normalizedArguments.lazy.compactMap { argument -> Int? in
            guard argument.hasPrefix("--flower-show-saved-class=") else { return nil }
            return Int(argument.dropFirst("--flower-show-saved-class=".count))
        }.first

        let previewProgress: GameProgress
        if previewsReviewTiming {
            previewProgress = GameProgress(
                bestScore: 0,
                highestGarden: 2,
                reviewRequestState: ReviewRequestState(successfulGardenCompletions: 1)
            )
        } else {
            let completedThrough = min(30, max(0, previewClass - 1))
            let ratings: [Int: FlowerShowRating] = completedThrough == 0
                ? [:]
                : Dictionary(uniqueKeysWithValues: (1 ... completedThrough).map { ($0, .seedling) })
            let activeAttempt = savedFlowerShowClass.map { classNumber in
                let scenario = FlowerShowContent.resolve(classNumber: classNumber).scenario
                return PersistedFlowerShowAttempt(
                    contentVersion: FlowerShowContent.contentVersion,
                    context: FlowerShowAttemptContext(
                        kind: ratings[classNumber] == nil ? .campaign : .replay,
                        classNumber: classNumber
                    ),
                    engine: FlowerShowEngine(scenario: scenario)
                )
            }
            previewProgress = GameProgress(
                bestScore: 0,
                highestGarden: previewsFlowerShow ? 11 : 1,
                flowerShowProgress: FlowerShowProgressV3(
                    bestCampaignRatings: ratings,
                    nextCircuitClass: max(31, previewClass),
                    activeAttempt: activeAttempt,
                    pendingNoticeVersion: normalizedArguments.contains("--flower-show-v3-migration-notice") ? 3 : nil
                )
            )
        }
        return previewProgress
    }

    convenience init() {
        let mode = GameLaunchMode.current
        let arguments = ProcessInfo.processInfo.arguments.map { $0.lowercased() }
        let previewProgress = Self.previewProgress(arguments: arguments)

        switch mode {
        case .production:
            self.init(launchMode: mode, progressStore: FileGameProgressStore())
        case .uiTest, .screenshot:
            self.init(
                launchMode: mode,
                progressStore: InMemoryGameProgressStore(progress: previewProgress)
            )
        }
    }

    convenience init(seed: UInt64) {
        self.init(
            launchMode: .uiTest(seed: seed),
            progressStore: InMemoryGameProgressStore()
        )
    }

    convenience init(seed: UInt64, progressStore: any GameProgressStoring) {
        self.init(launchMode: .uiTest(seed: seed), progressStore: progressStore)
    }

    init(
        launchMode: GameLaunchMode,
        progressStore: any GameProgressStoring,
        currentDate: @escaping () -> Date = Date.init,
        appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
        hintSolver: any FlowerShowHintSolving = ExactFlowerShowHintSolver(),
        flowerShowAccess: any FlowerShowAccessProviding = SampleOnlyFlowerShowAccessProvider()
    ) {
        self.launchMode = launchMode
        self.progressStore = progressStore
        self.currentDate = currentDate
        self.appVersion = appVersion
        self.hintSolver = hintSolver
        self.flowerShowAccess = flowerShowAccess
        let resolvedBaseSeed = launchMode.deterministicSeed
            ?? UInt64.random(in: UInt64.min ... UInt64.max)
        baseSeed = resolvedBaseSeed

        let persisted = progressStore.load()
        bestScore = max(0, persisted.bestScore)
        highestGarden = max(1, persisted.highestGarden)
        globalBestStreak = max(0, persisted.globalBestStreak)
        radiantGardens = Set(persisted.radiantGardens.filter { $0 > 0 })
        let loadedFlowerShowProgress = persisted.flowerShowProgress
        let loadedCompletedClasses = loadedFlowerShowProgress.completedCampaignClasses
        let loadedGrandChampion = loadedFlowerShowProgress.isGrandChampion
        flowerShowProgress = loadedFlowerShowProgress
        bestCampaignRatings = loadedFlowerShowProgress.bestCampaignRatings
        completedFlowerShowClasses = loadedCompletedClasses
        nextCircuitClass = loadedFlowerShowProgress.nextCircuitClass
        grandChampionAchieved = loadedGrandChampion
        currentFlowerShowClass = loadedGrandChampion
            ? loadedFlowerShowProgress.nextCircuitClass
            : loadedFlowerShowProgress.nextCampaignClass
        flowerShowIntroduced = loadedCompletedClasses.isEmpty == false
            || loadedFlowerShowProgress.activeAttempt != nil
        seenFlowerShowIntroductionIDs = Set(loadedFlowerShowProgress.seenIntroductions.map(\.rawValue))
        pendingFlowerShowResult = loadedFlowerShowProgress.pendingResult
        pendingFlowerShowNoticeVersion = loadedFlowerShowProgress.pendingNoticeVersion
        reviewRequestState = persisted.reviewRequestState
        reviewRequestTrigger = nil
        flowerShowHintMove = nil
        flowerShowHintStatus = nil
        activeMode = .garden

        if case .production = launchMode,
           let activeGame = persisted.activeGame,
           activeGame.phase == .playing,
           let activeGardenSeed = persisted.activeGardenSeed
        {
            currentGardenSeed = activeGardenSeed
            gardenEngine = activeGame
            hasActiveGarden = true
            bestScore = max(bestScore, activeGame.score)
            highestGarden = max(highestGarden, activeGame.garden)
            globalBestStreak = max(globalBestStreak, activeGame.bestStreak)
        } else {
            currentGardenSeed = Self.seed(baseSeed: resolvedBaseSeed, garden: highestGarden)
            gardenEngine = GameEngine(seed: currentGardenSeed, garden: highestGarden)
            hasActiveGarden = false
        }

        if let activeAttempt = flowerShowProgress.activeAttempt {
            flowerShowAttemptContext = activeAttempt.context
            flowerShowEngine = activeAttempt.engine
            currentFlowerShowClass = activeAttempt.context.classNumber
            hasActiveFlowerShow = true
        } else {
            flowerShowAttemptContext = FlowerShowAttemptContext(
                kind: currentFlowerShowClass > 30 ? .circuit : .campaign,
                classNumber: currentFlowerShowClass
            )
            flowerShowEngine = FlowerShowEngine(
                scenario: FlowerShowContent.resolve(classNumber: currentFlowerShowClass).scenario
            )
            hasActiveFlowerShow = false
        }
    }

    func select(_ ring: Ring) {
        switch activeMode {
        case .garden:
            gardenEngine.select(ring)
        case .flowerShow:
            guard canPlayCurrentFlowerShow else { return }
            cancelHintWork()
            flowerShowEngine.select(ring)
            hasActiveFlowerShow = phase == .playing
        }
        persistProgress()
        if activeMode == .flowerShow { scheduleFlowerShowHintPrewarm() }
    }

    func selectRing(_ ring: Ring) {
        select(ring)
    }

    @discardableResult
    func requestHint() -> GameMove? {
        guard activeMode == .garden else { return nil }
        let move = gardenEngine.requestHint()
        if move != nil { hasActiveGarden = true }
        persistProgress()
        return move
    }

    func requestFlowerShowHint() async -> FlowerShowHintResult {
        guard activeMode == .flowerShow,
              canPlayCurrentFlowerShow,
              flowerShowEngine.state.phase == .playing,
              flowerShowEngine.hintRemaining
        else {
            return .cancelled
        }
        let attemptID = flowerShowEngine.attemptID
        let state = flowerShowEngine.state
        let scenario = flowerShowResolvedClass.scenario
        let request = FlowerShowHintRequest(
            attemptID: attemptID,
            state: state,
            scenario: scenario,
            preferredMaximumDepth: max(0, scenario.radiantPar - state.turnNumber)
        )
        let result = await hintSolver.solve(request)
        guard activeMode == .flowerShow,
              canPlayCurrentFlowerShow,
              flowerShowEngine.attemptID == attemptID,
              flowerShowEngine.state == state,
              flowerShowEngine.state.phase == .playing,
              flowerShowEngine.hintRemaining
        else {
            flowerShowHintStatus = .cancelled
            return .cancelled
        }
        flowerShowHintStatus = result
        if case let .move(move, _) = result {
            flowerShowEngine.consumeHint()
            flowerShowHintMove = move
            persistProgress()
        }
        return result
    }

    @discardableResult
    func rotate(_ direction: RotationDirection) -> TurnResult? {
        switch activeMode {
        case .garden:
            guard let result = gardenEngine.rotate(direction) else { return nil }
            bestScore = max(bestScore, gardenEngine.score)
            globalBestStreak = max(globalBestStreak, gardenEngine.bestStreak)
            if gardenEngine.phase == .won {
                highestGarden = max(highestGarden, gardenEngine.garden + 1)
                if gardenEngine.gardenRating == .radiant {
                    radiantGardens.insert(gardenEngine.garden)
                }
                ReviewRequestPolicy.registerSuccessfulGarden(state: &reviewRequestState)
                if ReviewRequestPolicy.isEligible(
                    state: reviewRequestState,
                    now: currentDate(),
                    appVersion: appVersion
                ) {
                    reviewRequestTrigger = (reviewRequestTrigger ?? 0) + 1
                }
            }
            hasActiveGarden = gardenEngine.phase == .playing
            persistProgress()
            return result

        case .flowerShow:
            guard canPlayCurrentFlowerShow else { return nil }
            cancelHintWork()
            let scenario = flowerShowResolvedClass.scenario
            guard let transition = flowerShowEngine.rotate(direction, scenario: scenario) else {
                return nil
            }
            flowerShowHintMove = nil
            flowerShowHintStatus = nil
            if flowerShowEngine.state.phase == .won {
                commitFlowerShowWin(scenario: scenario)
            } else {
                hasActiveFlowerShow = flowerShowEngine.state.phase == .playing
                    || (flowerShowEngine.state.phase == .lost && flowerShowEngine.canUndo)
            }
            persistProgress()
            if flowerShowEngine.state.phase == .playing {
                scheduleFlowerShowHintPrewarm()
            }
            return TurnResult(
                turnNumber: transition.stateAfter.turnNumber,
                ring: transition.ring,
                direction: transition.direction,
                bloomSpokes: transition.bloomSpokes,
                combo: transition.bloomCount,
                streak: transition.stateAfter.unbroken.current,
                streakBonus: 0,
                points: transition.bloomCount * 100,
                phase: transition.phase,
                didReshuffle: transition.didReshuffle
            )
        }
    }

    @discardableResult
    func retry() -> FlowerShowStartResult {
        switch activeMode {
        case .garden:
            gardenEngine = GameEngine(seed: currentGardenSeed, garden: gardenEngine.garden)
            hasActiveGarden = true
            persistProgress()
            return .started
        case .flowerShow:
            let action = FlowerShowAccessPolicy.action(
                highestGarden: highestGarden,
                accessState: flowerShowAccess.accessState,
                classNumber: flowerShowAttemptContext.classNumber,
                progressionAllowed: true
            )
            guard action == .play else { return FlowerShowStartResult(action: action) }
            cancelHintWork()
            flowerShowEngine = FlowerShowEngine(scenario: flowerShowResolvedClass.scenario)
            hasActiveFlowerShow = true
        }
        persistProgress()
        if activeMode == .flowerShow { scheduleFlowerShowHintPrewarm() }
        return .started
    }

    func nextGarden() {
        guard activeMode == .garden, phase == .won else { return }
        startGarden(gardenEngine.garden + 1)
    }

    /// Creates a terminal premium-Class fixture only for deterministic screenshot/UI-test runs.
    /// This lets the UI suite prove the result-screen retry gate after access has been lost,
    /// a state that cannot be launched through a production user path without real StoreKit.
    @discardableResult
    func preparePremiumFlowerShowRetryFixture(classNumber: Int) -> Bool {
        guard launchMode.isDeterministic,
              classNumber > FlowerShowAccessPolicy.freeClasses.upperBound
        else { return false }

        cancelHintWork()
        let resolved = FlowerShowContent.resolve(classNumber: classNumber)
        highestGarden = max(highestGarden, FlowerShowAccessPolicy.qualifyingGardenWins + 1)
        activeMode = .flowerShow
        flowerShowAttemptContext = FlowerShowAttemptContext(
            kind: classNumber > 30 ? .circuit : .campaign,
            classNumber: classNumber
        )
        currentFlowerShowClass = classNumber
        flowerShowEngine = FlowerShowEngine(scenario: resolved.scenario)

        var safety = 0
        while flowerShowEngine.state.phase == .playing, safety < 64 {
            let quietMove = Ring.allCases
                .flatMap { ring in
                    RotationDirection.allCases.map { GameMove(ring: ring, direction: $0) }
                }
                .first {
                    flowerShowEngine.state.board.rotated($0.ring, direction: $0.direction)
                        .bloomSpokes.isEmpty
                }
            guard let quietMove else { return false }
            flowerShowEngine.select(quietMove.ring)
            _ = flowerShowEngine.rotate(quietMove.direction, scenario: resolved.scenario)
            safety += 1
        }
        hasActiveFlowerShow = flowerShowEngine.state.phase == .playing || flowerShowEngine.canUndo
        return flowerShowEngine.state.phase == .lost
    }

    /// Completes an authored Class through the synchronous exact solver for deterministic
    /// screenshot/UI-test launches. It deliberately avoids the cached asynchronous hint path.
    @discardableResult
    func prepareFlowerShowWinFixture(classNumber: Int, asReplay: Bool = false) -> Bool {
        let accessAction = flowerShowAccessAction(for: classNumber)
        guard launchMode.isDeterministic,
              accessAction == .play || (asReplay && accessAction == .waitForAccess)
        else { return false }

        cancelHintWork()
        let resolved = FlowerShowContent.resolve(classNumber: classNumber)
        if asReplay, flowerShowProgress.bestCampaignRatings[classNumber] == nil {
            flowerShowProgress.bestCampaignRatings[classNumber] = .seedling
            bestCampaignRatings = flowerShowProgress.bestCampaignRatings
            completedFlowerShowClasses = flowerShowProgress.completedCampaignClasses
        }
        activeMode = .flowerShow
        flowerShowAttemptContext = FlowerShowAttemptContext(
            kind: asReplay ? .replay : flowerShowAttemptKind(for: classNumber),
            classNumber: classNumber
        )
        currentFlowerShowClass = classNumber
        flowerShowIntroduced = true
        flowerShowEngine = FlowerShowEngine(scenario: resolved.scenario)
        guard let solution = FlowerShowExactSolver.shortestRoute(
            from: flowerShowEngine.state,
            scenario: resolved.scenario
        ) else { return false }

        for move in solution.moves where flowerShowEngine.state.phase == .playing {
            flowerShowEngine.select(move.ring)
            _ = flowerShowEngine.rotate(move.direction, scenario: resolved.scenario)
        }
        guard flowerShowEngine.state.phase == .won else { return false }
        commitFlowerShowWin(scenario: resolved.scenario)
        hasActiveFlowerShow = false
        persistProgress()
        return pendingFlowerShowResult != nil
    }

    func startGarden(_ garden: Int? = nil) {
        activeMode = .garden
        let requestedGarden = max(1, garden ?? gardenEngine.garden)
        currentGardenSeed = Self.seed(baseSeed: baseSeed, garden: requestedGarden)
        gardenEngine = GameEngine(seed: currentGardenSeed, garden: requestedGarden)
        hasActiveGarden = true
        highestGarden = max(highestGarden, requestedGarden)
        persistProgress()
    }

    func resumeGarden() {
        activeMode = .garden
    }

    func introduceFlowerShow() {
        guard flowerShowQualified else { return }
    }

    @discardableResult
    func startFlowerShowClass(_ classNumber: Int? = nil) -> FlowerShowStartResult {
        guard flowerShowQualified else { return .qualificationRequired }
        let requested = max(1, classNumber ?? currentFlowerShowClass)
        let progressionAllowed: Bool
        if requested <= 30 {
            progressionAllowed = flowerShowProgress.bestCampaignRatings[requested] != nil
                || requested == flowerShowProgress.nextCampaignClass
        } else {
            progressionAllowed = flowerShowProgress.isGrandChampion
                && requested == flowerShowProgress.nextCircuitClass
        }
        let action = FlowerShowAccessPolicy.action(
            highestGarden: highestGarden,
            accessState: flowerShowAccess.accessState,
            classNumber: requested,
            progressionAllowed: progressionAllowed
        )
        guard action == .play else { return FlowerShowStartResult(action: action) }
        let kind: FlowerShowAttemptKind
        if requested > 30 {
            kind = .circuit
        } else if flowerShowProgress.bestCampaignRatings[requested] != nil {
            kind = .replay
        } else {
            kind = .campaign
        }
        return startFlowerShowAttempt(classNumber: requested, kind: kind)
    }

    @discardableResult
    func startFlowerShowReplay(_ classNumber: Int) -> FlowerShowStartResult {
        guard flowerShowProgress.bestCampaignRatings[classNumber] != nil else { return .progressionLocked }
        let action = FlowerShowAccessPolicy.action(
            highestGarden: highestGarden,
            accessState: flowerShowAccess.accessState,
            classNumber: classNumber,
            progressionAllowed: true
        )
        guard action == .play else { return FlowerShowStartResult(action: action) }
        return startFlowerShowAttempt(classNumber: classNumber, kind: .replay)
    }

    @discardableResult
    func resumeFlowerShow() -> FlowerShowStartResult {
        guard flowerShowQualified, hasActiveFlowerShow else { return .progressionLocked }
        let action = FlowerShowAccessPolicy.action(
            highestGarden: highestGarden,
            accessState: flowerShowAccess.accessState,
            classNumber: flowerShowAttemptContext.classNumber,
            progressionAllowed: true
        )
        guard action == .play else { return FlowerShowStartResult(action: action) }
        activeMode = .flowerShow
        scheduleFlowerShowHintPrewarm()
        return .started
    }

    @discardableResult
    func nextFlowerShowClass() -> FlowerShowStartResult {
        guard activeMode == .flowerShow, phase == .won else { return .progressionLocked }
        let next = currentFlowerShowClass
        let action = FlowerShowAccessPolicy.action(
            highestGarden: highestGarden,
            accessState: flowerShowAccess.accessState,
            classNumber: next,
            progressionAllowed: true
        )
        if action == .purchaseRequired {
            dismissPendingFlowerShowResult()
            return .purchaseRequired
        }
        guard action == .play else { return FlowerShowStartResult(action: action) }
        dismissPendingFlowerShowResult()
        return startFlowerShowAttempt(
            classNumber: next,
            kind: next > 30 ? .circuit : .campaign
        )
    }

    @discardableResult
    func undoFlowerShowTurn() -> Bool {
        guard activeMode == .flowerShow, canPlayCurrentFlowerShow else { return false }
        cancelHintWork()
        guard flowerShowEngine.useUndo() else { return false }
        flowerShowHintMove = nil
        flowerShowHintStatus = nil
        hasActiveFlowerShow = true
        persistProgress()
        scheduleFlowerShowHintPrewarm()
        return true
    }

    func dismissPendingFlowerShowResult() {
        flowerShowProgress.pendingResult = nil
        pendingFlowerShowResult = nil
        persistProgress()
    }

    func dismissFlowerShowRedesignNotice() {
        flowerShowProgress.pendingNoticeVersion = nil
        pendingFlowerShowNoticeVersion = nil
        persistProgress()
    }

    func commitReviewRequestAttempt(trigger: Int) -> Bool {
        guard reviewRequestTrigger == trigger,
              activeMode == .garden,
              phase == .won,
              ReviewRequestPolicy.recordAttemptIfEligible(
                  state: &reviewRequestState,
                  now: currentDate(),
                  appVersion: appVersion
              )
        else { return false }
        reviewRequestTrigger = nil
        persistProgress()
        return true
    }

    @discardableResult
    private func startFlowerShowAttempt(classNumber: Int, kind: FlowerShowAttemptKind) -> FlowerShowStartResult {
        let action = FlowerShowAccessPolicy.action(
            highestGarden: highestGarden,
            accessState: flowerShowAccess.accessState,
            classNumber: classNumber,
            progressionAllowed: true
        )
        guard action == .play else { return FlowerShowStartResult(action: action) }
        cancelHintWork()
        let resolved = FlowerShowContent.resolve(classNumber: classNumber)
        activeMode = .flowerShow
        flowerShowAttemptContext = FlowerShowAttemptContext(kind: kind, classNumber: classNumber)
        currentFlowerShowClass = classNumber
        flowerShowIntroduced = true
        if let introduction = FlowerShowClassDefinition.classNumber(classNumber).introductionID {
            flowerShowProgress.seenIntroductions.insert(introduction)
        }
        seenFlowerShowIntroductionIDs = Set(flowerShowProgress.seenIntroductions.map(\.rawValue))
        flowerShowEngine = FlowerShowEngine(scenario: resolved.scenario)
        flowerShowHintMove = nil
        flowerShowHintStatus = nil
        hasActiveFlowerShow = true
        persistProgress()
        scheduleFlowerShowHintPrewarm()
        return .started
    }

    private func commitFlowerShowWin(scenario: FlowerShowScenario) {
        guard flowerShowProgress.committedAttemptIDs.contains(flowerShowEngine.attemptID) == false else {
            return
        }
        let wasPerfect = flowerShowProgress.isPerfectShow
        let wasGrandChampion = flowerShowProgress.isGrandChampion
        let context = flowerShowAttemptContext
        let rating = flowerShowEngine.earnedRating(for: scenario)
        var isNewBest = false
        var milestone: FlowerShowMilestone?

        switch context.kind {
        case .campaign:
            isNewBest = flowerShowProgress.recordCampaignRating(rating, for: context.classNumber)
            if context.classNumber.isMultiple(of: 5) { milestone = .rosette }
            if context.classNumber == 30, wasGrandChampion == false { milestone = .grandChampion }
        case .replay:
            isNewBest = flowerShowProgress.recordCampaignRating(rating, for: context.classNumber)
        case .circuit:
            if context.classNumber == flowerShowProgress.nextCircuitClass {
                flowerShowProgress.nextCircuitClass = min(
                    FlowerShowProgressV3.maximumCircuitClass,
                    context.classNumber + 1
                )
            }
            if (context.classNumber - 30).isMultiple(of: 8) { milestone = .circuitCup }
        }

        if wasPerfect == false, flowerShowProgress.isPerfectShow {
            milestone = .perfectShow
        }

        flowerShowProgress.committedAttemptIDs.insert(flowerShowEngine.attemptID)
        let summary = FlowerShowResultSummary(
            attemptID: flowerShowEngine.attemptID,
            context: context,
            rating: rating,
            movesUsed: flowerShowEngine.state.turnNumber,
            radiantPar: scenario.radiantPar,
            didUseHint: flowerShowEngine.didUseHint,
            didUseUndo: flowerShowEngine.didUseUndo,
            isNewBest: isNewBest,
            milestone: milestone
        )
        flowerShowProgress.activeAttempt = nil
        flowerShowProgress.pendingResult = summary
        pendingFlowerShowResult = summary
        bestCampaignRatings = flowerShowProgress.bestCampaignRatings
        completedFlowerShowClasses = flowerShowProgress.completedCampaignClasses
        nextCircuitClass = flowerShowProgress.nextCircuitClass
        grandChampionAchieved = flowerShowProgress.isGrandChampion
        if context.kind == .circuit {
            currentFlowerShowClass = flowerShowProgress.nextCircuitClass
        } else if context.kind == .campaign {
            currentFlowerShowClass = flowerShowProgress.isGrandChampion
                ? flowerShowProgress.nextCircuitClass
                : flowerShowProgress.nextCampaignClass
        }
        hasActiveFlowerShow = false
    }

    private func cancelHintWork() {
        hintTask?.cancel()
        hintTask = nil
        flowerShowHintMove = nil
        flowerShowHintStatus = nil
    }

    private func scheduleFlowerShowHintPrewarm() {
        cancelHintWork()
        guard activeMode == .flowerShow,
              flowerShowEngine.state.phase == .playing,
              flowerShowEngine.hintRemaining
        else { return }
        let request = FlowerShowHintRequest(
            attemptID: flowerShowEngine.attemptID,
            state: flowerShowEngine.state,
            scenario: flowerShowResolvedClass.scenario,
            preferredMaximumDepth: max(
                0,
                flowerShowResolvedClass.scenario.radiantPar - flowerShowEngine.state.turnNumber
            )
        )
        hintTask = Task { [hintSolver] in
            _ = await hintSolver.solve(request)
        }
    }

    private func persistProgress() {
        if hasActiveFlowerShow,
           flowerShowEngine.state.phase == .playing
            || (flowerShowEngine.state.phase == .lost && flowerShowEngine.canUndo)
        {
            flowerShowProgress.activeAttempt = PersistedFlowerShowAttempt(
                contentVersion: FlowerShowContent.contentVersion,
                context: flowerShowAttemptContext,
                engine: flowerShowEngine
            )
        } else {
            flowerShowProgress.activeAttempt = nil
        }
        flowerShowProgress.pendingResult = pendingFlowerShowResult
        bestCampaignRatings = flowerShowProgress.bestCampaignRatings
        completedFlowerShowClasses = flowerShowProgress.completedCampaignClasses
        nextCircuitClass = flowerShowProgress.nextCircuitClass
        grandChampionAchieved = flowerShowProgress.isGrandChampion
        seenFlowerShowIntroductionIDs = Set(flowerShowProgress.seenIntroductions.map(\.rawValue))

        progressStore.save(
            GameProgress(
                bestScore: bestScore,
                highestGarden: highestGarden,
                globalBestStreak: globalBestStreak,
                radiantGardens: radiantGardens,
                activeGame: hasActiveGarden && gardenEngine.phase == .playing ? gardenEngine : nil,
                activeGardenSeed: hasActiveGarden && gardenEngine.phase == .playing
                    ? currentGardenSeed
                    : nil,
                flowerShowProgress: flowerShowProgress,
                reviewRequestState: reviewRequestState
            )
        )
    }

    private static func seed(baseSeed: UInt64, garden: Int) -> UInt64 {
        var value = baseSeed ^ (UInt64(max(1, garden)) &* 0x9E37_79B9_7F4A_7C15)
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
