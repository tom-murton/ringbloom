import SwiftUI

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

    @AccessibilityFocusState private var titleFocused: Bool

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
