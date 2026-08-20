import Combine
import Foundation

// MARK: - Public game vocabulary

enum PetalKind: Int, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case coral
    case saffron
    case mint
    case sky

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .coral: "Coral"
        case .saffron: "Saffron"
        case .mint: "Mint"
        case .sky: "Sky"
        }
    }

    /// A redundant shape cue so a petal is never identified by colour alone.
    var glyph: String {
        switch self {
        case .coral: "●"
        case .saffron: "◆"
        case .mint: "▲"
        case .sky: "✦"
        }
    }
}

enum Ring: Int, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case inner
    case middle
    case outer

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .inner: "Inner"
        case .middle: "Middle"
        case .outer: "Outer"
        }
    }
}

enum RotationDirection: Int, CaseIterable, Codable, Hashable, Sendable {
    case clockwise
    case counterClockwise

    var displayName: String {
        switch self {
        case .clockwise: "Clockwise"
        case .counterClockwise: "Counter-clockwise"
        }
    }

    var slotOffset: Int {
        switch self {
        case .clockwise: 1
        case .counterClockwise: -1
        }
    }
}

enum GamePhase: String, Codable, Equatable, Sendable {
    case playing
    case won
    case lost
}

struct GameMove: Codable, Equatable, Hashable, Sendable {
    let ring: Ring
    let direction: RotationDirection
}

struct TurnResult: Codable, Equatable, Identifiable, Sendable {
    let turnNumber: Int
    let ring: Ring
    let direction: RotationDirection
    let bloomSpokes: [Int]
    let combo: Int
    let streak: Int
    let streakBonus: Int
    let points: Int
    let phase: GamePhase
    let didReshuffle: Bool

    var id: Int { turnNumber }
    var bloomCount: Int { bloomSpokes.count }
    var clearedPetalCount: Int { bloomCount * Ring.allCases.count }
}

// MARK: - Board

struct GameBoard: Codable, Equatable, Hashable, Sendable {
    static let ringCount = 3
    static let slotsPerRing = 8

    private(set) var rings: [[PetalKind]]

    /// Synthesised `Decodable` bypasses the validating initialiser, so persisted boards must
    /// prove their shape before any subscript or bloom calculation consumes them.
    var hasValidDimensions: Bool {
        rings.count == Self.ringCount
            && rings.allSatisfy { $0.count == Self.slotsPerRing }
    }

    init(inner: [PetalKind], middle: [PetalKind], outer: [PetalKind]) {
        self.init(rings: [inner, middle, outer])
    }

    init(repeating kind: PetalKind) {
        rings = Array(
            repeating: Array(repeating: kind, count: Self.slotsPerRing),
            count: Self.ringCount
        )
    }

    init(rings: [[PetalKind]]) {
        precondition(rings.count == Self.ringCount, "A Ringbloom board must contain three rings.")
        precondition(
            rings.allSatisfy { $0.count == Self.slotsPerRing },
            "Every Ringbloom ring must contain eight petals."
        )
        self.rings = rings
    }

    subscript(_ ring: Ring, _ slot: Int) -> PetalKind {
        rings[ring.rawValue][Self.normalized(slot)]
    }

    func petals(in ring: Ring) -> [PetalKind] {
        rings[ring.rawValue]
    }

    var bloomSpokes: [Int] {
        (0 ..< Self.slotsPerRing).filter { slot in
            let kind = self[.inner, slot]
            return self[.middle, slot] == kind && self[.outer, slot] == kind
        }
    }

    var isStable: Bool { bloomSpokes.isEmpty }

    /// Whether at least one of the six legal moves creates a radial trio.
    var hasOneMoveBloom: Bool {
        scoringMoves.isEmpty == false
    }

    /// Every legal move that produces at least one bloom, in stable deterministic order.
    var scoringMoves: [GameMove] {
        guard isStable else { return [] }

        return Ring.allCases.flatMap { ring in
            RotationDirection.allCases.compactMap { direction in
                let move = GameMove(ring: ring, direction: direction)
                return rotated(ring, direction: direction).bloomSpokes.isEmpty ? nil : move
            }
        }
    }

    var scoringRings: Set<Ring> {
        Set(scoringMoves.map(\.ring))
    }

    /// A deterministic legal move that will bloom on the current stable board.
    var suggestedMove: GameMove? {
        scoringMoves.first
    }

    func bloomSpokes(after move: GameMove) -> [Int] {
        rotated(move.ring, direction: move.direction).bloomSpokes
    }

    func rotated(_ ring: Ring, direction: RotationDirection) -> GameBoard {
        var copy = self
        copy.rotate(ring, direction: direction)
        return copy
    }

    mutating func rotate(_ ring: Ring, direction: RotationDirection) {
        let source = rings[ring.rawValue]
        var destination = source

        for sourceSlot in source.indices {
            let destinationSlot = Self.normalized(sourceSlot + direction.slotOffset)
            destination[destinationSlot] = source[sourceSlot]
        }

        rings[ring.rawValue] = destination
    }

    mutating func set(_ kind: PetalKind, at slot: Int, in ring: Ring) {
        rings[ring.rawValue][Self.normalized(slot)] = kind
    }

    static func normalized(_ slot: Int) -> Int {
        let remainder = slot % slotsPerRing
        return remainder >= 0 ? remainder : remainder + slotsPerRing
    }
}

// MARK: - Deterministic engine

struct GameDifficulty: Codable, Equatable, Sendable {
    let targetBlooms: Int
    let moveBudget: Int
    let activeKindCount: Int

    static func forGarden(_ garden: Int) -> GameDifficulty {
        let level = max(1, garden)
        return switch level {
        case 1:
            GameDifficulty(targetBlooms: 5, moveBudget: 14, activeKindCount: 3)
        case 2:
            GameDifficulty(targetBlooms: 6, moveBudget: 14, activeKindCount: 3)
        case 3:
            GameDifficulty(targetBlooms: 6, moveBudget: 14, activeKindCount: 4)
        case 4:
            GameDifficulty(targetBlooms: 7, moveBudget: 14, activeKindCount: 4)
        case 5:
            GameDifficulty(targetBlooms: 7, moveBudget: 13, activeKindCount: 4)
        case 6 ... 7:
            GameDifficulty(targetBlooms: 8, moveBudget: 13, activeKindCount: 4)
        default:
            GameDifficulty(targetBlooms: 9, moveBudget: 13, activeKindCount: 4)
        }
    }
}

enum GardenRating: String, CaseIterable, Codable, Equatable, Sendable {
    case seedling
    case flourishing
    case radiant

    var displayName: String {
        switch self {
        case .seedling: "Seedling"
        case .flourishing: "Flourishing"
        case .radiant: "Radiant"
        }
    }

    var symbol: String {
        switch self {
        case .seedling: "leaf"
        case .flourishing: "leaf.fill"
        case .radiant: "sparkles"
        }
    }
}

struct GameEngine: Codable, Equatable, Sendable {
    private static let pointsPerBloom = 100
    private static let streakBonusPerBloom = 50
    static let hintsPerGarden = 3
    static let hintsPerFlowerShowClass = 1

    private(set) var board: GameBoard
    private(set) var selectedRing: Ring
    private(set) var score: Int
    private(set) var garden: Int
    private(set) var blooms: Int
    private(set) var targetBlooms: Int
    private(set) var movesRemaining: Int
    private(set) var phase: GamePhase
    private(set) var lastTurn: TurnResult?
    private(set) var streak: Int
    private(set) var bestStreak: Int
    private(set) var hintsRemaining: Int
    private(set) var hintsUsed: Int
    private(set) var completionBonus: Int
    private(set) var gardenRating: GardenRating
    private(set) var flowerShowClass: FlowerShowClassDefinition?
    private(set) var harmonyRings: Set<Ring>
    private(set) var infectedSpokes: Set<Int>
    private(set) var bindweedSpreadCountdown: Int?
    private(set) var twinBloomCompleted: Bool
    private(set) var didUseUndo: Bool

    private var random: SeededRandom
    private let activeKindCount: Int
    private var turnNumber: Int
    private var undoSnapshot: Snapshot?

    var mode: GameMode { flowerShowClass == nil ? .garden : .flowerShow }

    var objectivesComplete: Bool {
        guard let definition = flowerShowClass else { return true }
        let harmonyComplete = definition.objectives.requiresHarmony == false
            || harmonyRings == Set(Ring.allCases)
        let chainComplete = definition.objectives.requiredUnbrokenChain.map { bestStreak >= $0 } ?? true
        let bindweedComplete = definition.objectives.startingBindweedSpokes.isEmpty || infectedSpokes.isEmpty
        let twinBloomComplete = definition.objectives.requiresTwinBloom == false || twinBloomCompleted
        return harmonyComplete && chainComplete && bindweedComplete && twinBloomComplete
    }

    var unfinishedHarmonyRings: Set<Ring> {
        guard flowerShowClass?.objectives.requiresHarmony == true else { return [] }
        return Set(Ring.allCases).subtracting(harmonyRings)
    }

    var canUndo: Bool {
        flowerShowClass != nil && didUseUndo == false && undoSnapshot != nil
    }

