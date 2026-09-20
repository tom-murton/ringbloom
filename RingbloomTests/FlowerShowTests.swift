import Foundation
import Testing
@testable import Ringbloom

private let v3SingleBloomBoard = GameBoard(
    inner: [.saffron, .sky, .sky, .sky, .sky, .sky, .sky, .coral],
    middle: [.coral, .saffron, .saffron, .saffron, .saffron, .saffron, .saffron, .saffron],
    outer: [.coral, .mint, .mint, .mint, .mint, .mint, .mint, .mint]
)

private let v3DoubleBloomBoard = GameBoard(
    inner: [.saffron, .sky, .sky, .mint, .coral, .sky, .sky, .coral],
    middle: [.coral, .saffron, .saffron, .saffron, .mint, .saffron, .saffron, .saffron],
    outer: [.coral, .mint, .mint, .mint, .mint, .mint, .mint, .mint]
)

private let v3DeadBoard = GameBoard(
    inner: Array(repeating: .coral, count: 8),
    middle: Array(repeating: .saffron, count: 8),
    outer: Array(repeating: .mint, count: 8)
)

private func testScenario(
    id: String = "test",
    board: GameBoard = v3SingleBloomBoard,
    target: Int = 20,
    moves: Int = 10,
    par: Int = 8,
    kinds: Int = 4,
    objectives: FlowerShowObjectives = .init()
) -> FlowerShowScenario {
    FlowerShowScenario(
        scenarioID: id,
        scenarioDigest: "test-digest",
        initialBoard: board,
        startingSelectedRing: .inner,
        refillSource: FlowerShowRefillSource(seed: 0xCAFE),
        repairSalt: 0xBEEF,
        targetBlooms: target,
        moveBudget: moves,
        radiantPar: min(par, moves),
        activeKindCount: kinds,
        objectives: objectives
    )
}

struct FlowerShowShareCardTests {
    @Test func sharingAnAchievementRequiresAHealthyCommittedSave() {
        #expect(FlowerShowAchievementSharePolicy.isEligible(progressSaveHealth: .saved))
        #expect(FlowerShowAchievementSharePolicy.isEligible(progressSaveHealth: .pending) == false)
        #expect(FlowerShowAchievementSharePolicy.isEligible(progressSaveHealth: .blocked) == false)
    }

    @Test func radiantCardContainsOnlyTheEarnedClassRatingAndAllowedResultFacts() {
        let card = FlowerShowShareCardData(summary: shareSummary(
            kind: .campaign,
            classNumber: 12,
            rating: .radiant,
            movesUsed: 7,
            radiantPar: 7
        ))

        #expect(card.heading == "Ringbloom Flower Show")
        #expect(card.achievementLine == "Class 12 complete")
        #expect(card.classAndRatingLine == "Class 12 · RADIANT")
        #expect(card.detailLine == "7 moves · no Hint · no Undo")
        #expect(card.shareText.contains(FlowerShowShareCardData.appStoreURL.absoluteString))
        #expect(card.shareText.contains("score") == false)
        #expect(card.shareText.contains("board") == false)
    }

    @Test func flourishingSeedlingAndMilestoneCardsUseTheirActualEarnedStates() {
        let flourishing = FlowerShowShareCardData(summary: shareSummary(
            kind: .campaign,
            classNumber: 9,
            rating: .flourishing,
            movesUsed: 9,
            radiantPar: 8
        ))
        #expect(flourishing.detailLine == "9 moves · no Hint · no Undo")

        let seedling = FlowerShowShareCardData(summary: shareSummary(
            kind: .replay,
            classNumber: 5,
            rating: .seedling,
            didUseHint: true
        ))
        #expect(seedling.detailLine == "Hint used.")

        let seedlingWithoutHint = FlowerShowShareCardData(summary: shareSummary(
            kind: .campaign,
            classNumber: 1,
            rating: .seedling
        ))
        #expect(seedlingWithoutHint.detailLine == nil)

        let milestone = FlowerShowShareCardData(summary: shareSummary(
            kind: .campaign,
            classNumber: 30,
            rating: .radiant,
            milestone: .grandChampion
        ))
        #expect(milestone.achievementLine == "Grand Champion earned")
        #expect(milestone.classAndRatingLine == "Class 30 · RADIANT")
    }

    @Test func circuitCardKeepsTheEntireDecimalClassNumber() {
        let card = FlowerShowShareCardData(summary: shareSummary(
            kind: .circuit,
            classNumber: 1_000_000,
            rating: .seedling,
            milestone: .circuitCup
        ))

        #expect(card.heading == "Ringbloom Champion Circuit")
        #expect(card.classNumberText == "1000000")
        #expect(card.achievementLine == "Circuit Cup earned")
        #expect(card.classAndRatingLine == "Class 1000000 · SEEDLING")
        #expect(card.detailLine == nil)
    }

    @MainActor
    @Test func shareCardRendererWritesInspectableFixedSizePNGFixtures() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RingbloomShareCardVerification", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let cards: [(String, FlowerShowShareCardData)] = [
            ("class-1-seedling", FlowerShowShareCardData(summary: shareSummary(
                kind: .campaign, classNumber: 1, rating: .seedling
            ))),
            ("class-30-grand-champion-radiant", FlowerShowShareCardData(summary: shareSummary(
                kind: .campaign, classNumber: 30, rating: .radiant, milestone: .grandChampion
            ))),
            ("class-1000000-circuit", FlowerShowShareCardData(summary: shareSummary(
                kind: .circuit, classNumber: 1_000_000, rating: .seedling, milestone: .circuitCup
            ))),
            ("class-9-flourishing", FlowerShowShareCardData(summary: shareSummary(
                kind: .campaign, classNumber: 9, rating: .flourishing, radiantPar: 8
            ))),
        ]

        for (name, card) in cards {
            let data = try #require(FlowerShowShareCardRenderer.pngData(for: card))
            #expect(data.isEmpty == false)
            let destination = directory.appendingPathComponent("\(name).png")
            try data.write(to: destination, options: .atomic)
            print("RINGBLOOM_SHARE_CARD_VERIFICATION=\(destination.path)")
        }
    }

    @Test func cancellationAndDuplicateCallbacksNeverRecordCompletionAndAnalyticsExcludePrivateTargets() {
        let card = FlowerShowShareCardData(summary: shareSummary(
            kind: .campaign,
            classNumber: 6,
            rating: .seedling,
            didUseHint: true
        ))
        var cancelledGate = FlowerShowShareCompletionGate()
        #expect(cancelledGate.consume(completed: false) == false)
        #expect(cancelledGate.didFinish)
        #expect(cancelledGate.consume(completed: true) == false)

        var completedGate = FlowerShowShareCompletionGate()
        let firstCompletion = completedGate.consume(completed: true)
        #expect(firstCompletion)
        #expect(completedGate.didFinish)
        #expect(completedGate.consume(completed: true) == false)
        #expect(completedGate.consume(completed: false) == false)
        #expect(card.analyticsProperties["class_number"] as? Int == 6)
        #expect(card.analyticsProperties.keys.contains("attempt_id") == false)
        #expect(card.analyticsProperties.keys.contains("recipient") == false)
        #expect(card.analyticsProperties.keys.contains("destination") == false)
    }
}

private func shareSummary(
    kind: FlowerShowAttemptKind,
    classNumber: Int,
    rating: FlowerShowRating,
    movesUsed: Int = 8,
    radiantPar: Int = 7,
    didUseHint: Bool = false,
    milestone: FlowerShowMilestone? = nil
) -> FlowerShowResultSummary {
    FlowerShowResultSummary(
        attemptID: UUID(),
        context: FlowerShowAttemptContext(kind: kind, classNumber: classNumber),
        rating: rating,
        movesUsed: movesUsed,
        radiantPar: radiantPar,
        didUseHint: didUseHint,
        didUseUndo: false,
        isNewBest: false,
        milestone: milestone
    )
}

private final class FixtureBundleToken: NSObject {}

@MainActor
private final class FullFlowerShowAccessProvider: FlowerShowAccessProviding {
    let accessState: FlowerShowAccessState = .full(.storePurchase)

    var hasFullFlowerShowAccess: Bool { true }
}

private func fixtureURL(version: Int) -> URL {
    let resourceName = "legacy-v\(version)-active-garden"
    if let bundledURL = Bundle(for: FixtureBundleToken.self)
        .url(forResource: resourceName, withExtension: "json") {
        return bundledURL
    }

    return URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/\(resourceName).json")
}

