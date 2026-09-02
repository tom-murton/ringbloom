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
    @AccessibilityFocusState private var focusedHeading: Bool
    @State private var showsSuccess = false
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
            appearedAt = Date()
            showsSuccess = store.hasFullFlowerShowAccess
            focusedHeading = true
            analytics.capture("paywall_viewed", properties: paywallProperties)
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
                analytics.capture("paywall_unlocked", properties: paywallProperties)
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
            Text("Unlock Classes 6–30 and the Champion Circuit.")
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
            benefit("25 more handcrafted Classes")
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
        VStack(spacing: 8) {
            Text("NEXT · CLASS 6")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(RingbloomTheme.saffron)
            Text("UNBROKEN")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(RingbloomTheme.ivory)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(RingbloomTheme.saffron.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Next, Class 6, Unbroken")
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
        return isStorefrontOperationActive == false
    }

    private var unlockTitle: String {
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
        Task {
            await store.purchase()
            analytics.capture(
                "purchase_outcome",
                properties: paywallProperties.merging(["outcome": purchaseOutcome]) { _, outcomeValue in outcomeValue }
            )
        }
    }

    private func restore() {
        recordPaywallAction("restore")
        analytics.capture("restore_started", properties: paywallProperties)
        Task {
            await store.restorePurchases()
            analytics.capture(
                "restore_outcome",
                properties: paywallProperties.merging(["outcome": restoreOutcome]) { _, outcomeValue in outcomeValue }
            )
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

    private var purchaseOutcome: String {
        switch store.purchaseState {
        case .success: "success"
        case .pending: "pending"
        case .failed: "failed"
        case .disabled: "disabled"
        case .idle: isProductUnavailable ? "product_unavailable" : "cancelled"
        case .purchasing: "in_progress"
        case .restoring: "unexpected_restore"
        }
    }

    private var restoreOutcome: String {
        switch store.purchaseState {
        case .success: "access_restored"
        case .idle: "no_purchase_found"
        case .failed: "failed"
        case .disabled: "disabled"
        case .pending: "pending"
        case .purchasing: "unexpected_purchase"
        case .restoring: "in_progress"
        }
    }
}
