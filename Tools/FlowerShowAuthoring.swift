import Foundation

private struct CertificationRow {
    let displayedClass: String
    let scenarioID: String
    let shortest: Int
    let moveBudget: Int
    let radiantPar: Int
    let slack: Int
    let winningFirstActions: Int
    let meaningfulDecisions: Int
    let maximumForcedRun: Int
    let largestBloomCompletion: Int
    let visibleGreedyCompletion: Int
    let noisyPlannerCompletion: Int
    let repairCount: Int
    let visitedStates: Int
    let solveMilliseconds: Double
    let referenceRoute: [GameMove]

    var markdown: String {
        "| \(displayedClass) | `\(scenarioID)` | \(shortest) | \(moveBudget) | \(radiantPar) | \(slack) | \(winningFirstActions) | \(meaningfulDecisions) | \(maximumForcedRun) | \(largestBloomCompletion)% | \(visibleGreedyCompletion)% | \(noisyPlannerCompletion)% | \(repairCount) | \(visitedStates) | \(solveMilliseconds.formatted(.number.precision(.fractionLength(2)))) | \(routeText) |"
    }

    private var routeText: String {
        referenceRoute.map { "\($0.ring.displayName)-\($0.direction == .clockwise ? "R" : "L")" }
            .joined(separator: " ")
    }
}

private struct DirectionalComparison {
    let peak: String
    let comparator: String
    let passed: Bool
    let evidence: String

    var markdown: String {
        "| `\(peak)` | `\(comparator)` | \(passed ? "PASS" : "FAIL") | \(evidence) |"
    }
}

private struct DifficultyMetrics: Sendable {
    let slack: Int
    let winningFirstActions: Int
    let meaningfulDecisions: Int
    let largestBloomCompletion: Int
    let visibleGreedyCompletion: Int
    let noisyPlannerCompletion: Int
}

private enum CertificationFailure: Error, CustomStringConvertible {
    case invalid(String)

    var description: String {
        switch self {
        case let .invalid(message): message
        }
    }
}

private enum DiagnosticStrategy: UInt64 {
    case largestBloom = 0xB100
    case visibleGreedy = 0xB200
    case noisyPlanner = 0xB300
}

private struct VisibleMoveValue: Equatable {
    let blooms: Int
    let bindweedClears: Int
    let harmonyCredits: Int
    let bouquetKinds: Int
    let unbrokenAdvance: Int
    let twinAdvance: Int
    let judgesAdvance: Int

    var objectiveAdvance: Int {
        bindweedClears + harmonyCredits + bouquetKinds + unbrokenAdvance + twinAdvance + judgesAdvance
    }

    var greedyScore: Int {
        objectiveAdvance * 1_000 + blooms * 100
    }

    func dominates(_ other: Self) -> Bool {
        let pairs = [
            (blooms, other.blooms),
            (bindweedClears, other.bindweedClears),
            (harmonyCredits, other.harmonyCredits),
            (bouquetKinds, other.bouquetKinds),
            (unbrokenAdvance, other.unbrokenAdvance),
            (twinAdvance, other.twinAdvance),
            (judgesAdvance, other.judgesAdvance),
        ]
        return pairs.allSatisfy { $0.0 >= $0.1 }
            && pairs.contains { $0.0 > $0.1 }
    }
}

private struct AuthoringCheckpoint: Codable {
    static let currentFormatVersion = 1

    let formatVersion: Int
    let contentVersion: Int
    var scenarios: [String: FlowerShowScenario]
}

private enum AuthoringOutcome: Sendable {
    case success(index: Int, scenario: FlowerShowScenario)
    case failure(index: Int, message: String)
}

private struct DirectionalRepairRequest: Sendable {
    let peakID: String
    let scenario: FlowerShowScenario
    let comparators: [(id: String, metrics: DifficultyMetrics)]
}

private struct DirectionalRepairOutcome: Sendable {
    let peakID: String
    let scenario: FlowerShowScenario
}

@main
private enum FlowerShowAuthoring {
    private static let allMoves = Ring.allCases.flatMap { ring in
        RotationDirection.allCases.map { GameMove(ring: ring, direction: $0) }
    }
    private static var authoringCheckpointURL: URL {
        URL(
            fileURLWithPath: ProcessInfo.processInfo
                .environment["FLOWER_SHOW_AUTHOR_CHECKPOINT_PATH"]
                ?? ".build/flower-show-authoring-checkpoint.json"
        )
    }

