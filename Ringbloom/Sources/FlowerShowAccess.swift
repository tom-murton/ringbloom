import Foundation

enum FlowerShowEntitlementSource: Equatable, Hashable, Sendable {
    case legacyPaidApp
    case storePurchase
}

enum FlowerShowAccessState: Equatable, Sendable {
    case checking
    case sample
    case full(FlowerShowEntitlementSource)
}

@MainActor
protocol FlowerShowAccessProviding: AnyObject {
    var accessState: FlowerShowAccessState { get }
    var hasFullFlowerShowAccess: Bool { get }
}

@MainActor
final class SampleOnlyFlowerShowAccessProvider: FlowerShowAccessProviding {
    let accessState: FlowerShowAccessState = .sample

    var hasFullFlowerShowAccess: Bool { false }
}

enum FlowerShowAccessAction: Equatable, Sendable {
    case qualificationRequired
    case progressionLocked
    case play
    case waitForAccess
    case purchaseRequired
}

enum FlowerShowStartResult: Equatable, Sendable {
    case started
    case qualificationRequired
    case progressionLocked
    case accessChecking
    case purchaseRequired

    init(action: FlowerShowAccessAction) {
        switch action {
        case .qualificationRequired: self = .qualificationRequired
        case .progressionLocked: self = .progressionLocked
        case .play: self = .started
        case .waitForAccess: self = .accessChecking
        case .purchaseRequired: self = .purchaseRequired
        }
    }
}

enum FlowerShowTransactionEnvironment: Equatable, Sendable {
    case production
    case sandbox
    case xcode
}

struct FlowerShowAppTransactionSnapshot: Equatable, Sendable {
    let environment: FlowerShowTransactionEnvironment
    let originalPurchaseDate: Date
    let isVerified: Bool
}

enum FlowerShowAppTransactionCheck: Equatable, Sendable {
    case verified(FlowerShowAppTransactionSnapshot)
    case unverified
    case unavailable
}

struct FlowerShowPurchaseTransaction: Equatable, Sendable {
    let id: UInt64
    let productID: String
    let isVerified: Bool
    let isRevoked: Bool
}

struct FlowerShowEntitlementSnapshot: Equatable, Sendable {
    let appTransaction: FlowerShowAppTransactionCheck
    let purchaseTransaction: FlowerShowPurchaseTransaction?
}

struct FlowerShowProductInfo: Equatable, Sendable {
    let productID: String
    let displayPrice: String
}

enum FlowerShowPurchaseOutcome: Equatable, Sendable {
    case success(FlowerShowPurchaseTransaction)
    case userCancelled
    case pending
}

enum FlowerShowStoreClientError: Error, Equatable, Sendable {
    case productUnavailable
    case purchasesDisabled
    case failed
}

enum FlowerShowProductState: Equatable, Sendable {
    case loading
    case available(FlowerShowProductInfo)
    case unavailable
}

enum FlowerShowPurchaseState: Equatable, Sendable {
    case idle
    case purchasing
    case restoring
    case pending
    case success
    case failed
    case disabled
}

@MainActor
protocol FlowerShowStoreClient: AnyObject {
    var transactionUpdates: AsyncStream<FlowerShowPurchaseTransaction> { get }

    func loadProduct() async throws -> FlowerShowProductInfo?
    func loadEntitlementSnapshot() async throws -> FlowerShowEntitlementSnapshot
    func purchase() async throws -> FlowerShowPurchaseOutcome
    func sync() async throws
    func finish(transactionID: UInt64) async
}

enum FlowerShowLaunchAccessOverride: Equatable, Sendable {
    case sample
    case fullPurchase
    case legacy
    case checking
    case checkingThenFull
    case checkingThenSample
}

enum FlowerShowLaunchPurchaseOverride: Equatable, Sendable {
    case pending
    case failed
    case userCancelled
    case success
    case disabled
    case purchasing
}

enum FlowerShowLaunchRestoreOverride: Equatable, Sendable {
    case success
    case restoring
}

struct FlowerShowLaunchOverrides: Equatable, Sendable {
    let access: FlowerShowLaunchAccessOverride?
    let productUnavailable: Bool
    let purchase: FlowerShowLaunchPurchaseOverride?
    let restore: FlowerShowLaunchRestoreOverride?
    let displayPrice: String?

    init(
        access: FlowerShowLaunchAccessOverride?,
        productUnavailable: Bool,
        purchase: FlowerShowLaunchPurchaseOverride?,
        restore: FlowerShowLaunchRestoreOverride? = nil,
        displayPrice: String? = nil
    ) {
        self.access = access
        self.productUnavailable = productUnavailable
        self.purchase = purchase
        self.restore = restore
        self.displayPrice = displayPrice
    }