struct FlowerShowV3ContentTests {
    @Test func catalogueHasTheExactVersionedShapeAndValidDigests() throws {
        let catalogue = FlowerShowContent.catalogue
        try catalogue.validate()

        #expect(catalogue.contentVersion == 3)
        #expect(catalogue.mappingVersion == 1)
        #expect(catalogue.campaignScenarios.count == 30)
        #expect(catalogue.curatedCircuitScenarios.count == 8)
        #expect(catalogue.endlessCircuitScenarios.count == 128)
        #expect(Set(
            (catalogue.campaignScenarios
                + catalogue.curatedCircuitScenarios
                + catalogue.endlessCircuitScenarios).map(\.scenarioID)
        ).count == 166)
    }

    @Test func authoritativeCampaignNumbersAndIntroductionsMatchThePlan() {
        let expected: [(Int, Int, Int, Int)] = [
            (1, 5, 9, 7), (5, 7, 8, 7), (10, 7, 8, 7),
            (15, 8, 9, 8), (20, 8, 10, 8), (25, 9, 10, 8),
            (30, 11, 11, 9),
        ]
        for (number, target, moves, par) in expected {
            let scenario = FlowerShowContent.resolve(classNumber: number).scenario
            #expect(scenario.targetBlooms == target)
            #expect(abs(scenario.moveBudget - moves) <= 1)
            #expect(abs(scenario.radiantPar - par) <= 1)
        }
        #expect(FlowerShowIntroductionID.allCases.map(\.introductionClass) == [1, 6, 11, 16, 21, 24, 33])
        #expect(FlowerShowContent.resolve(classNumber: 24).scenario.objectives.harmonyCreditsPerRing == 2)
        #expect(FlowerShowContent.resolve(classNumber: 30).scenario.objectives.bindweed?.startingSpokes.count == 3)
    }

    @Test func circuitMappingIsStableAtAllGoldenBoundaries() {
        #expect(FlowerShowContent.resolve(classNumber: 39).scenario.scenarioID == "circuit-r1-v01")
        #expect(FlowerShowContent.resolve(classNumber: 46).scenario.scenarioID == "circuit-r8-v01")
        #expect(FlowerShowContent.resolve(classNumber: 47).scenario.scenarioID == "circuit-r1-v02")
        #expect(FlowerShowContent.resolve(classNumber: 166).scenario.scenarioID == "circuit-r8-v16")
        #expect(FlowerShowContent.resolve(classNumber: 167).scenario.scenarioID == "circuit-r1-v01")
        #expect(FlowerShowContent.resolve(classNumber: 1_000_039).scenario.scenarioID ==
            FlowerShowContent.resolve(classNumber: 1_000_039 + 128).scenario.scenarioID)
    }

    @Test func validationRejectsInvalidOrConflictingObjectives() {
        #expect(throws: FlowerShowValidationError.self) {
            try FlowerShowObjectives(harmonyCreditsPerRing: 3).validate()
        }
        #expect(throws: FlowerShowValidationError.self) {
            try FlowerShowObjectives(unbrokenChain: 6).validate()
        }
        #expect(throws: FlowerShowValidationError.self) {
            try FlowerShowObjectives(
                harmonyCreditsPerRing: 1,
                judgesOrder: [.inner, .middle, .outer]
            ).validate()
        }
        #expect(throws: FlowerShowValidationError.self) {
            try FlowerShowObjectives(
                bindweed: BindweedRequirement(startingSpokes: [1, 1], spreadInterval: 3)
            ).validate()
        }
    }
}

struct FlowerShowV3ReducerTests {
    @Test func oneTurnUsesPreRefillKindsAndUpdatesAllCompatibleObjectives() {
        let objectives = FlowerShowObjectives(
            harmonyCreditsPerRing: 1,
            twinBloomTurns: 1,
            bouquetKinds: .all
        )
        let scenario = testScenario(
            board: v3DoubleBloomBoard,
            target: 2,
            moves: 1,
            par: 1,
            objectives: objectives
        )
        var state = FlowerShowEngine(scenario: scenario).state
        state.harmonyCredits = RingCredits(inner: 0, middle: 1, outer: 1)
        state.bouquetKinds = [.saffron, .mint, .sky]

        let transition = FlowerShowReducer.apply(
            GameMove(ring: .inner, direction: .clockwise),
            to: state,
            rules: scenario
        )

        #expect(transition.bloomSpokes == [0, 4])
        #expect(Set(transition.blooms.map(\.kind)) == [.coral, .mint])
        #expect(transition.stateAfter.harmonyCredits.inner == 1)
        #expect(transition.stateAfter.twinBloomTurns == 1)
        #expect(transition.stateAfter.bouquetKinds == .all)
        #expect(transition.completedObjectiveIDs == [.harmony, .twinBloom, .prizeBouquet])
        #expect(transition.stateAfter.phase == .won)
    }

    @Test func clearingAnyBindweedResetsCountdownAndPreservesOtherSpokes() {
        let scenario = testScenario(
            objectives: FlowerShowObjectives(
                bindweed: BindweedRequirement(startingSpokes: [0, 4], spreadInterval: 3)
            )
        )
        var state = FlowerShowEngine(scenario: scenario).state
        state.bindweedCountdown = 1

        let transition = FlowerShowReducer.apply(
            GameMove(ring: .inner, direction: .clockwise),
            to: state,
            rules: scenario
        )

        #expect(transition.clearedBindweedSpokes == [0])
        #expect(transition.stateAfter.infectedSpokes == [4])
        #expect(transition.stateAfter.bindweedCountdown == 3)
        #expect(transition.newlyInfectedSpoke == nil)
    }

    @Test func bindweedSpreadsOnceToTheDeterministicPreviewedNeighbour() {
        let scenario = testScenario(
            objectives: FlowerShowObjectives(
                bindweed: BindweedRequirement(startingSpokes: [0], spreadInterval: 3)
            )
        )
        var state = FlowerShowEngine(scenario: scenario).state
        state.bindweedCountdown = 1

        let transition = FlowerShowReducer.apply(
            GameMove(ring: .inner, direction: .counterClockwise),
            to: state,
            rules: scenario
        )

        #expect(transition.blooms.isEmpty)
        #expect(transition.spreadSourceSpoke == 0)
        #expect(transition.newlyInfectedSpoke == 1)
        #expect(transition.stateAfter.infectedSpokes == [0, 1])
        #expect(transition.stateAfter.bindweedCountdown == 3)
    }

    @Test func judgesOrderAdvancesOnlyForAScoringTurnOnTheNextRing() {
        let scenario = testScenario(
            objectives: FlowerShowObjectives(judgesOrder: [.inner, .outer, .middle])
        )
        let state = FlowerShowEngine(scenario: scenario).state
        let matched = FlowerShowReducer.apply(
            GameMove(ring: .inner, direction: .clockwise),
            to: state,
            rules: scenario
        )
        #expect(matched.stateAfter.judgesOrderIndex == 1)
        #expect(matched.matchedOrderRing == .inner)
        #expect(matched.nextOrderRing == .outer)

        var offOrderState = state
        offOrderState.judgesOrderIndex = 1
        let offOrder = FlowerShowReducer.apply(
            GameMove(ring: .inner, direction: .clockwise),
            to: offOrderState,
            rules: scenario
        )
        #expect(offOrder.bloomCount == 1)
        #expect(offOrder.stateAfter.judgesOrderIndex == 1)
        #expect(offOrder.matchedOrderRing == nil)
    }

    @Test func finalMoveWinTakesPrecedenceOverMovesRunningOut() {
        let scenario = testScenario(target: 1, moves: 1, par: 1)
        let state = FlowerShowEngine(scenario: scenario).state
        let transition = FlowerShowReducer.apply(
            GameMove(ring: .inner, direction: .clockwise),
            to: state,
            rules: scenario
        )

        #expect(transition.stateAfter.movesRemaining == 0)
        #expect(transition.stateAfter.phase == .won)
    }

    @Test func deadBoardRepairIsStableAndOnlyGuaranteesAScoringMove() {
        let scenario = testScenario(board: v3DeadBoard, target: 20, moves: 4, par: 4)
        let state = FlowerShowEngine(scenario: scenario).state
        let move = GameMove(ring: .middle, direction: .clockwise)
        let first = FlowerShowReducer.apply(move, to: state, rules: scenario)
        let second = FlowerShowReducer.apply(move, to: state, rules: scenario)

        #expect(first.didReshuffle)
        #expect(first.stateAfter.board == second.stateAfter.board)
        #expect(first.stateAfter.board.isStable)
        #expect(first.stateAfter.board.scoringMoves.isEmpty == false)
    }

    @Test func exactUndoRestoresStateAndAssistanceButPermanentlyCapsRating() throws {
        let scenario = testScenario(target: 5, moves: 5, par: 4)
        var engine = FlowerShowEngine(scenario: scenario)
        let original = engine.state
        let rotation = engine.rotate(.clockwise, scenario: scenario)
        _ = try #require(rotation)
        let didUndo = engine.useUndo()
        #expect(didUndo)

        #expect(engine.state == original)
        #expect(engine.hintRemaining)
        #expect(engine.didUseHint == false)
        #expect(engine.didUseUndo)
        #expect(engine.canUndo == false)
        #expect(engine.bestAvailableRating(for: scenario) == .flourishing)
    }
}

struct FlowerShowV3SolverTests {
    @Test func exactSolverReturnsAWinningShortestRouteThroughTheProductionReducer() throws {
        let scenario = FlowerShowContent.resolve(classNumber: 30).scenario
        var state = FlowerShowEngine(scenario: scenario).state
        let solution = try #require(FlowerShowExactSolver.shortestRoute(from: state, scenario: scenario))
        #expect(solution.moves.count <= scenario.radiantPar)
        for move in solution.moves {
            state = FlowerShowReducer.apply(move, to: state, rules: scenario).stateAfter
        }
        #expect(state.phase == .won)
    }

