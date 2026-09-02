import Combine
import Foundation
import Testing
@testable import Ringbloom

struct FlowerShowAccessPolicyTests {
    @Test(arguments: [1, 2])
    func qualificationChangesOnlyAfterTheFirstGardenWin(highestGarden: Int) {
        #expect(
            FlowerShowAccessPolicy.isQualified(highestGarden: highestGarden)
                == (highestGarden == 2)
        )
    }

    @Test(arguments: [1, 2, 3, 4, 5, 6, 30, 31])
    func qualifiedSampleAccessPermitsOnlyClassesOneThroughFive(classNumber: Int) {
        let action = FlowerShowAccessPolicy.action(
            highestGarden: 2,
            accessState: .sample,
            classNumber: classNumber,
            progressionAllowed: true
        )
        #expect(action == ((1 ... 5).contains(classNumber) ? .play : .purchaseRequired))
    }

    @Test func freeAndPremiumActionsRemainDistinct() {
        #expect(
            FlowerShowAccessPolicy.action(
                highestGarden: 2,
                accessState: .sample,
                classNumber: 5,
                progressionAllowed: true
            ) == .play
        )
        #expect(
            FlowerShowAccessPolicy.action(
                highestGarden: 2,
                accessState: .sample,
                classNumber: 6,
                progressionAllowed: true
            ) == .purchaseRequired
        )
        #expect(
            FlowerShowAccessPolicy.action(
                highestGarden: 2,
                accessState: .checking,
                classNumber: 6,
                progressionAllowed: true
            ) == .waitForAccess
        )
        #expect(
            FlowerShowAccessPolicy.action(
                highestGarden: 2,
                accessState: .full(.storePurchase),
                classNumber: 6,
                progressionAllowed: true
            ) == .play
        )
    }

    @Test func progressionLockIsCheckedBeforeFreeAccess() {
        #expect(
            FlowerShowAccessPolicy.action(
                highestGarden: 2,
                accessState: .full(.storePurchase),
                classNumber: 3,
                progressionAllowed: false
            ) == .progressionLocked
        )
        #expect(
            FlowerShowAccessPolicy.tileAction(
                highestGarden: 2,
                accessState: .sample,
                classNumber: 8,
                progressionAllowed: false
            ) == .purchaseRequired
        )
    }

    @Test(arguments: [
        Date(timeIntervalSince1970: 0),
        FlowerShowAccessPolicy.businessModelChangeDate.addingTimeInterval(-1),
    ])
    func legacyAccessAcceptsVerifiedProductionPurchasesBeforeTheFreeModel(
        originalPurchaseDate: Date
    ) {
        let check = FlowerShowAppTransactionCheck.verified(
            FlowerShowAppTransactionSnapshot(
                environment: .production,
                originalPurchaseDate: originalPurchaseDate,
                isVerified: true
            )
        )
        #expect(FlowerShowAccessPolicy.hasLegacyAccess(check))
    }

    @Test(arguments: [
        FlowerShowAccessPolicy.businessModelChangeDate,
        FlowerShowAccessPolicy.businessModelChangeDate.addingTimeInterval(1),
    ])
    func legacyAccessRejectsPurchasesFromTheFreeModelOnwards(originalPurchaseDate: Date) {
        let production = FlowerShowAccessTransactionSnapshotFactory.make(
            environment: .production,
            originalPurchaseDate: originalPurchaseDate,
            isVerified: true
        )
        #expect(FlowerShowAccessPolicy.hasLegacyAccess(production) == false)
    }

    @Test(arguments: [FlowerShowTransactionEnvironment.sandbox, .xcode])
    func nonProductionPurchaseDatesNeverGrantLegacy(
        environment: FlowerShowTransactionEnvironment
    ) {
        let check = FlowerShowAccessTransactionSnapshotFactory.make(
            environment: environment,
            originalPurchaseDate: .distantPast,
            isVerified: true
        )
        #expect(FlowerShowAccessPolicy.hasLegacyAccess(check) == false)
    }

    @Test func unverifiedAppTransactionsFailClosed() {
        let unverifiedSnapshot = FlowerShowAccessTransactionSnapshotFactory.make(
            environment: .production,
            originalPurchaseDate: .distantPast,
            isVerified: false
        )
        #expect(FlowerShowAccessPolicy.hasLegacyAccess(unverifiedSnapshot) == false)
        #expect(FlowerShowAccessPolicy.hasLegacyAccess(.unverified) == false)
    }

    @Test func purchaseAccessRequiresTheExactVerifiedNonRevokedProduct() {
        let valid = FlowerShowPurchaseTransaction(
            id: 1,
            productID: FlowerShowAccessPolicy.productID,
            isVerified: true,
            isRevoked: false
        )
        #expect(FlowerShowAccessPolicy.hasPurchaseAccess(valid))
        #expect(FlowerShowAccessPolicy.hasPurchaseAccess(nil) == false)
        #expect(
            FlowerShowAccessPolicy.hasPurchaseAccess(
                FlowerShowPurchaseTransaction(
                    id: 2,
                    productID: "com.tommurton.ringbloom.other",
                    isVerified: true,
                    isRevoked: false
                )
            ) == false
        )
        #expect(
            FlowerShowAccessPolicy.hasPurchaseAccess(
                FlowerShowPurchaseTransaction(
                    id: 3,
                    productID: FlowerShowAccessPolicy.productID,
                    isVerified: false,
                    isRevoked: false
                )
            ) == false
        )
        #expect(
            FlowerShowAccessPolicy.hasPurchaseAccess(
                FlowerShowPurchaseTransaction(
                    id: 4,
                    productID: FlowerShowAccessPolicy.productID,
                    isVerified: true,
                    isRevoked: true
                )
            ) == false
        )
    }

    @Test func productionLaunchDoesNotAcceptDeterministicAccessOverrides() {
        let overrides = FlowerShowLaunchOverrides.resolve(
            arguments: ["--flower-show-access=full-purchase"],
            launchMode: .production
        )
        #expect(overrides == .production)
    }

    @Test func deterministicDisplayPriceIsInjectedOnlyByTheHarness() {
        let overrides = FlowerShowLaunchOverrides.resolve(
            arguments: [
                "--flower-show-access=sample",
                "--flower-show-display-price=£2.99",
            ],
            launchMode: .screenshot(seed: 1)
        )
        #expect(overrides.displayPrice == "£2.99")
        #expect(
            FlowerShowLaunchOverrides.resolve(
                arguments: ["--flower-show-access=sample"],
                launchMode: .production
            ).displayPrice == nil
        )
    }

    @Test func deterministicStorefrontOverridesPreserveDisplayPriceCase() {
        let overrides = FlowerShowLaunchOverrides.resolve(
            arguments: [
                "--flower-show-access=sample",
                "--flower-show-purchase=user-cancelled",
                "--flower-show-restore=restoring",
                "--flower-show-display-price=From £2.99",
            ],
            launchMode: .uiTest(seed: 61)
        )

        #expect(overrides.access == .sample)
        #expect(overrides.purchase == .userCancelled)
        #expect(overrides.restore == .restoring)
        #expect(overrides.displayPrice == "From £2.99")
    }
}

private enum FlowerShowAccessTransactionSnapshotFactory {
    static func make(
        environment: FlowerShowTransactionEnvironment,
        originalPurchaseDate: Date,
        isVerified: Bool
    ) -> FlowerShowAppTransactionCheck {
        .verified(
            FlowerShowAppTransactionSnapshot(
                environment: environment,
                originalPurchaseDate: originalPurchaseDate,
                isVerified: isVerified
            )
        )
    }
}

@MainActor
private final class TestFullFlowerShowAccessProvider: FlowerShowAccessProviding {
    let accessState: FlowerShowAccessState = .full(.storePurchase)

    var hasFullFlowerShowAccess: Bool { true }
}

@MainActor
private final class RecordingPurchaseAttributionTracker: PurchaseAttributionTracking {
    private(set) var transactionIDs: [UInt64] = []

    func trackUnlockPurchase(transactionID: UInt64) {
        transactionIDs.append(transactionID)
    }
}

@MainActor
private final class MutableFlowerShowAccessProvider: FlowerShowAccessProviding {
    var accessState: FlowerShowAccessState

    init(_ accessState: FlowerShowAccessState) {
        self.accessState = accessState
    }

    var hasFullFlowerShowAccess: Bool {
        if case .full = accessState { return true }
        return false
    }
}

@MainActor
struct GameModelFlowerShowAccessTests {
    @Test func directModelEntryEnforcesQualificationAndPremiumBoundary() {
        let unqualified = GameModel(
            launchMode: .uiTest(seed: 1),
            progressStore: InMemoryGameProgressStore(progress: GameProgress(bestScore: 0, highestGarden: 1))
        )
        #expect(unqualified.startFlowerShowClass(1) == .qualificationRequired)

        let sample = GameModel(
            launchMode: .uiTest(seed: 2),
            progressStore: InMemoryGameProgressStore(
                progress: GameProgress(
                    bestScore: 0,
                    highestGarden: 2,
                    flowerShowProgress: FlowerShowProgressV3(
                        bestCampaignRatings: Dictionary(uniqueKeysWithValues: (1 ... 5).map { ($0, .seedling) })
                    )
                )
            )
        )
        #expect(sample.startFlowerShowClass(1) == .started)
        #expect(sample.startFlowerShowClass(6) == .purchaseRequired)

        let full = GameModel(
            launchMode: .uiTest(seed: 3),
            progressStore: InMemoryGameProgressStore(
                progress: GameProgress(
                    bestScore: 0,
                    highestGarden: 2,
                    flowerShowProgress: FlowerShowProgressV3(
                        bestCampaignRatings: Dictionary(uniqueKeysWithValues: (1 ... 5).map { ($0, .seedling) })
                    )
                )
            ),
            flowerShowAccess: TestFullFlowerShowAccessProvider()
        )
        #expect(full.startFlowerShowClass(1) == .started)
        #expect(full.startFlowerShowClass(6) == .started)
    }

