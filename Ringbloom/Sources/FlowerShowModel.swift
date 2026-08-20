import Foundation

enum FlowerShowObjectiveID: String, CaseIterable, Codable, Hashable, Sendable {
    case harmony
    case unbroken
    case bindweed
    case twinBloom
    case prizeBouquet
    case judgesOrder
}

enum FlowerShowIntroductionID: String, CaseIterable, Codable, Hashable, Sendable {
    case harmony
    case unbroken
    case bindweed
    case twinBloom
    case prizeBouquet
    case doubleHarmony
    case judgesOrder

    var introductionClass: Int {
        switch self {
        case .harmony: 1
        case .unbroken: 6
        case .bindweed: 11
        case .twinBloom: 16
        case .prizeBouquet: 21
        case .doubleHarmony: 24
        case .judgesOrder: 33
        }
    }
}

struct RingCredits: Codable, Equatable, Hashable, Sendable {
    var inner: Int = 0
    var middle: Int = 0
    var outer: Int = 0

    subscript(_ ring: Ring) -> Int {
        get {
            switch ring {
            case .inner: inner
            case .middle: middle
            case .outer: outer
            }
        }
        set {
            switch ring {
            case .inner: inner = newValue
            case .middle: middle = newValue
            case .outer: outer = newValue
            }
        }
    }

    func satisfies(_ requirement: Int) -> Bool {
        Ring.allCases.allSatisfy { self[$0] >= requirement }
    }
}

struct PetalKindMask: OptionSet, Codable, Equatable, Hashable, Sendable {
    let rawValue: UInt8

    static let coral = Self(rawValue: 1 << 0)
    static let saffron = Self(rawValue: 1 << 1)
    static let mint = Self(rawValue: 1 << 2)
    static let sky = Self(rawValue: 1 << 3)
    static let all: Self = [.coral, .saffron, .mint, .sky]

    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    init(_ kind: PetalKind) {
        self = switch kind {
        case .coral: .coral
        case .saffron: .saffron
        case .mint: .mint
        case .sky: .sky
        }
    }

    var kinds: [PetalKind] {
        PetalKind.allCases.filter { contains(Self($0)) }
    }
}

struct BindweedRequirement: Codable, Equatable, Hashable, Sendable {
    let startingSpokes: [Int]
    let spreadInterval: Int
}

enum FlowerShowValidationError: Error, Equatable, CustomStringConvertible {
    case invalid(String)

    var description: String {
        switch self {
        case let .invalid(message): message
        }
    }
}

struct FlowerShowObjectives: Codable, Equatable, Hashable, Sendable {
    let harmonyCreditsPerRing: Int
    let unbrokenChain: Int?
    let bindweed: BindweedRequirement?
    let twinBloomTurns: Int
    let bouquetKinds: PetalKindMask
    let judgesOrder: [Ring]

    init(
        harmonyCreditsPerRing: Int = 0,
        unbrokenChain: Int? = nil,
        bindweed: BindweedRequirement? = nil,
        twinBloomTurns: Int = 0,
        bouquetKinds: PetalKindMask = [],
        judgesOrder: [Ring] = []
    ) {
        self.harmonyCreditsPerRing = harmonyCreditsPerRing
        self.unbrokenChain = unbrokenChain
        self.bindweed = bindweed
        self.twinBloomTurns = twinBloomTurns
        self.bouquetKinds = bouquetKinds
        self.judgesOrder = judgesOrder
    }

    private enum CodingKeys: String, CodingKey {
        case harmonyCreditsPerRing
        case unbrokenChain
        case bindweed
        case twinBloomTurns
        case bouquetKinds
        case judgesOrder
        case requiresHarmony
        case requiredUnbrokenChain
        case startingBindweedSpokes
        case requiresTwinBloom
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacySpokes = try container.decodeIfPresent([Int].self, forKey: .startingBindweedSpokes) ?? []
        let decodedBindweed = try container.decodeIfPresent(BindweedRequirement.self, forKey: .bindweed)
            ?? (legacySpokes.isEmpty ? nil : BindweedRequirement(startingSpokes: legacySpokes, spreadInterval: 3))
        self.init(
            harmonyCreditsPerRing: try container.decodeIfPresent(Int.self, forKey: .harmonyCreditsPerRing)
                ?? ((try container.decodeIfPresent(Bool.self, forKey: .requiresHarmony) ?? false) ? 1 : 0),
            unbrokenChain: try container.decodeIfPresent(Int.self, forKey: .unbrokenChain)
                ?? container.decodeIfPresent(Int.self, forKey: .requiredUnbrokenChain),
            bindweed: decodedBindweed,
            twinBloomTurns: try container.decodeIfPresent(Int.self, forKey: .twinBloomTurns)
                ?? ((try container.decodeIfPresent(Bool.self, forKey: .requiresTwinBloom) ?? false) ? 1 : 0),
            bouquetKinds: try container.decodeIfPresent(PetalKindMask.self, forKey: .bouquetKinds) ?? [],
            judgesOrder: try container.decodeIfPresent([Ring].self, forKey: .judgesOrder) ?? []
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(harmonyCreditsPerRing, forKey: .harmonyCreditsPerRing)
        try container.encodeIfPresent(unbrokenChain, forKey: .unbrokenChain)
        try container.encodeIfPresent(bindweed, forKey: .bindweed)
        try container.encode(twinBloomTurns, forKey: .twinBloomTurns)
        try container.encode(bouquetKinds, forKey: .bouquetKinds)
        try container.encode(judgesOrder, forKey: .judgesOrder)
    }

