import Foundation

enum FlowerShowReducer {
    static func apply(
        _ move: GameMove,
        to state: FlowerShowState,
        rules: FlowerShowScenario
    ) -> FlowerShowTransition {
        precondition(state.phase == .playing, "Only a playing Flower Show state can accept a move.")

        let before = state
        var after = state
        let objectives = rules.objectives
        let harmonyBefore = state.harmonyCredits
        let unbrokenBefore = state.unbroken
        let countdownBefore = state.bindweedCountdown
        let twinBefore = state.twinBloomTurns
        let bouquetBefore = state.bouquetKinds
        let completedBefore = completedObjectiveIDs(in: state, scenario: rules)

        after.selectedRing = move.ring
        after.board.rotate(move.ring, direction: move.direction)
        after.movesRemaining -= 1
        after.turnNumber += 1

        let bloomSpokes = after.board.bloomSpokes
        let bloomEvents = bloomSpokes.map {
            BloomEvent(spoke: $0, kind: after.board[.inner, $0])
        }

        if bloomEvents.isEmpty {
            after.unbroken.current = 0
        } else {
            after.unbroken.current += 1
            after.unbroken.best = max(after.unbroken.best, after.unbroken.current)
            after.blooms += bloomEvents.count
            let combo = bloomEvents.count
            after.score += 100 * combo * combo

            if objectives.harmonyCreditsPerRing > 0 {
                after.harmonyCredits[move.ring] = min(
                    objectives.harmonyCreditsPerRing,
                    after.harmonyCredits[move.ring] + 1
                )
            }
            if objectives.twinBloomTurns > 0, bloomEvents.count >= 2 {
                after.twinBloomTurns = min(objectives.twinBloomTurns, after.twinBloomTurns + 1)
            }
            if objectives.bouquetKinds.isEmpty == false {
                for event in bloomEvents {
                    after.bouquetKinds.insert(PetalKindMask(event.kind))
                }
            }
        }

        let matchedOrderRing: Ring?
        if bloomEvents.isEmpty == false,
           after.judgesOrderIndex < objectives.judgesOrder.count,
           objectives.judgesOrder[after.judgesOrderIndex] == move.ring
        {
            matchedOrderRing = move.ring
            after.judgesOrderIndex += 1
        } else {
            matchedOrderRing = nil
        }

        let clearedSpokes = bloomSpokes.filter(after.infectedSpokes.contains)
        after.infectedSpokes.subtract(clearedSpokes)

        var spreadSource: Int?
        var newlyInfected: Int?
        if objectives.bindweed != nil {
            if after.infectedSpokes.isEmpty {
                after.bindweedCountdown = nil
            } else if clearedSpokes.isEmpty == false {
                after.bindweedCountdown = objectives.bindweed?.spreadInterval ?? 3
            } else {
                let next = (after.bindweedCountdown ?? objectives.bindweed?.spreadInterval ?? 3) - 1
                if next > 0 {
                    after.bindweedCountdown = next
                } else {
                    let spread = bindweedSpread(from: after.infectedSpokes)
                    spreadSource = spread?.source
                    newlyInfected = spread?.destination
                    if let destination = spread?.destination {
                        after.infectedSpokes.insert(destination)
                    }
                    after.bindweedCountdown = objectives.bindweed?.spreadInterval ?? 3
                }
            }
        }

        if bloomSpokes.isEmpty == false {
            refill(
                board: &after.board,
                spokes: bloomSpokes,
                activeKindCount: rules.activeKindCount,
                state: &after.refillState
            )
        }

        if after.isComplete(for: rules) {
            after.phase = .won
        } else if after.movesRemaining <= 0 {
            after.phase = .lost
        }

        var didReshuffle = false
        if after.phase == .playing, after.board.scoringMoves.isEmpty {
            after.board = repairedBoard(for: after, scenario: rules)
            didReshuffle = true
        }

        let completedAfter = completedObjectiveIDs(in: after, scenario: rules)
        let nextOrder = after.judgesOrderIndex < objectives.judgesOrder.count
            ? objectives.judgesOrder[after.judgesOrderIndex]
            : nil

        return FlowerShowTransition(
            stateBeforeFingerprint: FlowerShowStateFingerprint(state: before),
            stateAfter: after,
            ring: move.ring,
            direction: move.direction,
            blooms: bloomEvents,
            harmonyBefore: harmonyBefore,
            harmonyAfter: after.harmonyCredits,
            unbrokenBefore: unbrokenBefore,
            unbrokenAfter: after.unbroken,
            clearedBindweedSpokes: clearedSpokes,
            spreadSourceSpoke: spreadSource,
            newlyInfectedSpoke: newlyInfected,
            bindweedCountdownBefore: countdownBefore,
            bindweedCountdownAfter: after.bindweedCountdown,
            twinTurnsBefore: twinBefore,
            twinTurnsAfter: after.twinBloomTurns,
            bouquetBefore: bouquetBefore,
            bouquetAfter: after.bouquetKinds,
            matchedOrderRing: matchedOrderRing,
            nextOrderRing: nextOrder,
            completedObjectiveIDs: completedAfter.subtracting(completedBefore),
            didReshuffle: didReshuffle,
            phase: after.phase
        )
    }