    static func main() async throws {
        let arguments = CommandLine.arguments.dropFirst()
        if arguments.contains("--legacy-fixtures") {
            try writeLegacyFixtures()
            return
        }
        if let scenarioID = value(after: "--author-scenario", in: Array(arguments)) {
            let catalogue = FlowerShowContent.catalogue
            let scenarios = catalogue.campaignScenarios
                + catalogue.curatedCircuitScenarios
                + catalogue.endlessCircuitScenarios
            guard let scenario = scenarios.first(where: { $0.scenarioID == scenarioID }) else {
                throw CertificationFailure.invalid("Unknown scenario \(scenarioID).")
            }
            let authored = try author(scenario)
            let checkpointURL = authoringCheckpointURL
            var cached = try loadAuthoringCheckpoint(
                from: checkpointURL,
                contentVersion: catalogue.contentVersion,
                originals: scenarios
            )
            cached[scenarioID] = authored
            try writeAuthoringCheckpoint(
                cached,
                to: checkpointURL,
                contentVersion: catalogue.contentVersion
            )
            return
        }
        if arguments.contains("--author") {
            try await authorCatalogue()
            return
        }
        if arguments.contains("--repair-directional") {
            try await repairDirectionalPeaks()
            return
        }
        if let rawIDs = value(after: "--reauthor-scenarios", in: Array(arguments)) {
            let scenarioIDs = rawIDs.split(separator: ",").map(String.init)
            try await reauthorScenarios(scenarioIDs)
            return
        }
        guard arguments.contains("--certify") else {
            print("Usage: FlowerShowAuthoring --author | --author-scenario ID | --reauthor-scenarios ID,ID | --repair-directional | --certify [--report PATH] [--smoke] | --legacy-fixtures")
            throw CertificationFailure.invalid("No authoring operation supplied.")
        }

        let smoke = arguments.contains("--smoke")
        let reportPath = value(after: "--report", in: Array(arguments))
            ?? "FLOWER_SHOW_V3_CERTIFICATION_REPORT.md"
        let scenarios = certificationInputs(smoke: smoke)
        var rows: [CertificationRow] = []
        var failures: [String] = []

        for input in scenarios {
            let started = ContinuousClock.now
            let engine = FlowerShowEngine(scenario: input.scenario)
            guard let solution = FlowerShowExactSolver.shortestRoute(
                from: engine.state,
                scenario: input.scenario
            ) else {
                failures.append("\(input.label) / \(input.scenario.scenarioID): no winning route within move budget")
                continue
            }
            let elapsed = started.duration(to: .now)
            let milliseconds = Double(elapsed.components.seconds) * 1_000
                + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000
            let firstActions = FlowerShowExactSolver.winningFirstActions(
                from: engine.state,
                scenario: input.scenario
            )
            if solution.moves.count > input.scenario.radiantPar {
                failures.append(
                    "\(input.label) / \(input.scenario.scenarioID): shortest \(solution.moves.count) exceeds Radiant par \(input.scenario.radiantPar)"
                )
            }
            if solution.moves.count < input.scenario.radiantPar - 1 {
                failures.append(
                    "\(input.label) / \(input.scenario.scenarioID): shortest \(solution.moves.count) is more than one move below Radiant par \(input.scenario.radiantPar)"
                )
            }
            if let plannedPar = plannedRadiantPar(for: input.scenario.scenarioID),
               abs(input.scenario.radiantPar - plannedPar) > 1
            {
                failures.append(
                    "\(input.label) / \(input.scenario.scenarioID): Radiant par \(input.scenario.radiantPar) is more than one move from planned \(plannedPar)"
                )
            }
            if let plannedBudget = plannedMoveBudget(for: input.scenario.scenarioID),
               abs(input.scenario.moveBudget - plannedBudget) > 1
            {
                failures.append(
                    "\(input.label) / \(input.scenario.scenarioID): move budget \(input.scenario.moveBudget) is more than one move from planned \(plannedBudget)"
                )
            }
            if solution.moves.count == input.scenario.radiantPar,
               allowsExactShortestPar(input.scenario.scenarioID) == false
            {
                failures.append(
                    "\(input.label) / \(input.scenario.scenarioID): ordinary fixture uses L rather than the required default L + 1"
                )
            }
            if firstActions.count < 2 {
                failures.append(
                    "\(input.label) / \(input.scenario.scenarioID): only \(firstActions.count) winning first action(s)"
                )
            }
            var reference = engine.state
            var repairCount = 0
            for move in solution.moves {
                let transition = FlowerShowReducer.apply(move, to: reference, rules: input.scenario)
                repairCount += transition.didReshuffle ? 1 : 0
                reference = transition.stateAfter
            }
            if reference.phase != .won {
                failures.append("\(input.label) / \(input.scenario.scenarioID): reference route does not win")
            }
            if repairCount > 0 {
                failures.append("\(input.label) / \(input.scenario.scenarioID): reference route repairs \(repairCount) time(s)")
            }
            let decisionMetrics = referenceDecisionMetrics(
                route: solution.moves,
                initial: engine.state,
                scenario: input.scenario
            )
            if input.scenario.scenarioID.hasPrefix("campaign-"),
               let classNumber = Int(input.scenario.scenarioID.suffix(2)),
               classNumber >= 8,
               decisionMetrics.meaningful == 0
            {
                failures.append("\(input.label) / \(input.scenario.scenarioID): no certified visible objective decision")
            }
            let requiresTwoDecisions = {
                if input.scenario.scenarioID.hasPrefix("campaign-") {
                    return (Int(input.scenario.scenarioID.suffix(2)) ?? 0) >= 21
                }
                return true
            }()
            if requiresTwoDecisions, decisionMetrics.meaningful < 2 {
                failures.append(
                    "\(input.label) / \(input.scenario.scenarioID): \(decisionMetrics.meaningful) meaningful decisions; requires 2"
                )
            }
            if requiresTwoDecisions, decisionMetrics.maximumForcedRun > 2 {
                failures.append(
                    "\(input.label) / \(input.scenario.scenarioID): forced-state run \(decisionMetrics.maximumForcedRun); maximum is 2"
                )
            }
            let rollouts = strategyDiagnostics(
                initial: engine.state,
                scenario: input.scenario,
                count: 200
            )
            failures.append(contentsOf: strategyBandFailures(
                label: input.label,
                scenario: input.scenario,
                rollouts: rollouts
            ))

            rows.append(CertificationRow(
                displayedClass: input.label,
                scenarioID: input.scenario.scenarioID,
                shortest: solution.moves.count,
                moveBudget: input.scenario.moveBudget,
                radiantPar: input.scenario.radiantPar,
                slack: input.scenario.moveBudget - solution.moves.count,
                winningFirstActions: firstActions.count,
                meaningfulDecisions: decisionMetrics.meaningful,
                maximumForcedRun: decisionMetrics.maximumForcedRun,
                largestBloomCompletion: rollouts.largestBloom,
                visibleGreedyCompletion: rollouts.visibleGreedy,
                noisyPlannerCompletion: rollouts.noisyPlanner,
                repairCount: repairCount,
                visitedStates: solution.visitedStateCount,
                solveMilliseconds: milliseconds,
                referenceRoute: solution.moves
            ))
            print("CERTIFIED \(input.label) \(input.scenario.scenarioID) shortest=\(solution.moves.count) first=\(firstActions.count) ms=\(milliseconds.formatted(.number.precision(.fractionLength(2))))")
        }
        let lateCampaignLargest = rows.filter {
            guard $0.scenarioID.hasPrefix("campaign-"),
                  let number = Int($0.scenarioID.suffix(2))
            else {
                return false
            }
            return (27 ... 30).contains(number)
        }
        if lateCampaignLargest.count == 4 {
            let average = lateCampaignLargest.map(\.largestBloomCompletion).reduce(0, +)
                / lateCampaignLargest.count
            if average > 25 {
                failures.append(
                    "Classes 27–30: largest-bloom average \(average)% exceeds the 25% band"
                )
            }
        }
        let directional = directionalComparisons(rows: rows)
        failures.append(contentsOf: directional.compactMap { comparison in
            comparison.passed
                ? nil
                : "\(comparison.peak) does not exceed \(comparison.comparator): \(comparison.evidence)"
        })

        let report = makeReport(
            rows: rows,
            directionalComparisons: directional,
            failures: failures,
            smoke: smoke
        )
        try report.write(toFile: reportPath, atomically: true, encoding: .utf8)
        print("Wrote \(reportPath)")

        if failures.isEmpty == false {
            for failure in failures { fputs("FAIL: \(failure)\n", stderr) }
            throw CertificationFailure.invalid("\(failures.count) certification failure(s)")
        }
        print("FLOWER_SHOW_V3_CERTIFICATION_PASSED scenarios=\(rows.count)")
    }

