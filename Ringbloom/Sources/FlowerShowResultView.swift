import SwiftUI
import UIKit

struct FlowerShowResultView: View {
    let phase: GamePhase
    let summary: FlowerShowResultSummary?
    let classNumber: Int
    let remainingWork: [String]
    let canUndo: Bool
    let undo: () -> Void
    let retry: () -> Void
    let accessChecking: Bool
    let retryAccessCheck: () -> Void
    let continueProgression: () -> Void
    let openClassBook: () -> Void
    let home: () -> Void
    let achievementIsSaved: Bool
    let share: (FlowerShowResultSummary) -> Void

    @AccessibilityFocusState private var titleFocused: Bool
    @EnvironmentObject private var analytics: ProductAnalytics
    @State private var shareCard: FlowerShowShareCardData?
    @State private var shareCardImageUnavailable = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: phase == .won ? milestoneSymbol : "hourglass.bottomhalf.filled")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(phase == .won ? RingbloomTheme.saffron : RingbloomTheme.mint)
                .accessibilityHidden(true)

            VStack(spacing: 7) {
                Text(title)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .tracking(1.1)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(RingbloomTheme.ivory)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($titleFocused)
                    .accessibilityIdentifier("flowerShowResultTitle")

                Text(subtitle)
                    .font(.system(.subheadline, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(RingbloomTheme.muted)
            }

            if let summary, phase == .won {
                ratingCard(summary)
            } else if remainingWork.isEmpty == false {
                Text("Still needed: \(naturalList(remainingWork)).")
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(RingbloomTheme.ivory)
                    .accessibilityIdentifier("flowerShowRemainingWork")
            }

            actions
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(RingbloomTheme.ivory.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.36), radius: 32, y: 16)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("flowerShowResult")
        .onAppear { titleFocused = true }
        .sheet(item: $shareCard) { card in
            FlowerShowShareSheet(card: card, imageUnavailable: {
                shareCardImageUnavailable = true
            }) { completed in
                guard completed else { return }
                analytics.capture("flower_show_share_completed", properties: card.analyticsProperties)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if shareCardImageUnavailable {
                Text("The achievement text and App Store link are ready to share. The card image was unavailable.")
                    .font(.footnote)
                    .foregroundStyle(RingbloomTheme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .accessibilityIdentifier("flowerShowShareImageFallback")
            }
        }
    }

    private func ratingCard(_ summary: FlowerShowResultSummary) -> some View {
        VStack(spacing: 6) {
            Label(summary.rating.displayName.uppercased(), systemImage: summary.rating.symbol)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(RingbloomTheme.saffron)
            Text(ratingReason(summary))
                .font(.system(.footnote, design: .rounded, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(RingbloomTheme.ivory)
            if summary.isNewBest {
                Text("NEW BEST CLASS RATING")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(RingbloomTheme.mint)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(RingbloomTheme.saffron.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(summary.rating.displayName) Class rating. \(ratingReason(summary))\(summary.isNewBest ? " New best." : "")")
        .accessibilityIdentifier("flowerShowRating")
    }

    private var actions: some View {
        VStack(spacing: 11) {
            if phase == .won {
                if summary?.context.kind == .replay {
                    Button(action: openClassBook) {
                        Label("BACK TO CLASS BOOK", systemImage: "books.vertical.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(RingbloomButtonStyle(prominent: true))
                    .accessibilityIdentifier("resultClassBookButton")

                    Button(action: retry) {
                        Label(
                            accessChecking ? "CHECKING ACCESS…" : "REPLAY CLASS",
                            systemImage: accessChecking ? "hourglass" : "arrow.counterclockwise"
                        )
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(RingbloomButtonStyle())
                    .disabled(accessChecking)
                    .accessibilityLabel(
                        accessChecking ? "Checking Flower Show access" : "Replay Class"
                    )
                    .accessibilityValue(
                        accessChecking ? "Waiting for access check to finish" : "Ready"
                    )
                    .accessibilityIdentifier("resultReplayButton")

                    if accessChecking {
                        Button(action: retryAccessCheck) {
                            Label("CHECK ACCESS AGAIN", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(RingbloomButtonStyle())
                        .accessibilityHint(
                            "Retries the Flower Show access check without leaving this result"
                        )
                        .accessibilityIdentifier("resultAccessRetryButton")
                    }
                } else {
                    Button(action: continueProgression) {
                        Label(
                            accessChecking ? "CHECKING ACCESS…" : nextTitle,
                            systemImage: accessChecking ? "hourglass" : "arrow.right"
                        )
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(RingbloomButtonStyle(prominent: true))
                    .disabled(accessChecking)
                    .accessibilityLabel(accessChecking ? "Checking Flower Show access" : nextTitle)
                    .accessibilityValue(accessChecking ? "Waiting for access check to finish" : "Ready")
                    .accessibilityIdentifier("nextGardenButton")

                    if accessChecking {
                        Button(action: retryAccessCheck) {
                            Label("CHECK ACCESS AGAIN", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(RingbloomButtonStyle())
                        .accessibilityHint("Retries the Flower Show access check without leaving this result")
                        .accessibilityIdentifier("resultAccessRetryButton")
                    }

                    Button(action: openClassBook) {
                        Label("CLASS BOOK", systemImage: "books.vertical.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(RingbloomButtonStyle())
                    .accessibilityIdentifier("resultClassBookButton")
                }

                shareAction
            } else {
                if canUndo {
                    Button(action: undo) {
                        Label("UNDO LAST TURN", systemImage: "arrow.uturn.backward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(RingbloomButtonStyle(prominent: true))
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

    @ViewBuilder
    private var shareAction: some View {
        if achievementIsSaved, let summary {
            Button {
                let card = FlowerShowShareCardData(summary: summary)
                shareCardImageUnavailable = false
                share(summary)
                shareCard = card
            } label: {
                Label("SHARE ACHIEVEMENT", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .buttonStyle(RingbloomButtonStyle())
            .accessibilityLabel("Share Flower Show achievement")
            .accessibilityHint("Opens the system share sheet. Sharing does not change your progress.")
            .accessibilityIdentifier("flowerShowShareButton")
        }
    }

    private var title: String {
        guard phase == .won else { return "MOVES USED UP" }
        return switch summary?.milestone {
        case .grandChampion: "GRAND CHAMPION · CLASS 30 COMPLETE"
        case .perfectShow: "PERFECT SHOW · CLASS \(classNumber) COMPLETE"
        case .rosette: "ROSETTE EARNED · CLASS \(classNumber) COMPLETE"
        case .circuitCup: "CIRCUIT CUP · CLASS \(classNumber) COMPLETE"
        case nil: classNumber > 30 ? "CIRCUIT CLASS COMPLETE" : "CLASS COMPLETE"
        }
    }

    private var subtitle: String {
        guard phase == .won else { return "The judges still need more from this arrangement." }
        if summary?.milestone == .grandChampion { return "The 30-Class campaign is complete. The Champion Circuit is open." }
        if summary?.milestone == .perfectShow { return "Every campaign Class now has a Radiant rating." }
        return "Class \(classNumber) is complete."
    }

    private var milestoneSymbol: String {
        switch summary?.milestone {
        case .grandChampion: "trophy.fill"
        case .perfectShow: "crown.fill"
        case .rosette, .circuitCup: "seal.fill"
        case nil: "sparkles"
        }
    }

    private var nextTitle: String {
        if classNumber == 30 { return "ENTER CHAMPION CIRCUIT" }
        return classNumber > 30 ? "NEXT CIRCUIT CLASS" : "NEXT CLASS"
    }

    private func ratingReason(_ summary: FlowerShowResultSummary) -> String {
        switch summary.rating {
        case .radiant:
            "\(summary.movesUsed) moves, no Hint, no Undo."
        case .flourishing:
            "Class complete without Hint. Replay in \(summary.radiantPar) moves or fewer without Undo for Radiant."
        case .seedling:
            summary.didUseHint ? "Class complete. Hint used." : "Class complete."
        }
    }

    private func naturalList(_ values: [String]) -> String {
        guard values.count > 1 else { return values.first ?? "" }
        return values.dropLast().joined(separator: ", ") + " and " + values.last!
    }
}

enum FlowerShowAchievementSharePolicy {
    static func isEligible(progressSaveHealth: ProgressSaveHealth) -> Bool {
        progressSaveHealth == .saved
    }
}

struct FlowerShowShareCardData: Equatable, Identifiable {
    static let appStoreURL = URL(string: "https://apps.apple.com/app/id6789952808")!

    let summary: FlowerShowResultSummary

    var id: UUID { summary.attemptID }
    var isCircuit: Bool { summary.context.kind == .circuit }
    var classNumberText: String { String(summary.context.classNumber) }
    var heading: String { isCircuit ? "Ringbloom Champion Circuit" : "Ringbloom Flower Show" }

    var achievementLine: String {
        if let milestone = summary.milestone { return "\(milestone.displayName) earned" }
        return "Class \(classNumberText) complete"
    }

    var classAndRatingLine: String {
        "Class \(classNumberText) · \(summary.rating.displayName.uppercased())"
    }

    var detailLine: String? {
        guard isCircuit == false, summary.milestone == nil else { return nil }
        switch summary.rating {
        case .radiant:
            return "\(summary.movesUsed) moves · no Hint · no Undo"
        case .flourishing:
            return earnedPlayFacts(summary)
        case .seedling:
            return summary.didUseHint ? "Hint used." : nil
        }
    }

    private func earnedPlayFacts(_ summary: FlowerShowResultSummary) -> String {
        let hint = summary.didUseHint ? "Hint used" : "no Hint"
        let undo = summary.didUseUndo ? "Undo used" : "no Undo"
        return "\(summary.movesUsed) moves · \(hint) · \(undo)"
    }

    var shareText: String {
        ([heading, achievementLine, classAndRatingLine]
            + (detailLine.map { [$0] } ?? [])
            + [Self.appStoreURL.absoluteString])
            .joined(separator: "\n")
    }

    var analyticsProperties: [String: Any] {
        [
            "class_number": summary.context.classNumber,
            "attempt_kind": summary.context.kind.rawValue,
            "rating": summary.rating.displayName.lowercased(),
            "milestone": summary.milestone?.rawValue ?? "none",
            "is_circuit": isCircuit,
        ]
    }
}

private extension FlowerShowMilestone {
    var displayName: String {
        switch self {
        case .rosette: "Rosette"
        case .grandChampion: "Grand Champion"
        case .perfectShow: "Perfect Show"
        case .circuitCup: "Circuit Cup"
        }
    }
}

private struct FlowerShowShareCard: View {
    let data: FlowerShowShareCardData

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 14) {
                Text(data.heading.uppercased())
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(RingbloomTheme.saffron)
                Text(data.achievementLine)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(RingbloomTheme.ivory)
                Text(data.classAndRatingLine)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(RingbloomTheme.mint)
                if let detailLine = data.detailLine {
                    Text(detailLine)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(RingbloomTheme.ivory)
                }
            }
            Spacer(minLength: 18)
            HStack(alignment: .bottom) {
                Text(FlowerShowShareCardData.appStoreURL.absoluteString)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(RingbloomTheme.muted)
                Spacer(minLength: 24)
                BloomMark()
                    .frame(width: 112, height: 112)
                    .accessibilityHidden(true)
            }
        }
        .padding(28)
        .frame(width: 600, height: 420, alignment: .leading)
        // Export at a stable size so a player’s Dynamic Type choice cannot crop a long Circuit class.
        .environment(\.dynamicTypeSize, .large)
        .background(RingbloomTheme.background)
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(RingbloomTheme.saffron.opacity(0.42), lineWidth: 2)
        }
    }
}

enum FlowerShowShareCardRenderer {
    @MainActor
    static func pngData(for data: FlowerShowShareCardData) -> Data? {
        let renderer = ImageRenderer(content: FlowerShowShareCard(data: data))
        renderer.scale = 3
        return renderer.uiImage?.pngData()
    }
}

struct FlowerShowShareCompletionGate {
    private(set) var didFinish = false

    mutating func consume(completed: Bool) -> Bool {
        guard didFinish == false else { return false }
        didFinish = true
        return completed
    }
}

@MainActor
private struct FlowerShowShareSheet: UIViewControllerRepresentable {
    let card: FlowerShowShareCardData
    let imageUnavailable: () -> Void
    let completion: (Bool) -> Void

    @MainActor
    final class Coordinator {
        private var gate = FlowerShowShareCompletionGate()

        func report(_ completed: Bool, completion: (Bool) -> Void) {
            guard gate.consume(completed: completed) else { return }
            completion(true)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        var items: [Any] = [card.shareText, FlowerShowShareCardData.appStoreURL]
        if let imageData = FlowerShowShareCardRenderer.pngData(for: card),
           let image = UIImage(data: imageData) {
            items.insert(image, at: 0)
        } else {
            Task { @MainActor in imageUnavailable() }
        }
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.view.accessibilityIdentifier = "flowerShowNativeShareSheet"
        controller.completionWithItemsHandler = { _, completed, _, _ in
            Task { @MainActor in
                context.coordinator.report(completed, completion: completion)
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