    // Read-only compatibility for the obsolete v2 engine payload.
    var requiresHarmony: Bool { harmonyCreditsPerRing > 0 }
    var requiredUnbrokenChain: Int? { unbrokenChain }
    var startingBindweedSpokes: [Int] { bindweed?.startingSpokes ?? [] }
    var requiresTwinBloom: Bool { twinBloomTurns > 0 }

    var activeIDs: [FlowerShowObjectiveID] {
        var result: [FlowerShowObjectiveID] = []
        if harmonyCreditsPerRing > 0 { result.append(.harmony) }
        if unbrokenChain != nil { result.append(.unbroken) }
        if bindweed != nil { result.append(.bindweed) }
        if twinBloomTurns > 0 { result.append(.twinBloom) }
        if bouquetKinds.isEmpty == false { result.append(.prizeBouquet) }
        if judgesOrder.isEmpty == false { result.append(.judgesOrder) }
        return result
    }

    func validate() throws {
        guard (0 ... 2).contains(harmonyCreditsPerRing) else {
            throw FlowerShowValidationError.invalid("Harmony credits must be 0...2.")
        }
        if let unbrokenChain, (2 ... 5).contains(unbrokenChain) == false {
            throw FlowerShowValidationError.invalid("Unbroken must be nil or 2...5.")
        }
        if let bindweed {
            guard bindweed.spreadInterval == 3 else {
                throw FlowerShowValidationError.invalid("Bindweed spread interval must be 3.")
            }
            let spokes = bindweed.startingSpokes
            guard spokes.isEmpty == false,
                  Set(spokes).count == spokes.count,
                  spokes.allSatisfy({ (0 ..< GameBoard.slotsPerRing).contains($0) })
            else {
                throw FlowerShowValidationError.invalid("Bindweed spokes must be unique values from 0...7.")
            }
        }
        guard (0 ... 2).contains(twinBloomTurns) else {
            throw FlowerShowValidationError.invalid("Twin Bloom turns must be 0...2.")
        }
        guard bouquetKinds.isEmpty || bouquetKinds == .all else {
            throw FlowerShowValidationError.invalid("Prize Bouquet must require all four kinds.")
        }
        if judgesOrder.isEmpty == false {
            guard (3 ... 4).contains(judgesOrder.count),
                  zip(judgesOrder, judgesOrder.dropFirst()).allSatisfy(!=),
                  Set(judgesOrder) == Set(Ring.allCases)
            else {
                throw FlowerShowValidationError.invalid("Judges' Order must contain 3...4 entries, use every ring and not repeat a ring immediately.")
            }
        }
        guard harmonyCreditsPerRing == 0 || judgesOrder.isEmpty else {
            throw FlowerShowValidationError.invalid("Harmony and Judges' Order cannot be combined.")
        }
        guard activeIDs.count <= 3 else {
            throw FlowerShowValidationError.invalid("A Class may have at most three special objectives.")
        }
    }
}

struct FlowerShowRefillSource: Codable, Equatable, Hashable, Sendable {
    let seed: UInt64
}

struct FlowerShowScenario: Codable, Equatable, Hashable, Identifiable, Sendable {
    let scenarioID: String
    let scenarioDigest: String
    let initialBoard: GameBoard
    let startingSelectedRing: Ring
    let refillSource: FlowerShowRefillSource
    let repairSalt: UInt64
    let targetBlooms: Int
    let moveBudget: Int
    let radiantPar: Int
    let activeKindCount: Int
    let objectives: FlowerShowObjectives

