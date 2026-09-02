import Darwin
import Foundation

@main
enum FlowerShowSimulation {
    static func main() {
        var completions = 0
        var repairs = 0
        var maximumMoves = 0
        var failures: [String] = []

        for definition in FlowerShowClassDefinition.all {
            for offset in UInt64(0) ..< 11 {
                let report = FlowerShowSolver.solve(
                    definition,
                    seed: definition.seed ^ (offset &* 0x9E37_79B9_7F4A_7C15)
                )
                record(
                    report,
                    label: "Class \(definition.number), seed offset \(offset)",
                    completions: &completions,
                    repairs: &repairs,
                    maximumMoves: &maximumMoves,
                    failures: &failures
                )
            }
        }

        let circuitStart = FlowerShowClassDefinition.championCircuitStartClass
        for number in circuitStart ... circuitStart + 49 {
            let report = FlowerShowSolver.solve(.classNumber(number))
            record(
                report,
                label: "Champion Circuit Class \(number)",
                completions: &completions,
                repairs: &repairs,
                maximumMoves: &maximumMoves,
                failures: &failures
            )
        }

        print("FLOWER_SHOW_SIMULATION completions=\(completions) repairs=\(repairs) maxMoves=\(maximumMoves)")
        if failures.isEmpty == false {
            for failure in failures {
                print("FAILED \(failure)")
            }
            exit(EXIT_FAILURE)
        }

        runDifficultyAudit()
    }

    private static func record(
        _ report: FlowerShowSolverReport,
        label: String,
        completions: inout Int,
        repairs: inout Int,
        maximumMoves: inout Int,
        failures: inout [String]
    ) {
        guard report.phase == .won, report.objectivesComplete else {
            failures.append(label)
            return
        }
        completions += 1
        repairs += report.repairCount
        maximumMoves = max(maximumMoves, report.movesUsed)
    }

    private static func runDifficultyAudit() {
        let trialsPerClass = 50

        for strategy in AuditStrategy.allCases {
            var bands = Array(repeating: AuditBand(), count: 6)

            for definition in FlowerShowClassDefinition.all {
                for trial in 0 ..< trialsPerClass {
                    let seed = definition.seed
                        ^ (UInt64(trial) &* 0x9E37_79B9_7F4A_7C15)
                    let result = play(definition, seed: seed, strategy: strategy)
                    bands[(definition.number - 1) / 5].record(result)
                }
            }

            for (index, band) in bands.enumerated() {
                let start = index * 5 + 1
                let end = start + 4
                print(
                    "FLOWER_SHOW_DIFFICULTY strategy=\(strategy.rawValue) "
                        + "classes=\(start)-\(end) "
                        + "wins=\(band.wins)/\(band.attempts) "
                        + "winRate=\(percentage(band.winRate)) "
                        + "avgMoves=\(decimal(band.averageMoves)) "
                        + "avgRepairs=\(decimal(band.averageRepairs))"
                )
            }
        }
    }

    private static func play(
        _ definition: FlowerShowClassDefinition,
        seed: UInt64,
        strategy: AuditStrategy
    ) -> AuditResult {
        var engine = GameEngine(flowerShow: definition, seed: seed)
        var picker = AuditRandom(seed: seed ^ 0xA11D_17A5)
        var moves = 0
        var repairs = 0
        let allMoves = Ring.allCases.flatMap { ring in
            RotationDirection.allCases.map { GameMove(ring: ring, direction: $0) }
        }

        while engine.phase == .playing {
            let candidates: [GameMove]
            switch strategy {
            case .objectiveAware:
                candidates = engine.suggestedMove.map { [$0] } ?? []
            case .scoringOnly:
                let scoringMoves = engine.board.scoringMoves
                let largestBloom = scoringMoves.map { engine.board.bloomSpokes(after: $0).count }.max() ?? 0
                candidates = scoringMoves.filter {
                    engine.board.bloomSpokes(after: $0).count == largestBloom
                }
            case .blind:
                candidates = allMoves
            }

            guard candidates.isEmpty == false else { break }
            let move = candidates[picker.nextInt(upperBound: candidates.count)]
            engine.select(move.ring)
            guard let result = engine.rotate(move.direction) else { break }
            moves += 1
            if result.didReshuffle { repairs += 1 }
        }

        return AuditResult(won: engine.phase == .won, moves: moves, repairs: repairs)
    }

    private static func percentage(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    private static func decimal(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}

private enum AuditStrategy: String, CaseIterable {
    case objectiveAware
    case scoringOnly
    case blind
}

private struct AuditResult {
    let won: Bool
    let moves: Int
    let repairs: Int
}

private struct AuditBand {
    private(set) var attempts = 0
    private(set) var wins = 0
    private var moves = 0
    private var repairs = 0

    var winRate: Double { attempts == 0 ? 0 : Double(wins) / Double(attempts) }
    var averageMoves: Double { attempts == 0 ? 0 : Double(moves) / Double(attempts) }
    var averageRepairs: Double { attempts == 0 ? 0 : Double(repairs) / Double(attempts) }

    mutating func record(_ result: AuditResult) {
        attempts += 1
        if result.won { wins += 1 }
        moves += result.moves
        repairs += result.repairs
    }
}

private struct AuditRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func nextInt(upperBound: Int) -> Int {
        precondition(upperBound > 0)
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        value ^= value >> 31
        return Int(value % UInt64(upperBound))
    }
}