    private struct Snapshot: Codable, Equatable, Sendable {
        let board: GameBoard
        let selectedRing: Ring
        let score: Int
        let blooms: Int
        let movesRemaining: Int
        let phase: GamePhase
        let lastTurn: TurnResult?
        let streak: Int
        let bestStreak: Int
        let hintsRemaining: Int
        let hintsUsed: Int
        let completionBonus: Int
        let gardenRating: GardenRating
        let random: SeededRandom
        let turnNumber: Int
        let harmonyRings: Set<Ring>
        let infectedSpokes: Set<Int>
        let bindweedSpreadCountdown: Int?
        let twinBloomCompleted: Bool

        init(engine: GameEngine) {
            board = engine.board
            selectedRing = engine.selectedRing
            score = engine.score
            blooms = engine.blooms
            movesRemaining = engine.movesRemaining
            phase = engine.phase
            lastTurn = engine.lastTurn
            streak = engine.streak
            bestStreak = engine.bestStreak
            hintsRemaining = engine.hintsRemaining
            hintsUsed = engine.hintsUsed
            completionBonus = engine.completionBonus
            gardenRating = engine.gardenRating
            random = engine.random
            turnNumber = engine.turnNumber
            harmonyRings = engine.harmonyRings
            infectedSpokes = engine.infectedSpokes
            bindweedSpreadCountdown = engine.bindweedSpreadCountdown
            twinBloomCompleted = engine.twinBloomCompleted
        }

        private enum CodingKeys: String, CodingKey {
            case board, selectedRing, score, blooms, movesRemaining, phase, lastTurn
            case streak, bestStreak, hintsRemaining, hintsUsed, completionBonus, gardenRating
            case random, turnNumber, harmonyRings, infectedSpokes, bindweedSpreadCountdown
            case twinBloomCompleted
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            board = try container.decode(GameBoard.self, forKey: .board)
            selectedRing = try container.decode(Ring.self, forKey: .selectedRing)
            score = try container.decode(Int.self, forKey: .score)
            blooms = try container.decode(Int.self, forKey: .blooms)
            movesRemaining = try container.decode(Int.self, forKey: .movesRemaining)
            phase = try container.decode(GamePhase.self, forKey: .phase)
            lastTurn = try container.decodeIfPresent(TurnResult.self, forKey: .lastTurn)
            streak = try container.decode(Int.self, forKey: .streak)
            bestStreak = try container.decode(Int.self, forKey: .bestStreak)
            hintsRemaining = try container.decode(Int.self, forKey: .hintsRemaining)
            hintsUsed = try container.decode(Int.self, forKey: .hintsUsed)
            completionBonus = try container.decode(Int.self, forKey: .completionBonus)
            gardenRating = try container.decode(GardenRating.self, forKey: .gardenRating)
            random = try container.decode(SeededRandom.self, forKey: .random)
            turnNumber = try container.decode(Int.self, forKey: .turnNumber)
            harmonyRings = try container.decodeIfPresent(Set<Ring>.self, forKey: .harmonyRings) ?? []
            infectedSpokes = try container.decodeIfPresent(Set<Int>.self, forKey: .infectedSpokes) ?? []
            bindweedSpreadCountdown = try container.decodeIfPresent(Int.self, forKey: .bindweedSpreadCountdown)
            twinBloomCompleted = try container.decodeIfPresent(Bool.self, forKey: .twinBloomCompleted) ?? false
        }
    }

    init(seed: UInt64, garden: Int = 1) {
        let garden = max(1, garden)
        let difficulty = GameDifficulty.forGarden(garden)
        var random = SeededRandom(seed: seed)
        let board = GameBoard.generatedPlayable(
            activeKindCount: difficulty.activeKindCount,
            isOpeningGarden: garden == 1,
            using: &random
        )

        self.board = board
        selectedRing = .middle
        score = 0
        self.garden = garden
        blooms = 0
        targetBlooms = difficulty.targetBlooms
        movesRemaining = difficulty.moveBudget
        phase = .playing
        lastTurn = nil
        streak = 0
        bestStreak = 0
        hintsRemaining = Self.hintsPerGarden
        hintsUsed = 0
        completionBonus = 0
        gardenRating = .seedling
        flowerShowClass = nil
        harmonyRings = []
        infectedSpokes = []
        bindweedSpreadCountdown = nil
        twinBloomCompleted = false
        didUseUndo = false
        self.random = random
        activeKindCount = difficulty.activeKindCount
        turnNumber = 0
        undoSnapshot = nil
    }

    init(flowerShow definition: FlowerShowClassDefinition, seed: UInt64? = nil) {
        var random = SeededRandom(seed: seed ?? definition.seed)
        let board = GameBoard.generatedPlayable(
            activeKindCount: definition.activeKindCount,
            isOpeningGarden: false,
            preferredRings: definition.objectives.requiresHarmony ? Set(Ring.allCases) : [],
            minimumScoringRingCount: definition.objectives.requiresHarmony ? 2 : 1,
            using: &random
        )

        self.board = board
        selectedRing = .middle
        score = 0
        garden = definition.number
        blooms = 0
        targetBlooms = definition.targetBlooms
        movesRemaining = definition.moveBudget
        phase = .playing
        lastTurn = nil
        streak = 0
        bestStreak = 0
        hintsRemaining = Self.hintsPerFlowerShowClass
        hintsUsed = 0
        completionBonus = 0
        gardenRating = .seedling
        flowerShowClass = definition
        harmonyRings = []
        infectedSpokes = Set(definition.objectives.startingBindweedSpokes)
        bindweedSpreadCountdown = infectedSpokes.isEmpty
            ? nil
            : FlowerShowClassDefinition.bindweedSpreadInterval
        twinBloomCompleted = false
        didUseUndo = false
        self.random = random
        activeKindCount = definition.activeKindCount
        turnNumber = 0
        undoSnapshot = nil
        _ = repairBoardIfNeeded()
    }

    /// Test- and tool-friendly initializer for a precisely authored board.
    init(
        board: GameBoard,
        seed: UInt64 = 1,
        garden: Int = 1,
        targetBlooms: Int = 5,
        moves: Int = 14,
        selectedRing: Ring = .middle
    ) {
        precondition(targetBlooms > 0, "The bloom target must be positive.")
        precondition(moves > 0, "The move budget must be positive.")

        self.board = board
        self.selectedRing = selectedRing
        score = 0
        self.garden = max(1, garden)
        blooms = 0
        self.targetBlooms = targetBlooms
        movesRemaining = moves
        phase = .playing
        lastTurn = nil
        streak = 0
        bestStreak = 0
        hintsRemaining = Self.hintsPerGarden
        hintsUsed = 0
        completionBonus = 0
        gardenRating = .seedling
        flowerShowClass = nil
        harmonyRings = []
        infectedSpokes = []
        bindweedSpreadCountdown = nil
        twinBloomCompleted = false
        didUseUndo = false
        random = SeededRandom(seed: seed)
        activeKindCount = GameDifficulty.forGarden(garden).activeKindCount
        turnNumber = 0
        undoSnapshot = nil
    }

    /// Test- and tooling-friendly initializer for an authored Flower Show state.
    init(
        board: GameBoard,
        flowerShow definition: FlowerShowClassDefinition,
        seed: UInt64 = 1,
        selectedRing: Ring = .middle,
        harmonyRings: Set<Ring> = [],
        infectedSpokes: Set<Int>? = nil,
        bindweedSpreadCountdown: Int? = nil,
        twinBloomCompleted: Bool = false
    ) {
        self.board = board
        self.selectedRing = selectedRing
        score = 0
        garden = definition.number
        blooms = 0
        targetBlooms = definition.targetBlooms
        movesRemaining = definition.moveBudget
        phase = .playing
        lastTurn = nil
        streak = 0
        bestStreak = 0
        hintsRemaining = Self.hintsPerFlowerShowClass
        hintsUsed = 0
        completionBonus = 0
        gardenRating = .seedling
        flowerShowClass = definition
        self.harmonyRings = harmonyRings
        self.infectedSpokes = infectedSpokes ?? Set(definition.objectives.startingBindweedSpokes)
        self.bindweedSpreadCountdown = self.infectedSpokes.isEmpty
            ? nil
            : (bindweedSpreadCountdown ?? FlowerShowClassDefinition.bindweedSpreadInterval)
        self.twinBloomCompleted = twinBloomCompleted
        didUseUndo = false
        random = SeededRandom(seed: seed)
        activeKindCount = definition.activeKindCount
        turnNumber = 0
        undoSnapshot = nil
    }

    mutating func select(_ ring: Ring) {
        selectedRing = ring
    }

    var suggestedMove: GameMove? {
        guard flowerShowClass != nil else { return board.suggestedMove }
        return board.scoringMoves.max { lhs, rhs in
            objectiveScore(for: lhs) < objectiveScore(for: rhs)
        }
    }

    /// Returns a guaranteed scoring move and consumes one of this garden's limited hints.
    @discardableResult
    mutating func requestHint() -> GameMove? {
        guard phase == .playing, hintsRemaining > 0 else {
            return nil
        }

        _ = repairBoardIfNeeded()
        guard let move = suggestedMove else { return nil }

        hintsRemaining -= 1
        hintsUsed += 1
        return move
    }

