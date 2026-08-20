import Foundation
import Testing
@testable import Ringbloom

private let singleBloomBoard = GameBoard(
    inner: [.saffron, .sky, .sky, .sky, .sky, .sky, .sky, .coral],
    middle: [.coral, .saffron, .saffron, .saffron, .saffron, .saffron, .saffron, .saffron],
    outer: [.coral, .mint, .mint, .mint, .mint, .mint, .mint, .mint]
)

private let doubleBloomBoard = GameBoard(
    inner: [.saffron, .sky, .sky, .mint, .coral, .sky, .sky, .coral],
    middle: [.coral, .saffron, .saffron, .saffron, .mint, .saffron, .saffron, .saffron],
    outer: [.coral, .mint, .mint, .mint, .mint, .mint, .mint, .mint]
)

private let deadBoard = GameBoard(
    inner: Array(repeating: .coral, count: GameBoard.slotsPerRing),
    middle: Array(repeating: .saffron, count: GameBoard.slotsPerRing),
    outer: Array(repeating: .mint, count: GameBoard.slotsPerRing)
)

private let allMoves = Ring.allCases.flatMap { ring in
    RotationDirection.allCases.map { GameMove(ring: ring, direction: $0) }
}

struct GameBoardTests {
    @Test func petalKindsHaveUniqueNonColourCues() {
        #expect(Set(PetalKind.allCases.map(\.glyph)).count == PetalKind.allCases.count)
        #expect(PetalKind.allCases.count == 4)
        #expect(Ring.allCases.count == 3)
        #expect(GameBoard.slotsPerRing == 8)
    }

    @Test func clockwiseRotationMovesEachPetalOneSlotForwardAndWraps() {
        let inner: [PetalKind] = [.coral, .saffron, .mint, .sky, .coral, .saffron, .mint, .sky]
        let board = GameBoard(
            inner: inner,
            middle: Array(repeating: .coral, count: 8),
            outer: Array(repeating: .saffron, count: 8)
        )

        let rotated = board.rotated(.inner, direction: .clockwise)

        #expect(rotated.petals(in: .inner) == [.sky, .coral, .saffron, .mint, .sky, .coral, .saffron, .mint])
        #expect(rotated.petals(in: .middle) == board.petals(in: .middle))
        #expect(rotated.petals(in: .outer) == board.petals(in: .outer))
    }

    @Test func counterClockwiseRotationMovesEachPetalOneSlotBackAndWraps() {
        let inner: [PetalKind] = [.coral, .saffron, .mint, .sky, .coral, .saffron, .mint, .sky]
        let board = GameBoard(
            inner: inner,
            middle: Array(repeating: .coral, count: 8),
            outer: Array(repeating: .saffron, count: 8)
        )

        let rotated = board.rotated(.inner, direction: .counterClockwise)

        #expect(rotated.petals(in: .inner) == [.saffron, .mint, .sky, .coral, .saffron, .mint, .sky, .coral])
    }

    @Test func radialBloomDetectionFindsOnlyCompleteTrios() {
        let rotated = doubleBloomBoard.rotated(.inner, direction: .clockwise)

        #expect(doubleBloomBoard.bloomSpokes.isEmpty)
        #expect(rotated.bloomSpokes == [0, 4])
    }

    @Test func deadBoardHasNoLegalOneMoveBloom() {
        #expect(deadBoard.isStable)
        #expect(deadBoard.hasOneMoveBloom == false)
        #expect(deadBoard.suggestedMove == nil)
    }

    @Test func suggestedMoveAlwaysCreatesABloom() throws {
        let board = GameEngine(seed: 0xB100).board
        let move = try #require(board.suggestedMove)

        #expect(board.rotated(move.ring, direction: move.direction).bloomSpokes.isEmpty == false)
    }

    @Test func accessibilitySummaryDescribesAllEightSpokesAndThreeRings() {
        let board = GameBoard(
            inner: Array(repeating: .coral, count: 8),
            middle: Array(repeating: .saffron, count: 8),
            outer: Array(repeating: .mint, count: 8)
        )
        let summary = board.accessibilitySpokeSummary

        for position in ["12 o'clock", "1:30", "3 o'clock", "4:30", "6 o'clock", "7:30", "9 o'clock", "10:30"] {
            #expect(summary.contains(position))
        }
        #expect(summary.contains("inner coral circle"))
        #expect(summary.contains("middle saffron diamond"))
        #expect(summary.contains("outer mint triangle"))
    }
}

