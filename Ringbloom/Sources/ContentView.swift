import StoreKit
import SwiftUI
import UIKit

struct ContentView: View {
    private enum Screen {
        case home
        case tutorial
        case flowerShowRules
        case classBook
        case purchase(FlowerShowPurchaseContext)
        case game
    }

    @EnvironmentObject private var game: GameModel
    @EnvironmentObject private var flowerShowStore: FlowerShowStore
    @EnvironmentObject private var audio: AudioService
    @EnvironmentObject private var feedback: FeedbackService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("ringbloom.tutorialSeen") private var tutorialSeen = false
    @State private var screen: Screen = .home
    @State private var flowerShowRulesPresentation: FlowerShowRulesPresentation = .preClass
    @State private var flowerShowRulesReturnScreen: Screen = .home
    @State private var selectedFlowerShowClass = 1
    @State private var replacementClass: Int?
    @State private var replacementSavedContext: FlowerShowAttemptContext?
    @State private var showsFlowerShowRedesignNotice = false
    @State private var didPrepareLaunch = false

    var body: some View {
        NavigationStack {
            ZStack {
                RingbloomTheme.background
                    .ignoresSafeArea()

                AmbientPetals()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                VStack(spacing: 0) {
                    if let storeCaption {
                        StoreScreenshotCaption(text: storeCaption)
                    }

                    switch screen {
                    case .home:
                        HomeView(
                            bestScore: game.bestScore,
                            highestGarden: game.highestGarden,
                            bestStreak: game.globalBestStreak,
                            radiantGardens: game.radiantGardens.count,
                            hasActiveGarden: game.hasActiveGarden,
                            flowerShowQualified: game.flowerShowQualified,
                            flowerShowAccessState: flowerShowStore.accessState,
                            flowerShowClass: game.currentFlowerShowClass,
                            flowerShowCompleted: game.completedFlowerShowClasses.count,
                            flowerShowCompletedFree: game.completedFlowerShowClasses.filter {
                                FlowerShowAccessPolicy.isFreeClass($0)
                            }.count,
                            hasActiveFlowerShow: game.hasActiveFlowerShow,
                            savedFlowerShowAttempt: game.savedFlowerShowAttemptContext,
                            grandChampionAchieved: game.grandChampionAchieved,
                            play: beginPlay,
                            openFlowerShow: beginFlowerShow,
                            openPurchase: { presentPurchase(context: $0) },
                            openClassBook: {
                                withAnimation(.easeInOut(duration: 0.25)) { screen = .classBook }
                            },
                            showTutorial: { withAnimation(.easeInOut(duration: 0.25)) { screen = .tutorial } }
                        )
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .opacity.combined(with: .scale(scale: 0.98))
                        )
                    case .tutorial:
                        TutorialView(
                            begin: {
                                tutorialSeen = true
                                game.startGarden(game.highestGarden)
                                withAnimation(.easeInOut(duration: 0.25)) { screen = .game }
                            },
                            close: { withAnimation(.easeInOut(duration: 0.25)) { screen = .home } }
                        )
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .opacity.combined(with: .move(edge: .bottom))
                        )
                    case .flowerShowRules:
                        FlowerShowRulesView(
                            definition: .classNumber(
                                flowerShowRulesPresentation == .inGame
                                    ? game.flowerShowDefinition.number
                                    : selectedFlowerShowClass
                            ),
                            completedCount: game.completedFlowerShowClasses.count,
                            seenIntroductions: game.seenFlowerShowIntroductions,
                            presentation: flowerShowRulesPresentation,
                            begin: beginFromFlowerShowRules,
                            close: closeFlowerShowRules
                        )
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .opacity.combined(with: .move(edge: .bottom))
                        )
                    case .classBook:
                        FlowerShowClassBookView(
                            ratings: game.bestCampaignRatings,
                            nextCampaignClass: game.nextIncompleteCampaignClass,
                            savedAttempt: game.savedFlowerShowAttemptContext,
                            grandChampion: game.grandChampionAchieved,
                            perfectShow: game.perfectShowAchieved,
                            radiantCount: game.radiantClassCount,
                            accessState: flowerShowStore.accessState,
                            selectClass: requestClassBookStart,
                            purchase: { presentPurchase(context: .lockedClass($0)) },
                            close: { withAnimation(.easeInOut(duration: 0.25)) { screen = .home } }
                        )
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .trailing)))
                    case let .purchase(context):
                        FlowerShowPurchaseView(
                            context: context,
                            targetIsPlayable: context.targetClass.map(game.flowerShowProgressionAllows) ?? false,
                            close: { closePurchase(context: context) },
                            goHome: goHome,
                            continueAfterPurchase: { continueAfterPurchase(context: context) }
                        )
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                    case .game:
                        GameScreen(
                            showHome: { withAnimation(.easeInOut(duration: 0.25)) { screen = .home } },
                            showFlowerShowRules: {
                                flowerShowRulesPresentation = .inGame
                                withAnimation(.easeInOut(duration: 0.25)) { screen = .flowerShowRules }
                            },
                            showNextFlowerShowRules: {
                                selectedFlowerShowClass = game.currentFlowerShowClass
                                flowerShowRulesPresentation = .preClass
                                flowerShowRulesReturnScreen = .home
                                withAnimation(.easeInOut(duration: 0.25)) { screen = .flowerShowRules }
                            },
                            openFlowerShowPurchase: { presentPurchase(context: $0) },
                            showClassBook: {
                                game.dismissPendingFlowerShowResult()
                                withAnimation(.easeInOut(duration: 0.25)) { screen = .classBook }
                            }
                        )
                        .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(RingbloomTheme.saffron)
        .onAppear(perform: prepareLaunchMode)
        .alert(
            replacementAlertTitle,
            isPresented: Binding(
                get: { replacementClass != nil },
                set: {
                    if $0 == false {
                        replacementClass = nil
                        replacementSavedContext = nil
                    }
                }
            )
        ) {
            Button(keepSavedAttemptTitle, role: .cancel) {
                replacementClass = nil
                replacementSavedContext = nil
            }
            Button(startReplacementTitle, role: .destructive) {
                guard let replacementClass else { return }
                selectedFlowerShowClass = replacementClass
                self.replacementClass = nil
                replacementSavedContext = nil
                flowerShowRulesPresentation = .preClass
                flowerShowRulesReturnScreen = .classBook
                withAnimation(.easeInOut(duration: 0.25)) { screen = .flowerShowRules }
            }
        } message: {
            if let saved = replacementSavedContext {
                Text("Progress in the saved Class \(saved.classNumber) attempt will be lost.")
            }
        }
        .alert("FLOWER SHOW REDESIGNED", isPresented: $showsFlowerShowRedesignNotice) {
            Button("CONTINUE") {
                game.dismissFlowerShowRedesignNotice()
                beginFlowerShow()
            }
        } message: {
            Text("Your Garden progress is unchanged. Flower Show now has authored Classes, mastery ratings, replay and the Champion Circuit.")
        }
    }

    private func beginPlay() {
        if game.hasActiveGarden {
            game.resumeGarden()
            withAnimation(.easeInOut(duration: 0.25)) { screen = .game }
        } else if tutorialSeen || ProcessInfo.processInfo.arguments.contains("--skip-tutorial") {
            game.startGarden(game.highestGarden)
            withAnimation(.easeInOut(duration: 0.25)) { screen = .game }
        } else {
            withAnimation(.easeInOut(duration: 0.25)) { screen = .tutorial }
        }
    }

    private func beginFlowerShow() {
        guard game.flowerShowQualified else { return }
        if game.pendingFlowerShowNoticeVersion != nil {
            showsFlowerShowRedesignNotice = true
            return
        }
        if game.hasActiveFlowerShow {
            switch game.resumeFlowerShow() {
            case .started:
                withAnimation(.easeInOut(duration: 0.25)) { screen = .game }
            case .purchaseRequired:
                presentPurchase(context: .lockedClass(game.currentFlowerShowClass))
            case .accessChecking, .qualificationRequired, .progressionLocked:
                break
            }
        } else {
            if case .purchaseRequired = game.flowerShowAccessAction(for: game.currentFlowerShowClass) {
                presentPurchase(context: .afterClassFive)
                return
            }
            if case .waitForAccess = game.flowerShowAccessAction(for: game.currentFlowerShowClass) {
                return
            }
            selectedFlowerShowClass = game.currentFlowerShowClass
            flowerShowRulesPresentation = .preClass
            flowerShowRulesReturnScreen = .home
            withAnimation(.easeInOut(duration: 0.25)) { screen = .flowerShowRules }
        }
    }

    private func beginFromFlowerShowRules() {
        let result: FlowerShowStartResult
        if flowerShowRulesPresentation == .preClass {
            result = game.startFlowerShowClass(selectedFlowerShowClass)
        } else {
            result = game.resumeFlowerShow()
        }
        switch result {
        case .started:
            withAnimation(.easeInOut(duration: 0.25)) { screen = .game }
        case .purchaseRequired:
            presentPurchase(context: .lockedClass(selectedFlowerShowClass))
        case .qualificationRequired, .progressionLocked, .accessChecking:
            break
        }
    }

    private func requestClassBookStart(_ classNumber: Int) {
        switch game.flowerShowAccessAction(for: classNumber) {
        case .purchaseRequired:
            presentPurchase(context: .lockedClass(classNumber))
            return
        case .waitForAccess, .qualificationRequired, .progressionLocked:
            return
        case .play:
            break
        }
        if let saved = game.savedFlowerShowAttemptContext,
           saved.classNumber == classNumber
        {
            if game.resumeFlowerShow() == .started {
                withAnimation(.easeInOut(duration: 0.25)) { screen = .game }
            }
            return
        }
        if let saved = game.savedFlowerShowAttemptWouldBeReplaced(by: classNumber) {
            replacementSavedContext = saved
            replacementClass = classNumber
            return
        }
        selectedFlowerShowClass = classNumber
        flowerShowRulesPresentation = .preClass
        flowerShowRulesReturnScreen = .classBook
        withAnimation(.easeInOut(duration: 0.25)) { screen = .flowerShowRules }
    }

    private var replacementAlertTitle: String {
        guard let saved = replacementSavedContext else { return "Replace saved attempt?" }
        return "Replace saved Class \(saved.classNumber) attempt?"
    }

    private var keepSavedAttemptTitle: String {
        guard let saved = replacementSavedContext else { return "KEEP SAVED CLASS" }
        return "KEEP CLASS \(saved.classNumber)"
    }

    private var startReplacementTitle: String {
        "START CLASS \(replacementClass ?? selectedFlowerShowClass)"
    }

    private func closeFlowerShowRules() {
        if flowerShowRulesPresentation == .inGame {
            if game.resumeFlowerShow() == .started {
                withAnimation(.easeInOut(duration: 0.25)) { screen = .game }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.25)) { screen = flowerShowRulesReturnScreen }
        }
    }

    private func presentPurchase(context: FlowerShowPurchaseContext) {
        withAnimation(.easeInOut(duration: 0.25)) { screen = .purchase(context) }
    }

    private func closePurchase(context: FlowerShowPurchaseContext) {
        let destination: Screen = switch context.origin {
        case .lockedClass: .classBook
        case .afterClassFive, .home: .home
        }
        withAnimation(.easeInOut(duration: 0.25)) { screen = destination }
    }

    private func goHome() {
        withAnimation(.easeInOut(duration: 0.25)) { screen = .home }
    }

    private func continueAfterPurchase(context: FlowerShowPurchaseContext) {
        guard let targetClass = context.targetClass else {
            goHome()
            return
        }
        guard game.flowerShowProgressionAllows(targetClass) else {
            withAnimation(.easeInOut(duration: 0.25)) { screen = .classBook }
            return
        }
        selectedFlowerShowClass = targetClass
        flowerShowRulesPresentation = .preClass
        flowerShowRulesReturnScreen = context.origin == .lockedClass ? .classBook : .home
        withAnimation(.easeInOut(duration: 0.25)) { screen = .flowerShowRules }
    }

    private func prepareLaunchMode() {
        guard !didPrepareLaunch else { return }
        didPrepareLaunch = true

        let arguments = ProcessInfo.processInfo.arguments.map { $0.lowercased() }
        guard arguments.contains(where: { $0.hasPrefix("--screenshot-") }) else { return }

        if arguments.contains("--screenshot-champion-home") {
            screen = .home
            return
        }

        if arguments.contains("--screenshot-review-timing") {
            game.startGarden(2)
            screen = .game
            while game.phase == .playing, let move = game.suggestedMove {
                game.select(move.ring)
                _ = game.rotate(move.direction)
            }
            return
        }

        if arguments.contains("--screenshot-flower-show-menu") {
            screen = .home
            return
        }
        if arguments.contains("--screenshot-flower-show-purchase") {
            let target = arguments.lazy.compactMap { argument -> Int? in
                guard argument.hasPrefix("--flower-show-purchase-target=") else { return nil }
                return Int(argument.dropFirst("--flower-show-purchase-target=".count))
            }.first
            screen = .purchase(target.map(FlowerShowPurchaseContext.lockedClass) ?? .afterClassFive)
            return
        }
        if arguments.contains("--screenshot-flower-show-class-book") {
            screen = .classBook
            return
        }
        if arguments.contains("--flower-show-premium-retry-fixture") {
            _ = game.preparePremiumFlowerShowRetryFixture(
                classNumber: game.currentFlowerShowClass
            )
            screen = .game
            return
        }
        if arguments.contains("--screenshot-flower-show-rules") {
            selectedFlowerShowClass = game.currentFlowerShowClass
            flowerShowRulesPresentation = .preClass
            flowerShowRulesReturnScreen = .home
            screen = .flowerShowRules
            return
        }
        if arguments.contains(where: { $0.hasPrefix("--screenshot-flower-show") }) {
            screen = .game

            if arguments.contains("--screenshot-flower-show-win") {
                _ = game.prepareFlowerShowWinFixture(
                    classNumber: game.currentFlowerShowClass,
                    asReplay: arguments.contains("--flower-show-replay-result")
                )
                return
            }

            game.startFlowerShowClass(game.currentFlowerShowClass)
            if arguments.contains("--screenshot-bindweed-spread") {
                for _ in 0 ..< FlowerShowClassDefinition.bindweedSpreadInterval {
                    let nonClearingMove = Ring.allCases
                        .flatMap { ring in
                            RotationDirection.allCases.map { GameMove(ring: ring, direction: $0) }
                        }
                        .filter { move in
                            game.board.bloomSpokes(after: move).contains(where: game.infectedSpokes.contains) == false
                        }
                        .min { first, second in
                            game.board.bloomSpokes(after: first).count < game.board.bloomSpokes(after: second).count
                        }
                    guard let nonClearingMove else { break }
                    game.select(nonClearingMove.ring)
                    _ = game.rotate(nonClearingMove.direction)
                }
            } else if arguments.contains("--screenshot-flower-show-loss") {
                var safety = 0
                while game.phase == .playing, safety < 24 {
                    let quietMove = Ring.allCases
                        .flatMap { ring in
                            RotationDirection.allCases.map { GameMove(ring: ring, direction: $0) }
                        }
                        .first { game.board.rotated($0.ring, direction: $0.direction).bloomSpokes.isEmpty }
                    guard let quietMove else { break }
                    game.select(quietMove.ring)
                    _ = game.rotate(quietMove.direction)
                    safety += 1
                }
            }
            return
        }

        if arguments.contains("--screenshot-menu") {
            screen = .home
            return
        }

        game.startGarden(1)
        screen = .game

        if arguments.contains("--screenshot-combo") {
            for _ in 0 ..< 2 {
                guard game.phase == .playing, let move = game.suggestedMove else { break }
                game.select(move.ring)
                _ = game.rotate(move.direction)
            }
        } else if arguments.contains("--screenshot-win") {
            var safety = 0
            while game.phase == .playing, safety < 20, let move = game.suggestedMove {
                game.select(move.ring)
                _ = game.rotate(move.direction)
                safety += 1
            }
        }
    }

    private var storeCaption: String? {
        let arguments = ProcessInfo.processInfo.arguments.map { $0.lowercased() }
        if arguments.contains("--screenshot-game") {
            return "ROTATE RINGS. BLOOM TRIOS."
        }
        if arguments.contains("--screenshot-hint") {
            return "SIX CHOICES. ONE SMART MOVE."
        }
        if arguments.contains("--screenshot-combo") {
            return "CHAIN BLOOMS. MULTIPLY SCORE."
        }
        if arguments.contains("--screenshot-win") {
            return "BEAT THE MOVE BUDGET."
        }
        if arguments.contains("--screenshot-menu") {
            return "PLAY GARDEN FREE. TRY THE FIRST FIVE CLASSES."
        }
        return nil
    }
}