    private static func writeLegacyFixtures() throws {
        var garden = GameEngine(seed: 0xA11CE, garden: 7)
        if let move = garden.suggestedMove {
            garden.select(move.ring)
            _ = garden.rotate(move.direction)
        }
        let progress = GameProgress(
            bestScore: 4_275,
            highestGarden: 7,
            globalBestStreak: 5,
            radiantGardens: [2, 4],
            activeGame: garden,
            activeGardenSeed: 0xA11CE,
            reviewRequestState: ReviewRequestState(successfulGardenCompletions: 6)
        )
        let encoded = try JSONEncoder().encode(progress)
        var base = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        base["flowerShowIntroduced"] = true
        base["completedFlowerShowClasses"] = [1, 2, 3, 4, 5]
        base["currentFlowerShowClass"] = 6
        base["activeFlowerShow"] = ["malformedObsoletePayload": true]
        base["seenFlowerShowIntroductions"] = ["ringHarmony", "unbroken"]
        base["grandChampionAchieved"] = false
        base["soundEnabled"] = false
        base["hapticsEnabled"] = true
        base.removeValue(forKey: "flowerShowProgress")

        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: "RingbloomTests/Fixtures"),
            withIntermediateDirectories: true
        )
        for version in [1, 2] {
            var fixture = base
            if version == 1 {
                fixture.removeValue(forKey: "flowerShowCampaignVersion")
            } else {
                fixture["flowerShowCampaignVersion"] = 2
            }
            let data = try JSONSerialization.data(
                withJSONObject: fixture,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            )
            let url = URL(fileURLWithPath: "RingbloomTests/Fixtures/legacy-v\(version)-active-garden.json")
            try data.write(to: url, options: .atomic)
            try Data([0x0A]).append(to: url)
            print("Wrote \(url.path)")
        }
    }

    private static func authorCatalogue() async throws {
        let original = FlowerShowContent.catalogue
        let originals = original.campaignScenarios
            + original.curatedCircuitScenarios
            + original.endlessCircuitScenarios
        let checkpointURL = authoringCheckpointURL
        var cached = try loadAuthoringCheckpoint(
            from: checkpointURL,
            contentVersion: original.contentVersion,
            originals: originals
        )
        for intent in originals where cached[intent.scenarioID] == nil {
            guard let plannedPar = plannedRadiantPar(for: intent.scenarioID),
                  intent.radiantPar <= plannedPar
            else {
                continue
            }
            if let promoted = acceptedCandidate(
                intent,
                board: intent.initialBoard,
                refillSeed: intent.refillSource.seed,
                radiantPar: plannedPar
            ) {
                cached[intent.scenarioID] = promoted
                print(
                    "PROMOTED \(intent.scenarioID) par=\(intent.radiantPar)→\(promoted.radiantPar)"
                )
                continue
            }
            let peers = originals.filter {
                $0.scenarioID != intent.scenarioID
                    && $0.targetBlooms == intent.targetBlooms
                    && $0.moveBudget == intent.moveBudget
                    && $0.activeKindCount == intent.activeKindCount
                    && $0.objectives == intent.objectives
            }
            for peer in peers {
                guard let rebound = acceptedCandidate(
                    intent,
                    board: peer.initialBoard,
                    refillSeed: peer.refillSource.seed,
                    radiantPar: plannedPar,
                    repairSalt: peer.repairSalt
                ) else {
                    continue
                }
                cached[intent.scenarioID] = rebound
                print("REBOUND \(intent.scenarioID) from=\(peer.scenarioID) par=\(plannedPar)")
                break
            }
        }
        let searched = try await authorAll(
            originals,
            cached: cached,
            checkpointURL: checkpointURL,
            contentVersion: original.contentVersion
        )
        let authored = zip(originals, searched).map { intent, candidate in
            let preferredPar = plannedRadiantPar(for: candidate.scenarioID)
                ?? intent.radiantPar
            guard candidate.radiantPar < preferredPar else { return candidate }
            return acceptedCandidate(
                intent,
                board: candidate.initialBoard,
                refillSeed: candidate.refillSource.seed,
                radiantPar: candidate.radiantPar + 1
            ) ?? candidate
        }
        try writeAuthoringCheckpoint(
            Dictionary(uniqueKeysWithValues: authored.map { ($0.scenarioID, $0) }),
            to: checkpointURL,
            contentVersion: original.contentVersion
        )
        let campaignEnd = original.campaignScenarios.count
        let curatedEnd = campaignEnd + original.curatedCircuitScenarios.count
        let campaign = Array(authored[..<campaignEnd])
        let curated = Array(authored[campaignEnd ..< curatedEnd])
        let endless = Array(authored[curatedEnd...])

        let lateLargestAverage = campaign[26 ... 29].map { scenario in
            let initial = FlowerShowEngine(scenario: scenario).state
            return strategyDiagnostics(initial: initial, scenario: scenario, count: 200).largestBloom
        }.reduce(0, +) / 4
        guard lateLargestAverage <= 25 else {
            throw CertificationFailure.invalid(
                "Authored Classes 27–30 largest-bloom average \(lateLargestAverage)% exceeds 25%."
            )
        }
        let catalogue = FlowerShowCatalogue(
            contentVersion: original.contentVersion,
            mappingVersion: original.mappingVersion,
            campaignScenarios: campaign,
            curatedCircuitScenarios: curated,
            endlessCircuitScenarios: endless
        )
        try catalogue.validate()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(catalogue)
        let url = URL(fileURLWithPath: "Ringbloom/Resources/FlowerShowV3Catalog.json")
        try data.write(to: url, options: .atomic)
        try Data([0x0A]).append(to: url)
        print("FLOWER_SHOW_V3_AUTHORING_PASSED scenarios=\(campaign.count + curated.count + endless.count)")
    }

    private static func reauthorScenarios(_ scenarioIDs: [String]) async throws {
        let catalogue = FlowerShowContent.catalogue
        let originals = catalogue.campaignScenarios
            + catalogue.curatedCircuitScenarios
            + catalogue.endlessCircuitScenarios
        let byID = Dictionary(uniqueKeysWithValues: originals.map { ($0.scenarioID, $0) })
        let targets = try scenarioIDs.map { scenarioID in
            guard let scenario = byID[scenarioID] else {
                throw CertificationFailure.invalid("Unknown scenario \(scenarioID).")
            }
            return scenario
        }
        let checkpointURL = authoringCheckpointURL
        var cached = try loadAuthoringCheckpoint(
            from: checkpointURL,
            contentVersion: catalogue.contentVersion,
            originals: originals
        )
        for scenarioID in scenarioIDs {
            cached.removeValue(forKey: scenarioID)
        }
        _ = try await authorAll(
            targets,
            cached: cached,
            checkpointURL: checkpointURL,
            contentVersion: catalogue.contentVersion
        )
        print("FLOWER_SHOW_V3_REAUTHOR_PASSED scenarios=\(targets.count)")
    }

    private static func circuitRole(from scenarioID: String) -> Int? {
        guard scenarioID.hasPrefix("circuit-r"),
              let roleCharacter = scenarioID.dropFirst("circuit-r".count).first
        else {
            return nil
        }
        return Int(String(roleCharacter))
    }

    private static func acceptedCandidate(
        _ original: FlowerShowScenario,
        board: GameBoard,
        refillSeed: UInt64,
        radiantPar: Int,
        repairSalt: UInt64? = nil,
        moveBudget: Int? = nil
    ) -> FlowerShowScenario? {
        let candidate = scenario(
            original,
            board: board,
            refillSeed: refillSeed,
            radiantPar: radiantPar,
            repairSalt: repairSalt,
            moveBudget: moveBudget
        )
        let initial = FlowerShowEngine(scenario: candidate).state
        guard let solution = FlowerShowExactSolver.shortestRoute(
            from: initial,
            scenario: candidate,
            maximumDepth: candidate.radiantPar
        ),
        solution.moves.count >= max(1, candidate.radiantPar - 1),
        referenceIsRepairFree(solution.moves, from: initial, scenario: candidate)
        else {
            return nil
        }
        guard solution.moves.count < candidate.radiantPar
            || allowsExactShortestPar(candidate.scenarioID)
        else {
            return nil
        }
        let firstActions = FlowerShowExactSolver.winningFirstActions(
            from: initial,
            scenario: candidate,
            maximumDepth: candidate.moveBudget
        )
        guard firstActions.count >= 2 else { return nil }
        let decisions = referenceDecisionMetrics(
            route: solution.moves,
            initial: initial,
            scenario: candidate
        )
        let requiresTwoDecisions = candidate.scenarioID.hasPrefix("campaign-")
            ? (Int(candidate.scenarioID.suffix(2)) ?? 0) >= 21
            : true
        guard (requiresTwoDecisions == false || decisions.meaningful >= 2),
              (requiresTwoDecisions == false || decisions.maximumForcedRun <= 2)
        else {
            return nil
        }
        let rollouts = strategyDiagnostics(initial: initial, scenario: candidate, count: 200)
        guard strategyBandFailures(
            label: candidate.scenarioID,
            scenario: candidate,
            rollouts: rollouts
        ).isEmpty else {
            return nil
        }
        return candidate
    }

    private static func repairDirectionalPeaks() async throws {
        let catalogue = FlowerShowContent.catalogue
        let originals = catalogue.campaignScenarios
            + catalogue.curatedCircuitScenarios
            + catalogue.endlessCircuitScenarios
        var byID = Dictionary(uniqueKeysWithValues: originals.map { ($0.scenarioID, $0) })
        let grouped = Dictionary(grouping: directionalPairs(), by: \.peak)
        let checkpointURL = authoringCheckpointURL
        var checkpoint = try loadAuthoringCheckpoint(
            from: checkpointURL,
            contentVersion: catalogue.contentVersion,
            originals: originals
        )
        for (scenarioID, scenario) in checkpoint {
            byID[scenarioID] = scenario
        }

        var requests: [DirectionalRepairRequest] = []
        for peakID in grouped.keys.sorted() {
            guard let pairs = grouped[peakID],
                  let current = byID[peakID]
            else {
                throw CertificationFailure.invalid("Missing directional peak \(peakID).")
            }
            let comparators = try pairs.map { pair -> (id: String, metrics: DifficultyMetrics) in
                guard let scenario = byID[pair.comparator] else {
                    throw CertificationFailure.invalid(
                        "Missing directional comparator \(pair.comparator)."
                    )
                }
                return (pair.comparator, try difficultyMetrics(for: scenario))
            }
            let currentMetrics = try difficultyMetrics(for: current)
            let alreadyPasses = comparators.allSatisfy {
                directionalComparison(
                    peakID: peakID,
                    peak: currentMetrics,
                    comparatorID: $0.id,
                    comparator: $0.metrics
                ).passed
            }
            if alreadyPasses {
                print("DIRECTIONAL \(peakID) already passes")
                continue
            }
            if current.moveBudget > 1,
               let tightened = acceptedCandidate(
                   current,
                   board: current.initialBoard,
                   refillSeed: current.refillSource.seed,
                   radiantPar: current.radiantPar,
                   repairSalt: current.repairSalt,
                   moveBudget: current.moveBudget - 1
               )
            {
                let tightenedMetrics = try difficultyMetrics(for: tightened)
                let tightenedPasses = comparators.allSatisfy {
                    directionalComparison(
                        peakID: peakID,
                        peak: tightenedMetrics,
                        comparatorID: $0.id,
                        comparator: $0.metrics
                    ).passed
                }
                if tightenedPasses {
                    byID[peakID] = tightened
                    checkpoint[peakID] = tightened
                    try writeAuthoringCheckpoint(
                        checkpoint,
                        to: checkpointURL,
                        contentVersion: catalogue.contentVersion
                    )
                    print(
                        "DIRECTIONAL \(peakID) tightened moves=\(current.moveBudget)→\(tightened.moveBudget)"
                    )
                    continue
                }
            }
            if peakID.hasPrefix("circuit-r8-") {
                let plannedBudget = plannedMoveBudget(for: peakID) ?? current.moveBudget
                let reboundBudget = min(current.moveBudget, plannedBudget - 1)
                let peers = byID.values
                    .filter {
                        $0.scenarioID != peakID
                            && $0.scenarioID.hasPrefix("circuit-r8-")
                            && $0.targetBlooms == current.targetBlooms
                            && $0.activeKindCount == current.activeKindCount
                            && $0.objectives == current.objectives
                    }
                    .sorted { $0.scenarioID < $1.scenarioID }
                var directionalRebound: FlowerShowScenario?
                for peer in peers {
                    for salt in [current.repairSalt, peer.repairSalt] {
                        guard let rebound = acceptedCandidate(
                            current,
                            board: peer.initialBoard,
                            refillSeed: peer.refillSource.seed,
                            radiantPar: current.radiantPar,
                            repairSalt: salt,
                            moveBudget: reboundBudget
                        ) else {
                            continue
                        }
                        let reboundMetrics = try difficultyMetrics(for: rebound)
                        if comparators.allSatisfy({
                            directionalComparison(
                                peakID: peakID,
                                peak: reboundMetrics,
                                comparatorID: $0.id,
                                comparator: $0.metrics
                            ).passed
                        }) {
                            directionalRebound = rebound
                            print(
                                "DIRECTIONAL \(peakID) rebound from=\(peer.scenarioID) moves=\(rebound.moveBudget)"
                            )
                            break
                        }
                    }
                    if directionalRebound != nil { break }
                }
                if let directionalRebound {
                    byID[peakID] = directionalRebound
                    checkpoint[peakID] = directionalRebound
                    try writeAuthoringCheckpoint(
                        checkpoint,
                        to: checkpointURL,
                        contentVersion: catalogue.contentVersion
                    )
                    continue
                }
            }
            let plannedBudget = plannedMoveBudget(for: peakID) ?? current.moveBudget
            let searchBudget = min(current.moveBudget, plannedBudget - 1)
            let searchScenario = searchBudget < current.moveBudget
                ? scenario(
                    current,
                    board: current.initialBoard,
                    refillSeed: current.refillSource.seed,
                    radiantPar: current.radiantPar,
                    repairSalt: current.repairSalt,
                    moveBudget: searchBudget
                )
                : current
            requests.append(
                DirectionalRepairRequest(
                    peakID: peakID,
                    scenario: searchScenario,
                    comparators: comparators
                )
            )
        }

        let requestedJobs = ProcessInfo.processInfo.environment["FLOWER_SHOW_AUTHOR_JOBS"]
            .flatMap(Int.init) ?? 8
        let jobCount = max(
            1,
            min(requestedJobs, ProcessInfo.processInfo.activeProcessorCount)
        )
        print("Repairing \(requests.count) directional peak(s) with \(jobCount) parallel jobs")
        try await withThrowingTaskGroup(of: DirectionalRepairOutcome.self) { group in
            var cursor = 0
            func submitNext() {
                guard cursor < requests.count else { return }
                let request = requests[cursor]
                cursor += 1
                group.addTask {
                    let replacement = try author(
                        request.scenario,
                        requiredHarderThan: request.comparators,
                        permittedParsOverride: [request.scenario.radiantPar]
                    )
                    return DirectionalRepairOutcome(
                        peakID: request.peakID,
                        scenario: replacement
                    )
                }
            }
            for _ in 0 ..< min(jobCount, requests.count) {
                submitNext()
            }
            while let outcome = try await group.next() {
                byID[outcome.peakID] = outcome.scenario
                checkpoint[outcome.peakID] = outcome.scenario
                try writeAuthoringCheckpoint(
                    checkpoint,
                    to: checkpointURL,
                    contentVersion: catalogue.contentVersion
                )
                print("DIRECTIONAL \(outcome.peakID) repaired")
                submitNext()
            }
        }

        let repaired = FlowerShowCatalogue(
            contentVersion: catalogue.contentVersion,
            mappingVersion: catalogue.mappingVersion,
            campaignScenarios: try catalogue.campaignScenarios.map {
                guard let scenario = byID[$0.scenarioID] else {
                    throw CertificationFailure.invalid("Missing \($0.scenarioID).")
                }
                return scenario
            },
            curatedCircuitScenarios: try catalogue.curatedCircuitScenarios.map {
                guard let scenario = byID[$0.scenarioID] else {
                    throw CertificationFailure.invalid("Missing \($0.scenarioID).")
                }
                return scenario
            },
            endlessCircuitScenarios: try catalogue.endlessCircuitScenarios.map {
                guard let scenario = byID[$0.scenarioID] else {
                    throw CertificationFailure.invalid("Missing \($0.scenarioID).")
                }
                return scenario
            }
        )
        try repaired.validate()
        try writeCatalogue(repaired)
        print("FLOWER_SHOW_V3_DIRECTIONAL_REPAIR_PASSED peaks=\(grouped.count)")
    }

    private static func difficultyMetrics(
        for scenario: FlowerShowScenario
    ) throws -> DifficultyMetrics {
        let initial = FlowerShowEngine(scenario: scenario).state
        guard let solution = FlowerShowExactSolver.shortestRoute(
            from: initial,
            scenario: scenario
        ) else {
            throw CertificationFailure.invalid("\(scenario.scenarioID) has no winning route.")
        }
        let firstActions = FlowerShowExactSolver.winningFirstActions(
            from: initial,
            scenario: scenario
        )
        let decisions = referenceDecisionMetrics(
            route: solution.moves,
            initial: initial,
            scenario: scenario
        )
        let rollouts = strategyDiagnostics(initial: initial, scenario: scenario, count: 200)
        return DifficultyMetrics(
            slack: scenario.moveBudget - solution.moves.count,
            winningFirstActions: firstActions.count,
            meaningfulDecisions: decisions.meaningful,
            largestBloomCompletion: rollouts.largestBloom,
            visibleGreedyCompletion: rollouts.visibleGreedy,
            noisyPlannerCompletion: rollouts.noisyPlanner
        )
    }

    private static func writeCatalogue(_ catalogue: FlowerShowCatalogue) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(catalogue)
        let url = URL(fileURLWithPath: "Ringbloom/Resources/FlowerShowV3Catalog.json")
        try data.write(to: url, options: .atomic)
        try Data([0x0A]).append(to: url)
    }

    private static func authorAll(
        _ originals: [FlowerShowScenario],
        cached: [String: FlowerShowScenario],
        checkpointURL: URL,
        contentVersion: Int
    ) async throws -> [FlowerShowScenario] {
        let requestedJobs = ProcessInfo.processInfo.environment["FLOWER_SHOW_AUTHOR_JOBS"]
            .flatMap(Int.init)
        let jobCount = max(
            1,
            min(requestedJobs ?? 8, ProcessInfo.processInfo.activeProcessorCount)
        )
        print("Authoring \(originals.count) scenarios with \(jobCount) parallel jobs")

        return try await withThrowingTaskGroup(
            of: AuthoringOutcome.self,
            returning: [FlowerShowScenario].self
        ) { group in
            var results = Array<FlowerShowScenario?>(repeating: nil, count: originals.count)
            for (index, original) in originals.enumerated() {
                results[index] = cached[original.scenarioID]
            }
            let pendingIndices = originals.indices.filter { results[$0] == nil }
            var pendingCursor = 0
            var checkpointScenarios = cached
            var failures: [String] = []
            if cached.isEmpty == false {
                print("Resuming with \(cached.count) certified scenario(s)")
            }

            func submitNext() {
                guard pendingCursor < pendingIndices.count else { return }
                let index = pendingIndices[pendingCursor]
                let original = originals[index]
                pendingCursor += 1
                group.addTask {
                    do {
                        return .success(index: index, scenario: try author(original))
                    } catch {
                        return .failure(
                            index: index,
                            message: "\(original.scenarioID): \(error)"
                        )
                    }
                }
            }

            for _ in 0 ..< min(jobCount, pendingIndices.count) {
                submitNext()
            }
            while let outcome = try await group.next() {
                switch outcome {
                case let .success(index, scenario):
                    results[index] = scenario
                    checkpointScenarios[scenario.scenarioID] = scenario
                    do {
                        try writeAuthoringCheckpoint(
                            checkpointScenarios,
                            to: checkpointURL,
                            contentVersion: contentVersion
                        )
                    } catch {
                        failures.append(
                            "\(scenario.scenarioID): could not write checkpoint: \(error)"
                        )
                    }
                case let .failure(index, message):
                    failures.append(message)
                    results[index] = nil
                }
                submitNext()
            }
            if failures.isEmpty == false {
                throw CertificationFailure.invalid(
                    "\(failures.count) authoring failure(s): \(failures.joined(separator: "; "))"
                )
            }
            return try results.enumerated().map { index, scenario in
                guard let scenario else {
                    throw CertificationFailure.invalid(
                        "Authoring produced no result for \(originals[index].scenarioID)."
                    )
                }
                return scenario
            }
        }
    }

    private static func loadAuthoringCheckpoint(
        from url: URL,
        contentVersion: Int,
        originals: [FlowerShowScenario]
    ) throws -> [String: FlowerShowScenario] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        let checkpoint = try JSONDecoder().decode(AuthoringCheckpoint.self, from: data)
        guard checkpoint.formatVersion == AuthoringCheckpoint.currentFormatVersion,
              checkpoint.contentVersion == contentVersion
        else {
            return [:]
        }
        let originalsByID = Dictionary(
            uniqueKeysWithValues: originals.map { ($0.scenarioID, $0) }
        )
        return checkpoint.scenarios.filter { scenarioID, candidate in
            guard let original = originalsByID[scenarioID] else { return false }
            return candidateMatchesIntent(candidate, original: original)
        }
    }

    private static func writeAuthoringCheckpoint(
        _ scenarios: [String: FlowerShowScenario],
        to url: URL,
        contentVersion: Int
    ) throws {
        let checkpoint = AuthoringCheckpoint(
            formatVersion: AuthoringCheckpoint.currentFormatVersion,
            contentVersion: contentVersion,
            scenarios: scenarios
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(checkpoint).write(to: url, options: .atomic)
    }

    private static func candidateMatchesIntent(
        _ candidate: FlowerShowScenario,
        original: FlowerShowScenario
    ) -> Bool {
        let plannedPar = plannedRadiantPar(for: candidate.scenarioID)
            ?? original.radiantPar
        let plannedBudget = plannedMoveBudget(for: candidate.scenarioID)
            ?? original.moveBudget
        let permittedPars = [plannedPar - 1, plannedPar, plannedPar + 1]
        return candidate.scenarioID == original.scenarioID
            && candidate.startingSelectedRing == original.startingSelectedRing
            && candidate.targetBlooms == original.targetBlooms
            && abs(candidate.moveBudget - plannedBudget) <= 1
            && permittedPars.contains(candidate.radiantPar)
            && candidate.activeKindCount == original.activeKindCount
            && candidate.objectives == original.objectives
            && candidate.scenarioDigest == FlowerShowContent.digest(for: candidate)
    }

    private static func author(
        _ original: FlowerShowScenario,
        requiredHarderThan comparators: [(id: String, metrics: DifficultyMetrics)] = [],
        permittedParsOverride: [Int]? = nil
    ) throws -> FlowerShowScenario {
        let stride: UInt64 = 0x9E37_79B9_7F4A_7C15
        let startAttempt = ProcessInfo.processInfo.environment["FLOWER_SHOW_AUTHOR_START_ATTEMPT"]
            .flatMap(Int.init) ?? 0
        let maximumAttempts = ProcessInfo.processInfo.environment["FLOWER_SHOW_AUTHOR_MAX_ATTEMPTS"]
            .flatMap(Int.init) ?? 16_384
        guard startAttempt >= 0, maximumAttempts > startAttempt else {
            throw CertificationFailure.invalid(
                "Invalid authoring attempt range \(startAttempt)..<\(maximumAttempts)."
            )
        }
        for attempt in startAttempt ..< maximumAttempts {
            if Task.isCancelled {
                throw CancellationError()
            }
            // Candidate generation is derived only from immutable authored intent.
            // Re-running --author therefore produces byte-identical catalogue data.
            let seed = (original.repairSalt ^ 0x5A5A_5A5A_D1B5_4A32)
                &+ (UInt64(attempt) &* stride)
            let board = authoredBoard(
                seed: original.repairSalt ^ UInt64(attempt) ^ 0xA076_1D64_78BD_642F,
                activeKindCount: original.activeKindCount
            )
            let plannedPar = plannedRadiantPar(for: original.scenarioID)
                ?? original.radiantPar
            let permittedPars = permittedParsOverride ?? [
                plannedPar,
                plannedPar - 1,
                plannedPar + 1,
            ].filter { $0 > 0 && $0 <= original.moveBudget }
            for radiantPar in permittedPars {
                let candidate = scenario(
                    original,
                    board: board,
                    refillSeed: seed,
                    radiantPar: radiantPar
                )
                let initial = FlowerShowEngine(scenario: candidate).state
                guard let solution = FlowerShowExactSolver.shortestRoute(
                    from: initial,
                    scenario: candidate,
                    maximumDepth: candidate.radiantPar
                ),
                solution.moves.count >= max(1, candidate.radiantPar - 1),
                referenceIsRepairFree(solution.moves, from: initial, scenario: candidate)
                else {
                    continue
                }
                if solution.moves.count == candidate.radiantPar,
                   allowsExactShortestPar(candidate.scenarioID) == false
                {
                    continue
                }
                let firstActions = FlowerShowExactSolver.winningFirstActions(
                    from: initial,
                    scenario: candidate,
                    maximumDepth: candidate.moveBudget
                )
                guard firstActions.count >= 2 else { continue }
                let decisionMetrics = referenceDecisionMetrics(
                    route: solution.moves,
                    initial: initial,
                    scenario: candidate
                )
                if candidate.scenarioID.hasPrefix("campaign-"),
                   let classNumber = Int(candidate.scenarioID.suffix(2)),
                   classNumber >= 8,
                   decisionMetrics.meaningful == 0
                {
                    continue
                }
                let requiresTwoDecisions = candidate.scenarioID.hasPrefix("campaign-")
                    ? (Int(candidate.scenarioID.suffix(2)) ?? 0) >= 21
                    : true
                guard (requiresTwoDecisions == false || decisionMetrics.meaningful >= 2),
                      (requiresTwoDecisions == false || decisionMetrics.maximumForcedRun <= 2)
                else {
                    continue
                }
                let rollouts = strategyDiagnostics(
                    initial: initial,
                    scenario: candidate,
                    count: 200
                )
                guard strategyBandFailures(
                    label: candidate.scenarioID,
                    scenario: candidate,
                    rollouts: rollouts
                ).isEmpty else {
                    continue
                }
                let strictLateLargest = ProcessInfo.processInfo
                    .environment["FLOWER_SHOW_AUTHOR_STRICT_LATE_LARGEST"] == "1"
                if strictLateLargest,
                   candidate.scenarioID.hasPrefix("campaign-"),
                   let classNumber = Int(candidate.scenarioID.suffix(2)),
                   (27 ... 30).contains(classNumber),
                   rollouts.largestBloom > 25
                {
                    continue
                }
                let candidateMetrics = DifficultyMetrics(
                    slack: candidate.moveBudget - solution.moves.count,
                    winningFirstActions: firstActions.count,
                    meaningfulDecisions: decisionMetrics.meaningful,
                    largestBloomCompletion: rollouts.largestBloom,
                    visibleGreedyCompletion: rollouts.visibleGreedy,
                    noisyPlannerCompletion: rollouts.noisyPlanner
                )
                if let minimumGreedy = ProcessInfo.processInfo
                    .environment["FLOWER_SHOW_AUTHOR_MIN_VISIBLE_GREEDY"]
                    .flatMap(Int.init),
                   candidateMetrics.visibleGreedyCompletion < minimumGreedy
                {
                    continue
                }
                if let maximumDecisions = ProcessInfo.processInfo
                    .environment["FLOWER_SHOW_AUTHOR_MAX_MEANINGFUL_DECISIONS"]
                    .flatMap(Int.init),
                   candidateMetrics.meaningfulDecisions > maximumDecisions
                {
                    continue
                }
                guard comparators.allSatisfy({
                    directionalComparison(
                        peakID: candidate.scenarioID,
                        peak: candidateMetrics,
                        comparatorID: $0.id,
                        comparator: $0.metrics
                    ).passed
                }) else {
                    continue
                }
                print(
                    "AUTHORED \(candidate.scenarioID) refill=\(seed) par=\(radiantPar) shortest=\(solution.moves.count) first=\(firstActions.count) attempts=\(attempt + 1)"
                )
                return candidate
            }
        }
        throw CertificationFailure.invalid("Could not author a repair-free refill for \(original.scenarioID).")
    }

    private static func scenario(
        _ original: FlowerShowScenario,
        board: GameBoard,
        refillSeed: UInt64,
        radiantPar: Int,
        repairSalt: UInt64? = nil,
        moveBudget: Int? = nil
    ) -> FlowerShowScenario {
        let undigested = FlowerShowScenario(
            scenarioID: original.scenarioID,
            scenarioDigest: "",
            initialBoard: board,
            startingSelectedRing: original.startingSelectedRing,
            refillSource: FlowerShowRefillSource(seed: refillSeed),
            repairSalt: repairSalt ?? original.repairSalt,
            targetBlooms: original.targetBlooms,
            moveBudget: moveBudget ?? original.moveBudget,
            radiantPar: radiantPar,
            activeKindCount: original.activeKindCount,
            objectives: original.objectives
        )
        return FlowerShowScenario(
            scenarioID: undigested.scenarioID,
            scenarioDigest: FlowerShowContent.digest(for: undigested),
            initialBoard: undigested.initialBoard,
            startingSelectedRing: undigested.startingSelectedRing,
            refillSource: undigested.refillSource,
            repairSalt: undigested.repairSalt,
            targetBlooms: undigested.targetBlooms,
            moveBudget: undigested.moveBudget,
            radiantPar: undigested.radiantPar,
            activeKindCount: undigested.activeKindCount,
            objectives: undigested.objectives
        )
    }

    private static func authoredBoard(seed: UInt64, activeKindCount: Int) -> GameBoard {
        var random = FlowerShowRefillState(seed: seed)
        let kinds = Array(PetalKind.allCases.prefix(activeKindCount))
        for _ in 0 ..< 200_000 {
            let board = GameBoard(rings: Ring.allCases.map { _ in
                (0 ..< GameBoard.slotsPerRing).map { _ in
                    kinds[random.nextInt(upperBound: kinds.count)]
                }
            })
            let moves = board.scoringMoves
            if board.isStable,
               moves.count >= 2,
               Set(moves.map(\.ring)).count >= 2
            {
                return board
            }
        }
        preconditionFailure("Could not materialise authored board for seed \(seed).")
    }

    private static func referenceIsRepairFree(
        _ route: [GameMove],
        from initial: FlowerShowState,
        scenario: FlowerShowScenario
    ) -> Bool {
        var state = initial
        for move in route {
            let transition = FlowerShowReducer.apply(move, to: state, rules: scenario)
            if transition.didReshuffle { return false }
            state = transition.stateAfter
        }
        return state.phase == .won
    }

    private static func certificationInputs(smoke: Bool) -> [(label: String, scenario: FlowerShowScenario)] {
        if smoke {
            return [1, 21, 30, 33, 38, 39, 166].map {
                ("Class \($0)", FlowerShowContent.resolve(classNumber: $0).scenario)
            }
        }
        var result: [(String, FlowerShowScenario)] = []
        result += (1 ... 38).map { ("Class \($0)", FlowerShowContent.resolve(classNumber: $0).scenario) }
        for (index, scenario) in FlowerShowContent.catalogue.endlessCircuitScenarios.enumerated() {
            result.append(("Catalogue \(index + 1)", scenario))
        }
        return result
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    private static func makeReport(
        rows: [CertificationRow],
        directionalComparisons: [DirectionalComparison],
        failures: [String],
        smoke: Bool
    ) -> String {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        var lines = [
            "# Flower Show V3 certification report",
            "",
            "- Generated: \(timestamp)",
            "- Content version: \(FlowerShowContent.contentVersion)",
            "- Mapping version: \(FlowerShowContent.mappingVersion)",
            "- Scope: \(smoke ? "smoke sample" : "30 campaign, Classes 31–38 and 128 endless catalogue fixtures")",
            "- Result: \(failures.isEmpty ? "PASS" : "FAIL")",
            "",
            "| Class / fixture | Scenario | Shortest | Moves | Radiant par | Slack | Winning first actions | Meaningful decisions | Max forced run | Largest bloom | Visible greedy | Noisy planner | Repairs | Visited states | Cold solve (ms) | Reference route |",
            "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|",
        ]
        lines += rows.map(\.markdown)
        let parDeviations = rows.compactMap { row -> String? in
            guard let planned = plannedRadiantPar(for: row.scenarioID),
                  planned != row.radiantPar
            else {
                return nil
            }
            return "- `\(row.scenarioID)`: \(planned) → \(row.radiantPar). Exact authored shortest is \(row.shortest), so the shipped par is \(row.radiantPar == row.shortest ? "L" : "L + 1"); the one-move adjustment keeps the advertised rating solver-honest."
        }
        if parDeviations.isEmpty == false {
            lines += [
                "",
                "## Authorised one-move Radiant-par deviations",
                "",
            ]
            lines += parDeviations
        }
        let budgetDeviations = rows.compactMap { row -> String? in
            guard let planned = plannedMoveBudget(for: row.scenarioID),
                  planned != row.moveBudget
            else {
                return nil
            }
            return "- `\(row.scenarioID)`: \(planned) → \(row.moveBudget). The one-move tightening is exact-solver safe and is required to preserve the release-to-peak difficulty relationship."
        }
        if budgetDeviations.isEmpty == false {
            lines += [
                "",
                "## Authorised one-move budget deviations",
                "",
            ]
            lines += budgetDeviations
        }
        if directionalComparisons.isEmpty == false {
            lines += [
                "",
                "## Directional peak comparisons",
                "",
                "| Peak | Comparator | Result | Evidence |",
                "|---|---|---|---|",
            ]
            lines += directionalComparisons.map(\.markdown)
        }
        if failures.isEmpty == false {
            lines += ["", "## Failures", ""]
            lines += failures.map { "- \($0)" }
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }

    private static func plannedRadiantPar(for scenarioID: String) -> Int? {
        let campaign = [
            7, 7, 6, 7, 7, 6, 6, 7, 7, 7,
            6, 7, 7, 8, 8, 6, 7, 7, 8, 8,
            7, 7, 8, 7, 8, 7, 8, 8, 8, 9,
        ]
        let circuit = [8, 8, 8, 8, 9, 8, 9, 10]
        if scenarioID.hasPrefix("campaign-"),
           let number = Int(scenarioID.suffix(2)),
           campaign.indices.contains(number - 1)
        {
            return campaign[number - 1]
        }
        if scenarioID.hasPrefix("circuit-curated-"),
           let number = Int(scenarioID.suffix(2)),
           (31 ... 38).contains(number)
        {
            return circuit[number - 31]
        }
        if let role = circuitRole(from: scenarioID), circuit.indices.contains(role - 1) {
            return circuit[role - 1]
        }
        return nil
    }

    private static func plannedMoveBudget(for scenarioID: String) -> Int? {
        let campaign = [
            9, 9, 8, 8, 8, 8, 8, 8, 9, 8,
            8, 8, 8, 9, 9, 8, 8, 9, 9, 10,
            9, 9, 9, 9, 10, 9, 10, 10, 10, 11,
        ]
        let circuit = [10, 10, 10, 10, 11, 10, 11, 12]
        if scenarioID.hasPrefix("campaign-"),
           let number = Int(scenarioID.suffix(2)),
           campaign.indices.contains(number - 1)
        {
            return campaign[number - 1]
        }
        if scenarioID.hasPrefix("circuit-curated-"),
           let number = Int(scenarioID.suffix(2)),
           (31 ... 38).contains(number)
        {
            return circuit[number - 31]
        }
        if let role = circuitRole(from: scenarioID), circuit.indices.contains(role - 1) {
            return circuit[role - 1]
        }
        return nil
    }

    private static func allowsExactShortestPar(_ scenarioID: String) -> Bool {
        if scenarioID.hasPrefix("campaign-"),
           let number = Int(scenarioID.suffix(2))
        {
            return [5, 10, 15, 20, 25, 29, 30].contains(number)
        }
        if scenarioID == "circuit-curated-37"
            || scenarioID == "circuit-curated-38"
        {
            return true
        }
        return scenarioID.hasPrefix("circuit-r7-")
            || scenarioID.hasPrefix("circuit-r8-")
    }

    private static func directionalComparisons(
        rows: [CertificationRow]
    ) -> [DirectionalComparison] {
        let byID = Dictionary(uniqueKeysWithValues: rows.map { ($0.scenarioID, $0) })
        return directionalPairs().compactMap { pair in
            guard let peak = byID[pair.peak], let comparator = byID[pair.comparator] else {
                return nil
            }
            return directionalComparison(
                peakID: pair.peak,
                peak: difficultyMetrics(from: peak),
                comparatorID: pair.comparator,
                comparator: difficultyMetrics(from: comparator)
            )
        }
    }

    private static func directionalPairs() -> [(peak: String, comparator: String)] {
        var pairs: [(peak: String, comparator: String)] = [
            ("campaign-05", "campaign-01"),
            ("campaign-05", "campaign-04"),
            ("campaign-10", "campaign-06"),
            ("campaign-10", "campaign-09"),
            ("campaign-15", "campaign-11"),
            ("campaign-15", "campaign-14"),
            ("campaign-20", "campaign-16"),
            ("campaign-20", "campaign-19"),
            ("campaign-25", "campaign-21"),
            ("campaign-25", "campaign-24"),
            ("campaign-30", "campaign-26"),
            ("campaign-30", "campaign-29"),
            ("circuit-curated-38", "circuit-curated-31"),
            ("circuit-curated-38", "circuit-curated-37"),
        ]
        for variant in 1 ... 16 {
            let suffix = String(format: "v%02d", variant)
            pairs.append(("circuit-r8-\(suffix)", "circuit-r1-\(suffix)"))
            pairs.append(("circuit-r8-\(suffix)", "circuit-r7-\(suffix)"))
        }
        return pairs
    }

    private static func difficultyMetrics(from row: CertificationRow) -> DifficultyMetrics {
        DifficultyMetrics(
            slack: row.slack,
            winningFirstActions: row.winningFirstActions,
            meaningfulDecisions: row.meaningfulDecisions,
            largestBloomCompletion: row.largestBloomCompletion,
            visibleGreedyCompletion: row.visibleGreedyCompletion,
            noisyPlannerCompletion: row.noisyPlannerCompletion
        )
    }

    private static func directionalComparison(
        peakID: String,
        peak: DifficultyMetrics,
        comparatorID: String,
        comparator: DifficultyMetrics
    ) -> DirectionalComparison {
        let slackPass = peak.slack <= comparator.slack
        let decisionsPass = peak.meaningfulDecisions >= comparator.meaningfulDecisions
        let strictlyHarder = peak.winningFirstActions < comparator.winningFirstActions
            || peak.visibleGreedyCompletion <= comparator.visibleGreedyCompletion - 10
            || peak.noisyPlannerCompletion <= comparator.noisyPlannerCompletion - 10
        let noRegression = peak.visibleGreedyCompletion <= comparator.visibleGreedyCompletion + 5
            && peak.noisyPlannerCompletion <= comparator.noisyPlannerCompletion + 5
        let passed = slackPass && decisionsPass && strictlyHarder && noRegression
        let evidence = [
            "slack \(peak.slack)≤\(comparator.slack): \(slackPass ? "yes" : "no")",
            "decisions \(peak.meaningfulDecisions)≥\(comparator.meaningfulDecisions): \(decisionsPass ? "yes" : "no")",
            "first \(peak.winningFirstActions)/\(comparator.winningFirstActions)",
            "greedy \(peak.visibleGreedyCompletion)%/\(comparator.visibleGreedyCompletion)%",
            "noisy \(peak.noisyPlannerCompletion)%/\(comparator.noisyPlannerCompletion)%",
            "largest \(peak.largestBloomCompletion)%/\(comparator.largestBloomCompletion)%",
            "strictly harder: \(strictlyHarder ? "yes" : "no")",
            "strategy regression≤5: \(noRegression ? "yes" : "no")",
        ].joined(separator: "; ")
        return DirectionalComparison(
            peak: peakID,
            comparator: comparatorID,
            passed: passed,
            evidence: evidence
        )
    }

    private static func referenceDecisionMetrics(
        route: [GameMove],
        initial: FlowerShowState,
        scenario: FlowerShowScenario
    ) -> (meaningful: Int, maximumForcedRun: Int) {
        var state = initial
        var meaningful = 0
        var forcedRun = 0
        var maximumForcedRun = 0

        for referenceMove in route where state.phase == .playing {
            let winning = FlowerShowExactSolver.winningFirstActions(
                from: state,
                scenario: scenario
            )
            if winning.count == 1 {
                forcedRun += 1
                maximumForcedRun = max(maximumForcedRun, forcedRun)
            } else {
                forcedRun = 0
            }

            let candidates = allMoves.map { move -> (GameMove, VisibleMoveValue, Int) in
                let transition = FlowerShowReducer.apply(move, to: state, rules: scenario)
                return (
                    move,
                    visibleValue(transition),
                    attainableRatingBand(
                        after: transition.stateAfter,
                        scenario: scenario
                    )
                )
            }
            let plausible = candidates.filter { $0.1.blooms > 0 || $0.1.objectiveAdvance > 0 }
            var found = false
            for firstIndex in plausible.indices {
                for secondIndex in plausible.indices where secondIndex > firstIndex {
                    let first = plausible[firstIndex]
                    let second = plausible[secondIndex]
                    if first.1.dominates(second.1) || second.1.dominates(first.1) { continue }
                    if first.2 != second.2 {
                        found = true
                        break
                    }
                }
                if found { break }
            }
            if found { meaningful += 1 }
            state = FlowerShowReducer.apply(referenceMove, to: state, rules: scenario).stateAfter
        }
        return (meaningful, maximumForcedRun)
    }

    private static func attainableRatingBand(
        after state: FlowerShowState,
        scenario: FlowerShowScenario
    ) -> Int {
        if state.phase == .won {
            return state.turnNumber <= scenario.radiantPar ? 2 : 1
        }
        guard state.phase == .playing,
              let route = FlowerShowExactSolver.shortestRoute(from: state, scenario: scenario)
        else {
            return 0
        }
        return state.turnNumber + route.moves.count <= scenario.radiantPar ? 2 : 1
    }

    private static func strategyDiagnostics(
        initial: FlowerShowState,
        scenario: FlowerShowScenario,
        count: Int
    ) -> (largestBloom: Int, visibleGreedy: Int, noisyPlanner: Int) {
        func completion(_ strategy: DiagnosticStrategy) -> Int {
            var wins = 0
            for rollout in 0 ..< count {
                var choiceRandom = FlowerShowRefillState(
                    seed: scenario.repairSalt
                        ^ strategy.rawValue
                        ^ (UInt64(rollout) &* 0xD6E8_FEB8_6659_FD93)
                )
                var state = initial
                while state.phase == .playing {
                    let moves = diagnosticChoices(
                        from: state,
                        scenario: scenario,
                        strategy: strategy,
                        random: &choiceRandom
                    )
                    guard let move = moves.first else { break }
                    state = FlowerShowReducer.apply(move, to: state, rules: scenario).stateAfter
                }
                if state.phase == .won { wins += 1 }
            }
            return Int((Double(wins) / Double(count) * 100).rounded())
        }
        return (
            completion(.largestBloom),
            completion(.visibleGreedy),
            completion(.noisyPlanner)
        )
    }

    private static func strategyBandFailures(
        label: String,
        scenario: FlowerShowScenario,
        rollouts: (largestBloom: Int, visibleGreedy: Int, noisyPlanner: Int)
    ) -> [String] {
        let prefix = "\(label) / \(scenario.scenarioID)"
        func rangeFailure(_ name: String, _ value: Int, _ range: ClosedRange<Int>) -> String? {
            guard range.contains(value) == false else { return nil }
            return "\(prefix): \(name) \(value)% is outside \(range.lowerBound)–\(range.upperBound)%"
        }

        if scenario.scenarioID.hasPrefix("campaign-"),
           let classNumber = Int(scenario.scenarioID.suffix(2))
        {
            var failures: [String] = []
            if (21 ... 25).contains(classNumber) {
                if let failure = rangeFailure(
                    "visible-objective greedy",
                    rollouts.visibleGreedy,
                    45 ... 70
                ) {
                    failures.append(failure)
                }
                if let failure = rangeFailure(
                    "noisy visible planner",
                    rollouts.noisyPlanner,
                    60 ... 85
                ) {
                    failures.append(failure)
                }
            } else if (26 ... 30).contains(classNumber) {
                if classNumber >= 27, rollouts.largestBloom > 40 {
                    failures.append(
                        "\(prefix): largest-bloom \(rollouts.largestBloom)% exceeds 40%"
                    )
                }
                if let failure = rangeFailure(
                    "visible-objective greedy",
                    rollouts.visibleGreedy,
                    25 ... 55
                ) {
                    failures.append(failure)
                }
                if let failure = rangeFailure(
                    "noisy visible planner",
                    rollouts.noisyPlanner,
                    45 ... 75
                ) {
                    failures.append(failure)
                }
            }
            return failures
        }

        // Class 33 deliberately introduces Judges' Order with a one-off teaching
        // release. Every other curated and endless Circuit fixture uses the
        // ordinary/final bands.
        if scenario.scenarioID == "circuit-curated-33" {
            return []
        }
        let isLapFinal = scenario.scenarioID == "circuit-curated-38"
            || scenario.scenarioID.hasPrefix("circuit-r8-")
        let greedyBand = isLapFinal ? 20 ... 45 : 30 ... 60
        let noisyBand = isLapFinal ? 35 ... 65 : 45 ... 75
        return [
            rangeFailure("visible-objective greedy", rollouts.visibleGreedy, greedyBand),
            rangeFailure("noisy visible planner", rollouts.noisyPlanner, noisyBand),
        ].compactMap { $0 }
    }

    private static func diagnosticChoices(
        from state: FlowerShowState,
        scenario: FlowerShowScenario,
        strategy: DiagnosticStrategy,
        random: inout FlowerShowRefillState
    ) -> [GameMove] {
        let candidates = allMoves.map { move in
            let transition = FlowerShowReducer.apply(move, to: state, rules: scenario)
            return (move: move, value: visibleValue(transition))
        }
        let eligible: [(move: GameMove, value: VisibleMoveValue)]
        switch strategy {
        case .largestBloom:
            let maximum = candidates.map(\.value.blooms).max() ?? 0
            eligible = candidates.filter { $0.value.blooms == maximum }
        case .visibleGreedy:
            let maximum = candidates.map(\.value.greedyScore).max() ?? 0
            eligible = candidates.filter { $0.value.greedyScore == maximum }
        case .noisyPlanner:
            let best = candidates.map(\.value.greedyScore).max() ?? 0
            let nonDominated = candidates.filter { candidate in
                candidates.contains { $0.value.dominates(candidate.value) } == false
            }
            let chooseBest = random.nextInt(upperBound: 10) < 8
            eligible = chooseBest
                ? candidates.filter { $0.value.greedyScore == best }
                : nonDominated
        }
        guard eligible.isEmpty == false else { return [] }
        return [eligible[random.nextInt(upperBound: eligible.count)].move]
    }

    private static func visibleValue(_ transition: FlowerShowTransition) -> VisibleMoveValue {
        VisibleMoveValue(
            blooms: transition.bloomCount,
            bindweedClears: transition.clearedBindweedSpokes.count,
            harmonyCredits:
                transition.harmonyAfter.inner - transition.harmonyBefore.inner
                + transition.harmonyAfter.middle - transition.harmonyBefore.middle
                + transition.harmonyAfter.outer - transition.harmonyBefore.outer,
            bouquetKinds: Int(
                (transition.bouquetAfter.rawValue ^ transition.bouquetBefore.rawValue).nonzeroBitCount
            ),
            unbrokenAdvance: transition.bloomCount > 0 ? 1 : 0,
            twinAdvance: transition.twinTurnsAfter - transition.twinTurnsBefore,
            judgesAdvance: transition.matchedOrderRing == nil ? 0 : 1
        )
    }
}

private extension Data {
    func append(to url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: self)
    }
}