struct BoardGestureInterpreterTests {
    private let center = CGPoint(x: 100, y: 100)

    @Test func clockwiseTangentialSwipesResolveAtEveryCardinalPoint() {
        let swipes: [(location: String, start: CGPoint, end: CGPoint)] = [
            ("top", CGPoint(x: 100, y: 20), CGPoint(x: 140, y: 20)),
            ("right", CGPoint(x: 180, y: 100), CGPoint(x: 180, y: 140)),
            ("bottom", CGPoint(x: 100, y: 180), CGPoint(x: 60, y: 180)),
            ("left", CGPoint(x: 20, y: 100), CGPoint(x: 20, y: 60)),
        ]

        for swipe in swipes {
            #expect(
                BoardGestureInterpreter.direction(
                    from: swipe.start,
                    to: swipe.end,
                    around: center
                ) == .clockwise,
                "Clockwise swipe failed at the \(swipe.location) of the board"
            )
        }
    }

    @Test func counterClockwiseTangentialSwipesResolveAtEveryCardinalPoint() {
        let swipes: [(location: String, start: CGPoint, end: CGPoint)] = [
            ("top", CGPoint(x: 100, y: 20), CGPoint(x: 60, y: 20)),
            ("right", CGPoint(x: 180, y: 100), CGPoint(x: 180, y: 60)),
            ("bottom", CGPoint(x: 100, y: 180), CGPoint(x: 140, y: 180)),
            ("left", CGPoint(x: 20, y: 100), CGPoint(x: 20, y: 140)),
        ]

        for swipe in swipes {
            #expect(
                BoardGestureInterpreter.direction(
                    from: swipe.start,
                    to: swipe.end,
                    around: center
                ) == .counterClockwise,
                "Counter-clockwise swipe failed at the \(swipe.location) of the board"
            )
        }
    }

    @Test func radialAndShortSwipesAreRejected() {
        let radial = BoardGestureInterpreter.direction(
            from: CGPoint(x: 100, y: 20),
            to: CGPoint(x: 100, y: 70),
            around: center
        )
        let shortTangential = BoardGestureInterpreter.direction(
            from: CGPoint(x: 100, y: 20),
            to: CGPoint(x: 110, y: 20),
            around: center
        )
        let centerOrigin = BoardGestureInterpreter.direction(
            from: center,
            to: CGPoint(x: 140, y: 100),
            around: center
        )

        #expect(radial == nil)
        #expect(shortTangential == nil)
        #expect(centerOrigin == nil)
    }

    @Test func ringSelectionUsesDistanceFromBoardCenter() {
        let side: CGFloat = 400

        #expect(
            BoardGestureInterpreter.ring(
                at: CGPoint(x: center.x + 80, y: center.y),
                center: center,
                side: side
            ) == .inner
        )
        #expect(
            BoardGestureInterpreter.ring(
                at: CGPoint(x: center.x + 110, y: center.y),
                center: center,
                side: side
            ) == .middle
        )
        #expect(
            BoardGestureInterpreter.ring(
                at: CGPoint(x: center.x + 160, y: center.y),
                center: center,
                side: side
            ) == .outer
        )
    }
}

struct GameEngineTests {
    @Test func oneBloomScoresAndConsumesExactlyOneMove() throws {
        var engine = GameEngine(
            board: singleBloomBoard,
            seed: 7,
            targetBlooms: 5,
            moves: 9,
            selectedRing: .inner
        )

        let result = engine.rotate(.clockwise)
        let turn = try #require(result)

        #expect(turn.bloomSpokes == [0])
        #expect(turn.bloomCount == 1)
        #expect(turn.combo == 1)
        #expect(turn.streak == 1)
        #expect(turn.streakBonus == 0)
        #expect(turn.points == 100)
        #expect(turn.clearedPetalCount == 3)
        #expect(engine.score == 100)
        #expect(engine.blooms == 1)
        #expect(engine.movesRemaining == 8)
        #expect(engine.board.isStable)
    }