    @Test func admissibleSolverAgreesWithUnprunedSearchOnReducedDepthPrefixes() {
        let scenario = FlowerShowContent.resolve(classNumber: 1).scenario
        let initial = FlowerShowEngine(scenario: scenario).state
        for depth in 1 ... 3 {
            let exact = FlowerShowExactSolver.shortestRoute(
                from: initial,
                scenario: scenario,
                maximumDepth: depth
            ) != nil
            #expect(exact == exhaustiveWin(from: initial, scenario: scenario, depth: depth))
        }
    }

    @Test func hintActorCachesAnExactResultForTheCanonicalState() async {
        let scenario = FlowerShowContent.resolve(classNumber: 21).scenario
        let state = FlowerShowEngine(scenario: scenario).state
        let request = FlowerShowHintRequest(
            attemptID: UUID(),
            state: state,
            scenario: scenario,
            preferredMaximumDepth: scenario.radiantPar
        )
        let solver = ExactFlowerShowHintSolver()
        let first = await solver.solve(request)
        let second = await solver.solve(request)

        #expect(first == second)
        if case let .move(move, routeLength) = first {
            #expect(routeLength <= scenario.radiantPar)
            #expect(Ring.allCases.contains(move.ring))
        } else {
            Issue.record("Certified scenario did not return an exact Hint move.")
        }
    }

    private func exhaustiveWin(
        from state: FlowerShowState,
        scenario: FlowerShowScenario,
        depth: Int
    ) -> Bool {
        if state.phase == .won { return true }
        guard state.phase == .playing, depth > 0 else { return false }
        return Ring.allCases.contains { ring in
            RotationDirection.allCases.contains { direction in
                let next = FlowerShowReducer.apply(
                    GameMove(ring: ring, direction: direction),
                    to: state,
                    rules: scenario
                ).stateAfter
                return exhaustiveWin(from: next, scenario: scenario, depth: depth - 1)
            }
        }
    }
}

struct FlowerShowV3ProgressTests {
    @Test func bestRatingsOnlyImproveAndPerfectShowIsDerived() {
        var progress = FlowerShowProgressV3()
        let recordedFirst = progress.recordCampaignRating(.flourishing, for: 1)
        let recordedWorse = progress.recordCampaignRating(.seedling, for: 1)
        #expect(recordedFirst)
        #expect(recordedWorse == false)
        #expect(progress.bestCampaignRatings[1] == .flourishing)

        for number in 1 ... 30 {
            _ = progress.recordCampaignRating(.radiant, for: number)
        }
        #expect(progress.isGrandChampion)
        #expect(progress.isPerfectShow)
        #expect(progress.radiantCount == 30)
    }

    @MainActor
    @Test func progressionIsSequentialAndReplayDoesNotMoveTheMainCursor() {
        let store = InMemoryGameProgressStore(progress: GameProgress(bestScore: 0, highestGarden: 11))
        let model = GameModel(
            launchMode: .uiTest(seed: 41),
            progressStore: store,
            flowerShowAccess: FullFlowerShowAccessProvider()
        )

        model.startFlowerShowClass(2)
        #expect(model.activeMode == .garden)
        model.startFlowerShowClass(1)
        #expect(model.activeMode == .flowerShow)
        #expect(model.currentFlowerShowAttemptKind == .campaign)
    }

    @MainActor
    @Test func aWonAttemptCommitsOnceAndCannotAdvanceTwice() throws {
        let store = InMemoryGameProgressStore(progress: GameProgress(bestScore: 0, highestGarden: 11))
        let model = GameModel(
            launchMode: .uiTest(seed: 73),
            progressStore: store,
            flowerShowAccess: FullFlowerShowAccessProvider()
        )
        model.startFlowerShowClass(1)
        let scenario = FlowerShowContent.resolve(classNumber: 1).scenario
        let solution = try #require(FlowerShowExactSolver.shortestRoute(from: modelState(model), scenario: scenario))

        for move in solution.moves {
            model.select(move.ring)
            _ = try #require(model.rotate(move.direction))
        }
        let result = try #require(model.pendingFlowerShowResult)
        #expect(model.completedFlowerShowClasses == [1])
        #expect(store.progress.flowerShowProgress.committedAttemptIDs == [result.attemptID])
        #expect(model.rotate(.clockwise) == nil)
        #expect(store.progress.flowerShowProgress.committedAttemptIDs.count == 1)
    }

    @MainActor
    @Test("Circuit Classes 201 through 210 survive a relaunch")
    func highCircuitProgressSurvivesRelaunch() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RingbloomHighCircuit-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("progress.json")
        let ratings = Dictionary(
            uniqueKeysWithValues: (1 ... FlowerShowContent.campaignClassCount).map {
                ($0, FlowerShowRating.seedling)
            }
        )
        let store = FileGameProgressStore(fileURL: destination)
        #expect(store.save(
            GameProgress(
                bestScore: 0,
                highestGarden: 11,
                flowerShowProgress: FlowerShowProgressV3(
                    bestCampaignRatings: ratings,
                    nextCircuitClass: 201
                )
            )
        ))

        let model = GameModel(
            launchMode: .uiTest(seed: 201),
            progressStore: store,
            flowerShowAccess: FullFlowerShowAccessProvider()
        )
        for classNumber in 201 ... 210 {
            #expect(model.currentFlowerShowClass == classNumber)
            try #require(model.prepareFlowerShowWinFixture(classNumber: classNumber))
            #expect(model.nextCircuitClass == classNumber + 1)
        }

        let relaunched = GameModel(
            launchMode: .uiTest(seed: 211),
            progressStore: FileGameProgressStore(fileURL: destination),
            flowerShowAccess: FullFlowerShowAccessProvider()
        )
        #expect(relaunched.currentFlowerShowClass == 211)
        #expect(relaunched.nextCircuitClass == 211)
    }

    @MainActor
    private func modelState(_ model: GameModel) -> FlowerShowState {
        var engine = FlowerShowEngine(scenario: FlowerShowContent.resolve(classNumber: model.flowerShowDefinition.number).scenario)
        engine.state.board = model.board
        engine.state.selectedRing = model.selectedRing
        engine.state.blooms = model.blooms
        engine.state.movesRemaining = model.movesRemaining
        return engine.state
    }
}

struct FlowerShowPersistenceRegressionTests {
    @MainActor
    private final class ToggleProgressStore: GameProgressStoring {
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

    private var championRatings: [Int: FlowerShowRating] {
        Dictionary(uniqueKeysWithValues: (1 ... 30).map { ($0, .flourishing) })
    }

    private func movedEngine(classNumber: Int) throws -> FlowerShowEngine {
        let scenario = FlowerShowContent.resolve(classNumber: classNumber).scenario
        for ring in Ring.allCases {
            for direction in [RotationDirection.clockwise, .counterClockwise] {
                var candidate = FlowerShowEngine(scenario: scenario)
                candidate.select(ring)
                _ = candidate.rotate(direction, scenario: scenario)
                if candidate.state.phase == .playing { return candidate }
            }
        }
        throw FlowerShowValidationError.invalid("No playable first move in test scenario.")
    }

    @MainActor
    @Test("Move, select another ring and reload retains the exact active attempt")
    func selectionAfterMoveSurvivesReload() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RingbloomSelection-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("progress.json")
        var engine = try movedEngine(classNumber: 198)
        engine.select(Ring.allCases.first { $0 != engine.state.selectedRing }!)
        let progress = GameProgress(
            bestScore: 500,
            highestGarden: 11,
            flowerShowProgress: FlowerShowProgressV3(
                bestCampaignRatings: championRatings,
                nextCircuitClass: 198,
                activeAttempt: PersistedFlowerShowAttempt(
                    contentVersion: FlowerShowContent.contentVersion,
                    context: FlowerShowAttemptContext(kind: .circuit, classNumber: 198),
                    engine: engine
                )
            )
        )
        #expect(FileGameProgressStore(fileURL: destination).save(progress))
        let store = FileGameProgressStore(fileURL: destination)
        let loaded = store.load()
        #expect(loaded.flowerShowProgress.activeAttempt?.engine == engine)
        #expect(loaded.flowerShowProgress.nextCircuitClass == 198)
        #expect(loaded.bestScore == 500)
        guard case .loaded = store.lastLoadOutcome else {
            Issue.record("A valid changed selection must not trigger repair.")
            return
        }
    }

