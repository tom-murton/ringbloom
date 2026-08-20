import Foundation

enum GameMode: String, Codable, Equatable, Sendable {
    case garden
    case flowerShow
}

enum FlowerShowRule: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case ringHarmony
    case unbroken
    case bindweed
    case twinBloom
    case prizeBouquet
    case doubleHarmony
    case judgesOrder

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ringHarmony: "Ring Harmony"
        case .unbroken: "Unbroken"
        case .bindweed: "Bindweed"
        case .twinBloom: "Twin Bloom"
        case .prizeBouquet: "Prize Bouquet"
        case .doubleHarmony: "Double Harmony"
        case .judgesOrder: "Judges' Order"
        }
    }

    var symbol: String {
        switch self {
        case .ringHarmony, .doubleHarmony: "circle.hexagongrid.fill"
        case .unbroken: "link"
        case .bindweed: "leaf.arrow.triangle.circlepath"
        case .twinBloom: "sparkles.rectangle.stack"
        case .prizeBouquet: "camera.macro"
        case .judgesOrder: "list.number"
        }
    }

    var instruction: String {
        switch self {
        case .ringHarmony:
            "Score after turning each ring. Only turns that bloom count; repeats are allowed."
        case .unbroken:
            "Score on consecutive turns. A turn without a bloom resets the current run; once achieved, it stays complete."
        case .bindweed:
            "Clear every tangled spoke to win. After three turns without a clear, Bindweed spreads to the previewed neighbouring spoke. Clearing any tangled spoke resets the count to three."
        case .twinBloom:
            "Create at least two blooms in one turn."
        case .prizeBouquet:
            "Bloom Coral ●, Saffron ◆, Mint ▲ and Sky ✦. They do not need to bloom together."
        case .doubleHarmony:
            "Score twice after turning each ring. Only turns that bloom count; repeats are allowed."
        case .judgesOrder:
            "Score with the rings in the shown order. An off-order score still counts towards blooms and does not reset the order."
        }
    }
}

extension FlowerShowObjectives {
    var activeRules: [FlowerShowRule] {
        var rules: [FlowerShowRule] = []
        if harmonyCreditsPerRing == 1 { rules.append(.ringHarmony) }
        if harmonyCreditsPerRing == 2 { rules.append(.doubleHarmony) }
        if unbrokenChain != nil { rules.append(.unbroken) }
        if bindweed != nil { rules.append(.bindweed) }
        if twinBloomTurns > 0 { rules.append(.twinBloom) }
        if bouquetKinds.isEmpty == false { rules.append(.prizeBouquet) }
        if judgesOrder.isEmpty == false { rules.append(.judgesOrder) }
        return rules
    }
}

struct FlowerShowClassChange: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
}

struct FlowerShowClassDefinition: Codable, Equatable, Identifiable, Sendable {
    static let campaignVersion = 3
    static let classCount = 30
    static let rosetteInterval = 5
    static let bindweedSpreadInterval = 3
    static var championCircuitStartClass: Int { 31 }

    let number: Int
    let seed: UInt64
    let targetBlooms: Int
    let moveBudget: Int
    let activeKindCount: Int
    let objectives: FlowerShowObjectives
    let radiantPar: Int
    let scenarioID: String
    let scenarioDigest: String

    var id: Int { number }
    var isChampionCircuit: Bool { number > Self.classCount }
    var isRosetteClass: Bool { number <= Self.classCount && number.isMultiple(of: 5) }
    var rosetteNumber: Int? { isRosetteClass ? number / 5 : nil }
    var title: String { isChampionCircuit ? "Champion Circuit · Class \(number)" : "Class \(number)" }
    var activeRules: [FlowerShowRule] { objectives.activeRules }
    var ruleTitle: String { activeRules.map(\.title).joined(separator: " & ") }

    var stageTitle: String {
        switch number {
        case 1 ... 5: "Harmony Heats"
        case 6 ... 10: "Unbroken Heats"
        case 11 ... 15: "Bindweed Trials"
        case 16 ... 20: "Twin Bloom Heats"
        case 21 ... 25: "Bouquet Selection"
        case 26 ... 30: "Championship"
        default: "Champion Circuit"
        }
    }

    var introductionID: FlowerShowIntroductionID? {
        FlowerShowIntroductionID.allCases.first { $0.introductionClass == number }
    }

    var introducedRule: FlowerShowRule? {
        switch introductionID {
        case .harmony: .ringHarmony
        case .unbroken: .unbroken
        case .bindweed: .bindweed
        case .twinBloom: .twinBloom
        case .prizeBouquet: .prizeBouquet
        case .doubleHarmony: .doubleHarmony
        case .judgesOrder: .judgesOrder
        case nil: nil
        }
    }