    @Test func simultaneousBloomsApplyComboMultiplier() throws {
        var engine = GameEngine(
            board: doubleBloomBoard,
            seed: 9,
            targetBlooms: 5,
            moves: 9,
            selectedRing: .inner
        )

        let result = engine.rotate(.clockwise)
        let turn = try #require(result)

        #expect(turn.bloomSpokes == [0, 4])
        #expect(turn.bloomCount == 2)
        #expect(turn.combo == 2)
        #expect(turn.streak == 1)
        #expect(turn.streakBonus == 0)
        #expect(turn.points == 400)
        #expect(turn.clearedPetalCount == 6)
        #expect(engine.score == 400)
        #expect(engine.blooms == 2)
    }

    @Test func consecutiveBloomsBuildAStreakBonusAndAMissResetsIt() throws {
        var engine = GameEngine(
            board: singleBloomBoard,
            seed: 73,
            targetBlooms: 100,
            moves: 20,
            selectedRing: .inner
        )

        let firstResult = engine.rotate(.clockwise)
        let first = try #require(firstResult)
        #expect(first.streak == 1)
        #expect(first.streakBonus == 0)

        let scoringMove = try #require(engine.board.suggestedMove)
        engine.select(scoringMove.ring)
        let secondResult = engine.rotate(scoringMove.direction)
        let second = try #require(secondResult)
        #expect(second.streak == 2)
        #expect(second.streakBonus == 50 * second.bloomCount)
        #expect(second.points == 100 * second.bloomCount * second.combo + second.streakBonus)
        #expect(engine.bestStreak == 2)

        let miss = try #require(allMoves.first { move in
            engine.board.rotated(move.ring, direction: move.direction).bloomSpokes.isEmpty
        })
        engine.select(miss.ring)
        let missedResult = engine.rotate(miss.direction)
        let missedTurn = try #require(missedResult)
        #expect(missedTurn.bloomCount == 0)
        #expect(missedTurn.streak == 0)
        #expect(missedTurn.streakBonus == 0)
        #expect(engine.streak == 0)
        #expect(engine.bestStreak == 2)
    }

    @Test func hintsAreLimitedToThreeAndOnlyReturnScoringMoves() throws {
        var engine = GameEngine(seed: 0xA11CE, garden: 4)

        for expectedRemaining in stride(from: 2, through: 0, by: -1) {
            let hint = engine.requestHint()
            let move = try #require(hint)
            #expect(engine.board.rotated(move.ring, direction: move.direction).bloomSpokes.isEmpty == false)
            #expect(engine.hintsRemaining == expectedRemaining)
        }

        #expect(engine.hintsUsed == 3)
        let exhaustedHint = engine.requestHint()
        #expect(exhaustedHint == nil)
        #expect(engine.hintsRemaining == 0)
        #expect(engine.hintsUsed == 3)
    }

    @Test func engineCodableRoundTripPreservesRandomStateAndSession() throws {
        var original = GameEngine(seed: 0xC0DA_B1E, garden: 5)
        _ = original.requestHint()
        let firstMove = try #require(original.board.suggestedMove)
        original.select(firstMove.ring)
        let firstResult = original.rotate(firstMove.direction)
        _ = try #require(firstResult)

        let data = try JSONEncoder().encode(original)
        var restored = try JSONDecoder().decode(GameEngine.self, from: data)
        #expect(restored == original)

        let nextMove = try #require(original.board.suggestedMove)
        original.select(nextMove.ring)
        restored.select(nextMove.ring)
        let originalResult = original.rotate(nextMove.direction)
        let restoredResult = restored.rotate(nextMove.direction)
        #expect(originalResult == restoredResult)
        #expect(restored == original)
    }

    @Test func efficientHintFreeCompletionIsRadiantAndAwardsRemainingMoveBonus() throws {
        var engine = GameEngine(seed: 0xB100, garden: 1)
        var turnPoints = 0

        while engine.phase == .playing {
            let move = try #require(engine.board.suggestedMove)
            engine.select(move.ring)
            let result = engine.rotate(move.direction)
            let turn = try #require(result)
            turnPoints += turn.points
        }

        #expect(engine.phase == .won)
        #expect(engine.completionBonus == 25 * engine.movesRemaining)
        #expect(engine.score == turnPoints + engine.completionBonus)
        #expect(engine.gardenRating == .radiant)
        #expect(engine.bestStreak >= 3)
        #expect(engine.hintsUsed == 0)
    }

    @Test func usingAHintCapsAnOtherwiseStrongCompletionAtFlourishing() throws {
        var engine = GameEngine(seed: 0xB100, garden: 1)
        let hint = engine.requestHint()
        let hintedMove = try #require(hint)
        engine.select(hintedMove.ring)
        let hintedResult = engine.rotate(hintedMove.direction)
        _ = try #require(hintedResult)

        while engine.phase == .playing {
            let move = try #require(engine.board.suggestedMove)
            engine.select(move.ring)
            let result = engine.rotate(move.direction)
            _ = try #require(result)
        }

        #expect(engine.phase == .won)
        #expect(engine.gardenRating == .flourishing)
        #expect(engine.hintsUsed == 1)
    }

    @Test func lastMoveSingleBloomCompletionIsSeedling() throws {
        var engine = GameEngine(
            board: singleBloomBoard,
            seed: 11,
            targetBlooms: 1,
            moves: 1,
            selectedRing: .inner
        )

        let result = engine.rotate(.clockwise)
        _ = try #require(result)

        #expect(engine.gardenRating == .seedling)
        #expect(engine.completionBonus == 0)
    }

    @Test func reachingTargetOnLastMoveWins() throws {
        var engine = GameEngine(
            board: singleBloomBoard,
            seed: 11,
            targetBlooms: 1,
            moves: 1,
            selectedRing: .inner
        )

        let result = engine.rotate(.clockwise)
        let turn = try #require(result)

        #expect(turn.phase == .won)
        #expect(engine.phase == .won)
        #expect(engine.movesRemaining == 0)
    }

    @Test func exhaustingMovesBeforeTargetLoses() throws {
        var engine = GameEngine(
            board: singleBloomBoard,
            seed: 13,
            targetBlooms: 1,
            moves: 1,
            selectedRing: .inner
        )

        let result = engine.rotate(.counterClockwise)
        let turn = try #require(result)

        #expect(turn.bloomCount == 0)
        #expect(turn.points == 0)
        #expect(turn.phase == .lost)
        #expect(engine.phase == .lost)
    }

    @Test func terminalGameRejectsFurtherRotations() throws {
        var engine = GameEngine(
            board: singleBloomBoard,
            seed: 17,
            targetBlooms: 1,
            moves: 1,
            selectedRing: .inner
        )
        let winningResult = engine.rotate(.clockwise)
        _ = try #require(winningResult)
        let terminalBoard = engine.board

        let ignoredResult = engine.rotate(.counterClockwise)
        #expect(ignoredResult == nil)
        #expect(engine.board == terminalBoard)
        #expect(engine.movesRemaining == 0)
    }

    @Test func deadStableBoardIsRepairedWithoutConsumingMove() {
        var engine = GameEngine(board: deadBoard, seed: 19, targetBlooms: 5, moves: 6)
        let movesBeforeRepair = engine.movesRemaining

        let didRepair = engine.repairBoardIfNeeded()
        #expect(didRepair)
        #expect(engine.board.isStable)
        #expect(engine.board.hasOneMoveBloom)
        #expect(engine.movesRemaining == movesBeforeRepair)
        let repeatedRepair = engine.repairBoardIfNeeded()
        #expect(repeatedRepair == false)
    }

    @Test func deadBoardAutomaticallyReshufflesAfterPaidRotation() throws {
        var engine = GameEngine(board: deadBoard, seed: 23, targetBlooms: 5, moves: 6)

        let result = engine.rotate(.clockwise)
        let turn = try #require(result)

        #expect(turn.bloomCount == 0)
        #expect(turn.didReshuffle)
        #expect(engine.movesRemaining == 5)
        #expect(engine.board.isStable)
        #expect(engine.board.hasOneMoveBloom)
    }

    @Test func generatedBoardsAreStableAndGuaranteeAOneMoveBloom() {
        for seed in UInt64(0)..<128 {
            let engine = GameEngine(seed: seed)
            #expect(engine.board.isStable, "Seed \(seed) produced an unstable board")
            #expect(engine.board.hasOneMoveBloom, "Seed \(seed) produced a dead board")
        }
    }

    @Test(arguments: UInt64(0)..<32)
    func gardenOneStartsWithAtLeastTwoSingleBloomMoves(seed: UInt64) {
        let board = GameEngine(seed: seed, garden: 1).board
        let scoringMoves = board.scoringMoves

        #expect(scoringMoves.count >= 2, "Seed \(seed) did not offer two opening choices")
        for move in scoringMoves {
            #expect(
                board.rotated(move.ring, direction: move.direction).bloomSpokes.count == 1,
                "Seed \(seed) offered an opening multi-bloom"
            )
        }
    }

    @Test(
        arguments: [1, 3, 5, 8, 20],
        [UInt64(0), 1, 42, 0xCAFE_BABE]
    )
    func suggestedPathWinsWithinBudget(garden: Int, seed: UInt64) throws {
        var engine = GameEngine(seed: seed, garden: garden)

        while engine.phase == .playing {
            let move = try #require(engine.board.suggestedMove, "Garden \(garden), seed \(seed) became unsolvable")
            engine.select(move.ring)
            let result = engine.rotate(move.direction)
            _ = try #require(result)
        }

        #expect(engine.phase == .won, "Garden \(garden), seed \(seed) did not complete")
        #expect(engine.movesRemaining >= 0)
    }

    @Test func equalSeedsProduceEqualGamesAndTurnResults() {
        var first = GameEngine(seed: 0xCAFE_BABE, garden: 4)
        var second = GameEngine(seed: 0xCAFE_BABE, garden: 4)

        #expect(first == second)
        first.select(.outer)
        second.select(.outer)
        let firstTurn = first.rotate(.clockwise)
        let secondTurn = second.rotate(.clockwise)

        #expect(firstTurn == secondTurn)
        #expect(first == second)
    }

    @Test func difficultyCurveIsCapped() {
        #expect(GameDifficulty.forGarden(1) == GameDifficulty(targetBlooms: 5, moveBudget: 14, activeKindCount: 3))
        #expect(GameDifficulty.forGarden(2) == GameDifficulty(targetBlooms: 6, moveBudget: 14, activeKindCount: 3))
        #expect(GameDifficulty.forGarden(3).activeKindCount == 4)
        #expect(GameDifficulty.forGarden(5) == GameDifficulty(targetBlooms: 7, moveBudget: 13, activeKindCount: 4))
        #expect(GameDifficulty.forGarden(100).targetBlooms == 9)
        #expect(GameDifficulty.forGarden(100).moveBudget == 13)
    }
}

