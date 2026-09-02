import Foundation

struct FlowerShowSearchKey: Equatable, Hashable, Sendable {
    let board: GameBoard
    let refillState: FlowerShowRefillState
    let blooms: Int
    let movesRemaining: Int
    let unbroken: UnbrokenProgress
    let harmonyCredits: RingCredits
    let infectedSpokes: Set<Int>
    let bindweedCountdown: Int?
    let twinBloomTurns: Int
    let bouquetKinds: PetalKindMask
    let judgesOrderIndex: Int
    let phase: GamePhase

    init(_ state: FlowerShowState) {
        board = state.board
        refillState = state.refillState
        blooms = state.blooms
        movesRemaining = state.movesRemaining
        unbroken = state.unbroken
        harmonyCredits = state.harmonyCredits
        infectedSpokes = state.infectedSpokes
        bindweedCountdown = state.bindweedCountdown
        twinBloomTurns = state.twinBloomTurns
        bouquetKinds = state.bouquetKinds
        judgesOrderIndex = state.judgesOrderIndex
        phase = state.phase
    }
}

struct FlowerShowSolution: Equatable, Sendable {
    let moves: [GameMove]
    let visitedStateCount: Int
}

enum FlowerShowExactSolver {
    private static let allMoves = Ring.allCases.flatMap { ring in
        RotationDirection.allCases.map { GameMove(ring: ring, direction: $0) }
    }

    static func shortestRoute(
        from initialState: FlowerShowState,
        scenario: FlowerShowScenario,
        maximumDepth: Int? = nil,
        allowRepair: Bool = true,
        cancellation: @Sendable () -> Bool = { false }
    ) -> FlowerShowSolution? {
        if initialState.isComplete(for: scenario) {
            return FlowerShowSolution(moves: [], visitedStateCount: 0)
        }
        guard initialState.phase == .playing else { return nil }

        let upperBound = min(maximumDepth ?? initialState.movesRemaining, initialState.movesRemaining)
        let startDepth = lowerBound(for: initialState, scenario: scenario)
        guard startDepth <= upperBound else { return nil }

        var totalVisited = 0
        for limit in startDepth ... upperBound {
            var bestRemainingByState: [FlowerShowSearchKey: Int] = [:]
            var path: [GameMove] = []
            if depthFirst(
                state: initialState,
                scenario: scenario,
                remainingDepth: limit,
                path: &path,
                bestRemainingByState: &bestRemainingByState,
                visited: &totalVisited,
                allowRepair: allowRepair,
                cancellation: cancellation
            ) {
                return FlowerShowSolution(moves: path, visitedStateCount: totalVisited)
            }
            if cancellation() { return nil }
        }
        return nil
    }

    static func winningFirstActions(
        from state: FlowerShowState,
        scenario: FlowerShowScenario,
        maximumDepth: Int? = nil
    ) -> Set<GameMove> {
        guard state.phase == .playing else { return [] }
        let depth = maximumDepth ?? state.movesRemaining
        guard depth > 0 else { return [] }
        return Set(allMoves.filter { move in
            let next = FlowerShowReducer.apply(move, to: state, rules: scenario).stateAfter
            if next.phase == .won { return true }
            guard next.phase == .playing else { return false }
            return shortestRoute(from: next, scenario: scenario, maximumDepth: depth - 1) != nil
        })
    }

    static func lowerBound(for state: FlowerShowState, scenario: FlowerShowScenario) -> Int {
        let objectives = scenario.objectives
        let remainingBlooms = max(0, scenario.targetBlooms - state.blooms)
        let bloomBound = (remainingBlooms + 7) / 8
        let harmonyBound = Ring.allCases.reduce(0) {
            $0 + max(0, objectives.harmonyCreditsPerRing - state.harmonyCredits[$1])
        }
        let orderBound = max(0, objectives.judgesOrder.count - state.judgesOrderIndex)
        let twinBound = max(0, objectives.twinBloomTurns - state.twinBloomTurns)
        let unbrokenBound: Int
        if let required = objectives.unbrokenChain, state.unbroken.best < required {
            unbrokenBound = max(0, required - state.unbroken.current)
        } else {
            unbrokenBound = 0
        }
        let bouquetBound = state.bouquetKinds.isSuperset(of: objectives.bouquetKinds) ? 0 : 1
        let bindweedBound = objectives.bindweed == nil || state.infectedSpokes.isEmpty ? 0 : 1
        return max(
            bloomBound,
            harmonyBound,
            orderBound,
            twinBound,
            unbrokenBound,
            bouquetBound,
            bindweedBound
        )
    }

    private static func depthFirst(
        state: FlowerShowState,
        scenario: FlowerShowScenario,
        remainingDepth: Int,
        path: inout [GameMove],
        bestRemainingByState: inout [FlowerShowSearchKey: Int],
        visited: inout Int,
        allowRepair: Bool,
        cancellation: @Sendable () -> Bool
    ) -> Bool {
        if state.phase == .won { return true }
        guard state.phase == .playing,
              remainingDepth > 0,
              lowerBound(for: state, scenario: scenario) <= remainingDepth,
              cancellation() == false
        else {
            return false
        }

        let key = FlowerShowSearchKey(state)
        if let prior = bestRemainingByState[key], prior >= remainingDepth {
            return false
        }
        bestRemainingByState[key] = remainingDepth
        visited += 1

        let moves = orderedMoves(from: state, scenario: scenario)
        for move in moves {
            let transition = FlowerShowReducer.apply(move, to: state, rules: scenario)
            if transition.didReshuffle, allowRepair == false { continue }
            let next = transition.stateAfter
            path.append(move)
            if next.phase == .won || depthFirst(
                state: next,
                scenario: scenario,
                remainingDepth: remainingDepth - 1,
                path: &path,
                bestRemainingByState: &bestRemainingByState,
                visited: &visited,
                allowRepair: allowRepair,
                cancellation: cancellation
            ) {
                return true
            }
            path.removeLast()
        }
        return false
    }