    var id: String { scenarioID }

    func validate() throws {
        try objectives.validate()
        guard initialBoard.isStable else {
            throw FlowerShowValidationError.invalid("\(scenarioID) opens with an immediate bloom.")
        }
        guard initialBoard.rings.count == 3,
              initialBoard.rings.allSatisfy({ $0.count == 8 })
        else {
            throw FlowerShowValidationError.invalid("\(scenarioID) has invalid board dimensions.")
        }
        guard targetBlooms > 0, moveBudget > 0, radiantPar > 0, radiantPar <= moveBudget else {
            throw FlowerShowValidationError.invalid("\(scenarioID) has invalid target or move budgets.")
        }
        guard (3 ... 4).contains(activeKindCount) else {
            throw FlowerShowValidationError.invalid("\(scenarioID) has an invalid petal-kind count.")
        }
        guard initialBoard.rings
            .joined()
            .allSatisfy({ $0.rawValue < activeKindCount })
        else {
            throw FlowerShowValidationError.invalid("\(scenarioID) uses a petal kind outside its active set.")
        }
        if objectives.bouquetKinds.isEmpty == false, activeKindCount != 4 {
            throw FlowerShowValidationError.invalid("\(scenarioID) requires Bouquet without four kinds.")
        }
    }
}

struct ResolvedFlowerShowClass: Equatable, Sendable {
    let displayedClassNumber: Int
    let scenario: FlowerShowScenario
}

struct UnbrokenProgress: Codable, Equatable, Hashable, Sendable {
    var current: Int = 0
    var best: Int = 0
}

struct FlowerShowRefillState: Codable, Equatable, Hashable, Sendable {
    private(set) var value: UInt64

    init(seed: UInt64) {
        value = seed
    }

    mutating func next() -> UInt64 {
        value &+= 0x9E37_79B9_7F4A_7C15
        var mixed = value
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }

    mutating func nextInt(upperBound: Int) -> Int {
        precondition(upperBound > 0)
        return Int(next() % UInt64(upperBound))
    }
}

struct FlowerShowState: Codable, Equatable, Hashable, Sendable {
    var board: GameBoard
    var refillState: FlowerShowRefillState
    var selectedRing: Ring
    var blooms: Int
    var movesRemaining: Int
    var unbroken: UnbrokenProgress
    var harmonyCredits: RingCredits
    var infectedSpokes: Set<Int>
    var bindweedCountdown: Int?
    var twinBloomTurns: Int
    var bouquetKinds: PetalKindMask
    var judgesOrderIndex: Int
    var phase: GamePhase
    var turnNumber: Int
    var score: Int

    func objectivesComplete(for scenario: FlowerShowScenario) -> Bool {
        let objectives = scenario.objectives
        return harmonyCredits.satisfies(objectives.harmonyCreditsPerRing)
            && objectives.unbrokenChain.map { unbroken.best >= $0 } ?? true
            && (objectives.bindweed == nil || infectedSpokes.isEmpty)
            && twinBloomTurns >= objectives.twinBloomTurns
            && bouquetKinds.isSuperset(of: objectives.bouquetKinds)
            && judgesOrderIndex >= objectives.judgesOrder.count
    }

    func isComplete(for scenario: FlowerShowScenario) -> Bool {
        blooms >= scenario.targetBlooms && objectivesComplete(for: scenario)
    }
}

struct BloomEvent: Codable, Equatable, Hashable, Sendable {
    let spoke: Int
    let kind: PetalKind
}

struct FlowerShowStateFingerprint: Codable, Equatable, Hashable, Sendable {
    let state: FlowerShowState
}

struct FlowerShowTransition: Codable, Equatable, Sendable {
    let stateBeforeFingerprint: FlowerShowStateFingerprint
    let stateAfter: FlowerShowState
    let ring: Ring
    let direction: RotationDirection
    let blooms: [BloomEvent]
    let harmonyBefore: RingCredits
    let harmonyAfter: RingCredits
    let unbrokenBefore: UnbrokenProgress
    let unbrokenAfter: UnbrokenProgress
    let clearedBindweedSpokes: [Int]
    let spreadSourceSpoke: Int?
    let newlyInfectedSpoke: Int?
    let bindweedCountdownBefore: Int?
    let bindweedCountdownAfter: Int?
    let twinTurnsBefore: Int
    let twinTurnsAfter: Int
    let bouquetBefore: PetalKindMask
    let bouquetAfter: PetalKindMask
    let matchedOrderRing: Ring?
    let nextOrderRing: Ring?
    let completedObjectiveIDs: Set<FlowerShowObjectiveID>
    let didReshuffle: Bool
    let phase: GamePhase