@MainActor
struct GameModelTests {
    @Test func retryRestoresTheSameDeterministicGarden() throws {
        let model = GameModel(seed: 29)
        let initialBoard = model.board
        let initialMoves = model.movesRemaining
        let move = try #require(model.suggestedMove)

        model.select(move.ring)
        _ = model.rotate(move.direction)
        model.retry()

        #expect(model.board == initialBoard)
        #expect(model.movesRemaining == initialMoves)
        #expect(model.score == 0)
        #expect(model.phase == .playing)
    }

    @Test func productionModelRestoresAndPersistsAnActiveSession() throws {
        let activeSeed: UInt64 = 0xAC71_E
        var activeGame = GameEngine(seed: activeSeed, garden: 3)
        let hint = activeGame.requestHint()
        let hintedMove = try #require(hint)
        activeGame.select(hintedMove.ring)
        let result = activeGame.rotate(hintedMove.direction)
        _ = try #require(result)

        let store = InMemoryGameProgressStore(
            progress: GameProgress(
                bestScore: 250,
                highestGarden: 3,
                globalBestStreak: 2,
                radiantGardens: [1, 2],
                activeGame: activeGame,
                activeGardenSeed: activeSeed
            )
        )
        let model = GameModel(launchMode: .production, progressStore: store)

        #expect(model.hasActiveGarden)
        #expect(model.bestScore == 250)
        #expect(model.highestGarden == 3)
        #expect(model.garden == 3)
        #expect(model.board == activeGame.board)
        #expect(model.score == activeGame.score)
        #expect(model.hintsUsed == 1)
        #expect(model.globalBestStreak == 2)
        #expect(model.radiantGardens == [1, 2])

        model.select(.outer)
        #expect(store.progress.activeGame?.selectedRing == .outer)
        #expect(store.progress.activeGardenSeed == activeSeed)

        model.retry()
        let expectedRetry = GameEngine(seed: activeSeed, garden: 3)
        #expect(model.board == expectedRetry.board)
        #expect(model.hintsRemaining == GameEngine.hintsPerGarden)
        #expect(store.progress.activeGame == GameEngine(seed: activeSeed, garden: 3))
    }