    private static func orderedMoves(
        from state: FlowerShowState,
        scenario: FlowerShowScenario
    ) -> [GameMove] {
        allMoves.sorted { lhs, rhs in
            let lhsTransition = FlowerShowReducer.apply(lhs, to: state, rules: scenario)
            let rhsTransition = FlowerShowReducer.apply(rhs, to: state, rules: scenario)
            let lhsScore = orderingScore(lhsTransition, scenario: scenario)
            let rhsScore = orderingScore(rhsTransition, scenario: scenario)
            if lhsScore != rhsScore { return lhsScore > rhsScore }
            if lhs.ring.rawValue != rhs.ring.rawValue { return lhs.ring.rawValue < rhs.ring.rawValue }
            return lhs.direction.rawValue < rhs.direction.rawValue
        }
    }

    private static func orderingScore(
        _ transition: FlowerShowTransition,
        scenario: FlowerShowScenario
    ) -> Int {
        var score = transition.bloomCount * 100
        score += transition.completedObjectiveIDs.count * 1_000
        score += transition.clearedBindweedSpokes.count * 400
        score += transition.harmonyAfter.inner - transition.harmonyBefore.inner
        score += (transition.harmonyAfter.middle - transition.harmonyBefore.middle) * 2
        score += (transition.harmonyAfter.outer - transition.harmonyBefore.outer) * 3
        score += (transition.twinTurnsAfter - transition.twinTurnsBefore) * 300
        score += Int((transition.bouquetAfter.rawValue ^ transition.bouquetBefore.rawValue).nonzeroBitCount) * 150
        if transition.matchedOrderRing != nil { score += 250 }
        if transition.unbrokenAfter.current > transition.unbrokenBefore.current { score += 20 }
        if transition.newlyInfectedSpoke != nil { score -= 200 }
        // Prefer an equally short authored route which never needs dead-board repair.
        // Repair remains part of the exact state graph, so this changes only stable
        // deterministic tie-breaking, not reachability or shortest-route proof.
        if transition.didReshuffle { score -= 1_000_000 }
        return score
    }
}

struct FlowerShowHintRequest: Sendable {
    let attemptID: UUID
    let state: FlowerShowState
    let scenario: FlowerShowScenario
    let preferredMaximumDepth: Int
}

enum FlowerShowHintResult: Sendable, Equatable {
    case move(GameMove, routeLength: Int)
    case provenNoRoute
    case timedOut
    case cancelled
}

protocol FlowerShowHintSolving: Sendable {
    func solve(_ request: FlowerShowHintRequest) async -> FlowerShowHintResult
}

actor ExactFlowerShowHintSolver: FlowerShowHintSolving {
    private struct CacheKey: Hashable {
        let scenarioID: String
        let scenarioDigest: String
        let state: FlowerShowSearchKey
    }

    private var cache: [CacheKey: FlowerShowHintResult] = [:]
    private var inFlight: [CacheKey: Task<FlowerShowHintResult, Never>] = [:]
    private let timeoutNanoseconds: UInt64

    init(timeoutNanoseconds: UInt64 = 1_000_000_000) {
        self.timeoutNanoseconds = timeoutNanoseconds
    }

    func solve(_ request: FlowerShowHintRequest) async -> FlowerShowHintResult {
        let key = CacheKey(
            scenarioID: request.scenario.scenarioID,
            scenarioDigest: request.scenario.scenarioDigest,
            state: FlowerShowSearchKey(request.state)
        )
        if let cached = cache[key] { return cached }
        if let inFlight = inFlight[key] { return await inFlight.value }
        if Task.isCancelled { return .cancelled }

        let task = Task.detached { [timeoutNanoseconds] in
            await withTaskGroup(of: FlowerShowHintResult.self) { group in
                group.addTask {
                    if request.preferredMaximumDepth > 0,
                       let preferred = FlowerShowExactSolver.shortestRoute(
                           from: request.state,
                           scenario: request.scenario,
                           maximumDepth: min(request.preferredMaximumDepth, request.state.movesRemaining),
                           cancellation: { Task.isCancelled }
                       ),
                       let move = preferred.moves.first
                    {
                        return .move(move, routeLength: preferred.moves.count)
                    }
                    let solution = FlowerShowExactSolver.shortestRoute(
                        from: request.state,
                        scenario: request.scenario,
                        maximumDepth: request.state.movesRemaining,
                        cancellation: { Task.isCancelled }
                    )
                    if Task.isCancelled { return .cancelled }
                    guard let solution, let move = solution.moves.first else { return .provenNoRoute }
                    return .move(move, routeLength: solution.moves.count)
                }
                group.addTask {
                    try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                    return Task.isCancelled ? .cancelled : .timedOut
                }
                let first = await group.next() ?? .cancelled
                group.cancelAll()
                return first
            }
        }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil

        if case .cancelled = result {
            return result
        }
        if case .timedOut = result {
            return result
        }
        cache[key] = result
        return result
    }
}