    @MainActor
    @Test("Selection, next move, Undo and reload retain the selected historical board")
    func selectionUndoSurvivesReload() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RingbloomSelectionUndo-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("progress.json")
        let scenario = FlowerShowContent.resolve(classNumber: 198).scenario
        var engine = try movedEngine(classNumber: 198)
        engine.select(Ring.allCases.first { $0 != engine.state.selectedRing }!)
        let selectedState = engine.state
        var second: FlowerShowEngine?
        for direction in [RotationDirection.clockwise, .counterClockwise] {
            var candidate = engine
            _ = candidate.rotate(direction, scenario: scenario)
            if candidate.canUndo { second = candidate; break }
        }
        engine = try #require(second)
        func progress(for engine: FlowerShowEngine) -> GameProgress {
            GameProgress(bestScore: 0, highestGarden: 11, flowerShowProgress: FlowerShowProgressV3(
                bestCampaignRatings: championRatings,
                nextCircuitClass: 198,
                activeAttempt: PersistedFlowerShowAttempt(
                    contentVersion: FlowerShowContent.contentVersion,
                    context: FlowerShowAttemptContext(kind: .circuit, classNumber: 198),
                    engine: engine
                )
            ))
        }
        #expect(FileGameProgressStore(fileURL: destination).save(progress(for: engine)))
        var reloaded = try #require(FileGameProgressStore(fileURL: destination).load()
            .flowerShowProgress.activeAttempt?.engine)
        let didUndo = reloaded.useUndo()
        #expect(didUndo)
        #expect(reloaded.state == selectedState)
        #expect(FileGameProgressStore(fileURL: destination).save(progress(for: reloaded)))
        let final = FileGameProgressStore(fileURL: destination).load()
        #expect(final.flowerShowProgress.activeAttempt?.engine.state == selectedState)
        #expect(final.flowerShowProgress.activeAttempt?.engine.didUseUndo == true)
    }

    @MainActor
    @Test("A selected ring does not excuse altered board or score", arguments: ["board", "score"])
    func selectionStillRejectsAlteredGameplay(field: String) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RingbloomSelectionTamper-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("progress.json")
        var engine = try movedEngine(classNumber: 198)
        engine.select(Ring.allCases.first { $0 != engine.state.selectedRing }!)
        if field == "score" {
            engine.state.score += 1
        } else {
            let initialBoard = FlowerShowContent.resolve(classNumber: 198).scenario.initialBoard
            try #require(engine.state.board != initialBoard)
            engine.state.board = initialBoard
        }
        let progress = GameProgress(bestScore: 500, highestGarden: 11,
            flowerShowProgress: FlowerShowProgressV3(
                bestCampaignRatings: championRatings, nextCircuitClass: 198,
                activeAttempt: PersistedFlowerShowAttempt(
                    contentVersion: FlowerShowContent.contentVersion,
                    context: FlowerShowAttemptContext(kind: .circuit, classNumber: 198),
                    engine: engine
                )
            ))
        try JSONEncoder().encode(progress).write(to: destination, options: .atomic)
        let store = FileGameProgressStore(fileURL: destination)
        let loaded = store.load()
        #expect(loaded.flowerShowProgress.activeAttempt == nil)
        #expect(loaded.flowerShowProgress.nextCircuitClass == 198)
        #expect(loaded.flowerShowProgress.bestCampaignRatings == championRatings)
        guard case .repaired = store.lastLoadOutcome else {
            Issue.record("Altered gameplay state must be repaired, not resumed.")
            return
        }
    }

    @MainActor
    @Test("A damaged primary recovers the latest valid earned cursor and ratings")
    func damagedPrimaryRecovers() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RingbloomRecovery-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("progress.json")
        let store = FileGameProgressStore(fileURL: destination)
        #expect(store.save(GameProgress(bestScore: 800, highestGarden: 11,
                                        flowerShowProgress: FlowerShowProgressV3(
                                            bestCampaignRatings: championRatings,
                                            nextCircuitClass: 230))))
        let damaged = Data("{ damaged primary".utf8)
        try damaged.write(to: destination, options: .atomic)
        let recoveredStore = FileGameProgressStore(fileURL: destination)
        let recovered = recoveredStore.load()
        #expect(recovered.flowerShowProgress.nextCircuitClass == 230)
        #expect(recovered.flowerShowProgress.bestCampaignRatings == championRatings)
        #expect(recovered.bestScore == 800)
        #expect(recoveredStore.persistenceEnabled)
        guard case let .repaired(_, backupURL) = recoveredStore.lastLoadOutcome else {
            Issue.record("Expected a recovered load with the damaged original preserved.")
            return
        }
        #expect(try Data(contentsOf: backupURL) == damaged)
    }

    @MainActor
    @Test("A failed model write retains earned progress and recovers on retry")
    func modelRetainsPendingProgress() throws {
        let store = ToggleProgressStore(progress: GameProgress(
            bestScore: 0, highestGarden: 11,
            flowerShowProgress: FlowerShowProgressV3(
                bestCampaignRatings: championRatings, nextCircuitClass: 198
            )
        ))
        let model = GameModel(
            launchMode: .uiTest(seed: 198),
            progressStore: store,
            flowerShowAccess: FullFlowerShowAccessProvider()
        )
        try #require(model.prepareFlowerShowWinFixture(classNumber: 198))
        #expect(model.nextCircuitClass == 199)
        #expect(model.progressSaveHealth == .pending)
        #expect(store.progress.flowerShowProgress.nextCircuitClass == 198)
        store.acceptsWrites = true
        model.retryPendingProgress()
        #expect(model.progressSaveHealth == .saved)
        #expect(store.progress.flowerShowProgress.nextCircuitClass == 199)
        #expect(store.progress.flowerShowProgress.bestCampaignRatings == championRatings)
    }

    @MainActor
    @Test("Restarting a completed replay replaces its result with a relaunchable saved attempt")
    func completedReplayRestartPersists() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RingbloomReplayRestart-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("progress.json")
        let store = FileGameProgressStore(fileURL: destination)
        #expect(store.save(GameProgress(
            bestScore: 0,
            highestGarden: 2,
            flowerShowProgress: FlowerShowProgressV3(
                bestCampaignRatings: [1: .seedling]
            )
        )))
        let model = GameModel(
            launchMode: .uiTest(seed: 0x571),
            progressStore: store,
            flowerShowAccess: FullFlowerShowAccessProvider()
        )

        #expect(model.startFlowerShowClass(1) == .started)
        let winningRoute = [
            GameMove(ring: .middle, direction: .counterClockwise),
            GameMove(ring: .outer, direction: .clockwise),
            GameMove(ring: .middle, direction: .counterClockwise),
            GameMove(ring: .inner, direction: .counterClockwise),
            GameMove(ring: .middle, direction: .clockwise),
        ]
        for move in winningRoute {
            model.select(move.ring)
            _ = model.rotate(move.direction)
        }
        #expect(model.pendingFlowerShowResult?.context.kind == .replay)
        #expect(model.retry() == .started)
        #expect(model.progressSaveHealth == .saved)
        #expect(model.pendingFlowerShowResult == nil)

        let relaunched = GameModel(
            launchMode: .production,
            progressStore: FileGameProgressStore(fileURL: destination),
            flowerShowAccess: FullFlowerShowAccessProvider()
        )
        #expect(relaunched.hasActiveFlowerShow)
        #expect(relaunched.savedFlowerShowAttemptContext == FlowerShowAttemptContext(kind: .replay, classNumber: 1))
        #expect(relaunched.pendingFlowerShowResult == nil)
    }

    @MainActor
    @Test("Starting another Class after a result persists only the new attempt")
    func classBookStartAfterResultPersists() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RingbloomResultClassStart-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("progress.json")
        let resultID = UUID()
        let result = FlowerShowResultSummary(
            attemptID: resultID,
            context: FlowerShowAttemptContext(kind: .campaign, classNumber: 1),
            rating: .seedling,
            movesUsed: 8,
            radiantPar: 7,
            didUseHint: false,
            didUseUndo: false,
            isNewBest: true,
            milestone: nil
        )
        let store = FileGameProgressStore(fileURL: destination)
        #expect(store.save(GameProgress(
            bestScore: 0,
            highestGarden: 2,
            flowerShowProgress: FlowerShowProgressV3(
                bestCampaignRatings: [1: .seedling],
                pendingResult: result,
                committedAttemptIDs: [resultID]
            )
        )))
        let model = GameModel(
            launchMode: .uiTest(seed: 0x581),
            progressStore: store,
            flowerShowAccess: FullFlowerShowAccessProvider()
        )

        #expect(model.pendingFlowerShowResult != nil)
        #expect(model.startFlowerShowClass(2) == .started)
        #expect(model.progressSaveHealth == .saved)
        #expect(model.pendingFlowerShowResult == nil)

        let relaunched = GameModel(
            launchMode: .production,
            progressStore: FileGameProgressStore(fileURL: destination),
            flowerShowAccess: FullFlowerShowAccessProvider()
        )
        #expect(relaunched.hasActiveFlowerShow)
        #expect(relaunched.savedFlowerShowAttemptContext == FlowerShowAttemptContext(kind: .campaign, classNumber: 2))
        #expect(relaunched.pendingFlowerShowResult == nil)
    }

    @MainActor
    @Test("If the newest recovery slot is damaged, the previous valid revision survives")
    func previousValidRecoverySurvives() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RingbloomPreviousRecovery-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("progress.json")
        let store = FileGameProgressStore(fileURL: destination)
        #expect(store.save(GameProgress(bestScore: 100, highestGarden: 11,
                                        flowerShowProgress: FlowerShowProgressV3(
                                            bestCampaignRatings: championRatings,
                                            nextCircuitClass: 229))))
        #expect(store.save(GameProgress(bestScore: 200, highestGarden: 11,
                                        flowerShowProgress: FlowerShowProgressV3(
                                            bestCampaignRatings: championRatings,
                                            nextCircuitClass: 230))))
        let latest = destination.appendingPathExtension("recovery-v1-0")
        try Data("damaged recovery".utf8).write(to: latest, options: .atomic)
        try Data("damaged primary".utf8).write(to: destination, options: .atomic)
        let recovered = FileGameProgressStore(fileURL: destination).load()
        #expect(recovered.flowerShowProgress.nextCircuitClass == 229)
        #expect(recovered.bestScore == 100)
        #expect(recovered.flowerShowProgress.bestCampaignRatings == championRatings)
    }

    @MainActor
    @Test("Circuit 198 through 230 survives a relaunch after every earned win")
    func repeatedCircuitRelaunches() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RingbloomRepeatedCircuit-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("progress.json")
        #expect(FileGameProgressStore(fileURL: destination).save(GameProgress(
            bestScore: 0, highestGarden: 11,
            flowerShowProgress: FlowerShowProgressV3(
                bestCampaignRatings: championRatings, nextCircuitClass: 198
            )
        )))
        for number in 198 ... 230 {
            let model = GameModel(
                launchMode: .uiTest(seed: UInt64(number)),
                progressStore: FileGameProgressStore(fileURL: destination),
                flowerShowAccess: FullFlowerShowAccessProvider()
            )
            #expect(model.nextCircuitClass == number)
            #expect(model.bestCampaignRatings == championRatings)
            try #require(model.prepareFlowerShowWinFixture(classNumber: number))
            #expect(model.progressSaveHealth == .saved)
            let relaunched = FileGameProgressStore(fileURL: destination).load()
            #expect(relaunched.flowerShowProgress.nextCircuitClass == number + 1)
            #expect(relaunched.flowerShowProgress.bestCampaignRatings == championRatings)
        }
    }
}