    var bloomSpokes: [Int] { blooms.map(\.spoke) }
    var bloomCount: Int { blooms.count }
}

enum FlowerShowRating: Int, CaseIterable, Codable, Comparable, Equatable, Sendable {
    case seedling
    case flourishing
    case radiant

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

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

enum FlowerShowAttemptKind: String, Codable, Equatable, Sendable {
    case campaign
    case replay
    case circuit
}

struct FlowerShowAttemptContext: Codable, Equatable, Sendable {
    let kind: FlowerShowAttemptKind
    let classNumber: Int
}

enum FlowerShowMilestone: String, Codable, Equatable, Sendable {
    case rosette
    case grandChampion
    case perfectShow
    case circuitCup
}

struct FlowerShowUndoSnapshot: Codable, Equatable, Sendable {
    let state: FlowerShowState
    let hintRemaining: Bool
    let didUseHint: Bool
    let lastTransition: FlowerShowTransition?
}

struct FlowerShowEngine: Codable, Equatable, Sendable {
    var attemptID: UUID
    var scenarioID: String
    var scenarioDigest: String
    var state: FlowerShowState
    var hintRemaining: Bool
    var didUseHint: Bool
    var didUseUndo: Bool
    var undoSnapshot: FlowerShowUndoSnapshot?
    var lastTransition: FlowerShowTransition?

    init(scenario: FlowerShowScenario, attemptID: UUID = UUID()) {
        self.attemptID = attemptID
        scenarioID = scenario.scenarioID
        scenarioDigest = scenario.scenarioDigest
        state = FlowerShowState(
            board: scenario.initialBoard,
            refillState: FlowerShowRefillState(seed: scenario.refillSource.seed),
            selectedRing: scenario.startingSelectedRing,
            blooms: 0,
            movesRemaining: scenario.moveBudget,
            unbroken: UnbrokenProgress(),
            harmonyCredits: RingCredits(),
            infectedSpokes: Set(scenario.objectives.bindweed?.startingSpokes ?? []),
            bindweedCountdown: scenario.objectives.bindweed == nil ? nil : 3,
            twinBloomTurns: 0,
            bouquetKinds: [],
            judgesOrderIndex: 0,
            phase: .playing,
            turnNumber: 0,
            score: 0
        )
        hintRemaining = true
        didUseHint = false
        didUseUndo = false
        undoSnapshot = nil
        lastTransition = nil
    }

    var canUndo: Bool {
        didUseUndo == false && undoSnapshot != nil && (state.phase == .playing || state.phase == .lost)
    }

    var movesUsed: Int {
        max(0, (state.movesRemaining + state.turnNumber) - state.movesRemaining)
    }

    mutating func select(_ ring: Ring) {
        state.selectedRing = ring
    }

    mutating func rotate(_ direction: RotationDirection, scenario: FlowerShowScenario) -> FlowerShowTransition? {
        guard state.phase == .playing else { return nil }
        if didUseUndo == false {
            undoSnapshot = FlowerShowUndoSnapshot(
                state: state,
                hintRemaining: hintRemaining,
                didUseHint: didUseHint,
                lastTransition: lastTransition
            )
        }
        let transition = FlowerShowReducer.apply(
            GameMove(ring: state.selectedRing, direction: direction),
            to: state,
            rules: scenario
        )
        state = transition.stateAfter
        lastTransition = transition
        return transition
    }

    mutating func useUndo() -> Bool {
        guard canUndo, let snapshot = undoSnapshot else { return false }
        state = snapshot.state
        hintRemaining = snapshot.hintRemaining
        didUseHint = snapshot.didUseHint
        lastTransition = snapshot.lastTransition
        didUseUndo = true
        undoSnapshot = nil
        return true
    }

    mutating func consumeHint() {
        guard hintRemaining else { return }
        hintRemaining = false
        didUseHint = true
    }

    func bestAvailableRating(for scenario: FlowerShowScenario) -> FlowerShowRating {
        if didUseHint { return .seedling }
        if didUseUndo || state.turnNumber > scenario.radiantPar { return .flourishing }
        return .radiant
    }

    func earnedRating(for scenario: FlowerShowScenario) -> FlowerShowRating {
        guard state.phase == .won else { return .seedling }
        if didUseHint { return .seedling }
        if didUseUndo == false, state.turnNumber <= scenario.radiantPar { return .radiant }
        return .flourishing
    }
}
