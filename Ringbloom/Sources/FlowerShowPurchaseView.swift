import Foundation
import SwiftUI

struct FlowerShowPurchaseView: View {
    let context: FlowerShowPurchaseContext
    let targetIsPlayable: Bool
    let freeClassesCompleted: Int
    let campaignClassesCompleted: Int
    let close: () -> Void
    let goHome: () -> Void
    let continueAfterPurchase: () -> Void

    @EnvironmentObject private var store: FlowerShowStore
    @EnvironmentObject private var analytics: ProductAnalytics
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @AccessibilityFocusState private var focusedHeading: Bool
    @State private var showsSuccess = false
    @State private var unlockAction: String?
    @State private var appearedAt = Date()
    @State private var lastAction = "none"

    var body: some View {
        ZStack {
            RingbloomTheme.background
                .ignoresSafeArea()

            AmbientPetals()
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            ScrollView {
                VStack(spacing: 24) {
                    closeButton
                    if showsSuccess {
                        successContent
                    } else {
                        purchaseContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity, minHeight: 620)
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityIdentifier("flowerShowPurchaseView")
        .onAppear {
            store.refreshPendingPurchaseState()
            appearedAt = Date()
            showsSuccess = store.hasFullFlowerShowAccess
            focusedHeading = true
            analytics.capture("paywall_viewed", properties: paywallProperties)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.refreshPendingPurchaseState() }
        }
        .onDisappear {
            analytics.capture(
                "paywall_session_ended",
                properties: paywallProperties.merging(
                    [
                        "last_action": lastAction,
                        "seconds_visible": secondsVisible,
                        "unlocked": store.hasFullFlowerShowAccess,
                    ]
                ) { _, sessionValue in sessionValue }
            )
        }
        .onChange(of: store.accessState) { _, newState in
            if case .full = newState {
                let source = switch newState {
                case .full(.legacyPaidApp): "legacy"
                case .full(.storePurchase): unlockAction ?? "restore"
                case .checking, .sample: "restore"
                }
                analytics.capture("paywall_unlocked", properties: paywallProperties.merging([
                    "unlock_source": source,
                ]) { _, value in value })
                unlockAction = nil
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    showsSuccess = true
                }
                focusedHeading = true
            } else {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    showsSuccess = false
                }
            }
        }
    }

    private var closeButton: some View {
        HStack {
            Spacer()
            Button(action: { dismissPaywall(action: "close") }) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .foregroundStyle(RingbloomTheme.ivory)
            .accessibilityLabel("Close Flower Show purchase")
            .accessibilityHint("Return to the previous screen")
            .accessibilityIdentifier("flowerShowPurchaseCloseButton")
        }
    }

    @ViewBuilder
    private var purchaseContent: some View {
        switch store.purchaseState {
        case .disabled:
            operationalContent(
                heading: "PURCHASES UNAVAILABLE",
                bodyText: "Purchases aren’t available on this device.",
                primaryTitle: "KEEP PLAYING FREE",
                primaryAction: { dismissPaywall(action: "keep_playing_free") },
                primaryIdentifier: "flowerShowKeepPlayingButton",
                showsRestore: true
            )
        case .pending:
            operationalContent(
                heading: "PURCHASE PENDING",
                bodyText: "Flower Show will unlock when the purchase is approved.",
                primaryTitle: "KEEP PLAYING FREE",
                primaryAction: { dismissPaywall(action: "keep_playing_free") },
                primaryIdentifier: "flowerShowKeepPlayingButton",
                showsRestore: false
            )
        case .failed where isProductUnavailable:
            unavailableContent
        case .failed:
            operationalContent(
                heading: "PURCHASE NOT COMPLETED",
                bodyText: "Check your connection and try again.",
                primaryTitle: "TRY AGAIN",
                primaryAction: purchase,
                primaryIdentifier: "flowerShowPurchaseRetryButton",
                showsRestore: true,
                secondaryTitle: "KEEP PLAYING FREE",
                secondaryAction: { dismissPaywall(action: "keep_playing_free") },
                secondaryIdentifier: "flowerShowKeepPlayingButton"
            )
        case .idle, .purchasing, .restoring, .success:
            if isProductUnavailable {
                unavailableContent
            } else {
                normalContent
            }
        }
    }