    @Test(arguments: [FlowerShowEntitlementSource.legacyPaidApp, .storePurchase])
    func fullLegacyAndPurchaseAccessPermitPremiumButEnforceCampaignSequence(
        source: FlowerShowEntitlementSource
    ) {
        let model = GameModel(
            launchMode: .uiTest(seed: 63),
            progressStore: InMemoryGameProgressStore(
                progress: qualifiedProgress(completedThrough: 5)
            ),
            flowerShowAccess: MutableFlowerShowAccessProvider(.full(source))
        )

        #expect(model.startFlowerShowClass(6) == .started)
        #expect(model.startFlowerShowClass(7) == .progressionLocked)
    }

    @Test func sampleAccessAllowsFreeReplayAndRejectsEveryPremiumDirectOrReplayRoute() {
        let model = GameModel(
            launchMode: .uiTest(seed: 64),
            progressStore: InMemoryGameProgressStore(
                progress: qualifiedProgress(completedThrough: 30)
            ),
            flowerShowAccess: MutableFlowerShowAccessProvider(.sample)
        )

        #expect(model.startFlowerShowReplay(1) == .started)
        #expect(model.startFlowerShowReplay(6) == .purchaseRequired)
        #expect(model.startFlowerShowClass(30) == .purchaseRequired)
        #expect(model.startFlowerShowClass(31) == .purchaseRequired)
        #expect(model.flowerShowAccessAction(for: 6) == .purchaseRequired)
        #expect(model.flowerShowAccessAction(for: 30) == .purchaseRequired)
        #expect(model.flowerShowAccessAction(for: 31) == .purchaseRequired)
    }

    @Test func savedPremiumResumeAndRetryRequireFullAccess() {
        let attempt = PersistedFlowerShowAttempt(
            contentVersion: FlowerShowContent.contentVersion,
            context: FlowerShowAttemptContext(kind: .campaign, classNumber: 6),
            engine: FlowerShowEngine(scenario: FlowerShowContent.resolve(classNumber: 6).scenario)
        )
        let progress = GameProgress(
            bestScore: 0,
            highestGarden: 2,
            flowerShowProgress: FlowerShowProgressV3(
                bestCampaignRatings: Dictionary(
                    uniqueKeysWithValues: (1 ... 5).map { ($0, .seedling) }
                ),
                activeAttempt: attempt
            )
        )
        let sample = MutableFlowerShowAccessProvider(.sample)
        let model = GameModel(
            launchMode: .production,
            progressStore: InMemoryGameProgressStore(progress: progress),
            flowerShowAccess: sample
        )

        #expect(model.savedFlowerShowAttemptContext == attempt.context)
        #expect(model.resumeFlowerShow() == .purchaseRequired)

        let mutableFullAccess = MutableFlowerShowAccessProvider(.full(.legacyPaidApp))
        let resumedModel = GameModel(
            launchMode: .production,
            progressStore: InMemoryGameProgressStore(progress: progress),
            flowerShowAccess: mutableFullAccess
        )
        #expect(resumedModel.resumeFlowerShow() == .started)
        mutableFullAccess.accessState = .sample
        #expect(resumedModel.retry() == .purchaseRequired)
        mutableFullAccess.accessState = .full(.storePurchase)
        #expect(resumedModel.retry() == .started)
    }

    @Test func classFiveNextAndPrivatePremiumRetryCannotBypassSampleGate() throws {
        let sample = MutableFlowerShowAccessProvider(.sample)
        let model = GameModel(
            launchMode: .uiTest(seed: 65),
            progressStore: InMemoryGameProgressStore(
                progress: qualifiedProgress(completedThrough: 4)
            ),
            flowerShowAccess: sample
        )
        #expect(model.startFlowerShowClass(5) == .started)
        let scenario = FlowerShowContent.resolve(classNumber: 5).scenario
        let route = try #require(
            FlowerShowExactSolver.shortestRoute(from: modelState(model), scenario: scenario)
        )
        for move in route.moves {
            model.select(move.ring)
            _ = try #require(model.rotate(move.direction))
        }
        #expect(model.nextFlowerShowClass() == .purchaseRequired)

        #expect(model.preparePremiumFlowerShowRetryFixture(classNumber: 6))
        #expect(model.retry() == .purchaseRequired)
    }

    @Test func activePremiumAttemptStopsMutatingAfterAccessIsLost() {
        let access = MutableFlowerShowAccessProvider(.full(.storePurchase))
        let model = GameModel(
            launchMode: .uiTest(seed: 4),
            progressStore: InMemoryGameProgressStore(
                progress: GameProgress(
                    bestScore: 0,
                    highestGarden: 2,
                    flowerShowProgress: FlowerShowProgressV3(
                        bestCampaignRatings: Dictionary(uniqueKeysWithValues: (1 ... 5).map { ($0, .seedling) })
                    )
                )
            ),
            flowerShowAccess: access
        )

        #expect(model.startFlowerShowClass(6) == .started)
        let boardBeforeLoss = model.board
        access.accessState = .sample

        #expect(model.rotate(.clockwise) == nil)
        #expect(model.board == boardBeforeLoss)
        #expect(model.undoFlowerShowTurn() == false)
    }

    @Test(
        "A Class 5 result remains intact while premium access is checked",
        .bug("https://linear.app/weevolve/issue/TOM-57")
    )
    func checkingResultIsIdempotentThenRoutesForResolvedAccess() throws {
        let access = MutableFlowerShowAccessProvider(.checking)
        let store = InMemoryGameProgressStore(
            progress: GameProgress(
                bestScore: 0,
                highestGarden: 2,
                flowerShowProgress: FlowerShowProgressV3(
                    bestCampaignRatings: Dictionary(
                        uniqueKeysWithValues: (1 ... 4).map { ($0, .seedling) }
                    )
                )
            )
        )
        let model = GameModel(
            launchMode: .uiTest(seed: 57),
            progressStore: store,
            flowerShowAccess: access
        )

        #expect(model.startFlowerShowClass(5) == .started)
        let scenario = FlowerShowContent.resolve(classNumber: 5).scenario
        let route = try #require(
            FlowerShowExactSolver.shortestRoute(
                from: modelState(model),
                scenario: scenario
            )
        )
        for move in route.moves {
            model.select(move.ring)
            _ = try #require(model.rotate(move.direction))
        }

        let result = try #require(model.pendingFlowerShowResult)
        let persistedAtResult = store.progress.flowerShowProgress
        #expect(model.nextFlowerShowClass() == .accessChecking)
        #expect(model.nextFlowerShowClass() == .accessChecking)
        #expect(model.pendingFlowerShowResult == result)
        #expect(store.progress.flowerShowProgress == persistedAtResult)

        access.accessState = .full(.storePurchase)
        #expect(model.pendingFlowerShowResult == result)
        #expect(model.nextFlowerShowClass() == .started)
        #expect(model.currentFlowerShowClass == 6)
    }

    @Test(
        "Checking then sample keeps the result until Continue requests purchase",
        .bug("https://linear.app/weevolve/issue/TOM-57")
    )
    func checkingThenSamplePreservesResultUntilAction() throws {
        let resultID = UUID()
        let summary = FlowerShowResultSummary(
            attemptID: resultID,
            context: FlowerShowAttemptContext(kind: .campaign, classNumber: 5),
            rating: .seedling,
            movesUsed: 8,
            radiantPar: 7,
            didUseHint: true,
            didUseUndo: false,
            isNewBest: true,
            milestone: .rosette
        )
        let access = MutableFlowerShowAccessProvider(.checking)
        let model = GameModel(
            launchMode: .uiTest(seed: 58),
            progressStore: InMemoryGameProgressStore(
                progress: GameProgress(
                    bestScore: 0,
                    highestGarden: 2,
                    flowerShowProgress: FlowerShowProgressV3(
                        bestCampaignRatings: Dictionary(
                            uniqueKeysWithValues: (1 ... 5).map { ($0, .seedling) }
                        ),
                        pendingResult: summary,
                        committedAttemptIDs: [resultID]
                    )
                )
            ),
            flowerShowAccess: access
        )

        // Restored results are displayed before any routing decision is made.
        let restored = try #require(model.pendingFlowerShowResult)
        #expect(restored == summary)
        access.accessState = .sample
        #expect(model.pendingFlowerShowResult == summary)

        // `nextFlowerShowClass` requires an active won engine, so the UI-path assertion is
        // covered by the deterministic result-screen UI test. State restoration is proven here.
    }

    private func modelState(_ model: GameModel) -> FlowerShowState {
        var engine = FlowerShowEngine(
            scenario: FlowerShowContent.resolve(
                classNumber: model.flowerShowDefinition.number
            ).scenario
        )
        engine.state.board = model.board
        engine.state.selectedRing = model.selectedRing
        engine.state.blooms = model.blooms
        engine.state.movesRemaining = model.movesRemaining
        return engine.state
    }

    private func qualifiedProgress(completedThrough classNumber: Int) -> GameProgress {
        GameProgress(
            bestScore: 0,
            highestGarden: 2,
            flowerShowProgress: FlowerShowProgressV3(
                bestCampaignRatings: Dictionary(
                    uniqueKeysWithValues: (1 ... classNumber).map { ($0, .seedling) }
                )
            )
        )
    }
}

struct FlowerShowHomeProgressTests {
    struct Case: CustomTestStringConvertible, Sendable {
        let qualified: Bool
        let access: FlowerShowAccessState
        let expectedCaption: String?
        let expectedValue: String?

        var testDescription: String {
            "qualified=\(qualified), access=\(access)"
        }
    }