    @discardableResult
    mutating func rotate(_ direction: RotationDirection) -> TurnResult? {
        guard phase == .playing else { return nil }

        if flowerShowClass != nil, didUseUndo == false {
            undoSnapshot = Snapshot(engine: self)
        }

        let rotatedRing = selectedRing
        board.rotate(rotatedRing, direction: direction)
        movesRemaining -= 1
        turnNumber += 1

        let bloomSpokes = board.bloomSpokes
        let combo = bloomSpokes.count
        let basePoints = Self.pointsPerBloom * bloomSpokes.count * combo
        let streakBonus: Int

        if bloomSpokes.isEmpty == false {
            streak += 1
            bestStreak = max(bestStreak, streak)
            if flowerShowClass?.objectives.requiresHarmony == true {
                harmonyRings.insert(rotatedRing)
            }
            streakBonus = Self.streakBonusPerBloom * (streak - 1) * bloomSpokes.count
            blooms += bloomSpokes.count
            score += basePoints + streakBonus
            infectedSpokes.subtract(bloomSpokes)
            if flowerShowClass?.objectives.requiresTwinBloom == true, bloomSpokes.count >= 2 {
                twinBloomCompleted = true
            }
            board.refill(
                spokes: bloomSpokes,
                activeKindCount: activeKindCount,
                using: &random
            )
        } else {
            streak = 0
            streakBonus = 0
        }

        advanceBindweedAfterTurn()

        if blooms >= targetBlooms, objectivesComplete {
            phase = .won
            completionBonus = 25 * movesRemaining
            score += completionBonus
            gardenRating = resolvedGardenRating()
        } else if movesRemaining == 0 {
            phase = .lost
        }

        let didReshuffle = phase == .playing ? repairBoardIfNeeded() : false
        let result = TurnResult(
            turnNumber: turnNumber,
            ring: rotatedRing,
            direction: direction,
            bloomSpokes: bloomSpokes,
            combo: combo,
            streak: streak,
            streakBonus: streakBonus,
            points: basePoints + streakBonus,
            phase: phase,
            didReshuffle: didReshuffle
        )
        lastTurn = result
        return result
    }

    /// Repairs only a stable dead board. Returns whether a reshuffle occurred.
    @discardableResult
    mutating func repairBoardIfNeeded() -> Bool {
        guard board.isStable else { return false }

        if flowerShowClass == nil {
            guard board.hasOneMoveBloom == false else { return false }
            board.reshufflePlayable(activeKindCount: activeKindCount, using: &random)
            return true
        }

        let existingMoves = board.scoringMoves
        if existingMoves.contains(where: isFullyProductive) {
            return false
        }

        board.reshuffleObjectivePlayable(
            activeKindCount: activeKindCount,
            requiredSpokes: infectedSpokes,
            requiresTwinBloom: flowerShowClass?.objectives.requiresTwinBloom == true
                && twinBloomCompleted == false,
            preferredRings: unfinishedHarmonyRings,
            using: &random
        )
        return true
    }

    @discardableResult
    mutating func useUndo() -> Bool {
        guard canUndo, let snapshot = undoSnapshot else { return false }

        board = snapshot.board
        selectedRing = snapshot.selectedRing
        score = snapshot.score
        blooms = snapshot.blooms
        movesRemaining = snapshot.movesRemaining
        phase = snapshot.phase
        lastTurn = snapshot.lastTurn
        streak = snapshot.streak
        bestStreak = snapshot.bestStreak
        hintsRemaining = snapshot.hintsRemaining
        hintsUsed = snapshot.hintsUsed
        completionBonus = snapshot.completionBonus
        gardenRating = snapshot.gardenRating
        random = snapshot.random
        turnNumber = snapshot.turnNumber
        harmonyRings = snapshot.harmonyRings
        infectedSpokes = snapshot.infectedSpokes
        bindweedSpreadCountdown = snapshot.bindweedSpreadCountdown
        twinBloomCompleted = snapshot.twinBloomCompleted
        didUseUndo = true
        undoSnapshot = nil
        return true
    }

    private func objectiveScore(for move: GameMove) -> Int {
        let bloomSpokes = board.bloomSpokes(after: move)
        var score = bloomSpokes.count
        score += bloomSpokes.filter(infectedSpokes.contains).count * 1000
        if flowerShowClass?.objectives.requiresTwinBloom == true,
           twinBloomCompleted == false,
           bloomSpokes.count >= 2
        {
            score += 500
        }
        if unfinishedHarmonyRings.contains(move.ring) {
            score += 100
        }
        return score
    }

    private func isFullyProductive(_ move: GameMove) -> Bool {
        let bloomSpokes = board.bloomSpokes(after: move)
        guard bloomSpokes.isEmpty == false else { return false }
        if infectedSpokes.isEmpty == false,
           bloomSpokes.contains(where: infectedSpokes.contains) == false
        {
            return false
        }
        if flowerShowClass?.objectives.requiresTwinBloom == true,
           twinBloomCompleted == false,
           bloomSpokes.count < 2
        {
            return false
        }
        if unfinishedHarmonyRings.isEmpty == false,
           unfinishedHarmonyRings.contains(move.ring) == false
        {
            return false
        }
        return true
    }

    private mutating func advanceBindweedAfterTurn() {
        guard flowerShowClass?.objectives.startingBindweedSpokes.isEmpty == false else { return }
        guard infectedSpokes.isEmpty == false else {
            bindweedSpreadCountdown = nil
            return
        }

        let nextCountdown = (bindweedSpreadCountdown ?? FlowerShowClassDefinition.bindweedSpreadInterval) - 1
        if nextCountdown > 0 {
            bindweedSpreadCountdown = nextCountdown
            return
        }

        spreadBindweed()
        bindweedSpreadCountdown = FlowerShowClassDefinition.bindweedSpreadInterval
    }

    private mutating func spreadBindweed() {
        for spoke in infectedSpokes.sorted() {
            let adjacent = [
                GameBoard.normalized(spoke + 1),
                GameBoard.normalized(spoke - 1),
            ]
            if let next = adjacent.first(where: { infectedSpokes.contains($0) == false }) {
                infectedSpokes.insert(next)
                return
            }
        }
    }

    private func resolvedGardenRating() -> GardenRating {
        let startingMoves = max(1, movesRemaining + turnNumber)
        let efficiency = Double(movesRemaining) / Double(startingMoves)

        if hintsUsed == 0, efficiency >= 0.25, bestStreak >= 3 {
            return didUseUndo ? .flourishing : .radiant
        }
        if efficiency >= 0.10, bestStreak >= 2 {
            return .flourishing
        }
        return .seedling
    }

    private enum CodingKeys: String, CodingKey {
        case board
        case selectedRing
        case score
        case garden
        case blooms
        case targetBlooms
        case movesRemaining
        case phase
        case lastTurn
        case streak
        case bestStreak
        case hintsRemaining
        case hintsUsed
        case completionBonus
        case gardenRating
        case random
        case activeKindCount
        case turnNumber
        case flowerShowClass
        case harmonyRings
        case infectedSpokes
        case bindweedSpreadCountdown
        case twinBloomCompleted
        case didUseUndo
        case undoSnapshot
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        board = try container.decode(GameBoard.self, forKey: .board)
        selectedRing = try container.decode(Ring.self, forKey: .selectedRing)
        score = try container.decode(Int.self, forKey: .score)
        garden = try container.decode(Int.self, forKey: .garden)
        blooms = try container.decode(Int.self, forKey: .blooms)
        targetBlooms = try container.decode(Int.self, forKey: .targetBlooms)
        movesRemaining = try container.decode(Int.self, forKey: .movesRemaining)
        phase = try container.decode(GamePhase.self, forKey: .phase)
        lastTurn = try container.decodeIfPresent(TurnResult.self, forKey: .lastTurn)
        streak = try container.decode(Int.self, forKey: .streak)
        bestStreak = try container.decode(Int.self, forKey: .bestStreak)
        hintsRemaining = try container.decode(Int.self, forKey: .hintsRemaining)
        hintsUsed = try container.decode(Int.self, forKey: .hintsUsed)
        completionBonus = try container.decode(Int.self, forKey: .completionBonus)
        gardenRating = try container.decode(GardenRating.self, forKey: .gardenRating)
        random = try container.decode(SeededRandom.self, forKey: .random)
        activeKindCount = try container.decode(Int.self, forKey: .activeKindCount)
        turnNumber = try container.decode(Int.self, forKey: .turnNumber)
        flowerShowClass = try container.decodeIfPresent(FlowerShowClassDefinition.self, forKey: .flowerShowClass)
        harmonyRings = try container.decodeIfPresent(Set<Ring>.self, forKey: .harmonyRings) ?? []
        infectedSpokes = try container.decodeIfPresent(Set<Int>.self, forKey: .infectedSpokes)
            ?? Set(flowerShowClass?.objectives.startingBindweedSpokes ?? [])
        bindweedSpreadCountdown = try container.decodeIfPresent(Int.self, forKey: .bindweedSpreadCountdown)
        if infectedSpokes.isEmpty == false, bindweedSpreadCountdown == nil {
            bindweedSpreadCountdown = FlowerShowClassDefinition.bindweedSpreadInterval
        }
        twinBloomCompleted = try container.decodeIfPresent(Bool.self, forKey: .twinBloomCompleted) ?? false
        didUseUndo = try container.decodeIfPresent(Bool.self, forKey: .didUseUndo) ?? false
        undoSnapshot = try container.decodeIfPresent(Snapshot.self, forKey: .undoSnapshot)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(board, forKey: .board)
        try container.encode(selectedRing, forKey: .selectedRing)
        try container.encode(score, forKey: .score)
        try container.encode(garden, forKey: .garden)
        try container.encode(blooms, forKey: .blooms)
        try container.encode(targetBlooms, forKey: .targetBlooms)
        try container.encode(movesRemaining, forKey: .movesRemaining)
        try container.encode(phase, forKey: .phase)
        try container.encodeIfPresent(lastTurn, forKey: .lastTurn)
        try container.encode(streak, forKey: .streak)
        try container.encode(bestStreak, forKey: .bestStreak)
        try container.encode(hintsRemaining, forKey: .hintsRemaining)
        try container.encode(hintsUsed, forKey: .hintsUsed)
        try container.encode(completionBonus, forKey: .completionBonus)
        try container.encode(gardenRating, forKey: .gardenRating)
        try container.encode(random, forKey: .random)
        try container.encode(activeKindCount, forKey: .activeKindCount)
        try container.encode(turnNumber, forKey: .turnNumber)
        try container.encodeIfPresent(flowerShowClass, forKey: .flowerShowClass)
        try container.encode(harmonyRings, forKey: .harmonyRings)
        try container.encode(infectedSpokes, forKey: .infectedSpokes)
        try container.encodeIfPresent(bindweedSpreadCountdown, forKey: .bindweedSpreadCountdown)
        try container.encode(twinBloomCompleted, forKey: .twinBloomCompleted)
        try container.encode(didUseUndo, forKey: .didUseUndo)
        try container.encodeIfPresent(undoSnapshot, forKey: .undoSnapshot)
    }
}