private struct StoreScreenshotCaption: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.title3, design: .rounded, weight: .bold))
            .tracking(1.2)
            .multilineTextAlignment(.center)
            .foregroundStyle(RingbloomTheme.ivory)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(RingbloomTheme.ink.opacity(0.92))
            .accessibilityHidden(true)
    }
}

private struct HomeView: View {
    let bestScore: Int
    let highestGarden: Int
    let bestStreak: Int
    let radiantGardens: Int
    let hasActiveGarden: Bool
    let flowerShowQualified: Bool
    let flowerShowAccessState: FlowerShowAccessState
    let flowerShowClass: Int
    let flowerShowCompleted: Int
    let flowerShowCompletedFree: Int
    let hasActiveFlowerShow: Bool
    let savedFlowerShowAttempt: FlowerShowAttemptContext?
    let grandChampionAchieved: Bool
    let play: () -> Void
    let openFlowerShow: () -> Void
    let openPurchase: (FlowerShowPurchaseContext) -> Void
    let openClassBook: () -> Void
    let showTutorial: () -> Void

    @EnvironmentObject private var audio: AudioService
    @EnvironmentObject private var feedback: FeedbackService
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GeometryReader { proxy in
            let pairedLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 12))
                : AnyLayout(HStackLayout(spacing: 12))
            let utilityLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 8))
                : AnyLayout(HStackLayout(spacing: 8))

            ScrollView {
                VStack(spacing: 12) {
                    Spacer(minLength: 12)

                    BloomMark()
                        .frame(width: 96, height: 96)
                        .accessibilityHidden(true)

                    VStack(spacing: 8) {
                        Text("RINGBLOOM")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .tracking(1.5)
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                            .foregroundStyle(RingbloomTheme.ivory)
                            .accessibilityAddTraits(.isHeader)

                        Text("TURN · ALIGN · BLOOM")
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                            .tracking(3)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(RingbloomTheme.muted)
                    }

                    pairedLayout {
                        HomeStat(title: "BEST", value: bestScore.formatted(.number.grouping(.never)), symbol: "sparkles")
                        HomeStat(title: "GARDEN", value: highestGarden.formatted(.number.grouping(.never)), symbol: "leaf.fill")
                    }
                    .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        ModeCard(
                            title: "GARDEN",
                            subtitle: "The original calm, endless game.",
                            detail: hasActiveGarden
                                ? "Garden \(highestGarden) is saved exactly where you left it."
                                : nil,
                            progress: nil,
                            actionTitle: hasActiveGarden
                                ? "RESUME GARDEN \(highestGarden)"
                                : "PLAY GARDEN \(highestGarden)",
                            actionSymbol: hasActiveGarden ? "arrow.clockwise" : "play.fill",
                            prominent: true,
                            locked: false,
                            identifier: "playButton",
                            action: play
                        )

                        ModeCard(
                            title: grandChampionAchieved ? "GRAND CHAMPION" : "FLOWER SHOW",
                            subtitle: "Judged puzzle Classes with special rules.",
                            detail: flowerShowDetail,
                            progress: flowerShowProgress,
                            actionTitle: flowerShowActionTitle,
                            actionSymbol: flowerShowActionSymbol,
                            prominent: false,
                            locked: flowerShowQualified == false || isAccessChecking,
                            identifier: "flowerShowButton",
                            action: flowerShowQualified
                                ? (flowerShowAccessState == .sample && flowerShowCompletedInFreeSampler >= 5
                                    ? { openPurchase(.home) }
                                    : openFlowerShow)
                                : {}
                        )

                        if flowerShowQualified {
                            Button(action: openClassBook) {
                                Label("CLASS BOOK", systemImage: "books.vertical.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(RingbloomButtonStyle())
                            .accessibilityIdentifier("classBookButton")
                        }
                    }
                    .padding(.horizontal, 20)

                    utilityLayout {
                        HomeUtilityButton(
                            title: "How to Play",
                            symbol: "questionmark.circle",
                            identifier: "howToPlayButton",
                            action: showTutorial
                        )
                        SettingButton(
                            title: "Sound",
                            enabled: audio.isSoundEnabled,
                            enabledSymbol: "speaker.wave.2.fill",
                            disabledSymbol: "speaker.slash.fill",
                            identifier: "soundToggle",
                            action: { _ = audio.toggleSound() }
                        )
                        SettingButton(
                            title: "Haptics",
                            enabled: feedback.isHapticsEnabled,
                            enabledSymbol: "waveform.path",
                            disabledSymbol: "waveform.path.badge.minus",
                            identifier: "hapticsToggle",
                            action: { _ = feedback.toggleHaptics() }
                        )
                    }
                    .padding(.horizontal, 20)

                    if bestStreak > 0 || radiantGardens > 0 {
                        Text("Best chain \(bestStreak) · Radiant clears \(radiantGardens)")
                            .font(.system(.footnote, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(RingbloomTheme.muted)
                    }

                    Spacer(minLength: 8)
                }
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var flowerShowDetail: String {
        guard flowerShowQualified else { return "Win your first Garden to qualify." }
        if isEntitlementChecking { return "Checking your Flower Show access…" }
        let freeCompleted = min(5, flowerShowCompletedInFreeSampler)
        if flowerShowAccessState == .sample, freeCompleted >= 5 {
            return "Classes 1–5 complete. Unlock Class 6 and beyond."
        }
        if flowerShowAccessState == .sample {
            return "Classes 1–5 are free.\n\(freeCompleted)/5 complete"
        }
        if grandChampionAchieved {
            return "Champion Circuit · Class \(flowerShowClass)"
        }
        return "Class \(flowerShowClass) of 30 · \(FlowerShowClassDefinition.classNumber(flowerShowClass).stageTitle)\n\(flowerShowCompleted)/30 complete"
    }

    private var flowerShowProgress: ModeCardProgress? {
        ModeCardProgress.flowerShow(
            highestGarden: highestGarden,
            qualified: flowerShowQualified,
            accessState: flowerShowAccessState,
            completedFreeClasses: flowerShowCompletedInFreeSampler,
            completedCampaignClasses: flowerShowCompleted
        )
    }

    private var flowerShowCompletedInFreeSampler: Int {
        min(5, flowerShowCompletedFree)
    }

    private var isAccessChecking: Bool {
        isEntitlementChecking && flowerShowCompletedInFreeSampler >= 5
    }

    private var isEntitlementChecking: Bool {
        if case .checking = flowerShowAccessState { return flowerShowQualified }
        return false
    }

    private var flowerShowActionTitle: String {
        guard flowerShowQualified else { return "LOCKED" }
        if isAccessChecking { return "CHECKING…" }
        if flowerShowAccessState == .sample,
           flowerShowCompletedInFreeSampler >= 5
        {
            return "UNLOCK FULL SHOW"
        }
        if hasActiveFlowerShow, let savedFlowerShowAttempt {
            return switch savedFlowerShowAttempt.kind {
            case .campaign:
                "RESUME CLASS \(savedFlowerShowAttempt.classNumber)"
            case .replay:
                "RESUME REPLAY · CLASS \(savedFlowerShowAttempt.classNumber)"
            case .circuit:
                "RESUME CIRCUIT · CLASS \(savedFlowerShowAttempt.classNumber)"
            }
        }
        return flowerShowClass > FlowerShowClassDefinition.classCount ? "CONTINUE CIRCUIT" : "CONTINUE"
    }

    private var flowerShowActionSymbol: String {
        if flowerShowQualified == false || isAccessChecking { return "lock.fill" }
        if flowerShowAccessState == .sample, flowerShowCompletedInFreeSampler >= 5 {
            return "lock.open.fill"
        }
        return hasActiveFlowerShow ? "arrow.clockwise" : "medal.fill"
    }
}

private struct GameScreen: View {
    let showHome: () -> Void
    let showFlowerShowRules: () -> Void
    let showNextFlowerShowRules: () -> Void
    let openFlowerShowPurchase: (FlowerShowPurchaseContext) -> Void
    let showClassBook: () -> Void

    @EnvironmentObject private var game: GameModel
    @EnvironmentObject private var flowerShowStore: FlowerShowStore
    @EnvironmentObject private var audio: AudioService
    @EnvironmentObject private var feedback: FeedbackService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.requestReview) private var requestReview
    @AppStorage("ringbloom.guidedFirstBloomSeen") private var guidedFirstBloomSeen = false
    @State private var bloomSpokes: [Int] = []
    @State private var bloomToken = 0
    @State private var statusText = "Choose a ring, then turn it"
    @State private var displayBoard: GameBoard?
    @State private var rotatingRing: Ring?
    @State private var rotationDegrees = 0.0
    @State private var hintMove: GameMove?
    @State private var guidedMove: GameMove?
    @State private var isResolvingTurn = false
    @State private var isPaused = false
    @State private var quietTurns = 0
    @State private var resolutionTask: Task<Void, Never>?
    @State private var hintRequestTask: Task<Void, Never>?
    @State private var reviewRequestTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { proxy in
            let boardSide = max(0, min(proxy.size.width - 32, proxy.size.height * 0.49))

            ZStack {
                gameplayContent(boardSide: boardSide, minHeight: proxy.size.height)
                    .accessibilityHidden(game.phase != .playing || isPaused)
                    .allowsHitTesting(game.phase == .playing && !isPaused)

                if isPaused {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .transition(.opacity)

                    ScrollView {
                        VStack {
                            PauseCard(
                                garden: game.garden,
                                mode: game.activeMode,
                                flowerShowClass: game.flowerShowDefinition.number,
                                resume: resume,
                                restart: restartFromPause,
                                home: leaveForHome
                            )
                            .padding(.horizontal, 32)
                            .transition(
                                reduceMotion
                                    ? .opacity
                                    : .scale(scale: 0.9).combined(with: .opacity)
                            )
                        }
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                    }
                    .scrollIndicators(.hidden)
                } else if game.phase != .playing {
                    Color.black.opacity(0.46)
                        .ignoresSafeArea()
                        .transition(.opacity)

                    ScrollView {
                        VStack {
                            Group {
                                if game.activeMode == .flowerShow {
                                    FlowerShowResultView(
                                        phase: game.phase,
                                        summary: game.pendingFlowerShowResult,
                                        classNumber: game.flowerShowDefinition.number,
                                        remainingWork: game.remainingFlowerShowWork,
                                        canUndo: game.canUndo,
                                        undo: undo,
                                        retry: retry,
                                        accessChecking: isResultAccessChecking,
                                        retryAccessCheck: retryResultAccessCheck,
                                        continueProgression: nextExperience,
                                        openClassBook: showClassBook,
                                        home: showHome
                                    )
                                } else {
                                    OutcomeCard(
                                        phase: game.phase,
                                        score: game.score,
                                        garden: game.garden,
                                        mode: game.activeMode,
                                        flowerShowClass: game.flowerShowDefinition.number,
                                        bestStreak: game.bestStreak,
                                        completionBonus: game.completionBonus,
                                        rating: game.gardenRating,
                                        canUndo: game.canUndo,
                                        undo: undo,
                                        retry: retry,
                                        next: nextExperience,
                                        home: showHome
                                    )
                                }
                            }
                            .padding(.horizontal, 32)
                            .transition(reduceMotion ? .opacity : .scale(scale: 0.88).combined(with: .opacity))
                        }
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .animation(.easeInOut(duration: reduceMotion ? 0.15 : 0.3), value: game.phase)
            .animation(.easeInOut(duration: reduceMotion ? 0.15 : 0.25), value: isPaused)
        }
        .onAppear(perform: prepareGameplay)
        .onDisappear {
            resolutionTask?.cancel()
            resolutionTask = nil
            hintRequestTask?.cancel()
            hintRequestTask = nil
            reviewRequestTask?.cancel()
            reviewRequestTask = nil
        }
        .onChange(of: game.reviewRequestTrigger) { _, trigger in
            scheduleReviewRequest(for: trigger)
        }
    }

    private func gameplayContent(boardSide: CGFloat, minHeight: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                gameToolbar
                if game.activeMode == .flowerShow {
                    flowerShowCompactHeader
                    if let attention = flowerShowAttention ?? FlowerShowAttentionMessage.current(
                        definition: game.flowerShowDefinition,
                        blooms: game.blooms,
                        infectedSpokes: game.infectedSpokes,
                        bindweedSpreadCountdown: game.bindweedSpreadCountdown,
                        turnNumber: game.lastTurn?.turnNumber ?? 0
                    ) {
                        FlowerShowAttentionBanner(message: attention)
                            .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                    }

                    FlowerShowObjectiveProgress(
                        definition: game.flowerShowDefinition,
                        harmonyRings: game.harmonyRings,
                        streak: game.streak,
                        bestStreak: game.bestStreak,
                        harmonyCredits: game.harmonyCredits,
                        infectedSpokes: game.infectedSpokes,
                        bindweedSpreadCountdown: game.bindweedSpreadCountdown,
                        twinBloomTurns: game.twinBloomTurns,
                        bouquetKinds: game.bouquetKinds,
                        judgesOrderIndex: game.judgesOrderIndex
                    )
                } else {
                    stats
                    bloomProgress
                }

                GameBoardView(
                    board: displayBoard ?? game.board,
                    selectedRing: game.selectedRing,
                    bloomSpokes: bloomSpokes,
                    bloomToken: bloomToken,
                    rotatingRing: rotatingRing,
                    rotationDegrees: rotationDegrees,
                    hintMove: hintMove,
                    infectedSpokes: game.infectedSpokes,
                    bindweedSpreadPreview: game.bindweedSpreadPreview,
                    interactionEnabled: !isResolvingTurn && !isPaused && game.phase == .playing,
                    onSelect: select,
                    onRotate: rotate
                )
                .frame(width: boardSide, height: boardSide)
                .padding(.vertical, 4)

                Text(statusText)
                    .font(.system(.footnote, design: .rounded, weight: .medium))
                    .foregroundStyle(RingbloomTheme.muted)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 20)
                    .accessibilityIdentifier("statusLabel")

                ringSelector
                rotationControls
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .top)
        }
        .scrollIndicators(.hidden)
    }

    private var gameToolbar: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        pauseButton
                        gameContext
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    gameActions
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack {
                    pauseButton
                    Spacer()
                    gameContext
                    Spacer()
                    gameActions
                }
            }
        }
        .frame(minHeight: 48)
    }

    private var pauseButton: some View {
        Button(action: pause) {
            Image(systemName: "pause.fill")
                .font(.system(size: 19, weight: .semibold))
                .frame(width: 44, height: 44)
        }
        .foregroundStyle(RingbloomTheme.ivory)
        .background(Circle().fill(RingbloomTheme.inkLifted))
        .disabled(isResolvingTurn)
        .accessibilityLabel(game.activeMode == .garden ? "Pause garden" : "Pause Flower Show class")
        .accessibilityIdentifier("homeButton")
    }

    private var gameContext: some View {
        VStack(spacing: 2) {
            Text(game.activeMode == .garden ? "GARDEN" : "FLOWER SHOW")
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(RingbloomTheme.muted)
            Text(
                game.activeMode == .garden
                    ? game.garden.formatted(.number.grouping(.never))
                    : flowerShowContextLabel
            )
            .font(.system(.title3, design: .rounded, weight: .semibold))
            .foregroundStyle(RingbloomTheme.ivory)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            game.activeMode == .garden
                ? "Garden \(game.garden)"
                : (game.flowerShowDefinition.number > FlowerShowClassDefinition.classCount
                    ? "Champion Circuit, Class \(game.flowerShowDefinition.number)"
                    : "Flower Show, Class \(game.flowerShowDefinition.number)")
        )
    }

    private var gameActions: some View {
        HStack(spacing: 8) {
            if game.activeMode == .flowerShow {
                Button(action: showFlowerShowRules) {
                    VStack(spacing: 1) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("RULES")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                    }
                    .frame(width: 44, height: 44)
                }
                .foregroundStyle(RingbloomTheme.ivory)
                .background(Circle().fill(RingbloomTheme.inkLifted))
                .disabled(isResolvingTurn)
                .accessibilityLabel("Show class rules")
                .accessibilityIdentifier("flowerShowRulesButton")

                Button(action: undo) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 19, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .foregroundStyle(game.canUndo ? RingbloomTheme.ivory : RingbloomTheme.muted)
                .background(Circle().fill(RingbloomTheme.inkLifted))
                .disabled(isResolvingTurn || game.canUndo == false || game.canPlayCurrentFlowerShow == false)
                .accessibilityLabel("Undo last turn")
                .accessibilityValue(game.canUndo ? "Available" : "Used or not yet available")
                .accessibilityIdentifier("flowerShowUndoButton")
            }

            Button(action: requestHint) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: hintMove == nil ? "lightbulb" : "lightbulb.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .frame(width: 44, height: 44)

                    Text(game.hintsRemaining.formatted(.number.grouping(.never)))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(RingbloomTheme.ink)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Circle().fill(RingbloomTheme.saffron))
                }
            }
            .foregroundStyle(hintMove == nil ? RingbloomTheme.ivory : RingbloomTheme.saffron)
            .background(Circle().fill(RingbloomTheme.inkLifted))
            .disabled(
                isResolvingTurn
                    || game.hintsRemaining == 0
                    || (game.activeMode == .flowerShow && game.canPlayCurrentFlowerShow == false)
            )
            .accessibilityLabel("Show one move")
            .accessibilityValue(
                game.hintsRemaining == 1
                    ? "1 hint remaining"
                    : "\(game.hintsRemaining) hints remaining"
            )
            .accessibilityIdentifier("hintButton")

            Button {
                _ = audio.toggleSound()
            } label: {
                Image(systemName: audio.isSoundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .foregroundStyle(RingbloomTheme.ivory)
            .background(Circle().fill(RingbloomTheme.inkLifted))
            .accessibilityLabel(audio.isSoundEnabled ? "Sound on" : "Sound off")
            .accessibilityIdentifier("gameSoundToggle")
        }
    }

    private var stats: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))

        return layout {
            GameStat(title: "SCORE", value: game.score.formatted(.number.grouping(.never)), identifier: "scoreLabel")
            GameStat(title: "MOVES", value: game.movesRemaining.formatted(.number.grouping(.never)), identifier: "movesLabel")
            GameStat(title: "CHAIN", value: game.streak.formatted(.number.grouping(.never)), identifier: "streakLabel")
        }
    }

    private var flowerShowCompactHeader: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 2))
            : AnyLayout(HStackLayout(spacing: 6))

        return layout {
            Text("\(min(game.blooms, game.targetBlooms))/\(game.targetBlooms) blooms")
            if dynamicTypeSize.isAccessibilitySize == false {
                Text("·")
                    .accessibilityHidden(true)
            }
            Text("\(game.movesRemaining) moves left")
            if dynamicTypeSize.isAccessibilitySize == false {
                Text("·")
                    .accessibilityHidden(true)
            }
            Text(ratingAvailabilityText)
                .foregroundStyle(
                    game.bestAvailableFlowerShowRating == .radiant
                        ? RingbloomTheme.saffron
                        : RingbloomTheme.mint
                )
        }
        .font(.system(.caption, design: .rounded, weight: .bold))
        .multilineTextAlignment(.center)
        .foregroundStyle(RingbloomTheme.ivory)
        .padding(.horizontal, 12)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 8 : 0)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(RingbloomTheme.inkLifted, in: RoundedRectangle(cornerRadius: 13))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(game.blooms) of \(game.targetBlooms) blooms, \(game.movesRemaining) moves left, \(ratingAvailabilityText)"
        )
        .accessibilityIdentifier("flowerShowCompactHeader")
    }

    private var ratingAvailabilityText: String {
        switch game.bestAvailableFlowerShowRating {
        case .radiant: "Radiant possible"
        case .flourishing: "Best: Flourishing"
        case .seedling: "Best: Seedling"
        }
    }

    private var flowerShowAttention: FlowerShowAttentionMessage? {
        guard game.blooms >= game.targetBlooms,
              game.objectivesComplete == false,
              game.remainingFlowerShowWork.isEmpty == false
        else { return nil }
        return FlowerShowAttentionMessage(
            title: "BLOOM TARGET MET",
            detail: "Still needed: \(naturalList(game.remainingFlowerShowWork)).",
            symbol: "checkmark.circle.fill"
        )
    }

    private func naturalList(_ values: [String]) -> String {
        guard values.count > 1 else { return values.first ?? "" }
        return values.dropLast().joined(separator: ", ") + " and " + values.last!
    }

    private var bloomProgress: some View {
        VStack(spacing: 6) {
            HStack {
                Text("BLOOMS")
                Spacer()
                Text("\(min(game.blooms, game.targetBlooms)) / \(game.targetBlooms)")
            }
            .font(.system(.caption2, design: .rounded, weight: .semibold))
            .tracking(1.5)
            .foregroundStyle(RingbloomTheme.muted)

            GeometryReader { proxy in
                let fraction = min(1, CGFloat(game.blooms) / CGFloat(max(1, game.targetBlooms)))
                ZStack(alignment: .leading) {
                    Capsule().fill(RingbloomTheme.ivory.opacity(0.12))
                    Capsule()
                        .fill(LinearGradient(colors: [RingbloomTheme.mint, RingbloomTheme.saffron], startPoint: .leading, endPoint: .trailing))
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Bloom progress")
        .accessibilityValue(
            game.phase == .won
                ? "Complete, \(game.targetBlooms) of \(game.targetBlooms)"
                : "\(game.blooms) of \(game.targetBlooms)"
        )
        .accessibilityIdentifier("bloomProgress")
    }

    private var ringSelector: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))

        return layout {
            ForEach(Ring.allCases) { ring in
                Button {
                    select(ring)
                } label: {
                    VStack(spacing: 1) {
                        Text(ring.shortName)
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                            .tracking(1.2)
                        if game.activeMode == .flowerShow, game.nextJudgesOrderRing == ring {
                            Text("NEXT")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundStyle(RingbloomTheme.saffron)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(
                    RingChipStyle(
                        selected: game.selectedRing == ring,
                        hinted: hintMove?.ring == ring
                    )
                )
                .disabled(
                    isResolvingTurn
                        || (game.activeMode == .flowerShow && game.canPlayCurrentFlowerShow == false)
                )
                .accessibilityLabel("Select \(ring.displayName) ring")
                .accessibilityValue(
                    [
                        game.selectedRing == ring ? "Selected" : "Not selected",
                        hintMove?.ring == ring ? "Hinted move" : nil,
                        game.nextJudgesOrderRing == ring ? "Next for Judges' Order" : nil,
                    ]
                    .compactMap(\.self)
                    .joined(separator: ", ")
                )
                .accessibilityIdentifier(ringIdentifier(ring))
            }
        }
    }

    private var rotationControls: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))

        return layout {
            Button { rotate(.counterClockwise) } label: {
                Label("TURN LEFT", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(RingbloomButtonStyle())
            .overlay {
                if hintMove?.direction == .counterClockwise {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(RingbloomTheme.saffron, lineWidth: 3)
                        .shadow(color: RingbloomTheme.saffron.opacity(0.5), radius: 8)
                }
            }
            .accessibilityLabel("Rotate counter-clockwise")
            .accessibilityHint(
                hintMove?.direction == .counterClockwise
                    ? "Hinted move. Turns the selected \(game.selectedRing.displayName) ring one notch"
                    : "Turns the selected \(game.selectedRing.displayName) ring one notch"
            )
            .accessibilityIdentifier("rotateCounterClockwise")

            Button { rotate(.clockwise) } label: {
                Label("TURN RIGHT", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(RingbloomButtonStyle(prominent: true))
            .overlay {
                if hintMove?.direction == .clockwise {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(RingbloomTheme.ivory, lineWidth: 3)
                        .shadow(color: RingbloomTheme.saffron.opacity(0.62), radius: 10)
                }
            }
            .accessibilityLabel("Rotate clockwise")
            .accessibilityHint(
                hintMove?.direction == .clockwise
                    ? "Hinted move. Turns the selected \(game.selectedRing.displayName) ring one notch"
                    : "Turns the selected \(game.selectedRing.displayName) ring one notch"
            )
            .accessibilityIdentifier("rotateClockwise")
        }
        .disabled(
            game.phase != .playing
                || isResolvingTurn
                || isPaused
                || (game.activeMode == .flowerShow && game.canPlayCurrentFlowerShow == false)
        )
    }

    private func select(_ ring: Ring) {
        guard game.phase == .playing,
              !isResolvingTurn,
              !isPaused,
              game.canPlayCurrentFlowerShow
        else { return }
        let changed = game.selectedRing != ring
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            game.select(ring)
        }
        if changed {
            feedback.selectionChanged()
        }
        statusText = "\(ring.displayName) ring selected"
    }

    private func rotate(_ direction: RotationDirection) {
        guard game.phase == .playing,
              !isResolvingTurn,
              !isPaused,
              game.canPlayCurrentFlowerShow
        else { return }

        isResolvingTurn = true
        let move = GameMove(ring: game.selectedRing, direction: direction)
        resolutionTask = Task { @MainActor in
            await resolveRotation(move)
        }
    }

    private func retry() {
        if game.activeMode == .flowerShow,
           game.flowerShowAccessAction(for: game.currentFlowerShowClass) == .purchaseRequired
        {
            openFlowerShowPurchase(.lockedClass(game.currentFlowerShowClass))
            return
        }
        switch game.retry() {
        case .started:
            resetPresentation()
            statusText = game.activeMode == .garden ? "Same garden. New plan." : "Same class. New plan."
        case .purchaseRequired:
            openFlowerShowPurchase(.lockedClass(game.currentFlowerShowClass))
        case .qualificationRequired, .progressionLocked, .accessChecking:
            break
        }
    }

    private func nextExperience() {
        if game.activeMode == .garden {
            game.nextGarden()
            resetPresentation()
            statusText = "A new garden opens"
        } else {
            switch game.nextFlowerShowClass() {
            case .started:
                showNextFlowerShowRules()
            case .purchaseRequired:
                openFlowerShowPurchase(.afterClassFive)
            case .qualificationRequired, .progressionLocked, .accessChecking:
                break
            }
        }
    }

    private var isResultAccessChecking: Bool {
        guard game.activeMode == .flowerShow, game.phase == .won else { return false }
        return game.flowerShowAccessAction(for: game.currentFlowerShowClass) == .waitForAccess
    }

    private func retryResultAccessCheck() {
        Task { await flowerShowStore.retryAccessCheck() }
    }

    private func undo() {
        guard !isResolvingTurn, game.undoFlowerShowTurn() else { return }
        resetPresentation()
        statusText = "Last turn restored · Undo used"
        feedback.selectionChanged()
        UIAccessibility.post(
            notification: .announcement,
            argument: "Last turn restored. Undo used. The highest possible rating is now Flourishing."
        )
    }

    @MainActor
    private func resolveRotation(_ move: GameMove) async {
        let startingBoard = game.board
        let alignedBoard = startingBoard.rotated(move.ring, direction: move.direction)
        let wasGuidedMove = guidedMove == move
        let startingHarmonyRings = game.harmonyRings
        let startingInfectedSpokes = game.infectedSpokes
        let startingTwinBloomCompleted = game.twinBloomCompleted

        displayBoard = startingBoard
        hintMove = nil
        guidedMove = nil
        bloomSpokes = []
        statusText = "Turning the \(move.ring.displayName.lowercased()) ring"
        audio.playRotate()
        feedback.rotation()

        defer {
            rotatingRing = nil
            rotationDegrees = 0
            isResolvingTurn = false
            resolutionTask = nil

            if Task.isCancelled {
                displayBoard = game.board
                bloomSpokes = []
            }
        }

        if reduceMotion {
            displayBoard = alignedBoard
            guard await waitForPresentation(milliseconds: 100) else { return }
        } else {
            rotatingRing = move.ring
            withAnimation(.snappy(duration: 0.28, extraBounce: 0.08)) {
                rotationDegrees = move.direction == .clockwise ? 45 : -45
            }
            guard await waitForPresentation(milliseconds: 280) else { return }

            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                displayBoard = alignedBoard
                rotatingRing = nil
                rotationDegrees = 0
            }
        }

        let predictedBlooms = alignedBoard.bloomSpokes
        if !predictedBlooms.isEmpty {
            bloomSpokes = predictedBlooms
            bloomToken += 1
            statusText = predictedBlooms.count > 1 ? "A bloom combo is opening" : "A bloom is opening"
            audio.playBloom()
            feedback.bloom()
            guard await waitForPresentation(milliseconds: reduceMotion ? 180 : 460) else { return }
        }

        guard let result = game.rotate(move.direction) else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
            displayBoard = game.board
            bloomSpokes = []
        }

        if game.infectedSpokes.count > startingInfectedSpokes.count,
           result.phase == .playing
        {
            feedback.failure()
        }

        if result.bloomCount > 0 {
            quietTurns = 0
            statusText = flowerShowStatus(
                result,
                startingHarmonyRings: startingHarmonyRings,
                startingInfectedSpokes: startingInfectedSpokes,
                startingTwinBloomCompleted: startingTwinBloomCompleted
            ) ?? turnStatus(result)
            if !guidedFirstBloomSeen {
                guidedFirstBloomSeen = true
            }
        } else {
            quietTurns += 1
            if let flowerShowStatus = flowerShowStatus(
                result,
                startingHarmonyRings: startingHarmonyRings,
                startingInfectedSpokes: startingInfectedSpokes,
                startingTwinBloomCompleted: startingTwinBloomCompleted
            ) {
                statusText = flowerShowStatus
            } else if result.didReshuffle {
                statusText = "A fresh pattern unfurled"
            } else if quietTurns >= 2, game.hintsRemaining > 0 {
                statusText = "Two quiet turns — Hint can show one move"
            } else {
                statusText = "Keep weaving the rings"
            }

            if !guidedFirstBloomSeen,
               game.activeMode == .garden,
               game.garden == 1,
               game.phase == .playing
            {
                showFreeFirstBloomGuide()
            }
        }

        if wasGuidedMove, result.bloomCount == 0, game.phase == .playing {
            showFreeFirstBloomGuide()
        }

        announce(result)

        switch result.phase {
        case .won:
            audio.playWin()
            feedback.success()
        case .lost:
            audio.playLose()
            feedback.failure()
        case .playing:
            break
        }
    }

    private func requestHint() {
        guard !isResolvingTurn,
              !isPaused,
              game.phase == .playing,
              game.canPlayCurrentFlowerShow
        else { return }

        if let hintMove {
            statusText = hintText(hintMove)
            return
        }

        if game.activeMode == .flowerShow {
            guard hintRequestTask == nil, game.hintsRemaining > 0 else {
                statusText = "No hints left in this class"
                return
            }
            statusText = "Considering…"
            UIAccessibility.post(notification: .announcement, argument: statusText)
            hintRequestTask = Task { @MainActor in
                let result = await game.requestFlowerShowHint()
                guard Task.isCancelled == false else { return }
                switch result {
                case let .move(move, _):
                    hintMove = move
                    feedback.selectionChanged()
                    statusText = hintText(move)
                case .provenNoRoute:
                    statusText = game.canUndo
                        ? "No winning route remains. Undo the last turn or restart the Class."
                        : "No winning route remains. Restart the Class to try a new route."
                case .timedOut:
                    statusText = "Still considering. You can keep playing and try the Hint again."
                case .cancelled:
                    statusText = "The board changed before the Hint was ready."
                }
                UIAccessibility.post(notification: .announcement, argument: statusText)
                hintRequestTask = nil
            }
            return
        }

        guard let move = game.requestHint() else {
            statusText = "No hints left in this garden"
            UIAccessibility.post(notification: .announcement, argument: statusText)
            return
        }

        hintMove = move
        feedback.selectionChanged()
        statusText = hintText(move)
        UIAccessibility.post(notification: .announcement, argument: statusText)
    }

    private func showFreeFirstBloomGuide() {
        guard game.activeMode == .garden,
              game.launchMode == .production,
              let move = game.suggestedMove else { return }
        hintMove = move
        guidedMove = move
        let direction = move.direction == .clockwise ? "right" : "left"
        statusText = "First bloom: choose \(move.ring.displayName), then turn \(direction)"
    }

    private func hintText(_ move: GameMove) -> String {
        let direction = move.direction == .clockwise ? "right" : "left"
        return "Hint: choose \(move.ring.displayName), then turn \(direction)"
    }

    private func turnStatus(_ result: TurnResult) -> String {
        if result.combo > 1 {
            return "\(result.combo)× COMBO · CHAIN \(result.streak)  +\(result.points)"
        }
        if result.streak > 1 {
            return "BLOOM · CHAIN \(result.streak)  +\(result.points)"
        }
        return "BLOOM  +\(result.points)"
    }

    private func flowerShowStatus(
        _ result: TurnResult,
        startingHarmonyRings: Set<Ring>,
        startingInfectedSpokes: Set<Int>,
        startingTwinBloomCompleted: Bool
    ) -> String? {
        guard game.activeMode == .flowerShow,
              let transition = game.lastFlowerShowTransition
        else { return nil }
        var parts: [String] = []
        let definition = game.flowerShowDefinition

        let harmonyGain = transition.harmonyAfter[result.ring] - transition.harmonyBefore[result.ring]
        if harmonyGain > 0 {
            let required = definition.objectives.harmonyCreditsPerRing
            parts.append(
                transition.harmonyAfter[result.ring] >= required
                    ? "\(result.ring.displayName) Harmony complete"
                    : "\(result.ring.displayName) Harmony \(transition.harmonyAfter[result.ring]) of \(required)"
            )
        }
        if let required = definition.objectives.unbrokenChain {
            if transition.unbrokenAfter.best >= required,
               transition.unbrokenBefore.best < required
            {
                parts.append("Unbroken complete")
            } else if transition.unbrokenAfter.current != transition.unbrokenBefore.current {
                parts.append("Unbroken \(transition.unbrokenAfter.current) of \(required)")
            }
        }
        if transition.clearedBindweedSpokes.isEmpty == false {
            parts.append(
                transition.stateAfter.infectedSpokes.isEmpty
                    ? "All Bindweed cleared"
                    : "\(transition.clearedBindweedSpokes.count) tangled \(transition.clearedBindweedSpokes.count == 1 ? "spoke" : "spokes") cleared; \(transition.stateAfter.infectedSpokes.count) remain; countdown reset to 3"
            )
        }
        if let destination = transition.newlyInfectedSpoke {
            parts.append("Bindweed spread to \(clockPosition(destination)); \(transition.stateAfter.infectedSpokes.count) tangled spokes remain")
        }
        if transition.twinTurnsAfter > transition.twinTurnsBefore {
            parts.append("Twin Bloom \(transition.twinTurnsAfter) of \(definition.objectives.twinBloomTurns)")
        }
        let addedKinds = transition.bouquetAfter.subtracting(transition.bouquetBefore).kinds
        if addedKinds.isEmpty == false {
            parts.append(addedKinds.map { "\($0.displayName) added to Prize Bouquet" }.joined(separator: ", "))
        }
        if let matched = transition.matchedOrderRing {
            if let next = transition.nextOrderRing {
                parts.append("Judges' Order: \(matched.displayName) complete; \(next.displayName) next")
            } else {
                parts.append("Judges' Order complete")
            }
        }
        if game.blooms >= definition.targetBlooms, game.objectivesComplete == false {
            parts.append("Bloom target met; still needed: \(game.remainingFlowerShowWork.joined(separator: ", "))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func announce(_ result: TurnResult) {
        if game.activeMode == .flowerShow {
            let changed = flowerShowStatus(
                result,
                startingHarmonyRings: [],
                startingInfectedSpokes: [],
                startingTwinBloomCompleted: false
            )
            let base = result.bloomCount > 0
                ? "\(result.bloomCount) \(result.bloomCount == 1 ? "bloom" : "blooms")."
                : (result.didReshuffle ? "No bloom. The board reshuffled." : "No bloom.")
            let announcement = [base, changed, "\(game.movesRemaining) moves remaining."]
                .compactMap(\.self)
                .joined(separator: " ")
            UIAccessibility.post(notification: .announcement, argument: announcement)
            return
        }
        let announcement = if result.bloomCount > 0 {
            "\(turnStatus(result)). \(game.blooms) of \(game.targetBlooms) blooms. \(game.movesRemaining) moves remaining."
        } else if result.didReshuffle {
            "No bloom. The board reshuffled. \(game.movesRemaining) moves remaining."
        } else {
            "No bloom. \(game.movesRemaining) moves remaining."
        }
        let objectiveAnnouncement: String
        if game.activeMode == .flowerShow {
            var parts: [String] = []
            if game.flowerShowDefinition.objectives.requiresHarmony {
                parts.append("Harmony \(game.harmonyRings.count) of 3 rings")
            }
            if let requiredChain = game.flowerShowDefinition.objectives.requiredUnbrokenChain {
                parts.append("best chain \(min(game.bestStreak, requiredChain)) of \(requiredChain)")
            }
            if game.flowerShowDefinition.objectives.startingBindweedSpokes.isEmpty == false {
                if game.infectedSpokes.isEmpty {
                    parts.append("bindweed cleared")
                } else {
                    parts.append(
                        "\(game.infectedSpokes.count) tangled stems, spreads in \(game.bindweedSpreadCountdown ?? 3) turns"
                    )
                }
            }
            if game.flowerShowDefinition.objectives.requiresTwinBloom {
                parts.append(game.twinBloomCompleted ? "Twin Bloom complete" : "Twin Bloom still needed")
            }
            objectiveAnnouncement = parts.isEmpty ? "" : " " + parts.joined(separator: ". ") + "."
        } else {
            objectiveAnnouncement = ""
        }
        UIAccessibility.post(notification: .announcement, argument: announcement + objectiveAnnouncement)
    }

    private func clockPosition(_ spoke: Int) -> String {
        ["12 o'clock", "1:30", "3 o'clock", "4:30", "6 o'clock", "7:30", "9 o'clock", "10:30"][
            GameBoard.normalized(spoke)
        ]
    }

    private func pause() {
        guard !isResolvingTurn, game.phase == .playing else { return }
        audio.stopAll()
        isPaused = true
    }

    private func resume() {
        isPaused = false
    }

    private func leaveForHome() {
        isPaused = false
        showHome()
    }

    private func restartFromPause() {
        switch game.retry() {
        case .started:
            resetPresentation()
            statusText = game.activeMode == .garden ? "Garden restarted" : "Class restarted"
            isPaused = false
        case .purchaseRequired:
            isPaused = false
            openFlowerShowPurchase(.lockedClass(game.currentFlowerShowClass))
        case .qualificationRequired, .progressionLocked, .accessChecking:
            break
        }
    }

    private func prepareGameplay() {
        displayBoard = game.board
        scheduleReviewRequest(for: game.reviewRequestTrigger)

        if let result = game.lastTurn {
            statusText = turnStatus(result)
        }

        let arguments = ProcessInfo.processInfo.arguments.map { $0.lowercased() }
        if arguments.contains("--screenshot-hint"), let move = game.suggestedMove {
            hintMove = move
            statusText = hintText(move)
        }

        if !guidedFirstBloomSeen,
           game.activeMode == .garden,
           game.launchMode == .production,
           game.garden == 1,
           game.phase == .playing,
           game.blooms == 0
        {
            showFreeFirstBloomGuide()
        }
    }

    private func resetPresentation() {
        resolutionTask?.cancel()
        resolutionTask = nil
        hintRequestTask?.cancel()
        hintRequestTask = nil
        displayBoard = game.board
        bloomSpokes = []
        rotatingRing = nil
        rotationDegrees = 0
        hintMove = nil
        guidedMove = nil
        quietTurns = 0
        isResolvingTurn = false
    }

    private func waitForPresentation(milliseconds: Int) async -> Bool {
        do {
            try await Task.sleep(for: .milliseconds(milliseconds))
            return Task.isCancelled == false
        } catch {
            return false
        }
    }

    private func ringIdentifier(_ ring: Ring) -> String {
        switch ring {
        case .inner: "ringInner"
        case .middle: "ringMiddle"
        case .outer: "ringOuter"
        }
    }

    private var flowerShowContextLabel: String {
        game.flowerShowDefinition.number > FlowerShowClassDefinition.classCount
            ? "CIRCUIT \(game.flowerShowDefinition.number)"
            : "CLASS \(game.flowerShowDefinition.number)"
    }

    private func scheduleReviewRequest(for trigger: Int?) {
        reviewRequestTask?.cancel()
        guard trigger != nil, game.activeMode == .garden, game.phase == .won else { return }

        reviewRequestTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(2))
            } catch {
                return
            }
            guard Task.isCancelled == false,
                  game.activeMode == .garden,
                  game.phase == .won,
                  game.reviewRequestTrigger == trigger,
                  let trigger,
                  game.commitReviewRequestAttempt(trigger: trigger)
            else { return }
            requestReview()
            reviewRequestTask = nil
        }
    }
}

