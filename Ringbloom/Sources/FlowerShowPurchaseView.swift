import SwiftUI

struct FlowerShowPurchaseView: View {
    let context: FlowerShowPurchaseContext
    let targetIsPlayable: Bool
    let close: () -> Void
    let goHome: () -> Void
    let continueAfterPurchase: () -> Void

    @EnvironmentObject private var store: FlowerShowStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var focusedHeading: Bool
    @State private var showsSuccess = false

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
            showsSuccess = store.hasFullFlowerShowAccess
            focusedHeading = true
        }
        .onChange(of: store.accessState) { _, newState in
            if case .full = newState {
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
            Button(action: close) {
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
                primaryAction: close,
                primaryIdentifier: "flowerShowKeepPlayingButton",
                showsRestore: true
            )
        case .pending:
            operationalContent(
                heading: "PURCHASE PENDING",
                bodyText: "Flower Show will unlock when the purchase is approved.",
                primaryTitle: "KEEP PLAYING FREE",
                primaryAction: close,
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
                secondaryAction: close,
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

            Button("KEEP PLAYING FREE", action: close)
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

            Button(action: continueAfterPurchase) {
                Text(successTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(RingbloomButtonStyle(prominent: true))
            .accessibilityIdentifier("flowerShowPurchaseSuccessButton")

            Button("BACK TO HOME", action: goHome)
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
            secondaryAction: close,
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
        Task { await store.purchase() }
    }

    private func restore() {
        Task { await store.restorePurchases() }
    }

    private func retryProduct() {
        Task { await store.retryProductLoad() }
    }
}