// MARK: - Board generation and repair

private extension GameBoard {
    static func generatedPlayable(
        activeKindCount: Int,
        isOpeningGarden: Bool,
        preferredRings: Set<Ring> = [],
        minimumScoringRingCount: Int = 1,
        using random: inout SeededRandom
    ) -> GameBoard {
        let maximumAttempts = isOpeningGarden || minimumScoringRingCount > 1 ? 4096 : 128
        for _ in 0 ..< maximumAttempts {
            let candidate = randomBoard(activeKindCount: activeKindCount, using: &random)
            guard candidate.isStable else { continue }

            let scoringMoves = candidate.scoringMoves
            let hasPlayableOpening = scoringMoves.isEmpty == false
            let hasGentleOpening = scoringMoves.count >= 2 && scoringMoves.allSatisfy { move in
                candidate.rotated(move.ring, direction: move.direction).bloomSpokes.count == 1
            }
            let relevantScoringRings = candidate.scoringRings.intersection(
                preferredRings.isEmpty ? Set(Ring.allCases) : preferredRings
            )
            let meetsRingRequirement = relevantScoringRings.count >= minimumScoringRingCount

            if isOpeningGarden ? hasGentleOpening : hasPlayableOpening, meetsRingRequirement {
                return candidate
            }
        }

        var fallback = randomBoard(activeKindCount: activeKindCount, using: &random)
        if minimumScoringRingCount > 1 {
            fallback.forceScoringMoves(
                on: Array(
                    Ring.allCases
                        .filter { preferredRings.isEmpty || preferredRings.contains($0) }
                        .prefix(minimumScoringRingCount)
                ),
                activeKindCount: activeKindCount
            )
        } else {
            fallback.forceOneMoveBloom(
                activeKindCount: activeKindCount,
                preferredRings: preferredRings,
                using: &random
            )
        }
        return fallback
    }

    static func randomBoard(
        activeKindCount: Int,
        using random: inout SeededRandom
    ) -> GameBoard {
        let kinds = Array(PetalKind.allCases.prefix(max(2, min(activeKindCount, PetalKind.allCases.count))))
        let rings = (0 ..< ringCount).map { _ in
            (0 ..< slotsPerRing).map { _ in kinds[random.nextInt(upperBound: kinds.count)] }
        }
        return GameBoard(rings: rings)
    }

    mutating func refill(
        spokes: [Int],
        activeKindCount: Int,
        using random: inout SeededRandom
    ) {
        let kinds = Array(PetalKind.allCases.prefix(max(2, min(activeKindCount, PetalKind.allCases.count))))

        for slot in spokes {
            for ring in Ring.allCases {
                set(kinds[random.nextInt(upperBound: kinds.count)], at: slot, in: ring)
            }

            if self[.inner, slot] == self[.middle, slot],
               self[.middle, slot] == self[.outer, slot]
            {
                set(differentKind(from: self[.outer, slot], among: kinds), at: slot, in: .outer)
            }
        }
    }

    mutating func reshufflePlayable(
        activeKindCount: Int,
        preferredRings: Set<Ring> = [],
        minimumScoringRingCount: Int = 1,
        using random: inout SeededRandom
    ) {
        let originalPetals = rings.flatMap(\.self)

        for _ in 0 ..< 128 {
            var shuffled = originalPetals
            random.shuffle(&shuffled)
            let candidate = GameBoard(rings: stride(from: 0, to: shuffled.count, by: Self.slotsPerRing).map {
                Array(shuffled[$0 ..< ($0 + Self.slotsPerRing)])
            })

            let relevantScoringRings = candidate.scoringRings.intersection(
                preferredRings.isEmpty ? Set(Ring.allCases) : preferredRings
            )
            if candidate.isStable,
               candidate.hasOneMoveBloom,
               relevantScoringRings.count >= minimumScoringRingCount
            {
                self = candidate
                return
            }
        }

        self = Self.randomBoard(activeKindCount: activeKindCount, using: &random)
        forceOneMoveBloom(
            activeKindCount: activeKindCount,
            preferredRings: preferredRings,
            using: &random
        )
    }

    mutating func reshuffleObjectivePlayable(
        activeKindCount: Int,
        requiredSpokes: Set<Int>,
        requiresTwinBloom: Bool,
        preferredRings: Set<Ring>,
        using random: inout SeededRandom
    ) {
        let originalPetals = rings.flatMap(\.self)

        for _ in 0 ..< 256 {
            var shuffled = originalPetals
            random.shuffle(&shuffled)
            let candidate = GameBoard(rings: stride(from: 0, to: shuffled.count, by: Self.slotsPerRing).map {
                Array(shuffled[$0 ..< ($0 + Self.slotsPerRing)])
            })
            guard candidate.isStable else { continue }

            let hasObjectiveMove = candidate.scoringMoves.contains { move in
                let blooms = candidate.bloomSpokes(after: move)
                let clearsBindweed = requiredSpokes.isEmpty
                    || blooms.contains(where: requiredSpokes.contains)
                let completesTwin = requiresTwinBloom == false || blooms.count >= 2
                let advancesHarmony = preferredRings.isEmpty || preferredRings.contains(move.ring)
                return clearsBindweed && completesTwin && advancesHarmony
            }
            if hasObjectiveMove {
                self = candidate
                return
            }
        }

        self = Self.randomBoard(activeKindCount: activeKindCount, using: &random)
        forceObjectiveMove(
            activeKindCount: activeKindCount,
            requiredSpokes: requiredSpokes,
            requiresTwinBloom: requiresTwinBloom,
            preferredRings: preferredRings,
            using: &random
        )
    }

    mutating func forceObjectiveMove(
        activeKindCount: Int,
        requiredSpokes: Set<Int>,
        requiresTwinBloom: Bool,
        preferredRings: Set<Ring>,
        using random: inout SeededRandom
    ) {
        let kinds = Array(PetalKind.allCases.prefix(max(2, min(activeKindCount, PetalKind.allCases.count))))
        let availableRings = Ring.allCases.filter { preferredRings.isEmpty || preferredRings.contains($0) }
        let rotatingRing = availableRings[random.nextInt(upperBound: availableRings.count)]
        let direction = RotationDirection.allCases[random.nextInt(upperBound: RotationDirection.allCases.count)]
        let firstDestination = requiredSpokes.sorted().first
            ?? random.nextInt(upperBound: Self.slotsPerRing)
        var destinations = [firstDestination]
        if requiresTwinBloom {
            destinations.append(Self.normalized(firstDestination + 3))
        }

        let protectedSources = Set(destinations.map { Self.normalized($0 - direction.slotOffset) })
        for (index, destination) in destinations.enumerated() {
            let source = Self.normalized(destination - direction.slotOffset)
            let matchingKind = kinds[index % kinds.count]
            for ring in Ring.allCases where ring != rotatingRing {
                set(matchingKind, at: destination, in: ring)
            }
            set(matchingKind, at: source, in: rotatingRing)
            set(differentKind(from: matchingKind, among: kinds), at: destination, in: rotatingRing)
        }

        for bloomingSlot in bloomSpokes {
            let breakRing: Ring = if protectedSources.contains(bloomingSlot) {
                Ring.allCases.first { $0 != rotatingRing } ?? .inner
            } else {
                rotatingRing
            }
            set(
                differentKind(from: self[breakRing, bloomingSlot], among: kinds),
                at: bloomingSlot,
                in: breakRing
            )
        }

        let promisedMove = GameMove(ring: rotatingRing, direction: direction)
        let promisedBlooms = bloomSpokes(after: promisedMove)
        assert(isStable)
        assert(requiredSpokes.isEmpty || promisedBlooms.contains(where: requiredSpokes.contains))
        assert(requiresTwinBloom == false || promisedBlooms.count >= 2)
    }