    static func resolve(arguments: [String], launchMode: GameLaunchMode) -> Self {
        guard launchMode.isDeterministic else {
            return Self(access: nil, productUnavailable: false, purchase: nil)
        }

        let normalized = arguments.map { $0.lowercased() }
        let access: FlowerShowLaunchAccessOverride? = if normalized.contains("--flower-show-access=full-purchase")
            || normalized.contains("--flower-show-unlocked")
        {
            .fullPurchase
        } else if normalized.contains("--flower-show-access=legacy") {
            .legacy
        } else if normalized.contains("--flower-show-access=checking-then-full") {
            .checkingThenFull
        } else if normalized.contains("--flower-show-access=checking-then-sample") {
            .checkingThenSample
        } else if normalized.contains("--flower-show-access=checking") {
            .checking
        } else {
            .sample
        }

        let purchase: FlowerShowLaunchPurchaseOverride? = if normalized.contains("--flower-show-purchase=pending") {
            .pending
        } else if normalized.contains("--flower-show-purchase=failed") {
            .failed
        } else if normalized.contains("--flower-show-purchase=user-cancelled") {
            .userCancelled
        } else if normalized.contains("--flower-show-purchase=success") {
            .success
        } else if normalized.contains("--flower-show-purchase=disabled") {
            .disabled
        } else if normalized.contains("--flower-show-purchase=purchasing") {
            .purchasing
        } else {
            nil
        }

        let restore: FlowerShowLaunchRestoreOverride? = if normalized.contains("--flower-show-restore=success") {
            .success
        } else if normalized.contains("--flower-show-restore=restoring") {
            .restoring
        } else {
            nil
        }

        let displayPrice = arguments.first {
            $0.lowercased().hasPrefix("--flower-show-display-price=")
        }.map { String($0.dropFirst("--flower-show-display-price=".count)) }

        return Self(
            access: access,
            productUnavailable: normalized.contains("--flower-show-product-unavailable"),
            purchase: purchase,
            restore: restore,
            displayPrice: displayPrice
        )
    }
}

struct FlowerShowAccessPolicy: Sendable {
    static let productID = "com.tommurton.ringbloom.flower_show"
    /// Version 1.2's public release at 2026-08-11T12:47:18Z, after the price became free.
    static let businessModelChangeDate = Date(timeIntervalSince1970: 1_786_452_438)
    static let qualifyingGardenWins = 1
    static let freeClasses = 1 ... 5

    static func isQualified(highestGarden: Int) -> Bool {
        highestGarden > qualifyingGardenWins
    }

    static func isFreeClass(_ classNumber: Int) -> Bool {
        freeClasses.contains(classNumber)
    }

    static func hasLegacyAccess(_ check: FlowerShowAppTransactionCheck) -> Bool {
        guard case let .verified(transaction) = check,
              transaction.isVerified,
              transaction.environment == .production
        else { return false }
        return transaction.originalPurchaseDate < businessModelChangeDate
    }

    static func hasPurchaseAccess(_ transaction: FlowerShowPurchaseTransaction?) -> Bool {
        guard let transaction else { return false }
        return transaction.isVerified
            && transaction.productID == productID
            && transaction.isRevoked == false
    }

    static func hasFullAccess(_ snapshot: FlowerShowEntitlementSnapshot) -> Bool {
        hasLegacyAccess(snapshot.appTransaction) || hasPurchaseAccess(snapshot.purchaseTransaction)
    }

    static func action(
        highestGarden: Int,
        accessState: FlowerShowAccessState,
        classNumber: Int,
        progressionAllowed: Bool
    ) -> FlowerShowAccessAction {
        guard isQualified(highestGarden: highestGarden) else { return .qualificationRequired }
        guard progressionAllowed else { return .progressionLocked }
        if isFreeClass(classNumber) { return .play }

        switch accessState {
        case .checking:
            return .waitForAccess
        case .sample:
            return .purchaseRequired
        case .full:
            return .play
        }
    }

    static func tileAction(
        highestGarden: Int,
        accessState: FlowerShowAccessState,
        classNumber: Int,
        progressionAllowed: Bool
    ) -> FlowerShowAccessAction {
        guard isQualified(highestGarden: highestGarden) else { return .qualificationRequired }
        if isFreeClass(classNumber) == false {
            switch accessState {
            case .checking:
                return .waitForAccess
            case .sample:
                return .purchaseRequired
            case .full:
                break
            }
        }
        return action(
            highestGarden: highestGarden,
            accessState: accessState,
            classNumber: classNumber,
            progressionAllowed: progressionAllowed
        )
    }
}