    var changesFromPrevious: [FlowerShowClassChange] {
        if let introducedRule {
            return [.init(
                id: "new-rule-\(introducedRule.rawValue)",
                title: introductionID == .doubleHarmony ? "RULE UPGRADE · DOUBLE HARMONY" : "NEW RULE · \(introducedRule.title.uppercased())",
                detail: introducedRule.instruction,
                symbol: introducedRule.symbol
            )]
        }
        if number == 30 {
            return [.init(
                id: "grand-final",
                title: "GRAND CHAMPION FINAL",
                detail: "Eleven blooms, three tangled spokes, Double Harmony and the full Prize Bouquet.",
                symbol: "trophy.fill"
            )]
        }
        if number == 26 {
            return [.init(
                id: "twin-upgrade",
                title: "TWO TWIN BLOOMS",
                detail: "Create at least two blooms in one turn, twice.",
                symbol: "sparkles.rectangle.stack"
            )]
        }
        guard number > 1, isChampionCircuit == false else { return [] }
        let previous = Self.classNumber(number - 1)
        if objectives.activeIDs != previous.objectives.activeIDs {
            return [.init(
                id: "rules",
                title: "RULES COMBINE",
                detail: ruleTitle,
                symbol: "square.stack.3d.up.fill"
            )]
        }
        if moveBudget < previous.moveBudget {
            return [.init(id: "moves", title: "FEWER MOVES", detail: "\(moveBudget) moves instead of \(previous.moveBudget).", symbol: "hourglass.bottomhalf.filled")]
        }
        if activeKindCount > previous.activeKindCount {
            return [.init(id: "petals", title: "FOUR PETAL KINDS", detail: "Sky joins Coral, Saffron and Mint.", symbol: "paintpalette.fill")]
        }
        if targetBlooms != previous.targetBlooms {
            return [.init(id: "target", title: "ONE MORE BLOOM", detail: "The judges now want \(targetBlooms). The objective is unchanged.", symbol: "leaf.fill")]
        }
        return [.init(id: "recovery", title: "ROOM TO RECOVER", detail: "\(moveBudget) moves for a different authored decision.", symbol: "arrow.trianglehead.2.clockwise")]
    }

    static let all: [FlowerShowClassDefinition] = (1 ... classCount).map(classNumber)

    static func classNumber(_ number: Int) -> Self {
        let resolved = FlowerShowContent.resolve(classNumber: number)
        let scenario = resolved.scenario
        return Self(
            number: resolved.displayedClassNumber,
            seed: scenario.refillSource.seed,
            targetBlooms: scenario.targetBlooms,
            moveBudget: scenario.moveBudget,
            activeKindCount: scenario.activeKindCount,
            objectives: scenario.objectives,
            radiantPar: scenario.radiantPar,
            scenarioID: scenario.scenarioID,
            scenarioDigest: scenario.scenarioDigest
        )
    }

    private enum CodingKeys: String, CodingKey {
        case number, seed, targetBlooms, moveBudget, activeKindCount, objectives
        case radiantPar, scenarioID, scenarioDigest
    }

    init(
        number: Int,
        seed: UInt64,
        targetBlooms: Int,
        moveBudget: Int,
        activeKindCount: Int,
        objectives: FlowerShowObjectives,
        radiantPar: Int? = nil,
        scenarioID: String? = nil,
        scenarioDigest: String? = nil
    ) {
        self.number = number
        self.seed = seed
        self.targetBlooms = targetBlooms
        self.moveBudget = moveBudget
        self.activeKindCount = activeKindCount
        self.objectives = objectives
        self.radiantPar = radiantPar ?? moveBudget
        self.scenarioID = scenarioID ?? "legacy-\(number)"
        self.scenarioDigest = scenarioDigest ?? ""
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let number = try container.decode(Int.self, forKey: .number)
        self.init(
            number: number,
            seed: try container.decode(UInt64.self, forKey: .seed),
            targetBlooms: try container.decode(Int.self, forKey: .targetBlooms),
            moveBudget: try container.decode(Int.self, forKey: .moveBudget),
            activeKindCount: try container.decode(Int.self, forKey: .activeKindCount),
            objectives: try container.decode(FlowerShowObjectives.self, forKey: .objectives),
            radiantPar: try container.decodeIfPresent(Int.self, forKey: .radiantPar),
            scenarioID: try container.decodeIfPresent(String.self, forKey: .scenarioID),
            scenarioDigest: try container.decodeIfPresent(String.self, forKey: .scenarioDigest)
        )
    }
}

struct FlowerShowAttentionMessage: Equatable, Sendable {
    let title: String
    let detail: String
    let symbol: String

    static func current(
        definition: FlowerShowClassDefinition,
        blooms: Int,
        infectedSpokes: Set<Int>,
        bindweedSpreadCountdown: Int?,
        turnNumber: Int
    ) -> Self? {
        guard blooms >= definition.targetBlooms else {
            if turnNumber > 0,
               infectedSpokes.isEmpty == false,
               bindweedSpreadCountdown == FlowerShowClassDefinition.bindweedSpreadInterval
            {
                let noun = infectedSpokes.count == 1 ? "stem" : "stems"
                return Self(
                    title: "BINDWEED SPREAD",
                    detail: "\(infectedSpokes.count) tangled \(noun) now need clearing.",
                    symbol: "exclamationmark.triangle.fill"
                )
            }
            return nil
        }
        guard infectedSpokes.isEmpty == false else { return nil }
        return Self(
            title: "BLOOM TARGET MET",
            detail: "Still needed: clear all Bindweed.",
            symbol: "checkmark.seal.fill"
        )
    }
}