    @Test func deterministicLaunchIgnoresPersistedProductionSession() {
        let activeGame = GameEngine(seed: 99, garden: 7)
        let store = InMemoryGameProgressStore(
            progress: GameProgress(
                bestScore: 1_000,
                highestGarden: 7,
                activeGame: activeGame,
                activeGardenSeed: 99
            )
        )

        let model = GameModel(seed: 31, progressStore: store)

        #expect(model.hasActiveGarden == false)
        #expect(model.garden == 7)
        #expect(model.board != activeGame.board)
    }

    @Test func modelPersistsHintsAndClearsActiveSessionAfterRadiantWin() throws {
        let store = InMemoryGameProgressStore()
        let model = GameModel(seed: 0xB100, progressStore: store)
        model.startGarden(1)

        while model.phase == .playing {
            let move = try #require(model.suggestedMove)
            model.select(move.ring)
            _ = try #require(model.rotate(move.direction))
        }

        #expect(model.phase == .won)
        #expect(model.hasActiveGarden == false)
        #expect(model.gardenRating == .radiant)
        #expect(model.globalBestStreak == model.bestStreak)
        #expect(model.radiantGardens.contains(1))
        #expect(model.highestGarden == 2)
        #expect(store.progress.activeGame == nil)
        #expect(store.progress.activeGardenSeed == nil)
        #expect(store.progress.radiantGardens.contains(1))
    }