struct FlowerShowV3MigrationTests {
    private struct StoredFixtureResult {
        let progress: GameProgress
        let outcome: GameProgressLoadOutcome
        let original: Data
        let persisted: Data
        let backup: Data?
        let secondLoad: GameProgress
        let secondOutcome: GameProgressLoadOutcome
    }

    @MainActor
    @Test(arguments: [1, 2])
    func rawLegacySavePreservesGardenAndCompletedFlowerShowClasses(version: Int) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RingbloomMigration-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("progress.json")
        let original = try Data(contentsOf: fixtureURL(version: version))
        try original.write(to: destination)

        let store = FileGameProgressStore(fileURL: destination)
        let progress = store.load()

        #expect(progress.bestScore == 4_275)
        #expect(progress.highestGarden == 7)
        #expect(progress.globalBestStreak == 5)
        #expect(progress.radiantGardens == [2, 4])
        #expect(progress.activeGame != nil)
        #expect(progress.activeGardenSeed == 0xA11CE)
        #expect(progress.reviewRequestState.successfulGardenCompletions == 6)
        #expect(progress.flowerShowCampaignVersion == 3)
        #expect(progress.flowerShowProgress.bestCampaignRatings == [
            1: .seedling,
            2: .seedling,
            3: .seedling,
            4: .seedling,
            5: .seedling,
        ])
        #expect(progress.completedFlowerShowClasses == [1, 2, 3, 4, 5])
        #expect(progress.currentFlowerShowClass == 6)
        #expect(progress.flowerShowProgress.seenIntroductions == [.harmony, .unbroken])
        #expect(progress.flowerShowProgress.activeAttempt == nil)
        #expect(progress.flowerShowProgress.pendingNoticeVersion == 3)

        guard case let .migrated(_, backupURL) = store.lastLoadOutcome else {
            Issue.record("Expected typed migrated outcome.")
            return
        }
        #expect(try Data(contentsOf: backupURL) == original)
        let migratedText = try String(contentsOf: destination, encoding: .utf8)
        #expect(migratedText.contains("\"flowerShowCampaignVersion\":3"))
        #expect(migratedText.contains("activeFlowerShow") == false)

        let secondStore = FileGameProgressStore(fileURL: destination)
        let secondLoad = secondStore.load()
        #expect(secondLoad == progress)
        guard case .loaded = secondStore.lastLoadOutcome else {
            Issue.record("The migrated representation should load unchanged on its second pass.")
            return
        }
    }

    @MainActor
    @Test(
        "A build-6 reset save recovers legacy Flower Show completion from its backup",
        arguments: [1, 2]
    )
    func build6ResetSaveRecoversLegacyCompletedClasses(version: Int) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RingbloomBackupRecovery-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("progress.json")
        let backupURL = destination.appendingPathExtension("flower-show-v\(version)-backup")
        let legacyData = try Data(contentsOf: fixtureURL(version: version))
        try legacyData.write(to: backupURL, options: .atomic)

        let build6Progress = GameProgress(
            bestScore: 9_100,
            highestGarden: 9,
            globalBestStreak: 8,
            radiantGardens: [3, 8],
            flowerShowProgress: FlowerShowProgressV3(
                bestCampaignRatings: [
                    1: .radiant,
                    3: .flourishing,
                ],
                pendingNoticeVersion: nil
            )
        )
        try JSONEncoder().encode(build6Progress).write(to: destination, options: .atomic)

        let store = FileGameProgressStore(fileURL: destination)
        let recovered = store.load()

        #expect(recovered.bestScore == 9_100)
        #expect(recovered.highestGarden == 9)
        #expect(recovered.globalBestStreak == 8)
        #expect(recovered.radiantGardens == [3, 8])
        #expect(recovered.flowerShowProgress.bestCampaignRatings == [
            1: .radiant,
            2: .seedling,
            3: .flourishing,
            4: .seedling,
            5: .seedling,
        ])
        #expect(recovered.currentFlowerShowClass == 6)
        #expect(recovered.flowerShowProgress.seenIntroductions == [.harmony, .unbroken])
        #expect(recovered.flowerShowProgress.pendingNoticeVersion == nil)
        #expect(try Data(contentsOf: backupURL) == legacyData)
        guard case let .migrated(_, outcomeBackupURL) = store.lastLoadOutcome else {
            Issue.record("Expected the versioned backup to restore missing completion.")
            return
        }
        #expect(outcomeBackupURL == backupURL)

        let secondStore = FileGameProgressStore(fileURL: destination)
        let secondLoad = secondStore.load()
        #expect(secondLoad == recovered)
        guard case .loaded = secondStore.lastLoadOutcome else {
            Issue.record("Backup recovery should be idempotent after the merged save is written.")
            return
        }
    }

    @MainActor
    @Test("An unreadable legacy backup cannot damage valid current progress")
    func malformedLegacyBackupIsIgnored() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RingbloomBackupSafety-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("progress.json")
        let backupURL = destination.appendingPathExtension("flower-show-v2-backup")
        let current = GameProgress(
            bestScore: 7_200,
            highestGarden: 8,
            flowerShowProgress: FlowerShowProgressV3(
                bestCampaignRatings: [1: .radiant, 2: .flourishing]
            )
        )
        let currentData = try JSONEncoder().encode(current)
        try currentData.write(to: destination, options: .atomic)
        try Data("not a legacy save".utf8).write(to: backupURL, options: .atomic)

        let store = FileGameProgressStore(fileURL: destination)
        let loaded = store.load()

        #expect(loaded.flowerShowProgress == current.flowerShowProgress)
        #expect(loaded.bestScore == current.bestScore)
        #expect(loaded.highestGarden == current.highestGarden)
        #expect(store.persistenceEnabled)
        #expect(try Data(contentsOf: destination) == currentData)
        guard case .loaded = store.lastLoadOutcome else {
            Issue.record("An optional unreadable backup should leave valid current progress loaded.")
            return
        }
    }

    @MainActor
    @Test("A future-version save remains read-only and is not rewritten by legacy backup recovery")
    func futureVersionSaveIsNotRewrittenByLegacyBackupRecovery() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RingbloomFutureVersionSafety-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("progress.json")
        let backupURL = destination.appendingPathExtension("flower-show-v2-backup")
        let legacyData = try Data(contentsOf: fixtureURL(version: 2))
        try legacyData.write(to: backupURL, options: .atomic)

        let current = GameProgress(
            bestScore: 8_400,
            highestGarden: 10,
            flowerShowProgress: FlowerShowProgressV3(
                bestCampaignRatings: [1: .radiant]
            )
        )
        var root = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(current)) as? [String: Any]
        )
        root["flowerShowCampaignVersion"] = 4
        root["futureSchemaPayload"] = ["mustSurvive": true]
        let futureData = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
        try futureData.write(to: destination, options: .atomic)

        let store = FileGameProgressStore(fileURL: destination)
        let loaded = store.load()

        #expect(loaded.bestScore == current.bestScore)
        #expect(loaded.highestGarden == current.highestGarden)
        #expect(loaded.flowerShowProgress.bestCampaignRatings == [1: .radiant])
        #expect(try Data(contentsOf: destination) == futureData)
        #expect(try Data(contentsOf: backupURL) == legacyData)
        #expect(store.persistenceEnabled == false)
        #expect(store.save(.fresh) == false)
        #expect(try Data(contentsOf: destination) == futureData)
        #expect(store.loadReasonCode == "future_version")
        guard case .failed = store.lastLoadOutcome else {
            Issue.record("A future-version representation should be read-only without rewriting.")
            return
        }
    }

    @MainActor
    @Test("A future-version save with an invalid optional attempt is never downgraded")
    func futureVersionInvalidAttemptPreservesSource() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RingbloomFutureAttempt-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("progress.json")
        let scenario = FlowerShowContent.resolve(classNumber: 198).scenario
        let original = GameProgress(bestScore: 800, highestGarden: 11,
            flowerShowProgress: FlowerShowProgressV3(
                bestCampaignRatings: [1: .radiant], nextCircuitClass: 230,
                activeAttempt: PersistedFlowerShowAttempt(
                    contentVersion: FlowerShowContent.contentVersion,
                    context: FlowerShowAttemptContext(kind: .circuit, classNumber: 198),
                    engine: FlowerShowEngine(scenario: scenario)
                )
            ))
        var root = try #require(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(original)) as? [String: Any])
        root["flowerShowCampaignVersion"] = 4
        root["futureSchemaPayload"] = ["mustSurvive": true]
        let futureData = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
        try futureData.write(to: destination, options: .atomic)
        let store = FileGameProgressStore(fileURL: destination)
        let loaded = store.load()
        #expect(loaded.flowerShowProgress.activeAttempt == nil)
        #expect(loaded.flowerShowProgress.nextCircuitClass == 230)
        #expect(store.persistenceEnabled == false)
        #expect(store.save(loaded) == false)
        #expect(try Data(contentsOf: destination) == futureData)
        #expect(store.loadReasonCode == "future_version")
    }

    @MainActor
    @Test("Older recovery records cannot replace a future-version primary")
    func futureVersionIgnoresOlderRecovery() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RingbloomFutureRecovery-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("progress.json")
        let store = FileGameProgressStore(fileURL: destination)
        let oldAttempt = Date(timeIntervalSince1970: 1_700_000_000)
        let futureAttempt = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(store.save(GameProgress(bestScore: 900, highestGarden: 11,
            flowerShowProgress: FlowerShowProgressV3(
                bestCampaignRatings: [1: .radiant], nextCircuitClass: 300
            ), reviewRequestState: ReviewRequestState(
                successfulGardenCompletions: 9,
                attemptedAppVersion: "1.6", attemptedDate: oldAttempt
            ))))
        var root = try #require(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(GameProgress(bestScore: 800, highestGarden: 11,
                flowerShowProgress: FlowerShowProgressV3(
                    bestCampaignRatings: [1: .seedling], nextCircuitClass: 230
                ), reviewRequestState: ReviewRequestState(
                    successfulGardenCompletions: 3,
                    attemptedAppVersion: "1.7", attemptedDate: futureAttempt
                )))) as? [String: Any])
        root["flowerShowCampaignVersion"] = 4
        root["futureSchemaPayload"] = ["mustSurvive": true]
        let futureData = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
        try futureData.write(to: destination, options: .atomic)
        let loadedStore = FileGameProgressStore(fileURL: destination)
        let loaded = loadedStore.load()
        #expect(loaded.reviewRequestState.successfulGardenCompletions == 3)
        #expect(loaded.reviewRequestState.attemptedVersions == ["1.7"])
        #expect(loaded.flowerShowProgress.nextCircuitClass == 230)
        #expect(loaded.flowerShowProgress.bestCampaignRatings[1] == .seedling)
        #expect(loadedStore.persistenceEnabled == false)
        #expect(try Data(contentsOf: destination) == futureData)
    }

    @MainActor
    @Test("A second legacy migration preserves each distinct original")
    func mismatchedLegacyMigrationBackupPreservesCurrentSource() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RingbloomLegacyBackupCollision-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("progress.json")
        let backupURL = destination.appendingPathExtension("flower-show-v2-backup")
        let source = try Data(contentsOf: fixtureURL(version: 2))
        let mismatchedBackup = Data("different legacy source".utf8)
        try source.write(to: destination, options: .atomic)
        try mismatchedBackup.write(to: backupURL, options: .atomic)

        let store = FileGameProgressStore(fileURL: destination)
        let loaded = store.load()

        #expect(loaded.bestScore == 4_275)
        #expect(loaded.highestGarden == 7)
        #expect(loaded.globalBestStreak == 5)
        #expect(loaded.radiantGardens == [2, 4])
        #expect(loaded.flowerShowProgress.bestCampaignRatings == [
            1: .seedling,
            2: .seedling,
            3: .seedling,
            4: .seedling,
            5: .seedling,
        ])
        #expect(try Data(contentsOf: destination) != source)
        #expect(try Data(contentsOf: backupURL) == mismatchedBackup)
        #expect(store.persistenceEnabled)
        guard case let .migrated(_, newBackupURL) = store.lastLoadOutcome else {
            Issue.record("A second migration should preserve its original and continue saving.")
            return
        }
        #expect(newBackupURL != backupURL)
        #expect(try Data(contentsOf: newBackupURL) == source)
    }

    @MainActor
    @Test("A later suffixed legacy backup restores the highest valid earned Circuit cursor")
    func suffixedLegacyBackupRestoresHighestCursor() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RingbloomSuffixedLegacy-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("progress.json")
        let ratings = Dictionary(uniqueKeysWithValues: (1 ... 30).map {
            ($0, FlowerShowRating.flourishing)
        })
        let regressed = GameProgress(bestScore: 1_000, highestGarden: 11,
            flowerShowProgress: FlowerShowProgressV3(
                bestCampaignRatings: ratings, nextCircuitClass: 198
            ))
        try JSONEncoder().encode(regressed).write(to: destination, options: .atomic)
        let legacy = try #require(JSONSerialization.jsonObject(
            with: Data(contentsOf: fixtureURL(version: 2))) as? [String: Any])
        for (suffix, cursor) in [("flower-show-v2-backup", 198),
                                 ("flower-show-v2-backup-2", 230)] {
            var versioned = legacy
            versioned["completedFlowerShowClasses"] = Array(1 ... 30)
            versioned["currentFlowerShowClass"] = cursor
            let data = try JSONSerialization.data(withJSONObject: versioned, options: [.sortedKeys])
            try data.write(to: destination.appendingPathExtension(suffix), options: .atomic)
        }
        let store = FileGameProgressStore(fileURL: destination)
        let recovered = store.load()
        #expect(recovered.flowerShowProgress.nextCircuitClass == 230)
        #expect(recovered.flowerShowProgress.bestCampaignRatings == ratings)
        #expect(recovered.bestScore == 1_000)
        #expect(store.persistenceEnabled)
        let relaunched = FileGameProgressStore(fileURL: destination).load()
        #expect(relaunched.flowerShowProgress.nextCircuitClass == 230)
    }

    @MainActor
    @Test("Review history from recovery is durably merged without inventing old sessions")
    func reviewHistoryRecoveryRetainsGardenDatesVersionsAndObservedSessions() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RingbloomReviewRecovery-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("progress.json")
        let firstID = "00000000-0000-0000-0000-000000000571"
        let secondID = "00000000-0000-0000-0000-000000000572"
        let olderDate = Date(timeIntervalSince1970: 1_700_000_000)
        let newerDate = Date(timeIntervalSince1970: 1_710_000_000)
        let recoveryState = ReviewRequestState(
            successfulGardenCompletions: 6,
            committedCampaignResults: 2,
            completedClassFive: true,
            meaningfulSessionIDs: [firstID],
            attemptedAppVersion: "1.6",
            attemptedDate: newerDate
        )
        let store = FileGameProgressStore(fileURL: destination)
        #expect(store.save(GameProgress(bestScore: 100, highestGarden: 7,
                                        reviewRequestState: recoveryState)))
        let regressedState = ReviewRequestState(
            successfulGardenCompletions: 3,
            committedCircuitResults: 1,
            meaningfulSessionIDs: [secondID],
            attemptedAppVersion: "1.5",
            attemptedDate: olderDate
        )
        try JSONEncoder().encode(GameProgress(saveRevision: 2, bestScore: 100, highestGarden: 4,
                                               reviewRequestState: regressedState))
            .write(to: destination, options: .atomic)

        let recovered = FileGameProgressStore(fileURL: destination).load()
        let state = recovered.reviewRequestState
        #expect(state.successfulGardenCompletions == 6)
        #expect(state.committedCampaignResults == 2)
        #expect(state.completedClassFive)
        #expect(state.committedCircuitResults == 1)
        #expect(Set(state.meaningfulSessionIDs) == [firstID, secondID])
        #expect(state.attemptedVersions == ["1.5", "1.6"])
        #expect(state.attemptedVersionDates["1.5"] == olderDate)
        #expect(state.attemptedVersionDates["1.6"] == newerDate)
        #expect(state.attemptedDate == newerDate)
        #expect(recovered.highestGarden == 7)
        #expect(recovered.saveRevision > 2)
        #expect(FileGameProgressStore(fileURL: destination).load().reviewRequestState == state)
    }

    @MainActor
    @Test func corruptSaveIsPreservedAndPersistenceIsDisabled() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RingbloomCorrupt-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("progress.json")
        let corrupt = Data("{ definitely-not-json".utf8)
        try corrupt.write(to: destination)

        let store = FileGameProgressStore(fileURL: destination)
        _ = store.load()
        store.save(.fresh)

        #expect(store.persistenceEnabled == false)
        guard case .failed = store.lastLoadOutcome else {
            Issue.record("Expected typed failed load outcome.")
            return
        }
        #expect(try Data(contentsOf: destination) == corrupt)
    }

    @MainActor
    @Test("A transient write failure does not disable later progress saves")
    func transientWriteFailureAllowsLaterRecovery() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RingbloomTransientSave-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let blockedParent = directory.appendingPathComponent("blocked")
        try Data("temporary obstruction".utf8).write(to: blockedParent, options: .atomic)
        let destination = blockedParent.appendingPathComponent("progress.json")
        let store = FileGameProgressStore(fileURL: destination)

        let class201 = GameProgress(
            bestScore: 0,
            highestGarden: 11,
            flowerShowProgress: FlowerShowProgressV3(nextCircuitClass: 201)
        )
        #expect(store.save(class201) == false)
        #expect(store.persistenceEnabled)
        guard case .failed = store.lastSaveOutcome else {
            Issue.record("Expected the obstructed write to report a save failure.")
            return
        }

        try FileManager.default.removeItem(at: blockedParent)
        try FileManager.default.createDirectory(at: blockedParent, withIntermediateDirectories: true)
        let class211 = GameProgress(
            bestScore: 0,
            highestGarden: 11,
            flowerShowProgress: FlowerShowProgressV3(nextCircuitClass: 211)
        )
        #expect(store.save(class211))
        #expect(store.lastSaveOutcome == .saved)

        let loaded = FileGameProgressStore(fileURL: destination).load()
        #expect(loaded.flowerShowProgress.nextCircuitClass == 211)
    }

    @Test func rawLegacyGardenContinuationIsDeterministic() throws {
        let data = try Data(contentsOf: fixtureURL(version: 2))
        let first = try JSONDecoder().decode(GameProgress.self, from: data)
        let second = try JSONDecoder().decode(GameProgress.self, from: data)
        var firstGarden = try #require(first.activeGame)
        var secondGarden = try #require(second.activeGame)
        let move = try #require(firstGarden.suggestedMove)
        firstGarden.select(move.ring)
        secondGarden.select(move.ring)

        #expect(firstGarden.rotate(move.direction) == secondGarden.rotate(move.direction))
        #expect(firstGarden == secondGarden)
    }

    @MainActor
    @Test(
        "Decoded circuit cursors are clamped through the real store",
        .bug("https://linear.app/weevolve/issue/TOM-58"),
        arguments: [0, Int.max]
    )
    func invalidCircuitCursorIsRepaired(rawCursor: Int) throws {
        let fixture = try loadStoredFixture(
            GameProgress(bestScore: 321, highestGarden: 7)
        ) { root in
            var flowerShow = try #require(root["flowerShowProgress"] as? [String: Any])
            flowerShow["nextCircuitClass"] = rawCursor
            root["flowerShowProgress"] = flowerShow
        }

        let expected = rawCursor < FlowerShowContent.circuitStartClass
            ? FlowerShowContent.circuitStartClass
            : FlowerShowProgressV3.maximumCircuitClass
        #expect(fixture.progress.flowerShowProgress.nextCircuitClass == expected)
        #expect(fixture.progress.bestScore == 321)
        #expect(fixture.progress.highestGarden == 7)
        #expect(fixture.backup == fixture.original)
        guard case .repaired = fixture.outcome else {
            Issue.record("Expected a recoverable repaired load outcome.")
            return
        }
        #expect(fixture.secondLoad == fixture.progress)
        guard case .loaded = fixture.secondOutcome else {
            Issue.record("The repaired representation should be idempotent on its second load.")
            return
        }
    }

    @MainActor
    @Test(
        "Out-of-domain campaign ratings are removed without touching Garden progress",
        .bug("https://linear.app/weevolve/issue/TOM-58")
    )
    func invalidRatingKeysAreRemoved() throws {
        let fixture = try loadStoredFixture(
            GameProgress(
                bestScore: 4_275,
                highestGarden: 7,
                globalBestStreak: 5,
                radiantGardens: [2, 4],
                flowerShowProgress: FlowerShowProgressV3(
                    bestCampaignRatings: [1: .radiant, 30: .flourishing]
                )
            )
        ) { root in
            var flowerShow = try #require(root["flowerShowProgress"] as? [String: Any])
            var ratings = try #require(flowerShow["bestCampaignRatings"] as? [String: Any])
            ratings["-1"] = FlowerShowRating.seedling.rawValue
            ratings["31"] = FlowerShowRating.radiant.rawValue
            flowerShow["bestCampaignRatings"] = ratings
            root["flowerShowProgress"] = flowerShow
        }

        #expect(fixture.progress.flowerShowProgress.bestCampaignRatings == [
            1: .radiant,
            30: .flourishing,
        ])
        #expect(fixture.progress.bestScore == 4_275)
        #expect(fixture.progress.highestGarden == 7)
        #expect(fixture.progress.globalBestStreak == 5)
        #expect(fixture.progress.radiantGardens == [2, 4])
    }

    @MainActor
    @Test(
        "A second repair keeps both distinct originals and continues saving",
        .bug("https://linear.app/weevolve/issue/TOM-58")
    )
    func mismatchedRepairBackupPreservesCurrentSourceAndDisablesPersistence() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RingbloomRepairConflict-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("progress.json")
        let backupURL = destination.appendingPathExtension("repaired-backup")

        var object = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(GameProgress(bestScore: 900, highestGarden: 4))
            ) as? [String: Any]
        )
        var flowerShow = try #require(object["flowerShowProgress"] as? [String: Any])
        flowerShow["nextCircuitClass"] = 0
        object["flowerShowProgress"] = flowerShow
        let currentSource = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        let olderCorruptSource = Data("older repair source".utf8)
        try currentSource.write(to: destination, options: .atomic)
        try olderCorruptSource.write(to: backupURL, options: .atomic)

        let store = FileGameProgressStore(fileURL: destination)
        let loaded = store.load()
        #expect(store.save(loaded))

        #expect(loaded.flowerShowProgress.nextCircuitClass == FlowerShowContent.circuitStartClass)
        #expect(store.persistenceEnabled)
        guard case let .repaired(_, newBackupURL) = store.lastLoadOutcome else {
            Issue.record("Expected a repaired outcome despite the earlier backup.")
            return
        }
        #expect(newBackupURL != backupURL)
        #expect(try Data(contentsOf: newBackupURL) == currentSource)
        #expect(try Data(contentsOf: backupURL) == olderCorruptSource)
    }

    @MainActor
    @Test(
        "Stale and impossible active attempts are discarded",
        .bug("https://linear.app/weevolve/issue/TOM-58"),
        arguments: [
            FlowerShowAttemptContext(kind: .campaign, classNumber: 31),
            FlowerShowAttemptContext(kind: .circuit, classNumber: 5),
            FlowerShowAttemptContext(kind: .replay, classNumber: 2),
        ]
    )
    func invalidActiveAttemptContextIsDiscarded(context: FlowerShowAttemptContext) throws {
        let scenario = FlowerShowContent.resolve(classNumber: context.classNumber).scenario
        let fixture = try loadStoredFixture(
            GameProgress(
                bestScore: 0,
                highestGarden: 2,
                flowerShowProgress: FlowerShowProgressV3(
                    activeAttempt: PersistedFlowerShowAttempt(
                        contentVersion: context.kind == .replay
                            ? FlowerShowContent.contentVersion - 1
                            : FlowerShowContent.contentVersion,
                        context: context,
                        engine: FlowerShowEngine(scenario: scenario)
                    )
                )
            )
        )

        #expect(fixture.progress.flowerShowProgress.activeAttempt == nil)
        #expect(fixture.progress.currentFlowerShowClass == 1)
    }

    @MainActor
    @Test(
        "A decoded active attempt with a malformed board is discarded before consumption",
        .bug("https://linear.app/weevolve/issue/TOM-58")
    )
    func malformedActiveAttemptBoardIsDiscardedAndRepairedIdempotently() throws {
        let scenario = FlowerShowContent.resolve(classNumber: 1).scenario
        let fixture = try loadStoredFixture(
            GameProgress(
                bestScore: 2_400,
                highestGarden: 2,
                flowerShowProgress: FlowerShowProgressV3(
                    activeAttempt: PersistedFlowerShowAttempt(
                        contentVersion: FlowerShowContent.contentVersion,
                        context: FlowerShowAttemptContext(kind: .campaign, classNumber: 1),
                        engine: FlowerShowEngine(scenario: scenario)
                    )
                )
            )
        ) { root in
            var flowerShow = try #require(root["flowerShowProgress"] as? [String: Any])
            var attempt = try #require(flowerShow["activeAttempt"] as? [String: Any])
            var engine = try #require(attempt["engine"] as? [String: Any])
            var state = try #require(engine["state"] as? [String: Any])
            var board = try #require(state["board"] as? [String: Any])
            board["rings"] = []
            state["board"] = board
            engine["state"] = state
            attempt["engine"] = engine
            flowerShow["activeAttempt"] = attempt
            root["flowerShowProgress"] = flowerShow
        }

        #expect(fixture.progress.flowerShowProgress.activeAttempt == nil)
        #expect(fixture.progress.bestScore == 2_400)
        #expect(fixture.progress.highestGarden == 2)
        #expect(fixture.backup == fixture.original)
        guard case .repaired = fixture.outcome else {
            Issue.record("Expected malformed board removal to be recorded as a repair.")
            return
        }
        #expect(fixture.secondLoad == fixture.progress)
        guard case .loaded = fixture.secondOutcome else {
            Issue.record("The repaired progress should load unchanged on its second pass.")
            return
        }
    }

    @MainActor
    @Test(
        "Overflowing decoded active-attempt counters are discarded before the next move",
        .bug("https://linear.app/weevolve/issue/TOM-58"),
        arguments: ["blooms", "score"]
    )
    func overflowingActiveAttemptCounterIsDiscardedAndRepairedIdempotently(
        field: String
    ) throws {
        let scenario = FlowerShowContent.resolve(classNumber: 1).scenario
        let fixture = try loadStoredFixture(
            GameProgress(
                bestScore: 2_800,
                highestGarden: 3,
                globalBestStreak: 4,
                radiantGardens: [2],
                flowerShowProgress: FlowerShowProgressV3(
                    activeAttempt: PersistedFlowerShowAttempt(
                        contentVersion: FlowerShowContent.contentVersion,
                        context: FlowerShowAttemptContext(kind: .campaign, classNumber: 1),
                        engine: FlowerShowEngine(scenario: scenario)
                    )
                )
            )
        ) { root in
            var flowerShow = try #require(root["flowerShowProgress"] as? [String: Any])
            var attempt = try #require(flowerShow["activeAttempt"] as? [String: Any])
            var engine = try #require(attempt["engine"] as? [String: Any])
            var state = try #require(engine["state"] as? [String: Any])
            state[field] = Int.max
            engine["state"] = state
            attempt["engine"] = engine
            flowerShow["activeAttempt"] = attempt
            root["flowerShowProgress"] = flowerShow
        }

        #expect(fixture.progress.flowerShowProgress.activeAttempt == nil)
        #expect(fixture.progress.bestScore == 2_800)
        #expect(fixture.progress.highestGarden == 3)
        #expect(fixture.progress.globalBestStreak == 4)
        #expect(fixture.progress.radiantGardens == [2])
        #expect(fixture.backup == fixture.original)
        guard case .repaired = fixture.outcome else {
            Issue.record("Expected overflowing \(field) removal to be recorded as a repair.")
            return
        }
        #expect(fixture.secondLoad == fixture.progress)
        guard case .loaded = fixture.secondOutcome else {
            Issue.record("The repaired progress should load unchanged on its second pass.")
            return
        }
    }

    @MainActor
    @Test(
        "An already-committed attempt cannot be resumed and committed twice",
        .bug("https://linear.app/weevolve/issue/TOM-58")
    )
    func committedActiveAttemptIsDiscardedAndRepairedIdempotently() throws {
        let scenario = FlowerShowContent.resolve(classNumber: 1).scenario
        let attemptID = UUID()
        let attempt = PersistedFlowerShowAttempt(
            contentVersion: FlowerShowContent.contentVersion,
            context: FlowerShowAttemptContext(kind: .campaign, classNumber: 1),
            engine: FlowerShowEngine(scenario: scenario, attemptID: attemptID)
        )
        let fixture = try loadStoredFixture(
            GameProgress(
                bestScore: 3_600,
                highestGarden: 4,
                globalBestStreak: 6,
                radiantGardens: [2, 3],
                flowerShowProgress: FlowerShowProgressV3(
                    activeAttempt: attempt,
                    committedAttemptIDs: [attemptID]
                )
            )
        )

        #expect(fixture.progress.flowerShowProgress.activeAttempt == nil)
        #expect(fixture.progress.flowerShowProgress.committedAttemptIDs == [attemptID])
        #expect(fixture.progress.bestScore == 3_600)
        #expect(fixture.progress.highestGarden == 4)
        #expect(fixture.progress.globalBestStreak == 6)
        #expect(fixture.progress.radiantGardens == [2, 3])
        #expect(fixture.backup == fixture.original)
        guard case .repaired = fixture.outcome else {
            Issue.record("Expected duplicate active-attempt removal to be recorded as a repair.")
            return
        }
        #expect(fixture.secondLoad == fixture.progress)
        guard case .loaded = fixture.secondOutcome else {
            Issue.record("The repaired progress should load unchanged on its second pass.")
            return
        }
    }

    @MainActor
    @Test(
        "Pending results must reference a committed valid attempt",
        .bug("https://linear.app/weevolve/issue/TOM-58")
    )
    func invalidPendingResultIsDiscarded() throws {
        let result = FlowerShowResultSummary(
            attemptID: UUID(),
            context: FlowerShowAttemptContext(kind: .campaign, classNumber: 5),
            rating: .seedling,
            movesUsed: 8,
            radiantPar: 7,
            didUseHint: true,
            didUseUndo: false,
            isNewBest: true,
            milestone: .rosette
        )
        let fixture = try loadStoredFixture(
            GameProgress(
                bestScore: 0,
                highestGarden: 2,
                flowerShowProgress: FlowerShowProgressV3(
                    bestCampaignRatings: [5: .seedling],
                    pendingResult: result,
                    committedAttemptIDs: []
                )
            )
        )

        #expect(fixture.progress.flowerShowProgress.pendingResult == nil)
        #expect(fixture.progress.flowerShowProgress.bestCampaignRatings[5] == .seedling)
    }

    @MainActor
    @Test(
        "A valid V3 fixture loads byte-semantically unchanged",
        .bug("https://linear.app/weevolve/issue/TOM-58")
    )
    func validV3FixtureIsPreservedExactly() throws {
        let scenario = FlowerShowContent.resolve(classNumber: 2).scenario
        let attempt = PersistedFlowerShowAttempt(
            contentVersion: FlowerShowContent.contentVersion,
            context: FlowerShowAttemptContext(kind: .replay, classNumber: 2),
            engine: FlowerShowEngine(scenario: scenario)
        )
        let expected = GameProgress(
            bestScore: 8_100,
            highestGarden: 12,
            globalBestStreak: 9,
            radiantGardens: [1, 4, 11],
            flowerShowProgress: FlowerShowProgressV3(
                bestCampaignRatings: [1: .radiant, 2: .flourishing],
                nextCircuitClass: 31,
                activeAttempt: attempt,
                seenIntroductions: [.harmony],
                committedAttemptIDs: [UUID()]
            )
        )
        let fixture = try loadStoredFixture(expected)

        // The compatibility fields on `GameProgress` are intentionally derived from V3 when
        // decoding. Compare the authoritative payload and unrelated Garden progress instead.
        #expect(fixture.progress.bestScore == expected.bestScore)
        #expect(fixture.progress.highestGarden == expected.highestGarden)
        #expect(fixture.progress.globalBestStreak == expected.globalBestStreak)
        #expect(fixture.progress.radiantGardens == expected.radiantGardens)
        #expect(fixture.progress.flowerShowProgress == expected.flowerShowProgress)
        #expect(fixture.progress.reviewRequestState == expected.reviewRequestState)
        #expect(fixture.persisted == fixture.original)
        #expect(fixture.backup == nil)
        guard case .loaded = fixture.outcome else {
            Issue.record("Valid V3 progress should not be reported as repaired.")
            return
        }
    }

    @Test(
        "Encoded progress contains no entitlement or purchase state",
        .bug("https://linear.app/weevolve/issue/TOM-58")
    )
    func encodedProgressContainsNoEntitlementState() throws {
        let data = try JSONEncoder().encode(
            GameProgress(
                bestScore: 0,
                highestGarden: 2,
                flowerShowProgress: FlowerShowProgressV3(
                    bestCampaignRatings: [1: .seedling]
                )
            )
        )
        let encoded = String(decoding: data, as: UTF8.self).lowercased()
        #expect(encoded.contains("entitlement") == false)
        #expect(encoded.contains("purchase") == false)
        #expect(encoded.contains("hasfullflowershowaccess") == false)
    }

    @MainActor
    private func loadStoredFixture(
        _ progress: GameProgress,
        mutate: (inout [String: Any]) throws -> Void = { _ in }
    ) throws -> StoredFixtureResult {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RingbloomV3Validation-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("progress.json")

        var object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(progress)) as? [String: Any]
        )
        try mutate(&object)
        let original = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        try original.write(to: destination, options: .atomic)

        let store = FileGameProgressStore(fileURL: destination)
        let loaded = store.load()
        let outcome = store.lastLoadOutcome
        let persisted = try Data(contentsOf: destination)
        let backup: Data? = if case let .repaired(_, backupURL) = outcome {
            try Data(contentsOf: backupURL)
        } else {
            nil
        }

        let secondStore = FileGameProgressStore(fileURL: destination)
        let secondLoad = secondStore.load()
        return StoredFixtureResult(
            progress: loaded,
            outcome: outcome,
            original: original,
            persisted: persisted,
            backup: backup,
            secondLoad: secondLoad,
            secondOutcome: secondStore.lastLoadOutcome
        )
    }
}