    @Test(
        "Qualification and entitlement combinations expose accurate progress",
        .bug("https://linear.app/weevolve/issue/TOM-59"),
        arguments: [
            Case(qualified: false, access: .checking, expectedCaption: "GARDEN WON", expectedValue: "0 of 1 Garden won"),
            Case(qualified: false, access: .sample, expectedCaption: "GARDEN WON", expectedValue: "0 of 1 Garden won"),
            Case(qualified: false, access: .full(.storePurchase), expectedCaption: "GARDEN WON", expectedValue: "0 of 1 Garden won"),
            Case(qualified: true, access: .checking, expectedCaption: "GARDEN WON", expectedValue: "1 of 1 Garden won"),
            Case(qualified: true, access: .sample, expectedCaption: "FREE CLASSES", expectedValue: "3 of 5 free Classes complete"),
            Case(qualified: true, access: .full(.storePurchase), expectedCaption: "CAMPAIGN CLASSES", expectedValue: "12 of 30 campaign Classes complete"),
        ]
    )
    func progressMatrix(testCase: Case) {
        let progress = ModeCardProgress.flowerShow(
            highestGarden: testCase.qualified ? 2 : 1,
            qualified: testCase.qualified,
            accessState: testCase.access,
            completedFreeClasses: 3,
            completedCampaignClasses: 12
        )

        #expect(progress?.caption == testCase.expectedCaption)
        #expect(progress?.accessibilityValue == testCase.expectedValue)
    }

    @MainActor
    @Test func firstGardenWinExposesOneOfOneDuringChecking() throws {
        let model = GameModel(
            launchMode: .uiTest(seed: 59),
            progressStore: InMemoryGameProgressStore(
                progress: GameProgress(bestScore: 0, highestGarden: 2)
            )
        )
        #expect(model.flowerShowQualified)

        let progress = try #require(
            ModeCardProgress.flowerShow(
                highestGarden: model.highestGarden,
                qualified: model.flowerShowQualified,
                accessState: .checking,
                completedFreeClasses: 0,
                completedCampaignClasses: 0
            )
        )
        #expect(progress.value == 1)
        #expect(progress.accessibilityValue == "1 of 1 Garden won")
    }
}

@MainActor
struct FlowerShowStoreClientCompositionTests {
    @Test(
        "Hosted tests use a no-I/O client while ordinary launches retain StoreKit",
        .bug("https://linear.app/weevolve/issue/TOM-62")
    )
    func hostedTestCompositionIsExplicitAndDebugOnly() {
        let production = FlowerShowStoreClientComposition.resolve(environment: [:])
        #expect(production == .production)

        let hostedTests = FlowerShowStoreClientComposition.resolve(
            environment: [
                "XCInjectBundle": "/tmp/Ringbloom.app/PlugIns/RingbloomTests.xctest",
                "DYLD_INSERT_LIBRARIES": "/tmp/Ringbloom.app/Frameworks/libXCTestBundleInject.dylib",
            ]
        )
        #expect(hostedTests == .hostedUnitTests)
        #expect(hostedTests.makeStoreClient() is HostedUnitTestFlowerShowStoreClient)

        let arbitraryArgumentsCannotSelectHostedTests = FlowerShowStoreClientComposition.resolve(
            environment: ["ProcessArguments": "--hosted-unit-tests"]
        )
        #expect(arbitraryArgumentsCannotSelectHostedTests == .production)

        let unrelatedTestBundle = FlowerShowStoreClientComposition.resolve(
            environment: [
                "XCInjectBundle": "/tmp/RingbloomUITests.xctest",
                "DYLD_INSERT_LIBRARIES": "/tmp/libXCTestBundleInject.dylib",
            ]
        )
        #expect(unrelatedTestBundle == .production)
    }
}

@MainActor
private final class FakeFlowerShowStoreClient: FlowerShowStoreClient {
    let transactionUpdates: AsyncStream<FlowerShowPurchaseTransaction>
    private let transactionUpdatesContinuation: AsyncStream<FlowerShowPurchaseTransaction>.Continuation
    var product: FlowerShowProductInfo?
    var entitlement: FlowerShowEntitlementSnapshot
    var purchaseOutcome: Result<FlowerShowPurchaseOutcome, Error>
    var finishedIDs: [UInt64] = []
    private(set) var loadProductCallCount = 0
    private(set) var entitlementCallCount = 0
    private(set) var purchaseCallCount = 0
    var syncCallCount = 0
    var loadProductError: Error?
    var entitlementError: Error?
    var syncError: Error?
    var suspendsProductRequests: Bool
    var suspendsEntitlementRequests: Bool
    var suspendsPurchaseRequests: Bool
    var suspendsSyncRequests: Bool
    var suspendsFinishRequests: Bool
    private var finishWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var productCallWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var entitlementCallWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var purchaseCallWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var syncCallWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var productRequests: [Int: CheckedRequest<FlowerShowProductInfo?>] = [:]
    private var entitlementRequests: [Int: CheckedRequest<FlowerShowEntitlementSnapshot>] = [:]
    private var purchaseRequests: [Int: CheckedRequest<FlowerShowPurchaseOutcome>] = [:]
    private var syncRequests: [Int: CheckedRequest<Void>] = [:]
    private var finishRequests: [Int: CheckedRequest<Void>] = [:]

    init(
        product: FlowerShowProductInfo? = FlowerShowProductInfo(
            productID: FlowerShowAccessPolicy.productID,
            displayPrice: "£2.99"
        ),
        entitlement: FlowerShowEntitlementSnapshot = FlowerShowEntitlementSnapshot(
            appTransaction: .unavailable,
            purchaseTransaction: nil
        ),
        purchaseOutcome: Result<FlowerShowPurchaseOutcome, Error> = .success(
            .success(
                FlowerShowPurchaseTransaction(
                    id: 42,
                    productID: FlowerShowAccessPolicy.productID,
                    isVerified: true,
                    isRevoked: false
                )
            )
        ),
        suspendsProductRequests: Bool = false,
        suspendsEntitlementRequests: Bool = false,
        suspendsPurchaseRequests: Bool = false,
        suspendsSyncRequests: Bool = false,
        suspendsFinishRequests: Bool = false
    ) {
        self.product = product
        self.entitlement = entitlement
        self.purchaseOutcome = purchaseOutcome
        self.suspendsProductRequests = suspendsProductRequests
        self.suspendsEntitlementRequests = suspendsEntitlementRequests
        self.suspendsPurchaseRequests = suspendsPurchaseRequests
        self.suspendsSyncRequests = suspendsSyncRequests
        self.suspendsFinishRequests = suspendsFinishRequests
        var capturedContinuation: AsyncStream<FlowerShowPurchaseTransaction>.Continuation?
        transactionUpdates = AsyncStream { continuation in
            capturedContinuation = continuation
        }
        guard let capturedContinuation else {
            preconditionFailure("Failed to create fake transaction update stream")
        }
        transactionUpdatesContinuation = capturedContinuation
    }

    func loadProduct() async throws -> FlowerShowProductInfo? {
        let requestIndex = loadProductCallCount
        loadProductCallCount += 1
        resumeCallWaiters(&productCallWaiters, callCount: loadProductCallCount)
        if suspendsProductRequests {
            let request = CheckedRequest<FlowerShowProductInfo?>()
            productRequests[requestIndex] = request
            return try await request.value()
        }
        if let loadProductError { throw loadProductError }
        return product
    }

    func loadEntitlementSnapshot() async throws -> FlowerShowEntitlementSnapshot {
        let requestIndex = entitlementCallCount
        entitlementCallCount += 1
        resumeCallWaiters(&entitlementCallWaiters, callCount: entitlementCallCount)
        if suspendsEntitlementRequests {
            let request = CheckedRequest<FlowerShowEntitlementSnapshot>()
            entitlementRequests[requestIndex] = request
            return try await request.value()
        }
        if let entitlementError { throw entitlementError }
        return entitlement
    }

    func purchase() async throws -> FlowerShowPurchaseOutcome {
        let requestIndex = purchaseCallCount
        purchaseCallCount += 1
        resumeCallWaiters(&purchaseCallWaiters, callCount: purchaseCallCount)
        if suspendsPurchaseRequests {
            let request = CheckedRequest<FlowerShowPurchaseOutcome>()
            purchaseRequests[requestIndex] = request
            return try await request.value()
        }
        return try purchaseOutcome.get()
    }

    func sync() async throws {
        let requestIndex = syncCallCount
        syncCallCount += 1
        resumeCallWaiters(&syncCallWaiters, callCount: syncCallCount)
        if suspendsSyncRequests {
            let request = CheckedRequest<Void>()
            syncRequests[requestIndex] = request
            return try await request.value()
        }
        if let syncError { throw syncError }
    }

    func finish(transactionID: UInt64) async {
        let requestIndex = finishedIDs.count
        finishedIDs.append(transactionID)
        let readyWaiters = finishWaiters.filter { finishedIDs.count > $0.count }
        finishWaiters.removeAll { finishedIDs.count > $0.count }
        readyWaiters.forEach { $0.continuation.resume() }
        if suspendsFinishRequests {
            let request = CheckedRequest<Void>()
            finishRequests[requestIndex] = request
            _ = try? await request.value()
        }
    }

    func yieldTransaction(_ transaction: FlowerShowPurchaseTransaction) {
        transactionUpdatesContinuation.yield(transaction)
    }

    func waitForFinishedTransaction(after count: Int) async {
        guard finishedIDs.count <= count else { return }
        await withCheckedContinuation { continuation in
            finishWaiters.append((count: count, continuation: continuation))
        }
    }

    func waitForProductCall(after count: Int) async {
        guard loadProductCallCount <= count else { return }
        await withCheckedContinuation { continuation in
            productCallWaiters.append((count: count, continuation: continuation))
        }
    }

    func waitForEntitlementCall(after count: Int) async {
        guard entitlementCallCount <= count else { return }
        await withCheckedContinuation { continuation in
            entitlementCallWaiters.append((count: count, continuation: continuation))
        }
    }

    func waitForPurchaseCall(after count: Int) async {
        guard purchaseCallCount <= count else { return }
        await withCheckedContinuation { continuation in
            purchaseCallWaiters.append((count: count, continuation: continuation))
        }
    }