    @Test func modelHintRequestPersistsItsLimitedUse() throws {
        let store = InMemoryGameProgressStore()
        let model = GameModel(seed: 37, progressStore: store)
        model.startGarden(1)

        _ = try #require(model.requestHint())

        #expect(model.hintsRemaining == 2)
        #expect(model.hintsUsed == 1)
        #expect(store.progress.activeGame?.hintsRemaining == 2)
        #expect(store.progress.activeGame?.hintsUsed == 1)
    }

    @Test func legacyProgressFileMigratesWithoutRoundTwoKeys() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RingbloomTests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("progress.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let legacyJSON = """
        {
          "bestScore": 725,
          "highestGarden": 4,
          "soundEnabled": false,
          "hapticsEnabled": true
        }
        """
        try Data(legacyJSON.utf8).write(to: fileURL)

        let progress = FileGameProgressStore(fileURL: fileURL).load()

        #expect(progress.bestScore == 725)
        #expect(progress.highestGarden == 4)
        #expect(progress.globalBestStreak == 0)
        #expect(progress.radiantGardens.isEmpty)
        #expect(progress.activeGame == nil)
        #expect(progress.activeGardenSeed == nil)
    }

    @Test func launchModesParseSeedsAndRemainExplicit() {
        #expect(GameLaunchMode.detect(arguments: ["app"]) == .production)
        #expect(
            GameLaunchMode.detect(arguments: ["app", "--ui-testing", "--seed=42"])
                == .uiTest(seed: 42)
        )
        #expect(
            GameLaunchMode.detect(arguments: ["app", "--screenshot-mode"])
                == .screenshot(seed: GameLaunchMode.defaultScreenshotSeed)
        )
    }
}