private struct TutorialView: View {
    let begin: () -> Void
    let close: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        Spacer()
                        Button(action: close) {
                            Image(systemName: "xmark")
                                .frame(width: 44, height: 44)
                        }
                        .foregroundStyle(RingbloomTheme.ivory)
                        .accessibilityLabel("Close how to play")
                        .accessibilityIdentifier("tutorialCloseButton")
                    }

                    BloomMark()
                        .frame(width: 112, height: 112)
                        .accessibilityHidden(true)

                    VStack(spacing: 8) {
                        Text("HOW TO BLOOM")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .tracking(1.5)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(RingbloomTheme.ivory)
                            .accessibilityAddTraits(.isHeader)
                        Text("Every turn is one ring, one notch.")
                            .font(.system(.subheadline, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(RingbloomTheme.muted)
                    }

                    VStack(spacing: 0) {
                        TutorialStep(number: "1", title: "Choose a ring", detail: "Inner, middle, or outer.", symbol: "circle.circle")
                        Divider().overlay(RingbloomTheme.ivory.opacity(0.12)).padding(.leading, 16)
                        TutorialStep(number: "2", title: "Turn one notch", detail: "Swipe, or use the two arrows.", symbol: "arrow.clockwise")
                        Divider().overlay(RingbloomTheme.ivory.opacity(0.12)).padding(.leading, 16)
                        TutorialStep(number: "3", title: "Bloom a spoke", detail: "Match all three. Chain the next.", symbol: "sparkles")
                    }
                    .background(RingbloomTheme.inkLifted)
                    .clipShape(.rect(cornerRadius: 16))

                    Label(
                        "Your first garden highlights one live move. Three optional hints reset each garden.",
                        systemImage: "lightbulb.fill"
                    )
                    .font(.system(.footnote, design: .rounded, weight: .medium))
                    .foregroundStyle(RingbloomTheme.muted)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RingbloomTheme.saffron.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                    Button(action: begin) {
                        Label("BEGIN", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(RingbloomButtonStyle(prominent: true))
                    .accessibilityIdentifier("tutorialBeginButton")

                    Spacer()
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct PauseCard: View {
    let garden: Int
    let mode: GameMode
    let flowerShowClass: Int
    let resume: () -> Void
    let restart: () -> Void
    let home: () -> Void

    @AccessibilityFocusState private var titleFocused: Bool

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "pause.fill")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(RingbloomTheme.saffron)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(mode == .garden ? "GARDEN PAUSED" : "FLOWER SHOW PAUSED")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .tracking(1.2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(RingbloomTheme.ivory)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($titleFocused)

                Text(
                    mode == .garden
                        ? "Garden \(garden) is saved exactly where you left it."
                        : "Class \(flowerShowClass) is saved exactly where you left it."
                )
                .font(.system(.subheadline, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(RingbloomTheme.muted)
            }

            VStack(spacing: 12) {
                Button(action: resume) {
                    Label("RESUME", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(RingbloomButtonStyle(prominent: true))
                .accessibilityIdentifier("resumeButton")

                Button(action: home) {
                    Label("SAVE & HOME", systemImage: "house")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(RingbloomButtonStyle())
                .accessibilityIdentifier("pauseHomeButton")

                Button(action: restart) {
                    Label(
                        mode == .garden ? "RESTART GARDEN" : "RESTART CLASS",
                        systemImage: "arrow.counterclockwise"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(RingbloomButtonStyle())
                .accessibilityIdentifier("pauseRestartButton")
            }
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(RingbloomTheme.ivory.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.36), radius: 32, y: 16)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("gamePause")
        .onAppear {
            titleFocused = true
        }
    }
}

private struct OutcomeCard: View {
    let phase: GamePhase
    let score: Int
    let garden: Int
    let mode: GameMode
    let flowerShowClass: Int
    let bestStreak: Int
    let completionBonus: Int
    let rating: GardenRating?
    let canUndo: Bool
    let undo: () -> Void
    let retry: () -> Void
    let next: () -> Void
    let home: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var titleFocused: Bool

    var body: some View {
        let pairedLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
        let summaryLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))

        VStack(spacing: 20) {
            Image(systemName: phase == .won ? "sparkles" : "leaf")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(phase == .won ? RingbloomTheme.saffron : RingbloomTheme.mint)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(outcomeTitle)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .tracking(1.2)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(RingbloomTheme.ivory)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($titleFocused)
                Text(outcomeSubtitle)
                    .font(.system(.subheadline, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(RingbloomTheme.muted)
            }

            if phase == .won, let rating {
                VStack(spacing: 4) {
                    Text(String(repeating: "✦", count: rating.sparkCount))
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(RingbloomTheme.saffron)
                    Text(rating.displayName.uppercased())
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(RingbloomTheme.ivory)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(RingbloomTheme.saffron.opacity(0.14), in: Capsule())
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "\(rating.displayName) \(mode == .garden ? "garden" : "class") rating, \(rating.sparkCount) of 3"
                )
                .accessibilityIdentifier("gardenRating")
            }

            pairedLayout {
                HomeStat(
                    title: mode == .garden
                        ? "GARDEN"
                        : (flowerShowClass > FlowerShowClassDefinition.classCount ? "CIRCUIT" : "CLASS"),
                    value: (mode == .garden ? garden : flowerShowClass).formatted(.number.grouping(.never)),
                    symbol: mode == .garden ? "leaf.fill" : "medal.fill"
                )
                HomeStat(title: "SCORE", value: score.formatted(.number.grouping(.never)), symbol: "sparkles")
            }

            summaryLayout {
                Label("CHAIN \(bestStreak)", systemImage: "link")
                if phase == .won {
                    Label("+\(completionBonus) MOVE BONUS", systemImage: "leaf.fill")
                }
            }
            .font(.system(.caption2, design: .rounded, weight: .semibold))
            .foregroundStyle(RingbloomTheme.muted)
            .multilineTextAlignment(.center)

            if phase == .won, mode == .flowerShow {
                Text(objectiveSummary)
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .tracking(0.6)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(RingbloomTheme.mint)
                    .accessibilityIdentifier("flowerShowObjectiveSummary")
            }

            VStack(spacing: 12) {
                if phase == .won {
                    Button(action: next) {
                        Label(
                            nextButtonTitle,
                            systemImage: "arrow.right"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(RingbloomButtonStyle(prominent: true))
                    .accessibilityIdentifier("nextGardenButton")
                } else {
                    if canUndo {
                        Button(action: undo) {
                            Label("UNDO LAST TURN", systemImage: "arrow.uturn.backward")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(RingbloomButtonStyle(prominent: true))
                        .accessibilityHint("Restores the exact state before the final turn and caps the rating at Flourishing")
                        .accessibilityIdentifier("outcomeUndoButton")
                    }

                    Button(action: retry) {
                        Label("TRY AGAIN", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(RingbloomButtonStyle(prominent: canUndo == false))
                    .accessibilityIdentifier("retryButton")
                }

                Button(action: home) {
                    Label("HOME", systemImage: "house")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(RingbloomButtonStyle())
                .accessibilityIdentifier("outcomeHomeButton")
            }
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(RingbloomTheme.ivory.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.36), radius: 32, y: 16)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("gameOutcome")
        .onAppear {
            titleFocused = true
        }
    }

    private var outcomeTitle: String {
        if mode == .garden {
            return phase == .won ? "GARDEN COMPLETE" : "GARDEN RESTING"
        }
        if phase == .won, flowerShowClass == FlowerShowClassDefinition.classCount {
            return "GRAND CHAMPION"
        }
        if phase == .won,
           flowerShowClass < FlowerShowClassDefinition.classCount,
           flowerShowClass.isMultiple(of: FlowerShowClassDefinition.rosetteInterval)
        {
            return "ROSETTE EARNED"
        }
        if flowerShowClass > FlowerShowClassDefinition.classCount {
            return phase == .won ? "CIRCUIT CLASS COMPLETE" : "CIRCUIT CLASS RESTING"
        }
        return phase == .won ? "CLASS COMPLETE" : "CLASS RESTING"
    }

    private var outcomeSubtitle: String {
        if mode == .garden {
            return phase == .won ? "Every ring found its rhythm." : "The pattern is waiting for another try."
        }
        if phase == .won, flowerShowClass == FlowerShowClassDefinition.classCount {
            return "All 30 judged classes are complete. The Champion Circuit is open."
        }
        if phase == .won,
           flowerShowClass < FlowerShowClassDefinition.classCount,
           flowerShowClass.isMultiple(of: FlowerShowClassDefinition.rosetteInterval)
        {
            return "The judges award Rosette \(flowerShowClass / FlowerShowClassDefinition.rosetteInterval) of 6."
        }
        return phase == .won
            ? "The judges mark Class \(flowerShowClass) complete."
            : "The class is waiting for another try."
    }

    private var nextButtonTitle: String {
        if mode == .garden { return "NEXT GARDEN" }
        if flowerShowClass == FlowerShowClassDefinition.classCount {
            return "ENTER CHAMPION CIRCUIT \(FlowerShowClassDefinition.championCircuitStartClass)"
        }
        return flowerShowClass > FlowerShowClassDefinition.classCount
            ? "VIEW NEXT CIRCUIT CLASS"
            : "VIEW NEXT CLASS"
    }

    private var objectiveSummary: String {
        FlowerShowClassDefinition.classNumber(flowerShowClass).activeRules
            .map { "\($0.title.uppercased()) ✓" }
            .joined(separator: "  ·  ")
    }
}

private struct HomeStat: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(RingbloomTheme.saffron)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(RingbloomTheme.muted)
                Text(value)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(RingbloomTheme.ivory)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(RingbloomTheme.inkLifted)
        .clipShape(.rect(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title.capitalized), \(value)")
    }
}

private struct GameStat: View {
    let title: String
    let value: String
    let identifier: String

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(RingbloomTheme.muted)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(RingbloomTheme.ivory)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(RingbloomTheme.inkLifted.opacity(0.82))
        .clipShape(.rect(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title.capitalized)
        .accessibilityValue(value)
        .accessibilityIdentifier(identifier)
    }
}

private struct SettingButton: View {
    let title: String
    let enabled: Bool
    let enabledSymbol: String
    let disabledSymbol: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: enabled ? enabledSymbol : disabledSymbol)
                .font(.system(.footnote, design: .rounded, weight: .medium))
                .foregroundStyle(enabled ? RingbloomTheme.ivory : RingbloomTheme.muted)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(RingbloomTheme.inkLifted)
                .clipShape(.rect(cornerRadius: 12))
        }
        .accessibilityValue(enabled ? "On" : "Off")
        .accessibilityIdentifier(identifier)
    }
}

private struct HomeUtilityButton: View {
    let title: String
    let symbol: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(.footnote, design: .rounded, weight: .medium))
                .foregroundStyle(RingbloomTheme.ivory)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(RingbloomTheme.inkLifted)
                .clipShape(.rect(cornerRadius: 12))
        }
        .accessibilityIdentifier(identifier)
    }
}

private struct TutorialStep: View {
    let number: String
    let title: String
    let detail: String
    let symbol: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(RingbloomTheme.saffron.opacity(0.16))
                Text(number)
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(RingbloomTheme.saffron)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(RingbloomTheme.ivory)
                Text(detail)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(RingbloomTheme.muted)
            }

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer()
                Image(systemName: symbol)
                    .foregroundStyle(RingbloomTheme.mint)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

private struct RingChipStyle: ButtonStyle {
    let selected: Bool
    let hinted: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(
                selected
                    ? RingbloomTheme.ink
                    : (hinted ? RingbloomTheme.ivory : RingbloomTheme.muted)
            )
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? RingbloomTheme.mint : RingbloomTheme.inkLifted)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        hinted
                            ? RingbloomTheme.saffron
                            : (selected ? RingbloomTheme.ivory.opacity(0.38) : .clear),
                        lineWidth: hinted ? 3 : 1
                    )
            }
            .shadow(color: hinted ? RingbloomTheme.saffron.opacity(0.5) : .clear, radius: 8)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private extension GardenRating {
    var sparkCount: Int {
        switch self {
        case .seedling: 1
        case .flourishing: 2
        case .radiant: 3
        }
    }
}

private struct BloomMark: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                ForEach(0 ..< 8, id: \.self) { slot in
                    let kind = PetalKind.allCases[slot % PetalKind.allCases.count]
                    PetalShape()
                        .fill(kind.color)
                        .frame(width: side * 0.18, height: side * 0.38)
                        .offset(y: -side * 0.22)
                        .rotationEffect(.degrees(Double(slot) * 45))
                }
                Circle()
                    .fill(RingbloomTheme.ink)
                    .frame(width: side * 0.28, height: side * 0.28)
                Image(systemName: "sparkles")
                    .font(.system(size: side * 0.12, weight: .semibold))
                    .foregroundStyle(RingbloomTheme.ivory)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .shadow(color: RingbloomTheme.saffron.opacity(0.3), radius: 18)
        }
    }
}

struct AmbientPetals: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PetalShape()
                    .fill(RingbloomTheme.sky.opacity(0.06))
                    .frame(width: 110, height: 220)
                    .rotationEffect(.degrees(34))
                    .position(x: proxy.size.width * 0.02, y: proxy.size.height * 0.2)
                PetalShape()
                    .fill(RingbloomTheme.mint.opacity(0.05))
                    .frame(width: 140, height: 280)
                    .rotationEffect(.degrees(-48))
                    .position(x: proxy.size.width * 0.98, y: proxy.size.height * 0.78)
            }
        }
        .ignoresSafeArea()
    }
}