    func waitForSyncCall(after count: Int) async {
        guard syncCallCount <= count else { return }
        await withCheckedContinuation { continuation in
            syncCallWaiters.append((count: count, continuation: continuation))
        }
    }

    func completeProductRequest(
        at index: Int,
        with result: Result<FlowerShowProductInfo?, Error>
    ) {
        productRequests[index]?.resume(with: result)
    }

    func completeEntitlementRequest(
        at index: Int,
        with result: Result<FlowerShowEntitlementSnapshot, Error>
    ) {
        entitlementRequests[index]?.resume(with: result)
    }

    func completePurchaseRequest(
        at index: Int,
        with result: Result<FlowerShowPurchaseOutcome, Error>
    ) {
        purchaseRequests[index]?.resume(with: result)
    }

    func completeSyncRequest(at index: Int, with result: Result<Void, Error>) {
        syncRequests[index]?.resume(with: result)
    }

    func completeFinishRequest(at index: Int) {
        finishRequests[index]?.resume(with: .success(()))
    }

    func productRequestWasCancelled(at index: Int) -> Bool {
        productRequests[index]?.wasCancelled == true
    }

    func entitlementRequestWasCancelled(at index: Int) -> Bool {
        entitlementRequests[index]?.wasCancelled == true
    }

    func waitForProductRequestCancellation(at index: Int) async {
        await productRequests[index]?.waitUntilCancelled()
    }

    func waitForEntitlementRequestCancellation(at index: Int) async {
        await entitlementRequests[index]?.waitUntilCancelled()
    }

    private func resumeCallWaiters(
        _ waiters: inout [(count: Int, continuation: CheckedContinuation<Void, Never>)],
        callCount: Int
    ) {
        let readyWaiters = waiters.filter { callCount > $0.count }
        waiters.removeAll { callCount > $0.count }
        readyWaiters.forEach { $0.continuation.resume() }
    }
}

private final class CheckedRequest<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?
    private var pendingResult: Result<Value, Error>?
    private var cancelled = false
    private var completed = false
    private var cancellationWaiters: [CheckedContinuation<Void, Never>] = []

    var wasCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func waitUntilCancelled() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if cancelled {
                lock.unlock()
                continuation.resume()
            } else {
                cancellationWaiters.append(continuation)
                lock.unlock()
            }
        }
    }

    func value() async throws -> Value {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                if let pendingResult {
                    self.pendingResult = nil
                    lock.unlock()
                    continuation.resume(with: pendingResult)
                } else {
                    self.continuation = continuation
                    lock.unlock()
                }
            }
        } onCancel: {
            self.cancel()
        }
    }

    func resume(with result: Result<Value, Error>) {
        lock.lock()
        guard completed == false else {
            lock.unlock()
            return
        }
        completed = true
        if let continuation {
            self.continuation = nil
            lock.unlock()
            continuation.resume(with: result)
        } else {
            pendingResult = result
            lock.unlock()
        }
    }

    private func cancel() {
        lock.lock()
        guard completed == false else {
            lock.unlock()
            return
        }
        completed = true
        cancelled = true
        let cancellationWaiters = cancellationWaiters
        self.cancellationWaiters.removeAll()
        if let continuation {
            self.continuation = nil
            lock.unlock()
            continuation.resume(throwing: CancellationError())
            cancellationWaiters.forEach { $0.resume() }
        } else {
            pendingResult = .failure(CancellationError())
            lock.unlock()
            cancellationWaiters.forEach { $0.resume() }
        }
    }
}

@MainActor
private func waitForAccessState(
    _ expectedState: FlowerShowAccessState,
    in store: FlowerShowStore
) async {
    guard store.accessState != expectedState else { return }
    for await state in store.$accessState.values where state == expectedState {
        return
    }
}

@MainActor
private func waitForProductState(
    _ expectedState: FlowerShowProductState,
    in store: FlowerShowStore
) async {
    guard store.productState != expectedState else { return }
    for await state in store.$productState.values where state == expectedState {
        return
    }
}

@MainActor
private func waitForPurchaseState(
    _ expectedState: FlowerShowPurchaseState,
    in store: FlowerShowStore
) async {
    guard store.purchaseState != expectedState else { return }
    for await state in store.$purchaseState.values where state == expectedState {
        return
    }
}

private enum StoreTestFixture {
    static let emptySnapshot = FlowerShowEntitlementSnapshot(
        appTransaction: .unavailable,
        purchaseTransaction: nil
    )

    static let legacyAppTransaction = FlowerShowAppTransactionCheck.verified(
        FlowerShowAppTransactionSnapshot(
            environment: .production,
            originalPurchaseDate: .distantPast,
            isVerified: true
        )
    )

    static func purchase(id: UInt64 = 42, revoked: Bool = false) -> FlowerShowPurchaseTransaction {
        FlowerShowPurchaseTransaction(
            id: id,
            productID: FlowerShowAccessPolicy.productID,
            isVerified: true,
            isRevoked: revoked
        )
    }

    static func snapshot(
        appTransaction: FlowerShowAppTransactionCheck = .unavailable,
        purchase: FlowerShowPurchaseTransaction? = nil
    ) -> FlowerShowEntitlementSnapshot {
        FlowerShowEntitlementSnapshot(
            appTransaction: appTransaction,
            purchaseTransaction: purchase
        )
    }
}

@MainActor
struct FlowerShowStoreTests {
    @Test(
        arguments: [
            FlowerShowAppTransactionCheck.unverified,
            .verified(
                FlowerShowAppTransactionSnapshot(
                    environment: .production,
                    originalPurchaseDate: .distantPast,
                    isVerified: false
                )
            ),
        ]
    )
    func untrustedAppTransactionFailsClosedWithoutMutatingProgress(
        appTransaction: FlowerShowAppTransactionCheck
    ) async {
        let client = FakeFlowerShowStoreClient(
            entitlement: StoreTestFixture.snapshot(appTransaction: appTransaction)
        )
        let store = FlowerShowStore(client: client, launchOverrides: .production)
        let progressStore = InMemoryGameProgressStore(
            progress: GameProgress(
                bestScore: 9_999,
                highestGarden: 8,
                flowerShowProgress: FlowerShowProgressV3(
                    bestCampaignRatings: [1: .radiant, 2: .flourishing]
                )
            )
        )
        let progressBeforeRefresh = progressStore.progress
        _ = GameModel(
            launchMode: .uiTest(seed: 63),
            progressStore: progressStore,
            flowerShowAccess: store
        )

        await waitForAccessState(.sample, in: store)

        #expect(store.accessState == .sample)
        #expect(progressStore.progress == progressBeforeRefresh)
        store.stopTransactionListener()
    }