    mutating func forceOneMoveBloom(
        activeKindCount: Int,
        preferredRings: Set<Ring> = [],
        using random: inout SeededRandom
    ) {
        let kinds = Array(PetalKind.allCases.prefix(max(2, min(activeKindCount, PetalKind.allCases.count))))
        let availableRings = Ring.allCases.filter { preferredRings.isEmpty || preferredRings.contains($0) }
        let rotatingRing = availableRings[random.nextInt(upperBound: availableRings.count)]
        let direction = RotationDirection.allCases[
            random.nextInt(upperBound: RotationDirection.allCases.count)
        ]
        let destinationSlot = random.nextInt(upperBound: Self.slotsPerRing)
        let sourceSlot = Self.normalized(destinationSlot - direction.slotOffset)
        let matchingKind = kinds[random.nextInt(upperBound: kinds.count)]

        for ring in Ring.allCases where ring != rotatingRing {
            set(matchingKind, at: destinationSlot, in: ring)
        }
        set(matchingKind, at: sourceSlot, in: rotatingRing)

        // Keep the pre-move board stable without disturbing the promised move.
        if self[rotatingRing, destinationSlot] == matchingKind {
            set(
                differentKind(from: matchingKind, among: kinds),
                at: destinationSlot,
                in: rotatingRing
            )
        }

        for bloomingSlot in bloomSpokes {
            let breakRing: Ring = if bloomingSlot == sourceSlot {
                Ring.allCases.first { $0 != rotatingRing } ?? .inner
            } else {
                rotatingRing
            }
            set(
                differentKind(from: self[breakRing, bloomingSlot], among: kinds),
                at: bloomingSlot,
                in: breakRing
            )
        }

        assert(isStable)
        assert(hasOneMoveBloom)
    }

    /// Builds stable, independent clockwise blooms for the requested rings. This is the
    /// deterministic last resort for Harmony openings, where two productive rings are a rule.
    mutating func forceScoringMoves(
        on rotatingRings: [Ring],
        activeKindCount: Int
    ) {
        precondition(rotatingRings.isEmpty == false)
        precondition(rotatingRings.count <= Ring.allCases.count)

        let kinds = Array(PetalKind.allCases.prefix(max(2, min(activeKindCount, PetalKind.allCases.count))))

        for (index, rotatingRing) in rotatingRings.enumerated() {
            let destinationSlot = index * 3
            let sourceSlot = Self.normalized(destinationSlot - RotationDirection.clockwise.slotOffset)
            let matchingKind = kinds[index % kinds.count]

            for ring in Ring.allCases where ring != rotatingRing {
                set(matchingKind, at: destinationSlot, in: ring)
            }
            set(matchingKind, at: sourceSlot, in: rotatingRing)
            set(differentKind(from: matchingKind, among: kinds), at: destinationSlot, in: rotatingRing)
        }

        // Break any accidental blooms without touching a promised destination or source.
        let protectedSourceOwners = Dictionary(uniqueKeysWithValues: rotatingRings.enumerated().map { index, ring in
            (Self.normalized(index * 3 - RotationDirection.clockwise.slotOffset), ring)
        })
        for bloomingSlot in bloomSpokes {
            let breakRing = Ring.allCases.first { $0 != protectedSourceOwners[bloomingSlot] } ?? .outer
            set(
                differentKind(from: self[breakRing, bloomingSlot], among: kinds),
                at: bloomingSlot,
                in: breakRing
            )
        }

        assert(isStable)
        assert(Set(rotatingRings).isSubset(of: scoringRings))
    }

    func differentKind(from kind: PetalKind, among kinds: [PetalKind]) -> PetalKind {
        kinds.first { $0 != kind } ?? PetalKind.allCases[(kind.rawValue + 1) % PetalKind.allCases.count]
    }
}

private struct SeededRandom: Codable, Equatable, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }

    mutating func nextInt(upperBound: Int) -> Int {
        precondition(upperBound > 0)
        return Int(next() % UInt64(upperBound))
    }

    mutating func shuffle(_ values: inout [some Any]) {
        guard values.count > 1 else { return }
        for index in stride(from: values.count - 1, through: 1, by: -1) {
            let other = nextInt(upperBound: index + 1)
            if index != other {
                values.swapAt(index, other)
            }
        }
    }
}

// MARK: - Progress persistence

struct ReviewRequestState: Codable, Equatable, Sendable {
    var successfulGardenCompletions: Int
    var attemptedAppVersion: String?
    var attemptedDate: Date?

    init(
        successfulGardenCompletions: Int = 0,
        attemptedAppVersion: String? = nil,
        attemptedDate: Date? = nil
    ) {
        self.successfulGardenCompletions = max(0, successfulGardenCompletions)
        self.attemptedAppVersion = attemptedAppVersion
        self.attemptedDate = attemptedDate
    }
}

enum ReviewRequestPolicy {
    static let minimumDaysBetweenAttempts = 120

    static func registerSuccessfulGarden(state: inout ReviewRequestState) {
        state.successfulGardenCompletions += 1
    }

    static func isEligible(
        state: ReviewRequestState,
        now: Date,
        appVersion: String
    ) -> Bool {
        guard state.successfulGardenCompletions >= 2 else { return false }
        guard appVersion.isEmpty == false else { return false }
        guard state.attemptedAppVersion != appVersion else { return false }

        if let attemptedDate = state.attemptedDate {
            let interval = now.timeIntervalSince(attemptedDate)
            let minimumInterval = TimeInterval(minimumDaysBetweenAttempts * 24 * 60 * 60)
            guard interval >= minimumInterval else { return false }
        }

        return true
    }

    static func recordAttemptIfEligible(
        state: inout ReviewRequestState,
        now: Date,
        appVersion: String
    ) -> Bool {
        guard isEligible(state: state, now: now, appVersion: appVersion) else { return false }
        // StoreKit does not report whether it showed anything, so this is recorded first.
        state.attemptedAppVersion = appVersion
        state.attemptedDate = now
        return true
    }
}

private struct LegacyFlowerShowProgressSnapshot: Decodable {
    let storedVersion: Int
    let completedCampaignClasses: Set<Int>
    let currentClass: Int
    let seenIntroductions: Set<FlowerShowIntroductionID>

    private enum CodingKeys: String, CodingKey {
        case flowerShowCampaignVersion
        case completedFlowerShowClasses
        case currentFlowerShowClass
        case seenFlowerShowIntroductions
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        storedVersion = (try? container.decode(Int.self, forKey: .flowerShowCampaignVersion)) ?? 1
        completedCampaignClasses = Set(
            ((try? container.decode(Set<Int>.self, forKey: .completedFlowerShowClasses)) ?? [])
                .filter { (1 ... FlowerShowContent.campaignClassCount).contains($0) }
        )
        currentClass = max(
            1,
            (try? container.decode(Int.self, forKey: .currentFlowerShowClass)) ?? 1
        )
        let introductionIDs = (try? container.decode(
            Set<String>.self,
            forKey: .seenFlowerShowIntroductions
        )) ?? []
        seenIntroductions = Set(introductionIDs.compactMap(Self.introductionID(from:)))
    }

    var migratedProgress: FlowerShowProgressV3 {
        FlowerShowProgressV3(
            bestCampaignRatings: Dictionary(
                uniqueKeysWithValues: completedCampaignClasses.map { ($0, .seedling) }
            ),
            nextCircuitClass: legacyCircuitCursor,
            seenIntroductions: seenIntroductions,
            pendingNoticeVersion: FlowerShowClassDefinition.campaignVersion
        )
    }

    func mergeMissingProgress(into progress: inout FlowerShowProgressV3) -> Bool {
        let original = progress
        for classNumber in completedCampaignClasses
            where progress.bestCampaignRatings[classNumber] == nil
        {
            progress.bestCampaignRatings[classNumber] = .seedling
        }
        progress.nextCircuitClass = max(progress.nextCircuitClass, legacyCircuitCursor)
        progress.seenIntroductions.formUnion(seenIntroductions)
        _ = progress.sanitiseDecodedState()
        return progress != original
    }

    private var legacyCircuitCursor: Int {
        guard currentClass >= FlowerShowContent.circuitStartClass else {
            return FlowerShowContent.circuitStartClass
        }
        return min(FlowerShowProgressV3.maximumCircuitClass, currentClass)
    }

    private static func introductionID(from rawValue: String) -> FlowerShowIntroductionID? {
        switch rawValue {
        case "ringHarmony", FlowerShowIntroductionID.harmony.rawValue:
            .harmony
        case FlowerShowIntroductionID.unbroken.rawValue:
            .unbroken
        case FlowerShowIntroductionID.bindweed.rawValue:
            .bindweed
        case FlowerShowIntroductionID.twinBloom.rawValue:
            .twinBloom
        case FlowerShowIntroductionID.prizeBouquet.rawValue:
            .prizeBouquet
        case FlowerShowIntroductionID.doubleHarmony.rawValue:
            .doubleHarmony
        case FlowerShowIntroductionID.judgesOrder.rawValue:
            .judgesOrder
        default:
            nil
        }
    }
}

struct GameProgress: Codable, Equatable, Sendable {
    var bestScore: Int
    var highestGarden: Int
    var globalBestStreak: Int
    var radiantGardens: Set<Int>
    var activeGame: GameEngine?
    var activeGardenSeed: UInt64?
    var flowerShowIntroduced: Bool
    var completedFlowerShowClasses: Set<Int>
    var currentFlowerShowClass: Int
    var activeFlowerShow: GameEngine?
    var seenFlowerShowIntroductions: Set<String>
    var grandChampionAchieved: Bool
    var flowerShowCampaignVersion: Int
    var flowerShowProgress: FlowerShowProgressV3
    var reviewRequestState: ReviewRequestState

