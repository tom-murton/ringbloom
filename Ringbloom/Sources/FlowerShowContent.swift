import CryptoKit
import Foundation

struct FlowerShowCatalogue: Codable, Equatable, Sendable {
    let contentVersion: Int
    let mappingVersion: Int
    let campaignScenarios: [FlowerShowScenario]
    let curatedCircuitScenarios: [FlowerShowScenario]
    let endlessCircuitScenarios: [FlowerShowScenario]

    func validate() throws {
        guard contentVersion == 3 else {
            throw FlowerShowValidationError.invalid("Unexpected Flower Show content version.")
        }
        guard mappingVersion == 1 else {
            throw FlowerShowValidationError.invalid("Unexpected Circuit mapping version.")
        }
        guard campaignScenarios.count == 30,
              curatedCircuitScenarios.count == 8,
              endlessCircuitScenarios.count == 128
        else {
            throw FlowerShowValidationError.invalid("Catalogue must contain 30 campaign, 8 curated Circuit and 128 endless scenarios.")
        }
        let scenarios = campaignScenarios + curatedCircuitScenarios + endlessCircuitScenarios
        guard Set(scenarios.map(\.scenarioID)).count == scenarios.count else {
            throw FlowerShowValidationError.invalid("Scenario IDs must be unique.")
        }
        for scenario in scenarios {
            try scenario.validate()
            guard FlowerShowContent.digest(for: scenario) == scenario.scenarioDigest else {
                throw FlowerShowValidationError.invalid("\(scenario.scenarioID) digest mismatch.")
            }
        }
    }
}

enum FlowerShowContent {
    static let contentVersion = 3
    static let mappingVersion = 1
    static let campaignClassCount = 30
    static let circuitStartClass = 31

    static let catalogue: FlowerShowCatalogue = {
        do {
            let url = try catalogueURL()
            let data = try Data(contentsOf: url)
            let catalogue = try JSONDecoder().decode(FlowerShowCatalogue.self, from: data)
            try catalogue.validate()
            return catalogue
        } catch {
            preconditionFailure("Invalid Flower Show V3 catalogue: \(error)")
        }
    }()

    static func resolve(classNumber: Int) -> ResolvedFlowerShowClass {
        let number = max(1, classNumber)
        if number <= campaignClassCount {
            return ResolvedFlowerShowClass(
                displayedClassNumber: number,
                scenario: catalogue.campaignScenarios[number - 1]
            )
        }
        if number <= 38 {
            return ResolvedFlowerShowClass(
                displayedClassNumber: number,
                scenario: catalogue.curatedCircuitScenarios[number - circuitStartClass]
            )
        }
        let offset = number - 39
        let role = offset % 8
        let variant = (offset / 8) % 16
        return ResolvedFlowerShowClass(
            displayedClassNumber: number,
            scenario: catalogue.endlessCircuitScenarios[role * 16 + variant]
        )
    }

    static func digest(for scenario: FlowerShowScenario) -> String {
        struct Payload: Encodable {
            let activeKindCount: Int
            let initialBoard: GameBoard
            let moveBudget: Int
            let objectives: FlowerShowObjectives
            let radiantPar: Int
            let refillSource: FlowerShowRefillSource
            let repairSalt: UInt64
            let scenarioID: String
            let startingSelectedRing: Ring
            let targetBlooms: Int
        }
        let payload = Payload(
            activeKindCount: scenario.activeKindCount,
            initialBoard: scenario.initialBoard,
            moveBudget: scenario.moveBudget,
            objectives: scenario.objectives,
            radiantPar: scenario.radiantPar,
            refillSource: scenario.refillSource,
            repairSalt: scenario.repairSalt,
            scenarioID: scenario.scenarioID,
            startingSelectedRing: scenario.startingSelectedRing,
            targetBlooms: scenario.targetBlooms
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(payload) else { return "" }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func catalogueURL() throws -> URL {
        let bundles = [Bundle.main, Bundle(for: BundleToken.self)]
        if let url = bundles.lazy.compactMap({
            $0.url(forResource: "FlowerShowV3Catalog", withExtension: "json")
        }).first {
            return url
        }
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/FlowerShowV3Catalog.json")
        if FileManager.default.fileExists(atPath: sourceURL.path) {
            return sourceURL
        }
        throw FlowerShowValidationError.invalid("FlowerShowV3Catalog.json is missing.")
    }

    private final class BundleToken {}
}