    @Test func verifiedPurchaseUnlocksAndFinishesExactlyOnce() async {
        let client = FakeFlowerShowStoreClient()
        let attribution = RecordingPurchaseAttributionTracker()
        let store = FlowerShowStore(
            client: client,
            launchOverrides: FlowerShowLaunchOverrides(
                access: .sample,
                productUnavailable: false,
                purchase: nil,
                displayPrice: "£2.99"
            ),
            purchaseAttribution: attribution
        )

        #expect(store.productState == .available(
            FlowerShowProductInfo(
                productID: FlowerShowAccessPolicy.productID,
                displayPrice: "£2.99"
            )
        ))
        await store.purchase()
        #expect(store.accessState == .full(.storePurchase))
        #expect(store.purchaseState == .success)
        #expect(client.finishedIDs == [42])
        #expect(attribution.transactionIDs == [42])
    }

    @Test func cancellationDoesNotChangeAccessOrShowAnError() async {
        let client = FakeFlowerShowStoreClient(purchaseOutcome: .success(.userCancelled))
        let store = FlowerShowStore(
            client: client,
            launchOverrides: FlowerShowLaunchOverrides(
                access: .sample,
                productUnavailable: false,
                purchase: nil,
                displayPrice: "£2.99"
            )
        )

        await store.purchase()
        #expect(store.accessState == .sample)
        #expect(store.purchaseState == .idle)
        #expect(client.finishedIDs.isEmpty)
    }

    @Test func deterministicRestoreDoesNotContactStoreKit() async {
        let client = FakeFlowerShowStoreClient(
            entitlement: FlowerShowEntitlementSnapshot(
                appTransaction: .unavailable,
                purchaseTransaction: FlowerShowPurchaseTransaction(
                    id: 7,
                    productID: FlowerShowAccessPolicy.productID,
                    isVerified: true,
                    isRevoked: false
                )
            )
        )
        let store = FlowerShowStore(
            client: client,
            launchOverrides: FlowerShowLaunchOverrides(
                access: .sample,
                productUnavailable: false,
                purchase: nil,
                displayPrice: "£2.99"
            )
        )

        await store.restorePurchases()
        #expect(client.syncCallCount == 0)
        #expect(store.accessState == .sample)
        #expect(store.purchaseState == .idle)
    }

    @Test func productionRestoreUsesSyncAndPreservesEstablishedAccessOnRefreshFailure() async {
        let client = FakeFlowerShowStoreClient(
            entitlement: FlowerShowEntitlementSnapshot(
                appTransaction: .unavailable,
                purchaseTransaction: FlowerShowPurchaseTransaction(
                    id: 8,
                    productID: FlowerShowAccessPolicy.productID,
                    isVerified: true,
                    isRevoked: false
                )
            )
        )
        let store = FlowerShowStore(
            client: client,
            launchOverrides: .production
        )

        await store.restorePurchases()
        #expect(client.syncCallCount == 1)
        #expect(store.accessState == .full(.storePurchase))

        client.entitlementError = FlowerShowStoreClientError.failed
        await store.restorePurchases()
        #expect(client.syncCallCount == 2)
        #expect(store.accessState == .full(.storePurchase))
        #expect(store.purchaseState == .success)
    }

    @Test func verifiedRevocationDowngradesEvenWhenEntitlementRefreshFails() async {
        let transaction = StoreTestFixture.purchase(id: 44)
        let client = FakeFlowerShowStoreClient(
            entitlement: StoreTestFixture.snapshot(purchase: transaction),
            purchaseOutcome: .success(.success(transaction))
        )
        let store = FlowerShowStore(client: client, launchOverrides: .production)
        await store.retryProductLoad()
        await store.purchase()
        #expect(store.accessState == .full(.storePurchase))

        client.entitlementError = FlowerShowStoreClientError.failed
        let entitlementCallCount = client.entitlementCallCount
        client.yieldTransaction(
            StoreTestFixture.purchase(id: transaction.id, revoked: true)
        )
        await client.waitForEntitlementCall(after: entitlementCallCount)
        await waitForPurchaseState(.idle, in: store)
        #expect(store.accessState == .sample)
        #expect(store.purchaseState == .idle)
        #expect(client.finishedIDs == [transaction.id])
        store.stopTransactionListener()
    }

    @Test(
        "Bootstrap completion cannot erase a newer verified update",
        .bug("https://linear.app/weevolve/issue/TOM-53")
    )
    func bootstrapCompletionCannotEraseVerifiedUpdate() async {
        let client = FakeFlowerShowStoreClient(
            entitlement: StoreTestFixture.emptySnapshot,
            suspendsEntitlementRequests: true
        )
        let store = FlowerShowStore(client: client, launchOverrides: .production)
        await client.waitForEntitlementCall(after: 0)

        client.yieldTransaction(StoreTestFixture.purchase(id: 101))
        await client.waitForFinishedTransaction(after: 0)
        await waitForAccessState(.full(.storePurchase), in: store)
        await client.waitForEntitlementCall(after: 1)

        client.completeEntitlementRequest(at: 0, with: .success(StoreTestFixture.emptySnapshot))
        client.completeEntitlementRequest(at: 1, with: .success(StoreTestFixture.emptySnapshot))

        #expect(store.accessState == .full(.storePurchase))
        store.stopTransactionListener()
    }

    @Test(
        "A later ordinary empty refresh preserves a verified grant",
        .bug("https://linear.app/weevolve/issue/TOM-53")
    )
    func laterOrdinaryRefreshPreservesVerifiedGrant() async {
        let client = FakeFlowerShowStoreClient(
            entitlement: StoreTestFixture.emptySnapshot,
            suspendsEntitlementRequests: true
        )
        let store = FlowerShowStore(client: client, launchOverrides: .production)
        await client.waitForEntitlementCall(after: 0)

        client.yieldTransaction(StoreTestFixture.purchase(id: 102))
        await client.waitForFinishedTransaction(after: 0)
        await client.waitForEntitlementCall(after: 1)

        let ordinaryRefresh = Task { await store.retryAccessCheck() }
        await client.waitForEntitlementCall(after: 2)
        client.completeEntitlementRequest(at: 2, with: .success(StoreTestFixture.emptySnapshot))
        await ordinaryRefresh.value
        client.completeEntitlementRequest(at: 1, with: .success(StoreTestFixture.emptySnapshot))
        client.completeEntitlementRequest(at: 0, with: .success(StoreTestFixture.emptySnapshot))

        #expect(store.accessState == .full(.storePurchase))
        store.stopTransactionListener()
    }

    @Test(
        "Two ordinary refreshes use latest-started authority when completing in reverse",
        .bug("https://linear.app/weevolve/issue/TOM-53")
    )
    func ordinaryRefreshesCompleteInReverseOrder() async {
        let client = FakeFlowerShowStoreClient(
            entitlement: StoreTestFixture.emptySnapshot,
            suspendsEntitlementRequests: true
        )
        let store = FlowerShowStore(client: client, launchOverrides: .production)
        await client.waitForEntitlementCall(after: 0)

        let firstRefresh = Task { await store.retryAccessCheck() }
        await client.waitForEntitlementCall(after: 1)
        let secondRefresh = Task { await store.retryAccessCheck() }
        await client.waitForEntitlementCall(after: 2)

        let legacySnapshot = StoreTestFixture.snapshot(
            appTransaction: StoreTestFixture.legacyAppTransaction
        )
        client.completeEntitlementRequest(at: 2, with: .success(legacySnapshot))
        await secondRefresh.value
        client.completeEntitlementRequest(at: 1, with: .success(StoreTestFixture.emptySnapshot))
        await firstRefresh.value
        client.completeEntitlementRequest(at: 0, with: .success(StoreTestFixture.emptySnapshot))

        #expect(store.accessState == .full(.legacyPaidApp))
        store.stopTransactionListener()
    }

    @Test(
        "Revocation invalidates an outstanding pre-revocation refresh",
        .bug("https://linear.app/weevolve/issue/TOM-53")
    )
    func revocationInvalidatesOutstandingRefresh() async {
        let client = FakeFlowerShowStoreClient(
            entitlement: StoreTestFixture.snapshot(purchase: StoreTestFixture.purchase(id: 103))
        )
        let store = FlowerShowStore(client: client, launchOverrides: .production)
        await waitForAccessState(.full(.storePurchase), in: store)

        client.suspendsEntitlementRequests = true
        let preRevocationRefresh = Task { await store.retryAccessCheck() }
        await client.waitForEntitlementCall(after: 1)
        client.yieldTransaction(StoreTestFixture.purchase(id: 103, revoked: true))
        await client.waitForFinishedTransaction(after: 0)
        await client.waitForEntitlementCall(after: 2)

        client.completeEntitlementRequest(
            at: 1,
            with: .success(StoreTestFixture.snapshot(purchase: StoreTestFixture.purchase(id: 103)))
        )
        await preRevocationRefresh.value
        client.completeEntitlementRequest(at: 2, with: .success(StoreTestFixture.emptySnapshot))
        await waitForAccessState(.sample, in: store)

        #expect(store.accessState == .sample)
        store.stopTransactionListener()
    }

    @Test(
        "Revocation during direct-purchase finish defeats reserved and later stale refreshes",
        .bug("https://linear.app/weevolve/issue/TOM-53")
    )
    func revocationDuringSuspendedDirectFinishRemainsAuthoritative() async {
        let transaction = StoreTestFixture.purchase(id: 205)
        let staleSnapshot = StoreTestFixture.snapshot(purchase: transaction)
        let client = FakeFlowerShowStoreClient(
            entitlement: staleSnapshot,
            purchaseOutcome: .success(.success(transaction)),
            suspendsFinishRequests: true
        )
        let store = FlowerShowStore(client: client, launchOverrides: .production)
        await waitForProductState(
            .available(
                FlowerShowProductInfo(
                    productID: FlowerShowAccessPolicy.productID,
                    displayPrice: "£2.99"
                )
            ),
            in: store
        )
        await waitForAccessState(.full(.storePurchase), in: store)
        client.suspendsEntitlementRequests = true

        let purchase = Task { await store.purchase() }
        await client.waitForFinishedTransaction(after: 0)
        client.yieldTransaction(StoreTestFixture.purchase(id: 205, revoked: true))
        await client.waitForEntitlementCall(after: 1)
        await waitForAccessState(.sample, in: store)

        client.completeFinishRequest(at: 0)
        await purchase.value

        #expect(store.accessState == .sample)
        #expect(store.purchaseState == .idle)
        #expect(client.finishedIDs == [205])
        #expect(client.entitlementCallCount == 2)

        client.completeEntitlementRequest(at: 1, with: .success(staleSnapshot))
        let laterRetry = Task { await store.retryAccessCheck() }
        await client.waitForEntitlementCall(after: 2)
        client.completeEntitlementRequest(at: 2, with: .success(staleSnapshot))
        await laterRetry.value

        #expect(store.accessState == .sample)
        #expect(client.finishedIDs == [205])
        #expect(client.entitlementCallCount == 3)
        store.stopTransactionListener()
    }

    @Test(
        "A delayed direct success cannot supersede an earlier same-ID revocation",
        .bug("https://linear.app/weevolve/issue/TOM-53")
    )
    func revocationBeforeDelayedDirectSuccessRemainsAuthoritative() async {
        let transaction = StoreTestFixture.purchase(id: 206)
        let staleSnapshot = StoreTestFixture.snapshot(purchase: transaction)
        let client = FakeFlowerShowStoreClient(
            entitlement: StoreTestFixture.emptySnapshot,
            purchaseOutcome: .success(.success(transaction)),
            suspendsEntitlementRequests: true,
            suspendsPurchaseRequests: true
        )
        let store = FlowerShowStore(client: client, launchOverrides: .production)
        await waitForProductState(
            .available(
                FlowerShowProductInfo(
                    productID: FlowerShowAccessPolicy.productID,
                    displayPrice: "£2.99"
                )
            ),
            in: store
        )
        await client.waitForEntitlementCall(after: 0)
        client.completeEntitlementRequest(at: 0, with: .success(StoreTestFixture.emptySnapshot))
        await waitForAccessState(.sample, in: store)

        let purchase = Task { await store.purchase() }
        await client.waitForPurchaseCall(after: 0)
        client.yieldTransaction(StoreTestFixture.purchase(id: 206, revoked: true))
        await client.waitForFinishedTransaction(after: 0)
        await client.waitForEntitlementCall(after: 1)

        client.completePurchaseRequest(at: 0, with: .success(.success(transaction)))
        await purchase.value
        client.completeEntitlementRequest(at: 1, with: .success(staleSnapshot))

        #expect(store.accessState == .sample)
        #expect(store.purchaseState == .idle)
        #expect(client.purchaseCallCount == 1)
        #expect(client.finishedIDs == [206])
        #expect(client.entitlementCallCount == 2)
        store.stopTransactionListener()
    }

    @Test(
        "A new-ID purchase supersedes an older suspended revocation refresh",
        .bug("https://linear.app/weevolve/issue/TOM-53")
    )
    func newerPurchaseInvalidatesSuspendedOlderRevocationRefresh() async {
        let oldTransaction = StoreTestFixture.purchase(id: 207)
        let newTransaction = StoreTestFixture.purchase(id: 208)
        let client = FakeFlowerShowStoreClient(
            entitlement: StoreTestFixture.snapshot(purchase: oldTransaction),
            purchaseOutcome: .success(.success(newTransaction)),
            suspendsFinishRequests: true
        )
        let store = FlowerShowStore(client: client, launchOverrides: .production)
        await waitForProductState(
            .available(
                FlowerShowProductInfo(
                    productID: FlowerShowAccessPolicy.productID,
                    displayPrice: "£2.99"
                )
            ),
            in: store
        )
        await waitForAccessState(.full(.storePurchase), in: store)

        client.yieldTransaction(StoreTestFixture.purchase(id: 207, revoked: true))
        await client.waitForFinishedTransaction(after: 0)
        await waitForAccessState(.sample, in: store)
        client.suspendsFinishRequests = false

        await store.purchase()

        #expect(store.accessState == .full(.storePurchase))
        #expect(store.purchaseState == .success)
        #expect(client.finishedIDs == [207, 208])
        #expect(client.entitlementCallCount == 2)

        client.completeFinishRequest(at: 0)
        await Task.yield()

        #expect(store.accessState == .full(.storePurchase))
        #expect(store.purchaseState == .success)
        #expect(client.finishedIDs == [207, 208])
        #expect(client.entitlementCallCount == 2)
        store.stopTransactionListener()
    }

    @Test(
        "Late and duplicate old-ID revocations cannot remove a newer active transaction",
        .bug("https://linear.app/weevolve/issue/TOM-53")
    )
    func revocationRemovesOnlyItsOwnActiveTransaction() async {
        let oldTransaction = StoreTestFixture.purchase(id: 209)
        let newTransaction = StoreTestFixture.purchase(id: 210)
        let client = FakeFlowerShowStoreClient(
            entitlement: StoreTestFixture.snapshot(purchase: oldTransaction)
        )
        let store = FlowerShowStore(client: client, launchOverrides: .production)
        await waitForAccessState(.full(.storePurchase), in: store)
        client.entitlement = StoreTestFixture.snapshot(purchase: newTransaction)

        client.yieldTransaction(newTransaction)
        await client.waitForFinishedTransaction(after: 0)
        await client.waitForEntitlementCall(after: 1)
        #expect(store.accessState == .full(.storePurchase))

        client.yieldTransaction(StoreTestFixture.purchase(id: 209, revoked: true))
        await client.waitForFinishedTransaction(after: 1)
        await client.waitForEntitlementCall(after: 2)
        #expect(store.accessState == .full(.storePurchase))
        #expect(store.purchaseState == .success)

        client.yieldTransaction(StoreTestFixture.purchase(id: 209, revoked: true))
        await client.waitForEntitlementCall(after: 3)
        #expect(store.accessState == .full(.storePurchase))
        #expect(client.finishedIDs == [210, 209])

        client.yieldTransaction(StoreTestFixture.purchase(id: 210, revoked: true))
        await client.waitForEntitlementCall(after: 4)
        await waitForAccessState(.sample, in: store)

        #expect(store.purchaseState == .idle)
        #expect(client.finishedIDs == [210, 209])
        #expect(client.entitlementCallCount == 5)
        store.stopTransactionListener()
    }

    @Test(
        "Legacy authority survives IAP revocation when AppTransaction is unavailable",
        .bug("https://linear.app/weevolve/issue/TOM-53")
    )
    func legacySurvivesRevocationWithUnavailableAppTransaction() async {
        let client = FakeFlowerShowStoreClient(
            entitlement: StoreTestFixture.snapshot(
                appTransaction: StoreTestFixture.legacyAppTransaction,
                purchase: StoreTestFixture.purchase(id: 104)
            )
        )
        let store = FlowerShowStore(client: client, launchOverrides: .production)
        await waitForAccessState(.full(.storePurchase), in: store)
        client.entitlement = StoreTestFixture.emptySnapshot

        client.yieldTransaction(StoreTestFixture.purchase(id: 104, revoked: true))
        await client.waitForFinishedTransaction(after: 0)
        await waitForAccessState(.full(.legacyPaidApp), in: store)

        #expect(store.accessState == .full(.legacyPaidApp))
        store.stopTransactionListener()
    }

    @Test(
        "Duplicate listener and direct purchase delivery finishes once",
        .bug("https://linear.app/weevolve/issue/TOM-53")
    )
    func duplicateListenerAndDirectPurchaseFinishesOnce() async {
        let transaction = StoreTestFixture.purchase(id: 105)
        let client = FakeFlowerShowStoreClient(
            entitlement: StoreTestFixture.emptySnapshot,
            purchaseOutcome: .success(.success(transaction)),
            suspendsPurchaseRequests: true
        )
        let store = FlowerShowStore(client: client, launchOverrides: .production)
        await waitForProductState(
            .available(
                FlowerShowProductInfo(
                    productID: FlowerShowAccessPolicy.productID,
                    displayPrice: "£2.99"
                )
            ),
            in: store
        )

        let purchase = Task { await store.purchase() }
        await client.waitForPurchaseCall(after: 0)
        client.yieldTransaction(transaction)
        await client.waitForFinishedTransaction(after: 0)
        client.completePurchaseRequest(at: 0, with: .success(.success(transaction)))
        await purchase.value

        #expect(store.accessState == .full(.storePurchase))
        #expect(client.finishedIDs == [105])
        store.stopTransactionListener()
    }

    @Test(
        "Direct purchase and transaction update publish access before suspended finish",
        .bug("https://linear.app/weevolve/issue/TOM-63")
    )
    func verifiedDeliveriesPublishAccessBeforeFinishingExactlyOnce() async {
        let directTransaction = StoreTestFixture.purchase(id: 201)
        let directClient = FakeFlowerShowStoreClient(
            purchaseOutcome: .success(.success(directTransaction)),
            suspendsFinishRequests: true
        )
        let directStore = FlowerShowStore(
            client: directClient,
            launchOverrides: FlowerShowLaunchOverrides(
                access: .sample,
                productUnavailable: false,
                purchase: nil,
                displayPrice: "£2.99"
            )
        )
        let directPurchase = Task { await directStore.purchase() }
        await directClient.waitForFinishedTransaction(after: 0)
        #expect(directStore.accessState == .full(.storePurchase))
        #expect(directStore.purchaseState == .success)
        #expect(directClient.finishedIDs == [201])
        directClient.completeFinishRequest(at: 0)
        await directPurchase.value

        let updateTransaction = StoreTestFixture.purchase(id: 202)
        let updateClient = FakeFlowerShowStoreClient(
            entitlement: StoreTestFixture.emptySnapshot,
            suspendsFinishRequests: true
        )
        let updateStore = FlowerShowStore(client: updateClient, launchOverrides: .production)
        await waitForAccessState(.sample, in: updateStore)
        updateClient.yieldTransaction(updateTransaction)
        await updateClient.waitForFinishedTransaction(after: 0)
        #expect(updateStore.accessState == .full(.storePurchase))
        #expect(updateClient.finishedIDs == [202])
        updateClient.yieldTransaction(updateTransaction)
        updateClient.completeFinishRequest(at: 0)
        await updateClient.waitForEntitlementCall(after: 1)
        #expect(updateClient.finishedIDs == [202])
        updateStore.stopTransactionListener()
    }

    @Test(
        "Product suspension does not block legacy access",
        .bug("https://linear.app/weevolve/issue/TOM-54")
    )
    func productSuspensionDoesNotBlockLegacyAccess() async {
        let client = FakeFlowerShowStoreClient(
            suspendsProductRequests: true,
            suspendsEntitlementRequests: true
        )
        let store = FlowerShowStore(client: client, launchOverrides: .production)
        await client.waitForProductCall(after: 0)
        await client.waitForEntitlementCall(after: 0)

        client.completeEntitlementRequest(
            at: 0,
            with: .success(
                StoreTestFixture.snapshot(appTransaction: StoreTestFixture.legacyAppTransaction)
            )
        )
        await waitForAccessState(.full(.legacyPaidApp), in: store)

        #expect(store.productState == .loading)
        client.completeProductRequest(at: 0, with: .failure(CancellationError()))
        store.stopTransactionListener()
    }

    @Test(
        "Product suspension does not block current IAP access",
        .bug("https://linear.app/weevolve/issue/TOM-54")
    )
    func productSuspensionDoesNotBlockPurchaseAccess() async {
        let client = FakeFlowerShowStoreClient(
            suspendsProductRequests: true,
            suspendsEntitlementRequests: true
        )
        let store = FlowerShowStore(client: client, launchOverrides: .production)
        await client.waitForProductCall(after: 0)
        await client.waitForEntitlementCall(after: 0)

        client.completeEntitlementRequest(
            at: 0,
            with: .success(StoreTestFixture.snapshot(purchase: StoreTestFixture.purchase(id: 106)))
        )
        await waitForAccessState(.full(.storePurchase), in: store)

        #expect(store.productState == .loading)
        client.completeProductRequest(at: 0, with: .failure(CancellationError()))
        store.stopTransactionListener()
    }

    @Test(
        "Product failure and valid entitlement publish independently",
        .bug("https://linear.app/weevolve/issue/TOM-54")
    )
    func productFailureLeavesValidEntitlementUntouched() async {
        let client = FakeFlowerShowStoreClient(
            entitlement: StoreTestFixture.snapshot(purchase: StoreTestFixture.purchase(id: 107))
        )
        client.loadProductError = FlowerShowStoreClientError.failed
        let store = FlowerShowStore(client: client, launchOverrides: .production)

        await waitForAccessState(.full(.storePurchase), in: store)
        await waitForProductState(.unavailable, in: store)

        #expect(store.accessState == .full(.storePurchase))
        store.stopTransactionListener()
    }

    @Test(
        "Sample access becomes usable while product remains loading",
        .bug("https://linear.app/weevolve/issue/TOM-54")
    )
    func sampleAccessPublishesWhileProductRemainsLoading() async {
        let client = FakeFlowerShowStoreClient(
            suspendsProductRequests: true,
            suspendsEntitlementRequests: true
        )
        let store = FlowerShowStore(client: client, launchOverrides: .production)
        await client.waitForProductCall(after: 0)
        await client.waitForEntitlementCall(after: 0)
        client.completeEntitlementRequest(at: 0, with: .success(StoreTestFixture.emptySnapshot))
        await waitForAccessState(.sample, in: store)

        #expect(store.productState == .loading)
        #expect(store.purchaseState == .idle)
        client.completeProductRequest(at: 0, with: .failure(CancellationError()))
        store.stopTransactionListener()
    }

    @Test(
        "Store teardown cancels suspended independent bootstrap work",
        .bug("https://linear.app/weevolve/issue/TOM-54")
    )
    func teardownCancelsSuspendedBootstrapWork() async {
        let client = FakeFlowerShowStoreClient(
            suspendsProductRequests: true,
            suspendsEntitlementRequests: true
        )
        var store: FlowerShowStore? = FlowerShowStore(client: client, launchOverrides: .production)
        weak let weakStore = store
        await client.waitForProductCall(after: 0)
        await client.waitForEntitlementCall(after: 0)

        store = nil

        await client.waitForProductRequestCancellation(at: 0)
        await client.waitForEntitlementRequestCancellation(at: 0)

        #expect(weakStore == nil)
        #expect(client.productRequestWasCancelled(at: 0))
        #expect(client.entitlementRequestWasCancelled(at: 0))
    }

    @Test(
        "Double purchase invokes StoreKit once",
        .bug("https://linear.app/weevolve/issue/TOM-55")
    )
    func doublePurchaseInvokesClientOnce() async {
        let client = FakeFlowerShowStoreClient(suspendsPurchaseRequests: true)
        let store = FlowerShowStore(
            client: client,
            launchOverrides: FlowerShowLaunchOverrides(
                access: .sample,
                productUnavailable: false,
                purchase: nil,
                displayPrice: "£2.99"
            )
        )
        let first = Task { await store.purchase() }
        await client.waitForPurchaseCall(after: 0)
        let second = Task { await store.purchase() }
        await second.value

        #expect(client.purchaseCallCount == 1)
        #expect(store.purchaseState == .purchasing)
        client.completePurchaseRequest(at: 0, with: .success(.userCancelled))
        await first.value
    }

    @Test(
        "Double restore invokes sync once",
        .bug("https://linear.app/weevolve/issue/TOM-55")
    )
    func doubleRestoreInvokesSyncOnce() async {
        let client = FakeFlowerShowStoreClient(
            entitlement: StoreTestFixture.emptySnapshot,
            suspendsSyncRequests: true
        )
        let store = FlowerShowStore(client: client, launchOverrides: .production)
        await waitForAccessState(.sample, in: store)
        let first = Task { await store.restorePurchases() }
        await client.waitForSyncCall(after: 0)
        let second = Task { await store.restorePurchases() }
        await second.value

        #expect(client.syncCallCount == 1)
        #expect(store.purchaseState == .restoring)
        client.completeSyncRequest(at: 0, with: .success(()))
        await first.value
        store.stopTransactionListener()
    }

    @Test(
        "Restore cannot begin during purchase",
        .bug("https://linear.app/weevolve/issue/TOM-55")
    )
    func restoreCannotBeginDuringPurchase() async {
        let client = FakeFlowerShowStoreClient(suspendsPurchaseRequests: true)
        let store = FlowerShowStore(client: client, launchOverrides: .production)
        await waitForProductState(
            .available(FlowerShowProductInfo(productID: FlowerShowAccessPolicy.productID, displayPrice: "£2.99")),
            in: store
        )
        let purchase = Task { await store.purchase() }
        await client.waitForPurchaseCall(after: 0)
        await store.restorePurchases()

        #expect(client.syncCallCount == 0)
        client.completePurchaseRequest(at: 0, with: .success(.userCancelled))
        await purchase.value
        store.stopTransactionListener()
    }

    @Test(
        "Purchase cannot begin during restore",
        .bug("https://linear.app/weevolve/issue/TOM-55")
    )
    func purchaseCannotBeginDuringRestore() async {
        let client = FakeFlowerShowStoreClient(suspendsSyncRequests: true)
        let store = FlowerShowStore(client: client, launchOverrides: .production)
        await waitForProductState(
            .available(FlowerShowProductInfo(productID: FlowerShowAccessPolicy.productID, displayPrice: "£2.99")),
            in: store
        )
        let restore = Task { await store.restorePurchases() }
        await client.waitForSyncCall(after: 0)
        await store.purchase()

        #expect(client.purchaseCallCount == 0)
        client.completeSyncRequest(at: 0, with: .success(()))
        await restore.value
        store.stopTransactionListener()
    }

    @Test(
        "Transaction listener can unlock during restore",
        .bug("https://linear.app/weevolve/issue/TOM-55")
    )
    func transactionListenerUnlocksDuringRestore() async {
        let client = FakeFlowerShowStoreClient(suspendsSyncRequests: true)
        let attribution = RecordingPurchaseAttributionTracker()
        let store = FlowerShowStore(
            client: client,
            launchOverrides: .production,
            purchaseAttribution: attribution
        )
        let restore = Task { await store.restorePurchases() }
        await client.waitForSyncCall(after: 0)
        client.yieldTransaction(StoreTestFixture.purchase(id: 108))
        await client.waitForFinishedTransaction(after: 0)
        await waitForAccessState(.full(.storePurchase), in: store)

        #expect(store.purchaseState == .restoring)
        client.completeSyncRequest(at: 0, with: .success(()))
        await restore.value
        #expect(store.purchaseState == .success)
        #expect(attribution.transactionIDs.isEmpty)
        store.stopTransactionListener()
    }

    @Test(
        "Both sources fall back to legacy after successful revocation refresh",
        .bug("https://linear.app/weevolve/issue/TOM-56")
    )
    func bothSourcesFallBackToLegacyAfterRevocation() async {
        let legacyAndPurchase = StoreTestFixture.snapshot(
            appTransaction: StoreTestFixture.legacyAppTransaction,
            purchase: StoreTestFixture.purchase(id: 109)
        )
        let client = FakeFlowerShowStoreClient(entitlement: legacyAndPurchase)
        let store = FlowerShowStore(client: client, launchOverrides: .production)
        await waitForAccessState(.full(.storePurchase), in: store)
        client.entitlement = StoreTestFixture.snapshot(
            appTransaction: StoreTestFixture.legacyAppTransaction
        )
        client.yieldTransaction(StoreTestFixture.purchase(id: 109, revoked: true))
        await client.waitForFinishedTransaction(after: 0)
        await waitForAccessState(.full(.legacyPaidApp), in: store)

        #expect(store.accessState == .full(.legacyPaidApp))
        store.stopTransactionListener()
    }

    @Test(
        "Both sources preserve legacy when revocation refresh throws",
        .bug("https://linear.app/weevolve/issue/TOM-56")
    )
    func bothSourcesPreserveLegacyWhenRevocationRefreshThrows() async {
        let client = FakeFlowerShowStoreClient(
            entitlement: StoreTestFixture.snapshot(
                appTransaction: StoreTestFixture.legacyAppTransaction,
                purchase: StoreTestFixture.purchase(id: 110)
            )
        )
        let store = FlowerShowStore(client: client, launchOverrides: .production)
        await waitForAccessState(.full(.storePurchase), in: store)
        client.entitlementError = FlowerShowStoreClientError.failed
        client.yieldTransaction(StoreTestFixture.purchase(id: 110, revoked: true))
        await client.waitForFinishedTransaction(after: 0)
        await waitForAccessState(.full(.legacyPaidApp), in: store)

        #expect(store.accessState == .full(.legacyPaidApp))
        store.stopTransactionListener()
    }

    @Test(
        "IAP-only revocation with empty snapshot becomes sample",
        .bug("https://linear.app/weevolve/issue/TOM-56")
    )
    func purchaseOnlyRevocationWithEmptySnapshotBecomesSample() async {
        let client = FakeFlowerShowStoreClient(
            entitlement: StoreTestFixture.snapshot(purchase: StoreTestFixture.purchase(id: 111))
        )
        let store = FlowerShowStore(client: client, launchOverrides: .production)
        await waitForAccessState(.full(.storePurchase), in: store)
        client.entitlement = StoreTestFixture.emptySnapshot
        client.yieldTransaction(StoreTestFixture.purchase(id: 111, revoked: true))
        await client.waitForFinishedTransaction(after: 0)
        await waitForAccessState(.sample, in: store)

        #expect(store.accessState == .sample)
        store.stopTransactionListener()
    }

    @Test(
        "IAP-only revocation fails closed when refresh throws",
        .bug("https://linear.app/weevolve/issue/TOM-56")
    )
    func purchaseOnlyRevocationFailureBecomesSample() async {
        let client = FakeFlowerShowStoreClient(
            entitlement: StoreTestFixture.snapshot(purchase: StoreTestFixture.purchase(id: 112))
        )
        let store = FlowerShowStore(client: client, launchOverrides: .production)
        await waitForAccessState(.full(.storePurchase), in: store)
        client.entitlementError = FlowerShowStoreClientError.failed
        client.yieldTransaction(StoreTestFixture.purchase(id: 112, revoked: true))
        await client.waitForFinishedTransaction(after: 0)
        await waitForAccessState(.sample, in: store)

        #expect(store.accessState == .sample)
        store.stopTransactionListener()
    }

    @Test(
        "Duplicate revoked update finishes exactly once",
        .bug("https://linear.app/weevolve/issue/TOM-56")
    )
    func duplicateRevokedUpdateFinishesExactlyOnce() async {
        let transaction = StoreTestFixture.purchase(id: 113, revoked: true)
        let client = FakeFlowerShowStoreClient(
            entitlement: StoreTestFixture.snapshot(purchase: StoreTestFixture.purchase(id: 113))
        )
        let store = FlowerShowStore(client: client, launchOverrides: .production)
        await waitForAccessState(.full(.storePurchase), in: store)
        client.entitlement = StoreTestFixture.emptySnapshot

        client.yieldTransaction(transaction)
        client.yieldTransaction(transaction)
        await client.waitForFinishedTransaction(after: 0)

        #expect(client.finishedIDs == [113])
        #expect(store.accessState == .sample)
        store.stopTransactionListener()
    }

    @Test(
        "Revocation never deletes persisted premium progress",
        .bug("https://linear.app/weevolve/issue/TOM-56")
    )
    func revocationPreservesPersistedPremiumProgress() async {
        let transaction = StoreTestFixture.purchase(id: 114)
        let client = FakeFlowerShowStoreClient(
            entitlement: StoreTestFixture.snapshot(purchase: transaction)
        )
        let store = FlowerShowStore(client: client, launchOverrides: .production)
        await waitForAccessState(.full(.storePurchase), in: store)
        let progressStore = InMemoryGameProgressStore(
            progress: GameProgress(
                bestScore: 12_345,
                highestGarden: 7,
                flowerShowProgress: FlowerShowProgressV3(
                    bestCampaignRatings: Dictionary(
                        uniqueKeysWithValues: (1 ... 6).map { ($0, .flourishing) }
                    ),
                    seenIntroductions: [.harmony]
                )
            )
        )
        let model = GameModel(
            launchMode: .uiTest(seed: 114),
            progressStore: progressStore,
            flowerShowAccess: store
        )
        #expect(model.startFlowerShowClass(6) == .started)
        let progressBeforeRevocation = progressStore.progress
        client.entitlement = StoreTestFixture.emptySnapshot

        client.yieldTransaction(StoreTestFixture.purchase(id: 114, revoked: true))
        await client.waitForFinishedTransaction(after: 0)
        await waitForAccessState(.sample, in: store)

        #expect(progressStore.progress == progressBeforeRevocation)
        store.stopTransactionListener()
    }

    @Test(
        "Restore without entitlement returns to the normal idle purchase screen",
        .bug("https://linear.app/weevolve/issue/TOM-55")
    )
    func restoreWithoutEntitlementReturnsToIdle() async {
        let client = FakeFlowerShowStoreClient(entitlement: StoreTestFixture.emptySnapshot)
        let store = FlowerShowStore(client: client, launchOverrides: .production)
        await waitForAccessState(.sample, in: store)

        await store.restorePurchases()

        #expect(client.syncCallCount == 1)
        #expect(store.accessState == .sample)
        #expect(store.purchaseState == .idle)
        store.stopTransactionListener()
    }

    @Test(
        "Purchase-time product unavailability keeps access and retries product loading",
        .bug("https://linear.app/weevolve/issue/TOM-55")
    )
    func purchaseProductUnavailableUsesProductRecovery() async {
        let product = FlowerShowProductInfo(
            productID: FlowerShowAccessPolicy.productID,
            displayPrice: "£2.99"
        )
        let client = FakeFlowerShowStoreClient(
            product: product,
            entitlement: StoreTestFixture.snapshot(
                purchase: StoreTestFixture.purchase(id: 204)
            ),
            purchaseOutcome: .failure(FlowerShowStoreClientError.productUnavailable)
        )
        let store = FlowerShowStore(client: client, launchOverrides: .production)
        await waitForProductState(.available(product), in: store)
        await waitForAccessState(.full(.storePurchase), in: store)

        await store.purchase()

        #expect(client.purchaseCallCount == 1)
        #expect(store.productState == .unavailable)
        #expect(store.purchaseState == .idle)
        #expect(store.accessState == .full(.storePurchase))

        await store.retryProductLoad()

        #expect(client.loadProductCallCount == 2)
        #expect(client.purchaseCallCount == 1)
        #expect(store.productState == .available(product))
        #expect(store.purchaseState == .idle)
        #expect(store.accessState == .full(.storePurchase))
        store.stopTransactionListener()
    }

    @Test(
        "Pending disabled failed and sync failure remain distinct and retryable",
        .bug("https://linear.app/weevolve/issue/TOM-63")
    )
    func storefrontFailuresPublishDistinctStatesWithoutRemovingAccess() async {
        func deterministicStore(
            client: FakeFlowerShowStoreClient,
            purchase: FlowerShowLaunchPurchaseOverride? = nil
        ) -> FlowerShowStore {
            FlowerShowStore(
                client: client,
                launchOverrides: FlowerShowLaunchOverrides(
                    access: .sample,
                    productUnavailable: false,
                    purchase: purchase,
                    displayPrice: "£2.99"
                )
            )
        }

        let pendingClient = FakeFlowerShowStoreClient(purchaseOutcome: .success(.pending))
        let pendingStore = deterministicStore(client: pendingClient)
        await pendingStore.purchase()
        #expect(pendingStore.purchaseState == .pending)
        #expect(pendingStore.accessState == .sample)

        let disabledClient = FakeFlowerShowStoreClient(
            purchaseOutcome: .failure(FlowerShowStoreClientError.purchasesDisabled)
        )
        let disabledStore = deterministicStore(client: disabledClient)
        await disabledStore.purchase()
        #expect(disabledStore.purchaseState == .disabled)
        #expect(disabledStore.accessState == .sample)

        let failedClient = FakeFlowerShowStoreClient(
            purchaseOutcome: .failure(FlowerShowStoreClientError.failed)
        )
        let failedStore = deterministicStore(client: failedClient)
        await failedStore.purchase()
        #expect(failedStore.purchaseState == .failed)
        #expect(failedStore.accessState == .sample)

        let syncClient = FakeFlowerShowStoreClient(
            entitlement: StoreTestFixture.snapshot(purchase: StoreTestFixture.purchase(id: 203))
        )
        let syncStore = FlowerShowStore(client: syncClient, launchOverrides: .production)
        await waitForAccessState(.full(.storePurchase), in: syncStore)
        syncClient.syncError = FlowerShowStoreClientError.failed
        await syncStore.restorePurchases()
        #expect(syncStore.purchaseState == .failed)
        #expect(syncStore.accessState == .full(.storePurchase))
        #expect(syncClient.syncCallCount == 1)
        syncStore.stopTransactionListener()
    }

    @Test("Deterministic access retry transitions avoid StoreKit", .bug("https://linear.app/weevolve/issue/TOM-57"))
    func deterministicAccessRetryTransitionsAvoidStoreKit() async {
        let client = FakeFlowerShowStoreClient()
        let fullStore = FlowerShowStore(
            client: client,
            launchOverrides: FlowerShowLaunchOverrides(
                access: .checkingThenFull,
                productUnavailable: false,
                purchase: nil
            )
        )
        #expect(fullStore.accessState == .checking)
        await fullStore.retryAccessCheck()
        #expect(fullStore.accessState == .full(.storePurchase))

        let sampleStore = FlowerShowStore(
            client: client,
            launchOverrides: FlowerShowLaunchOverrides(
                access: .checkingThenSample,
                productUnavailable: false,
                purchase: nil
            )
        )
        #expect(sampleStore.accessState == .checking)
        await sampleStore.retryAccessCheck()
        #expect(sampleStore.accessState == .sample)
        #expect(client.entitlementCallCount == 0)
        #expect(client.loadProductCallCount == 0)
    }

    @Test(
        "Deterministic storefront outcomes never contact StoreKit",
        .bug("https://linear.app/weevolve/issue/TOM-61")
    )
    func deterministicStorefrontOutcomesAvoidStoreKit() async {
        let client = FakeFlowerShowStoreClient()
        func makeStore(
            purchase: FlowerShowLaunchPurchaseOverride? = nil,
            restore: FlowerShowLaunchRestoreOverride? = nil
        ) -> FlowerShowStore {
            FlowerShowStore(
                client: client,
                launchOverrides: FlowerShowLaunchOverrides(
                    access: .sample,
                    productUnavailable: false,
                    purchase: purchase,
                    restore: restore,
                    displayPrice: "£2.99"
                )
            )
        }

        let cancelledStore = makeStore(purchase: .userCancelled)
        await cancelledStore.purchase()
        #expect(cancelledStore.purchaseState == .idle)

        let successfulStore = makeStore(purchase: .success)
        await successfulStore.purchase()
        #expect(successfulStore.accessState == .full(.storePurchase))
        #expect(successfulStore.purchaseState == .success)

        let disabledStore = makeStore(purchase: .disabled)
        await disabledStore.purchase()
        #expect(disabledStore.purchaseState == .disabled)

        let purchasingStore = makeStore(purchase: .purchasing)
        let purchasingTask = Task { await purchasingStore.purchase() }
        await waitForPurchaseState(.purchasing, in: purchasingStore)
        purchasingTask.cancel()
        await purchasingTask.value

        let restoredStore = makeStore(restore: .success)
        await restoredStore.restorePurchases()
        #expect(restoredStore.accessState == .full(.storePurchase))
        #expect(restoredStore.purchaseState == .success)

        let restoringStore = makeStore(restore: .restoring)
        let restoringTask = Task { await restoringStore.restorePurchases() }
        await waitForPurchaseState(.restoring, in: restoringStore)
        restoringTask.cancel()
        await restoringTask.value

        #expect(client.purchaseCallCount == 0)
        #expect(client.syncCallCount == 0)
    }

    @Test func productRetryCanRecoverFromAProductLoadFailure() async {
        let client = FakeFlowerShowStoreClient()
        client.product = nil
        let store = FlowerShowStore(
            client: client,
            launchOverrides: FlowerShowLaunchOverrides(
                access: .sample,
                productUnavailable: false,
                purchase: nil
            )
        )

        await store.retryProductLoad()
        #expect(store.productState == .unavailable)
        client.product = FlowerShowProductInfo(
            productID: FlowerShowAccessPolicy.productID,
            displayPrice: "£2.99"
        )
        await store.retryProductLoad()
        let expectedProduct = FlowerShowProductInfo(
            productID: FlowerShowAccessPolicy.productID,
            displayPrice: "£2.99"
        )
        #expect(store.productState == .available(expectedProduct))
    }
}