    init(
        bestScore: Int,
        highestGarden: Int,
        globalBestStreak: Int = 0,
        radiantGardens: Set<Int> = [],
        activeGame: GameEngine? = nil,
        activeGardenSeed: UInt64? = nil,
        flowerShowIntroduced: Bool = false,
        completedFlowerShowClasses: Set<Int> = [],
        currentFlowerShowClass: Int = 1,
        activeFlowerShow: GameEngine? = nil,
        seenFlowerShowIntroductions: Set<String> = [],
        grandChampionAchieved: Bool? = nil,
        flowerShowCampaignVersion: Int = FlowerShowClassDefinition.campaignVersion,
        flowerShowProgress: FlowerShowProgressV3? = nil,
        reviewRequestState: ReviewRequestState? = nil
    ) {
        self.bestScore = bestScore
        self.highestGarden = highestGarden
        self.globalBestStreak = globalBestStreak
        self.radiantGardens = radiantGardens
        self.activeGame = activeGame
        self.activeGardenSeed = activeGardenSeed
        self.flowerShowIntroduced = flowerShowIntroduced
        self.completedFlowerShowClasses = completedFlowerShowClasses
        self.currentFlowerShowClass = currentFlowerShowClass
        self.activeFlowerShow = activeFlowerShow
        self.seenFlowerShowIntroductions = seenFlowerShowIntroductions
        self.grandChampionAchieved = grandChampionAchieved
            ?? completedFlowerShowClasses.contains(FlowerShowClassDefinition.classCount)
        self.flowerShowCampaignVersion = flowerShowCampaignVersion
        self.flowerShowProgress = flowerShowProgress ?? FlowerShowProgressV3(
            bestCampaignRatings: Dictionary(
                uniqueKeysWithValues: completedFlowerShowClasses
                    .filter { (1 ... 30).contains($0) }
                    .map { ($0, .seedling) }
            ),
            nextCircuitClass: currentFlowerShowClass > 30 ? currentFlowerShowClass : 31,
            seenIntroductions: Set(
                seenFlowerShowIntroductions.compactMap(FlowerShowIntroductionID.init(rawValue:))
            )
        )
        self.reviewRequestState = reviewRequestState
            ?? ReviewRequestState(successfulGardenCompletions: max(0, highestGarden - 1))
    }

    private enum CodingKeys: String, CodingKey {
        case bestScore
        case highestGarden
        case globalBestStreak
        case radiantGardens
        case activeGame
        case activeGardenSeed
        case flowerShowIntroduced
        case completedFlowerShowClasses
        case currentFlowerShowClass
        case activeFlowerShow
        case seenFlowerShowIntroductions
        case grandChampionAchieved
        case flowerShowCampaignVersion
        case flowerShowProgress
        case reviewRequestState

        // Round 1 stored these preferences here. They now belong solely to their services.
        case soundEnabled
        case hapticsEnabled
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyFlowerShowProgress = try LegacyFlowerShowProgressSnapshot(from: decoder)
        let decodedCampaignVersion = try container.decodeIfPresent(
            Int.self,
            forKey: .flowerShowCampaignVersion
        ) ?? 1
        bestScore = try container.decodeIfPresent(Int.self, forKey: .bestScore) ?? 0
        highestGarden = try container.decodeIfPresent(Int.self, forKey: .highestGarden) ?? 1
        globalBestStreak = try container.decodeIfPresent(Int.self, forKey: .globalBestStreak) ?? 0
        radiantGardens = try container.decodeIfPresent(Set<Int>.self, forKey: .radiantGardens) ?? []
        activeGame = try container.decodeIfPresent(GameEngine.self, forKey: .activeGame)
        activeGardenSeed = try container.decodeIfPresent(UInt64.self, forKey: .activeGardenSeed)
        if decodedCampaignVersion < FlowerShowClassDefinition.campaignVersion {
            flowerShowProgress = legacyFlowerShowProgress.migratedProgress
            flowerShowIntroduced = flowerShowProgress.completedCampaignClasses.isEmpty == false
            completedFlowerShowClasses = flowerShowProgress.completedCampaignClasses
            currentFlowerShowClass = flowerShowProgress.isGrandChampion
                ? flowerShowProgress.nextCircuitClass
                : flowerShowProgress.nextCampaignClass
            activeFlowerShow = nil
            seenFlowerShowIntroductions = Set(flowerShowProgress.seenIntroductions.map(\.rawValue))
            grandChampionAchieved = flowerShowProgress.isGrandChampion
            flowerShowCampaignVersion = FlowerShowClassDefinition.campaignVersion
        } else {
            var progress = try container.decodeIfPresent(
                FlowerShowProgressV3.self,
                forKey: .flowerShowProgress
            ) ?? FlowerShowProgressV3()
            progress.sanitiseDecodedState()
            flowerShowProgress = progress
            flowerShowIntroduced = progress.completedCampaignClasses.isEmpty == false
            completedFlowerShowClasses = progress.completedCampaignClasses
            currentFlowerShowClass = progress.isGrandChampion
                ? progress.nextCircuitClass
                : progress.nextCampaignClass
            activeFlowerShow = nil
            seenFlowerShowIntroductions = Set(progress.seenIntroductions.map(\.rawValue))
            grandChampionAchieved = progress.isGrandChampion
            flowerShowCampaignVersion = FlowerShowClassDefinition.campaignVersion
        }
        reviewRequestState = try container.decodeIfPresent(ReviewRequestState.self, forKey: .reviewRequestState)
            ?? ReviewRequestState(successfulGardenCompletions: max(0, highestGarden - 1))
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bestScore, forKey: .bestScore)
        try container.encode(highestGarden, forKey: .highestGarden)
        try container.encode(globalBestStreak, forKey: .globalBestStreak)
        try container.encode(radiantGardens, forKey: .radiantGardens)
        try container.encodeIfPresent(activeGame, forKey: .activeGame)
        try container.encodeIfPresent(activeGardenSeed, forKey: .activeGardenSeed)
        try container.encode(FlowerShowClassDefinition.campaignVersion, forKey: .flowerShowCampaignVersion)
        try container.encode(flowerShowProgress, forKey: .flowerShowProgress)
        try container.encode(reviewRequestState, forKey: .reviewRequestState)
    }

    static let fresh = GameProgress(
        bestScore: 0,
        highestGarden: 1
    )
}

@MainActor
protocol GameProgressStoring: AnyObject {
    func load() -> GameProgress
    func save(_ progress: GameProgress)
}

@MainActor
final class InMemoryGameProgressStore: GameProgressStoring {
    private(set) var progress: GameProgress

    init(progress: GameProgress = .fresh) {
        self.progress = progress
    }

    func load() -> GameProgress { progress }

    func save(_ progress: GameProgress) {
        self.progress = progress
    }
}