    private var normalContent: some View {
        VStack(spacing: 20) {
            heading(eyebrow: "FLOWER SHOW", title: "CONTINUE THE SHOW")
            Text("Unlock 25 additional Classes and the Champion Circuit.")
                .font(.system(.body, design: .rounded, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(RingbloomTheme.ivory)

            benefits
            preview
            storefrontOperationFeedback

            Button(action: purchase) {
                Text(unlockTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(RingbloomButtonStyle(prominent: true))
            .disabled(canPurchase == false)
            .accessibilityLabel(unlockTitle)
            .accessibilityHint("Permanently unlocks Classes 6 through 30 and the Champion Circuit")
            .accessibilityIdentifier("flowerShowPurchaseButton")

            Button("KEEP PLAYING FREE", action: { dismissPaywall(action: "keep_playing_free") })
                .buttonStyle(RingbloomButtonStyle())
                .accessibilityHint("Return to the free Garden and sampler Classes")
                .accessibilityIdentifier("flowerShowKeepPlayingButton")

            Button(restoreTitle, action: restore)
                .buttonStyle(.plain)
                .foregroundStyle(RingbloomTheme.muted)
                .frame(minHeight: 44)
                .disabled(isStorefrontOperationActive)
                .accessibilityLabel(restoreAccessibilityLabel)
                .accessibilityHint("Check this Apple account for a previous Flower Show purchase")
                .accessibilityIdentifier("flowerShowRestoreButton")
        }
    }

    private var successContent: some View {
        VStack(spacing: 20) {
            heading(eyebrow: "FLOWER SHOW", title: "FLOWER SHOW UNLOCKED")
            Text("Classes 6–30 and the Champion Circuit are ready.")
                .font(.system(.body, design: .rounded, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(RingbloomTheme.ivory)

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(RingbloomTheme.mint)
                .accessibilityHidden(true)

            Button(action: {
                recordPaywallAction("continue_after_purchase")
                continueAfterPurchase()
            }) {
                Text(successTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(RingbloomButtonStyle(prominent: true))
            .accessibilityIdentifier("flowerShowPurchaseSuccessButton")

            Button("BACK TO HOME") {
                recordPaywallAction("back_to_home")
                goHome()
            }
                .buttonStyle(RingbloomButtonStyle())
                .accessibilityIdentifier("flowerShowPurchaseHomeButton")
        }
    }

    private var unavailableContent: some View {
        operationalContent(
            heading: "FLOWER SHOW UNAVAILABLE",
            bodyText: "The full Flower Show can’t be loaded right now. Garden and Classes 1–5 are still available.",
            primaryTitle: "TRY AGAIN",
            primaryAction: retryProduct,
            primaryIdentifier: "flowerShowPurchaseRetryButton",
            showsRestore: true,
            secondaryTitle: "KEEP PLAYING FREE",
            secondaryAction: { dismissPaywall(action: "keep_playing_free") },
            secondaryIdentifier: "flowerShowKeepPlayingButton"
        )
    }

    private func operationalContent(
        heading: String,
        bodyText: String,
        primaryTitle: String,
        primaryAction: @escaping () -> Void,
        primaryIdentifier: String,
        showsRestore: Bool,
        secondaryTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil,
        secondaryIdentifier: String? = nil
    ) -> some View {
        VStack(spacing: 20) {
            self.heading(eyebrow: "FLOWER SHOW", title: heading)
            Text(bodyText)
                .font(.system(.body, design: .rounded, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(RingbloomTheme.ivory)

            storefrontOperationFeedback

            Button(primaryTitle, action: primaryAction)
                .buttonStyle(RingbloomButtonStyle(prominent: true))
                .disabled(isStorefrontOperationActive)
                .accessibilityIdentifier(primaryIdentifier)

            if let secondaryTitle, let secondaryAction, let secondaryIdentifier {
                Button(secondaryTitle, action: secondaryAction)
                    .buttonStyle(RingbloomButtonStyle())
                    .accessibilityIdentifier(secondaryIdentifier)
            }

            if showsRestore {
                Button(restoreTitle, action: restore)
                    .buttonStyle(.plain)
                    .foregroundStyle(RingbloomTheme.muted)
                    .frame(minHeight: 44)
                    .disabled(isStorefrontOperationActive)
                    .accessibilityLabel(restoreAccessibilityLabel)
                    .accessibilityIdentifier("flowerShowRestoreButton")
            }
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefit("25 additional campaign Classes")
            benefit("Six more special rules")
            benefit("The endless Champion Circuit")
            benefit("One permanent purchase")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RingbloomTheme.inkLifted, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private func benefit(_ text: String) -> some View {
        Label(text, systemImage: "checkmark")
            .font(.system(.subheadline, design: .rounded, weight: .medium))
            .foregroundStyle(RingbloomTheme.ivory)
    }

    private var preview: some View {
        let copy = FlowerShowPurchasePreviewCopy(context: context)
        return VStack(spacing: 12) {
            Text(copy.eyebrow)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(RingbloomTheme.saffron)
            Text(copy.title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(RingbloomTheme.ivory)
            if let targetTitle = copy.targetTitle {
                Text(targetTitle)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(RingbloomTheme.muted)
            }
            FlowerShowClass6PreviewView()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(RingbloomTheme.saffron.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("flowerShowClass6Preview")
    }

    private func heading(eyebrow: String, title: String) -> some View {
        VStack(spacing: 8) {
            Text(eyebrow)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(RingbloomTheme.saffron)
            Text(title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .tracking(1.1)
                .multilineTextAlignment(.center)
                .foregroundStyle(RingbloomTheme.ivory)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($focusedHeading)
        }
    }

    private var isProductUnavailable: Bool {
        if case .unavailable = store.productState { return true }
        return false
    }

    @ViewBuilder
    private var storefrontOperationFeedback: some View {
        switch store.purchaseState {
        case .purchasing:
            ProgressView("Completing purchase…")
                .tint(RingbloomTheme.ivory)
                .foregroundStyle(RingbloomTheme.ivory)
                .accessibilityLabel("Purchase in progress")
                .accessibilityIdentifier("flowerShowPurchaseProgress")
        case .restoring:
            ProgressView("Restoring purchases…")
                .tint(RingbloomTheme.ivory)
                .foregroundStyle(RingbloomTheme.ivory)
                .accessibilityLabel("Restore in progress")
                .accessibilityIdentifier("flowerShowRestoreProgress")
        case .idle, .pending, .success, .failed, .disabled:
            EmptyView()
        }
    }

    private var isStorefrontOperationActive: Bool {
        store.purchaseState == .purchasing || store.purchaseState == .restoring
    }

    private var canPurchase: Bool {
        guard case .available = store.productState else { return false }
        return isStorefrontOperationActive == false && store.purchaseState != .pending
    }

    private var unlockTitle: String {
        if store.purchaseState == .pending {
            return "PURCHASE PENDING"
        }
        if store.purchaseState == .purchasing {
            return "PURCHASING…"
        }
        if case let .available(product) = store.productState {
            return "UNLOCK FOR \(product.displayPrice)"
        }
        return "LOADING…"
    }

    private var restoreTitle: String {
        store.purchaseState == .restoring ? "RESTORING…" : "RESTORE PURCHASES"
    }

    private var restoreAccessibilityLabel: String {
        store.purchaseState == .restoring ? "Restore in progress" : "Restore purchases"
    }

    private var successTitle: String {
        guard let targetClass = context.targetClass else { return "BACK TO HOME" }
        guard targetIsPlayable else { return "BACK TO CLASS BOOK" }
        return targetClass == 6 ? "START CLASS 6" : "CONTINUE CLASS \(targetClass)"
    }

    private func purchase() {
        recordPaywallAction("purchase")
        analytics.capture("purchase_started", properties: paywallProperties)
        let accessBefore = store.accessState.analyticsName
        unlockAction = "purchase"
        Task {
            let verifiedNewPurchase = await store.purchase()
            analytics.capture(
                "purchase_outcome",
                properties: paywallProperties.merging([
                    "outcome": AnalyticsCommerceOutcome.purchase(
                        verifiedNewPurchase: verifiedNewPurchase,
                        state: store.purchaseState
                    ),
                    "access_state_before": accessBefore,
                    "access_state_after": store.accessState.analyticsName,
                ]) { _, outcomeValue in outcomeValue }
            )
            if !verifiedNewPurchase { unlockAction = nil }
        }
    }

    private func restore() {
        recordPaywallAction("restore")
        analytics.capture("restore_started", properties: paywallProperties)
        let accessBefore = store.accessState.analyticsName
        unlockAction = "restore"
        Task {
            await store.restorePurchases()
            analytics.capture(
                "restore_outcome",
                properties: paywallProperties.merging([
                    "outcome": AnalyticsCommerceOutcome.restore(
                        state: store.purchaseState,
                        hasFullAccess: store.hasFullFlowerShowAccess
                    ),
                    "access_state_before": accessBefore,
                    "access_state_after": store.accessState.analyticsName,
                ]) { _, outcomeValue in outcomeValue }
            )
            if !store.hasFullFlowerShowAccess { unlockAction = nil }
        }
    }

    private func retryProduct() {
        recordPaywallAction("retry_product")
        Task {
            await store.retryProductLoad()
            analytics.capture(
                "product_load_outcome",
                properties: paywallProperties.merging(["outcome": productStateName]) { _, outcomeValue in outcomeValue }
            )
        }
    }

    private func dismissPaywall(action: String) {
        recordPaywallAction(action)
        close()
    }

    private func recordPaywallAction(_ action: String) {
        lastAction = action
        analytics.capture(
            "paywall_action",
            properties: paywallProperties.merging(
                [
                    "action": action,
                    "seconds_visible": secondsVisible,
                ]
            ) { _, actionValue in actionValue }
        )
    }

    private var paywallProperties: [String: Any] {
        context.analyticsProperties.merging(
            [
                "campaign_classes_completed": campaignClassesCompleted,
                "free_classes_completed": freeClassesCompleted,
                "product_state": productStateName,
                "purchase_state": purchaseStateName,
                "target_is_playable": targetIsPlayable,
            ]
        ) { _, paywallValue in paywallValue }
    }

    private var secondsVisible: Double {
        max(0, Date().timeIntervalSince(appearedAt))
    }

    private var productStateName: String {
        switch store.productState {
        case .loading: "loading"
        case .available: "available"
        case .unavailable: "unavailable"
        }
    }

    private var purchaseStateName: String {
        switch store.purchaseState {
        case .idle: "idle"
        case .purchasing: "purchasing"
        case .pending: "pending"
        case .success: "success"
        case .failed: "failed"
        case .disabled: "disabled"
        case .restoring: "restoring"
        }
    }

}

struct FlowerShowPurchasePreviewCopy: Equatable {
    let eyebrow: String
    let title: String
    let targetTitle: String?

    init(context: FlowerShowPurchaseContext) {
        let targetsClassSix = context.targetClass == 6
            || context.origin == .afterClassFive

        if targetsClassSix {
            eyebrow = "NEXT · CLASS 6"
            title = "UNBROKEN"
            targetTitle = nil
        } else if let targetClass = context.targetClass {
            let definition = FlowerShowClassDefinition.classNumber(targetClass)
            eyebrow = "CLASS 6 RULE EXAMPLE"
            title = "UNBROKEN"
            targetTitle = "TARGET · \(definition.title.uppercased()) · \(definition.stageTitle.uppercased())"
        } else {
            eyebrow = "CLASS 6 RULE EXAMPLE"
            title = "UNBROKEN"
            targetTitle = nil
        }
    }

    var accessibilityLabel: String {
        [eyebrow, title, targetTitle].compactMap { $0 }.joined(separator: ". ")
    }
}

/// An isolated, reproducible prefix of Class 6. It deliberately owns its own
/// engine, so rendering the offer cannot start an attempt or affect progress.
struct FlowerShowClass6Preview: Equatable {
    let scenario: FlowerShowScenario
    let initialState: FlowerShowState
    let firstTransition: FlowerShowTransition
    let secondTransition: FlowerShowTransition

    static func make() -> Self? {
        let scenario = FlowerShowContent.resolve(classNumber: 6).scenario
        guard scenario.scenarioID == "campaign-06",
              scenario.scenarioDigest == "9a6261a14bf719236b43e948d1330006906e79bf1362700efdefc4ab159d5da9",
              scenario.refillSource.seed == 6_510_615_556_070_394_423,
              scenario.objectives.unbrokenChain == 2
        else { return nil }

        var engine = FlowerShowEngine(scenario: scenario)
        let initialState = engine.state
        engine.select(.middle)
        guard let first = engine.rotate(.clockwise, scenario: scenario) else { return nil }
        engine.select(.inner)
        guard let second = engine.rotate(.counterClockwise, scenario: scenario),
              first.blooms.isEmpty == false,
              second.blooms.isEmpty == false,
              first.unbrokenAfter.current == 1,
              second.unbrokenAfter.current == 2,
              second.unbrokenAfter.best == 2,
              first.phase == .playing,
              second.phase == .playing
        else { return nil }

        return Self(
            scenario: scenario,
            initialState: initialState,
            firstTransition: first,
            secondTransition: second
        )
    }

    var states: [FlowerShowState] {
        [initialState, firstTransition.stateAfter, secondTransition.stateAfter]
    }

    var transitions: [FlowerShowTransition] {
        [firstTransition, secondTransition]
    }

    func board(at step: Int) -> GameBoard {
        states[min(max(step, 0), states.count - 1)].board
    }

    func selectedRing(at step: Int) -> Ring {
        states[min(max(step, 0), states.count - 1)].selectedRing
    }

    func presentation(for phase: FlowerShowClass6PreviewPhase) -> FlowerShowClass6PreviewPresentation {
        switch phase {
        case .initial:
            .init(board: initialState.board, selectedRing: initialState.selectedRing)
        case .firstRotation:
            .init(
                board: initialState.board,
                selectedRing: firstTransition.ring,
                rotatingRing: firstTransition.ring,
                rotationDegrees: firstTransition.direction == .clockwise ? 45 : -45
            )
        case .firstAligned:
            .init(
                board: initialState.board.rotated(firstTransition.ring, direction: firstTransition.direction),
                selectedRing: firstTransition.ring
            )
        case .firstBloom:
            .init(
                board: initialState.board.rotated(firstTransition.ring, direction: firstTransition.direction),
                selectedRing: firstTransition.ring,
                bloomSpokes: firstTransition.bloomSpokes,
                bloomToken: 1
            )
        case .firstSettled:
            .init(board: firstTransition.stateAfter.board, selectedRing: firstTransition.stateAfter.selectedRing)
        case .secondRotation:
            .init(
                board: firstTransition.stateAfter.board,
                selectedRing: secondTransition.ring,
                rotatingRing: secondTransition.ring,
                rotationDegrees: secondTransition.direction == .clockwise ? 45 : -45
            )
        case .secondAligned:
            .init(
                board: firstTransition.stateAfter.board.rotated(secondTransition.ring, direction: secondTransition.direction),
                selectedRing: secondTransition.ring
            )
        case .secondBloom:
            .init(
                board: firstTransition.stateAfter.board.rotated(secondTransition.ring, direction: secondTransition.direction),
                selectedRing: secondTransition.ring,
                bloomSpokes: secondTransition.bloomSpokes,
                bloomToken: 2
            )
        case .complete:
            .init(board: secondTransition.stateAfter.board, selectedRing: secondTransition.stateAfter.selectedRing)
        }
    }
}

enum FlowerShowClass6PreviewPhase: CaseIterable, Equatable, Sendable {
    case initial
    case firstRotation
    case firstAligned
    case firstBloom
    case firstSettled
    case secondRotation
    case secondAligned
    case secondBloom
    case complete

    var isComplete: Bool { self == .complete }

    var wait: Duration {
        switch self {
        case .initial: .milliseconds(600)
        case .firstRotation, .secondRotation: .milliseconds(280)
        case .firstAligned, .secondAligned: .milliseconds(120)
        case .firstBloom, .secondBloom: .milliseconds(460)
        case .firstSettled: .milliseconds(620)
        case .complete: .zero
        }
    }

    var next: Self {
        switch self {
        case .initial: .firstRotation
        case .firstRotation: .firstAligned
        case .firstAligned: .firstBloom
        case .firstBloom: .firstSettled
        case .firstSettled: .secondRotation
        case .secondRotation: .secondAligned
        case .secondAligned: .secondBloom
        case .secondBloom: .complete
        case .complete: .complete
        }
    }
}

struct FlowerShowClass6PreviewPresentation: Equatable {
    let board: GameBoard
    let selectedRing: Ring
    var bloomSpokes: [Int] = []
    var bloomToken = 0
    var rotatingRing: Ring? = nil
    var rotationDegrees = 0.0
}

private struct FlowerShowClass6PreviewView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = FlowerShowClass6PreviewPhase.initial
    @State private var isPaused = true
    @State private var replayToken = UUID()

    private let preview = FlowerShowClass6Preview.make()

    var body: some View {
        Group {
            if let preview {
                if effectiveReduceMotion {
                    staticPreview(preview)
                } else {
                    animatedPreview(preview)
                }
            } else {
                Text("Class 6 introduces Unbroken: score on two turns in a row.")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(RingbloomTheme.ivory)
                    .accessibilityIdentifier("flowerShowClass6PreviewFallback")
            }
        }
    }

    private var effectiveReduceMotion: Bool {
        reduceMotion || uiTestReduceMotionOverride
    }

    private var uiTestReduceMotionOverride: Bool {
        #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments.map { $0.lowercased() }
            return arguments.contains("--ui-testing") && arguments.contains("--ui-test-reduce-motion")
        #else
            false
        #endif
    }

    private func animatedPreview(_ preview: FlowerShowClass6Preview) -> some View {
        VStack(spacing: 12) {
            demoBoard(preview.presentation(for: phase), identifier: phaseAccessibilityIdentifier)
            Text(animatedDescription)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(RingbloomTheme.ivory)
                .accessibilityLabel("Class 6 Unbroken example. Turn the middle ring clockwise for the first bloom, then the inner ring counter-clockwise for the second bloom. The Unbroken objective reaches 2 of 2. This is a demonstration, not a playable Class.")

            HStack(spacing: 12) {
                if phase.isComplete == false {
                    Button(isPaused ? "PLAY DEMO" : "PAUSE DEMO") {
                        isPaused.toggle()
                    }
                    .buttonStyle(RingbloomButtonStyle())
                    .frame(minHeight: 44)
                    .accessibilityLabel(isPaused ? "Play Class 6 demonstration" : "Pause Class 6 demonstration")
                    .accessibilityValue(isPaused ? "Paused at \(phaseAccessibilityDescription)" : "Playing \(phaseAccessibilityDescription)")
                    .accessibilityIdentifier("flowerShowClass6PreviewPauseButton")
                }

                Button("REPLAY DEMO") {
                    phase = .initial
                    isPaused = true
                    replayToken = UUID()
                }
                .buttonStyle(RingbloomButtonStyle())
                .frame(minHeight: 44)
                .accessibilityIdentifier("flowerShowClass6PreviewReplayButton")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("flowerShowClass6PreviewAnimated")
        .task(id: PlaybackKey(replayToken: replayToken, isPaused: isPaused)) {
            guard isPaused == false else { return }
            while phase.isComplete == false, Task.isCancelled == false {
                let visiblePhase = phase
                if visiblePhase.wait > .zero {
                    try? await Task.sleep(for: visiblePhase.wait)
                }
                guard Task.isCancelled == false, isPaused == false else { return }
                advance(from: visiblePhase)
            }
        }
    }

    private func staticPreview(_ preview: FlowerShowClass6Preview) -> some View {
        VStack(spacing: 12) {
            Text("2 SCORING TURNS IN A ROW")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .tracking(1)
                .foregroundStyle(RingbloomTheme.saffron)
                .accessibilityLabel("Class 6 Unbroken example. Static before and after boards show two scoring turns in a row. Turn the middle ring clockwise, then the inner ring counter-clockwise, to reach Unbroken 2 of 2. This is a demonstration, not a playable Class.")
                .accessibilityIdentifier("flowerShowClass6StaticSummary")
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    staticBoard(preview, phase: .initial, label: "BEFORE")
                    staticBoard(preview, phase: .complete, label: "AFTER · UNBROKEN 2 OF 2")
                }
                VStack(spacing: 12) {
                    staticBoard(preview, phase: .initial, label: "BEFORE")
                    staticBoard(preview, phase: .complete, label: "AFTER · UNBROKEN 2 OF 2")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("flowerShowClass6PreviewStatic")
    }

    private func staticBoard(_ preview: FlowerShowClass6Preview, phase: FlowerShowClass6PreviewPhase, label: String) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(RingbloomTheme.muted)
            demoBoard(
                preview.presentation(for: phase),
                identifier: phase == .initial ? "staticBefore" : "staticAfter"
            )
        }
    }

    private func demoBoard(
        _ presentation: FlowerShowClass6PreviewPresentation,
        identifier: String
    ) -> some View {
        GameBoardView(
            board: presentation.board,
            selectedRing: presentation.selectedRing,
            bloomSpokes: presentation.bloomSpokes,
            bloomToken: presentation.bloomToken,
            rotatingRing: presentation.rotatingRing,
            rotationDegrees: presentation.rotationDegrees,
            hintMove: nil,
            infectedSpokes: [],
            bindweedSpreadPreview: nil,
            interactionEnabled: false,
            onSelect: { _ in },
            onRotate: { _ in }
        )
        .frame(maxWidth: 250)
        .accessibilityHidden(true)
        .accessibilityIdentifier("flowerShowClass6PreviewBoard\(identifier)")
    }

    private var animatedDescription: String {
        switch phase {
        case .initial: "Score on two turns in a row."
        case .firstRotation, .firstAligned: "Turn the middle ring clockwise."
        case .firstBloom: "First bloom — Unbroken 1 of 2."
        case .firstSettled, .secondRotation, .secondAligned: "Turn the inner ring counter-clockwise."
        case .secondBloom, .complete: "Second bloom — Unbroken 2 of 2."
        }
    }

    private func advance(from visiblePhase: FlowerShowClass6PreviewPhase) {
        let next = visiblePhase.next
        guard next != visiblePhase else { return }
        if next == .firstAligned || next == .secondAligned {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { phase = next }
        } else if next == .firstRotation || next == .secondRotation {
            withAnimation(.snappy(duration: 0.28, extraBounce: 0.08)) { phase = next }
        } else {
            withAnimation(.easeOut(duration: 0.18)) { phase = next }
        }
    }

    private var phaseAccessibilityIdentifier: String {
        switch phase {
        case .initial: "0"
        case .firstRotation: "1rotation"
        case .firstAligned: "1aligned"
        case .firstBloom: "1bloom"
        case .firstSettled: "1settled"
        case .secondRotation: "2rotation"
        case .secondAligned: "2aligned"
        case .secondBloom: "2bloom"
        case .complete: "2"
        }
    }

    private var phaseAccessibilityDescription: String {
        switch phase {
        case .initial: "the opening board"
        case .firstRotation, .firstAligned: "the first middle-ring turn"
        case .firstBloom: "the first bloom"
        case .firstSettled: "the first completed turn"
        case .secondRotation, .secondAligned: "the second inner-ring turn"
        case .secondBloom: "the second bloom"
        case .complete: "the completed demonstration"
        }
    }

    private struct PlaybackKey: Hashable {
        let replayToken: UUID
        let isPaused: Bool
    }
}