    static func completedObjectiveIDs(
        in state: FlowerShowState,
        scenario: FlowerShowScenario
    ) -> Set<FlowerShowObjectiveID> {
        let objectives = scenario.objectives
        var completed: Set<FlowerShowObjectiveID> = []
        if objectives.harmonyCreditsPerRing > 0,
           state.harmonyCredits.satisfies(objectives.harmonyCreditsPerRing)
        {
            completed.insert(.harmony)
        }
        if let chain = objectives.unbrokenChain, state.unbroken.best >= chain {
            completed.insert(.unbroken)
        }
        if objectives.bindweed != nil, state.infectedSpokes.isEmpty {
            completed.insert(.bindweed)
        }
        if objectives.twinBloomTurns > 0, state.twinBloomTurns >= objectives.twinBloomTurns {
            completed.insert(.twinBloom)
        }
        if objectives.bouquetKinds.isEmpty == false,
           state.bouquetKinds.isSuperset(of: objectives.bouquetKinds)
        {
            completed.insert(.prizeBouquet)
        }
        if objectives.judgesOrder.isEmpty == false,
           state.judgesOrderIndex >= objectives.judgesOrder.count
        {
            completed.insert(.judgesOrder)
        }
        return completed
    }

    static func bindweedSpread(from infectedSpokes: Set<Int>) -> (source: Int, destination: Int)? {
        guard infectedSpokes.count < GameBoard.slotsPerRing else { return nil }
        for source in infectedSpokes.sorted() {
            for destination in [
                GameBoard.normalized(source + 1),
                GameBoard.normalized(source - 1),
            ] where infectedSpokes.contains(destination) == false {
                return (source, destination)
            }
        }
        return nil
    }

    private static func refill(
        board: inout GameBoard,
        spokes: [Int],
        activeKindCount: Int,
        state: inout FlowerShowRefillState
    ) {
        let kinds = Array(PetalKind.allCases.prefix(activeKindCount))
        for spoke in spokes.sorted() {
            for ring in Ring.allCases {
                board.set(kinds[state.nextInt(upperBound: kinds.count)], at: spoke, in: ring)
            }
            if board[.inner, spoke] == board[.middle, spoke],
               board[.middle, spoke] == board[.outer, spoke]
            {
                let current = board[.outer, spoke]
                let replacement = kinds.first { $0 != current } ?? .coral
                board.set(replacement, at: spoke, in: .outer)
            }
        }
    }

    private static func repairedBoard(
        for state: FlowerShowState,
        scenario: FlowerShowScenario
    ) -> GameBoard {
        let petals = state.board.rings.flatMap(\.self)
        var repairState = FlowerShowRefillState(seed: stableRepairSeed(state: state, salt: scenario.repairSalt))

        for _ in 0 ..< 256 {
            var shuffled = petals
            if shuffled.count > 1 {
                for index in stride(from: shuffled.count - 1, through: 1, by: -1) {
                    let other = repairState.nextInt(upperBound: index + 1)
                    if other != index { shuffled.swapAt(index, other) }
                }
            }
            let rings = stride(from: 0, to: shuffled.count, by: GameBoard.slotsPerRing).map {
                Array(shuffled[$0 ..< $0 + GameBoard.slotsPerRing])
            }
            let candidate = GameBoard(rings: rings)
            if candidate.isStable, candidate.scoringMoves.isEmpty == false {
                return candidate
            }
        }

        var fallback = state.board
        let kinds = Array(PetalKind.allCases.prefix(scenario.activeKindCount))
        let destination = repairState.nextInt(upperBound: GameBoard.slotsPerRing)
        let source = GameBoard.normalized(destination - RotationDirection.clockwise.slotOffset)
        let rotatingRing = Ring.allCases[repairState.nextInt(upperBound: Ring.allCases.count)]
        let kind = kinds[repairState.nextInt(upperBound: kinds.count)]
        for ring in Ring.allCases where ring != rotatingRing {
            fallback.set(kind, at: destination, in: ring)
        }
        fallback.set(kind, at: source, in: rotatingRing)
        fallback.set(kinds.first { $0 != kind } ?? .coral, at: destination, in: rotatingRing)
        for spoke in fallback.bloomSpokes {
            fallback.set(kinds.first { $0 != fallback[.outer, spoke] } ?? .coral, at: spoke, in: .outer)
        }
        return fallback
    }

    private static func stableRepairSeed(state: FlowerShowState, salt: UInt64) -> UInt64 {
        var value = salt ^ state.refillState.value ^ UInt64(state.blooms &* 31 + state.movesRemaining)
        func mix(_ input: UInt64) {
            value ^= input &+ 0x9E37_79B9_7F4A_7C15 &+ (value << 6) &+ (value >> 2)
            value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        }
        for ring in Ring.allCases {
            for petal in state.board.petals(in: ring) {
                mix(UInt64(petal.rawValue + 1 + ring.rawValue * 8))
            }
        }
        mix(UInt64(state.harmonyCredits.inner + state.harmonyCredits.middle * 3 + state.harmonyCredits.outer * 9))
        mix(UInt64(state.unbroken.current + state.unbroken.best * 7))
        for spoke in state.infectedSpokes.sorted() { mix(UInt64(spoke + 1)) }
        mix(UInt64(state.twinBloomTurns + Int(state.bouquetKinds.rawValue) * 17 + state.judgesOrderIndex * 31))
        return value
    }
}