/// A small JSON store keeps engine persistence injectable and avoids coupling it to UserDefaults.
@MainActor
final class FileGameProgressStore: GameProgressStoring {
    private let fileURL: URL
    private(set) var lastLoadOutcome: GameProgressLoadOutcome = .fresh
    private(set) var persistenceEnabled = true

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let baseURL = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? FileManager.default.temporaryDirectory
            self.fileURL = baseURL
                .appendingPathComponent("Ringbloom", isDirectory: true)
                .appendingPathComponent("progress.json", isDirectory: false)
        }
    }

    func load() -> GameProgress {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            lastLoadOutcome = .fresh
            return .fresh
        }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            persistenceEnabled = false
            lastLoadOutcome = .failed(message: "Unable to read progress: \(error)")
            return .fresh
        }

        struct VersionHeader: Decodable {
            let flowerShowCampaignVersion: Int?
        }
        let versionHeader = try? JSONDecoder().decode(VersionHeader.self, from: data)
        let storedVersion = versionHeader?.flowerShowCampaignVersion ?? 1
        struct FlowerShowProgressEnvelope: Decodable {
            let flowerShowProgress: FlowerShowProgressV3?
        }
        let originallyDecodedFlowerShowProgress = try? JSONDecoder()
            .decode(FlowerShowProgressEnvelope.self, from: data)
            .flowerShowProgress
        var progress: GameProgress
        do {
            progress = try JSONDecoder().decode(GameProgress.self, from: data)
        } catch {
            persistenceEnabled = false
            lastLoadOutcome = .failed(message: "Progress decode failed; original preserved: \(error)")
            return .fresh
        }

        progress.bestScore = max(0, progress.bestScore)
        progress.highestGarden = max(1, progress.highestGarden)
        progress.globalBestStreak = max(0, progress.globalBestStreak)
        progress.radiantGardens = Set(progress.radiantGardens.filter { $0 > 0 })
        progress.flowerShowProgress.sanitiseDecodedState()
        let flowerShowProgressWasRepaired = originallyDecodedFlowerShowProgress.map {
            $0 != progress.flowerShowProgress
        } ?? false
        let recoveredLegacyBackupURL = storedVersion == FlowerShowClassDefinition.campaignVersion
            ? recoverLegacyFlowerShowBackup(into: &progress.flowerShowProgress)
            : nil
        progress.completedFlowerShowClasses = progress.flowerShowProgress.completedCampaignClasses
        progress.currentFlowerShowClass = progress.flowerShowProgress.isGrandChampion
            ? progress.flowerShowProgress.nextCircuitClass
            : progress.flowerShowProgress.nextCampaignClass
        progress.grandChampionAchieved = progress.flowerShowProgress.isGrandChampion
        progress.seenFlowerShowIntroductions = Set(progress.flowerShowProgress.seenIntroductions.map(\.rawValue))
        progress.reviewRequestState.successfulGardenCompletions = max(
            0,
            progress.reviewRequestState.successfulGardenCompletions
        )

        if progress.activeGame?.phase != .playing || progress.activeGardenSeed == nil {
            progress.activeGame = nil
            progress.activeGardenSeed = nil
        }

        progress.activeFlowerShow = nil

        if storedVersion < FlowerShowClassDefinition.campaignVersion {
            do {
                let backupURL = fileURL.appendingPathExtension(
                    "flower-show-v\(storedVersion)-backup"
                )
                if FileManager.default.fileExists(atPath: backupURL.path) {
                    let existingBackup = try Data(contentsOf: backupURL)
                    guard existingBackup == data else {
                        throw CocoaError(.fileWriteFileExists)
                    }
                } else {
                    try data.write(to: backupURL, options: .atomic)
                    let verified = try Data(contentsOf: backupURL)
                    guard verified == data else {
                        throw CocoaError(.fileWriteUnknown)
                    }
                }
                save(progress)
                guard persistenceEnabled else { return progress }
                lastLoadOutcome = .migrated(progress, backupURL: backupURL)
            } catch {
                persistenceEnabled = false
                lastLoadOutcome = .failed(message: "Migration backup/write failed; original preserved: \(error)")
            }
        } else if flowerShowProgressWasRepaired {
            do {
                let backupURL = fileURL.appendingPathExtension("repaired-backup")
                if FileManager.default.fileExists(atPath: backupURL.path) {
                    let existingBackup = try Data(contentsOf: backupURL)
                    guard existingBackup == data else {
                        throw CocoaError(.fileWriteFileExists)
                    }
                } else {
                    try data.write(to: backupURL, options: .atomic)
                    let verified = try Data(contentsOf: backupURL)
                    guard verified == data else { throw CocoaError(.fileWriteUnknown) }
                }
                save(progress)
                guard persistenceEnabled else { return progress }
                lastLoadOutcome = .repaired(progress, backupURL: backupURL)
            } catch {
                persistenceEnabled = false
                lastLoadOutcome = .failed(message: "Repair backup/write failed; original preserved: \(error)")
            }
        } else if let recoveredLegacyBackupURL {
            save(progress)
            guard persistenceEnabled else { return progress }
            lastLoadOutcome = .migrated(progress, backupURL: recoveredLegacyBackupURL)
        } else {
            lastLoadOutcome = .loaded(progress)
        }
        return progress
    }

    private func recoverLegacyFlowerShowBackup(
        into progress: inout FlowerShowProgressV3
    ) -> URL? {
        var recoveredBackupURL: URL?
        for version in (1 ..< FlowerShowClassDefinition.campaignVersion).reversed() {
            let backupURL = fileURL.appendingPathExtension("flower-show-v\(version)-backup")
            guard FileManager.default.fileExists(atPath: backupURL.path),
                  let data = try? Data(contentsOf: backupURL),
                  let snapshot = try? JSONDecoder().decode(
                      LegacyFlowerShowProgressSnapshot.self,
                      from: data
                  ),
                  snapshot.storedVersion == version
            else { continue }

            if snapshot.mergeMissingProgress(into: &progress), recoveredBackupURL == nil {
                recoveredBackupURL = backupURL
            }
        }
        return recoveredBackupURL
    }

    func save(_ progress: GameProgress) {
        guard persistenceEnabled else { return }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(progress)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            persistenceEnabled = false
            lastLoadOutcome = .failed(message: "Unable to persist Ringbloom progress: \(error)")
        }
    }
}

// MARK: - Launch determinism

enum GameLaunchMode: Equatable, Sendable {
    static let defaultUITestSeed: UInt64 = 0x5249_4E47_5549_5445
    static let defaultScreenshotSeed: UInt64 = 0x5249_4E47_5348_4F54

    case production
    case uiTest(seed: UInt64)
    case screenshot(seed: UInt64)

    static var current: GameLaunchMode {
        detect(arguments: ProcessInfo.processInfo.arguments)
    }

    static func detect(arguments: [String]) -> GameLaunchMode {
        let normalized = arguments.map { $0.lowercased() }
        let requestedSeed = normalized.lazy.compactMap { argument -> UInt64? in
            guard let separator = argument.firstIndex(of: "=") else { return nil }
            let key = argument[..<separator]
            guard key == "--seed" || key == "-seed" else { return nil }
            return UInt64(argument[argument.index(after: separator)...])
        }.first

        if normalized.contains(where: { $0.contains("screenshot") }) {
            return .screenshot(seed: requestedSeed ?? defaultScreenshotSeed)
        }
        if normalized.contains(where: { $0.contains("ui-test") || $0.contains("uitest") }) {
            return .uiTest(seed: requestedSeed ?? defaultUITestSeed)
        }
        return .production
    }

    var deterministicSeed: UInt64? {
        switch self {
        case .production: nil
        case let .uiTest(seed), let .screenshot(seed): seed
        }
    }

    var isDeterministic: Bool { deterministicSeed != nil }
}

// MARK: - SwiftUI-facing model

#if false // Flower Show v2 model retained only in the recoverable source baseline.
@MainActor
final class GameModelV2: ObservableObject {
    @Published private var gardenEngine: GameEngine
    @Published private var flowerShowEngine: GameEngine
    @Published private(set) var activeMode: GameMode
    @Published private(set) var bestScore: Int
    @Published private(set) var highestGarden: Int
    @Published private(set) var hasActiveGarden: Bool
    @Published private(set) var globalBestStreak: Int
    @Published private(set) var radiantGardens: Set<Int>
    @Published private(set) var flowerShowIntroduced: Bool
    @Published private(set) var completedFlowerShowClasses: Set<Int>
    @Published private(set) var currentFlowerShowClass: Int
    @Published private(set) var hasActiveFlowerShow: Bool
    @Published private(set) var seenFlowerShowIntroductionIDs: Set<String>
    @Published private(set) var grandChampionAchieved: Bool
    @Published private(set) var reviewRequestState: ReviewRequestState
    @Published private(set) var reviewRequestTrigger: Int?

    let launchMode: GameLaunchMode

    private let progressStore: any GameProgressStoring
    private let baseSeed: UInt64
    private var currentGardenSeed: UInt64
    private let currentDate: () -> Date
    private let appVersion: String

    private var engine: GameEngine {
        activeMode == .garden ? gardenEngine : flowerShowEngine
    }

    var board: GameBoard { engine.board }
    var selectedRing: Ring { engine.selectedRing }
    var score: Int { engine.score }
    var garden: Int { gardenEngine.garden }
    var blooms: Int { engine.blooms }
    var targetBlooms: Int { engine.targetBlooms }
    var movesRemaining: Int { engine.movesRemaining }
    var phase: GamePhase { engine.phase }
    var lastTurn: TurnResult? { engine.lastTurn }
    var suggestedMove: GameMove? { engine.suggestedMove }
    var streak: Int { engine.streak }
    var bestStreak: Int { engine.bestStreak }
    var hintsRemaining: Int { engine.hintsRemaining }
    var hintsUsed: Int { engine.hintsUsed }
    var completionBonus: Int { engine.completionBonus }
    var gardenRating: GardenRating { engine.gardenRating }
    var harmonyRings: Set<Ring> { engine.harmonyRings }
    var infectedSpokes: Set<Int> { engine.infectedSpokes }
    var bindweedSpreadCountdown: Int? { engine.bindweedSpreadCountdown }
    var twinBloomCompleted: Bool { engine.twinBloomCompleted }
    var unfinishedHarmonyRings: Set<Ring> { engine.unfinishedHarmonyRings }
    var objectivesComplete: Bool { engine.objectivesComplete }
    var canUndo: Bool { activeMode == .flowerShow && flowerShowEngine.canUndo }
    var didUseUndo: Bool { engine.didUseUndo }
    var flowerShowUnlocked: Bool { highestGarden > 10 }
    var flowerShowDefinition: FlowerShowClassDefinition {
        flowerShowEngine.flowerShowClass ?? .classNumber(currentFlowerShowClass)
    }

    var seenFlowerShowIntroductions: Set<FlowerShowRule> {
        Set(FlowerShowRule.allCases.filter { seenFlowerShowIntroductionIDs.contains($0.rawValue) })
    }

    /// Production uses file persistence. UI-test and screenshot launches are isolated in memory.
    convenience init() {
        let mode = GameLaunchMode.current
        let normalizedArguments = ProcessInfo.processInfo.arguments.map { $0.lowercased() }
        let previewsFlowerShow = normalizedArguments.contains("--flower-show-unlocked")
            || normalizedArguments.contains { $0.hasPrefix("--screenshot-flower-show") }
            || normalizedArguments.contains("--screenshot-champion-home")
        let previewsReviewTiming = normalizedArguments.contains("--screenshot-review-timing")
        let previewClass = normalizedArguments.lazy.compactMap { argument -> Int? in
            guard argument.hasPrefix("--flower-show-class=") else { return nil }
            return Int(argument.dropFirst("--flower-show-class=".count))
        }.first ?? (
            normalizedArguments.contains("--screenshot-champion-home")
                ? FlowerShowClassDefinition.championCircuitStartClass
                : 1
        )
        let previewProgress = if previewsReviewTiming {
            GameProgress(
                bestScore: 0,
                highestGarden: 2,
                reviewRequestState: ReviewRequestState(successfulGardenCompletions: 1)
            )
        } else {
            GameProgress(
                bestScore: 0,
                highestGarden: previewsFlowerShow ? 11 : 1,
                completedFlowerShowClasses: previewClass > FlowerShowClassDefinition.classCount
                    ? Set(1 ... FlowerShowClassDefinition.classCount)
                    : [],
                currentFlowerShowClass: previewClass,
                grandChampionAchieved: previewClass > FlowerShowClassDefinition.classCount
            )
        }
        switch mode {
        case .production:
            self.init(launchMode: mode, progressStore: FileGameProgressStore())
        case .uiTest, .screenshot:
            self.init(
                launchMode: mode,
                progressStore: InMemoryGameProgressStore(
                    progress: previewProgress
                )
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
        appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    ) {
        self.launchMode = launchMode
        self.progressStore = progressStore
        self.currentDate = currentDate
        self.appVersion = appVersion

        let persisted = progressStore.load()
        bestScore = max(0, persisted.bestScore)
        let persistedHighestGarden = max(1, persisted.highestGarden)
        highestGarden = persistedHighestGarden
        globalBestStreak = max(0, persisted.globalBestStreak)
        radiantGardens = Set(persisted.radiantGardens.filter { $0 > 0 })
        flowerShowIntroduced = persisted.flowerShowIntroduced
        let persistedCompletedClasses = Set(
            persisted.completedFlowerShowClasses.filter { (1 ... FlowerShowClassDefinition.classCount).contains($0) }
        )
        completedFlowerShowClasses = persistedCompletedClasses
        let persistedFlowerShowClass = max(1, persisted.currentFlowerShowClass)
        currentFlowerShowClass = persistedFlowerShowClass
        seenFlowerShowIntroductionIDs = persisted.seenFlowerShowIntroductions
        grandChampionAchieved = persisted.grandChampionAchieved
            || persistedCompletedClasses.contains(FlowerShowClassDefinition.classCount)
        reviewRequestState = persisted.reviewRequestState
        reviewRequestTrigger = nil
        activeMode = .garden

        let resolvedBaseSeed = launchMode.deterministicSeed
            ?? UInt64.random(in: UInt64.min ... UInt64.max)
        baseSeed = resolvedBaseSeed
        flowerShowEngine = GameEngine(flowerShow: .classNumber(persistedFlowerShowClass))
        hasActiveFlowerShow = false

        if case .production = launchMode,
           let activeGame = persisted.activeGame,
           activeGame.phase == .playing,
           let activeGardenSeed = persisted.activeGardenSeed
        {
            currentGardenSeed = activeGardenSeed
            gardenEngine = activeGame
            hasActiveGarden = true
            bestScore = max(max(0, persisted.bestScore), activeGame.score)
            highestGarden = max(persistedHighestGarden, activeGame.garden)
            globalBestStreak = max(max(0, persisted.globalBestStreak), activeGame.bestStreak)
        } else {
            let initialGardenSeed = Self.seed(
                baseSeed: resolvedBaseSeed,
                garden: persistedHighestGarden
            )
            currentGardenSeed = initialGardenSeed
            gardenEngine = GameEngine(seed: initialGardenSeed, garden: persistedHighestGarden)
            hasActiveGarden = false
        }

        if case .production = launchMode,
           let activeFlowerShow = persisted.activeFlowerShow,
           activeFlowerShow.mode == .flowerShow,
           activeFlowerShow.phase == .playing || (activeFlowerShow.phase == .lost && activeFlowerShow.canUndo),
           let activeDefinition = activeFlowerShow.flowerShowClass,
           activeDefinition == FlowerShowClassDefinition.classNumber(activeDefinition.number)
        {
            flowerShowEngine = activeFlowerShow
            currentFlowerShowClass = activeFlowerShow.flowerShowClass?.number ?? persistedFlowerShowClass
            hasActiveFlowerShow = true
        }
    }

    func select(_ ring: Ring) {
        var updated = engine
        updated.select(ring)
        setCurrentEngine(updated)
        markCurrentSessionActiveIfPlayable()
        persistProgress()
    }

    func selectRing(_ ring: Ring) {
        select(ring)
    }

    @discardableResult
    func requestHint() -> GameMove? {
        var updated = engine
        let move = updated.requestHint()
        setCurrentEngine(updated)

        if move != nil {
            markCurrentSessionActiveIfPlayable()
        }
        persistProgress()
        return move
    }

    @discardableResult
    func rotate(_ direction: RotationDirection) -> TurnResult? {
        var updated = engine
        guard let result = updated.rotate(direction) else { return nil }
        setCurrentEngine(updated)

        switch activeMode {
        case .garden:
            bestScore = max(bestScore, updated.score)
            globalBestStreak = max(globalBestStreak, updated.bestStreak)

            if updated.phase == .won {
                highestGarden = max(highestGarden, updated.garden + 1)
                if updated.gardenRating == .radiant {
                    radiantGardens.insert(updated.garden)
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
            hasActiveGarden = updated.phase == .playing
        case .flowerShow:
            if updated.phase == .won, let completedClass = updated.flowerShowClass?.number {
                if completedClass <= FlowerShowClassDefinition.classCount {
                    completedFlowerShowClasses.insert(completedClass)
                }
                if completedClass == FlowerShowClassDefinition.classCount {
                    grandChampionAchieved = true
                }
                currentFlowerShowClass = completedClass + 1
                hasActiveFlowerShow = false
            } else {
                hasActiveFlowerShow = updated.phase == .playing || (updated.phase == .lost && updated.canUndo)
            }
        }
        persistProgress()
        return result
    }

    func retry() {
        switch activeMode {
        case .garden:
            gardenEngine = GameEngine(seed: currentGardenSeed, garden: gardenEngine.garden)
            hasActiveGarden = true
        case .flowerShow:
            flowerShowEngine = GameEngine(flowerShow: flowerShowDefinition)
            hasActiveFlowerShow = true
        }
        persistProgress()
    }

    func nextGarden() {
        guard activeMode == .garden, phase == .won else { return }
        startGarden(gardenEngine.garden + 1)
    }

    func startGarden(_ garden: Int? = nil) {
        activeMode = .garden
        let requestedGarden = max(1, garden ?? gardenEngine.garden)
        currentGardenSeed = Self.seed(baseSeed: baseSeed, garden: requestedGarden)
        gardenEngine = GameEngine(seed: currentGardenSeed, garden: requestedGarden)
        hasActiveGarden = true

        if requestedGarden > highestGarden {
            highestGarden = requestedGarden
        }
        persistProgress()
    }

    func resumeGarden() {
        activeMode = .garden
    }

    func introduceFlowerShow() {
        guard flowerShowUnlocked else { return }
    }

    func startFlowerShowClass(_ classNumber: Int? = nil) {
        guard flowerShowUnlocked else { return }
        let requestedClass = max(1, classNumber ?? currentFlowerShowClass)
        activeMode = .flowerShow
        currentFlowerShowClass = requestedClass
        flowerShowIntroduced = true
        let definition = FlowerShowClassDefinition.classNumber(requestedClass)
        if let introducedRule = definition.introducedRule {
            seenFlowerShowIntroductionIDs.insert(introducedRule.rawValue)
        }
        flowerShowEngine = GameEngine(flowerShow: definition)
        hasActiveFlowerShow = true
        persistProgress()
    }

    func resumeFlowerShow() {
        guard flowerShowUnlocked, hasActiveFlowerShow else { return }
        activeMode = .flowerShow
    }

    func nextFlowerShowClass() {
        guard activeMode == .flowerShow, phase == .won else { return }
        startFlowerShowClass(currentFlowerShowClass)
    }

    @discardableResult
    func undoFlowerShowTurn() -> Bool {
        guard activeMode == .flowerShow else { return false }
        var updated = flowerShowEngine
        guard updated.useUndo() else { return false }
        flowerShowEngine = updated
        hasActiveFlowerShow = true
        persistProgress()
        return true
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

    private func setCurrentEngine(_ updated: GameEngine) {
        switch activeMode {
        case .garden: gardenEngine = updated
        case .flowerShow: flowerShowEngine = updated
        }
    }

    private func markCurrentSessionActiveIfPlayable() {
        guard phase == .playing else { return }
        switch activeMode {
        case .garden: hasActiveGarden = true
        case .flowerShow: hasActiveFlowerShow = true
        }
    }

    private func persistProgress() {
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
                flowerShowIntroduced: flowerShowIntroduced,
                completedFlowerShowClasses: completedFlowerShowClasses,
                currentFlowerShowClass: currentFlowerShowClass,
                activeFlowerShow: hasActiveFlowerShow ? flowerShowEngine : nil,
                seenFlowerShowIntroductions: seenFlowerShowIntroductionIDs,
                grandChampionAchieved: grandChampionAchieved,
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
#endif
