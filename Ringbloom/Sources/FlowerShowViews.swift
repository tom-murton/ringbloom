import SwiftUI

struct ModeCardProgress {
    let value: Int
    let total: Int
    let caption: String
    let accessibilityValue: String
}

extension ModeCardProgress {
    static func flowerShow(
        highestGarden: Int,
        qualified: Bool,
        accessState: FlowerShowAccessState,
        completedFreeClasses: Int,
        completedCampaignClasses: Int
    ) -> Self? {
        if qualified == false {
            let value = min(1, max(0, highestGarden - 1))
            return Self(
                value: value,
                total: 1,
                caption: "GARDEN WON",
                accessibilityValue: "\(value) of 1 Garden won"
            )
        }

        switch accessState {
        case .checking:
            return Self(
                value: 1,
                total: 1,
                caption: "GARDEN WON",
                accessibilityValue: "1 of 1 Garden won"
            )
        case .sample:
            let value = min(FlowerShowAccessPolicy.freeClasses.count, max(0, completedFreeClasses))
            return Self(
                value: value,
                total: FlowerShowAccessPolicy.freeClasses.count,
                caption: "FREE CLASSES",
                accessibilityValue: "\(value) of 5 free Classes complete"
            )
        case .full:
            let value = min(FlowerShowClassDefinition.classCount, max(0, completedCampaignClasses))
            return Self(
                value: value,
                total: FlowerShowClassDefinition.classCount,
                caption: "CAMPAIGN CLASSES",
                accessibilityValue: "\(value) of 30 campaign Classes complete"
            )
        }
    }
}

struct ModeCard: View {
    let title: String
    let subtitle: String
    let detail: String?
    let progress: ModeCardProgress?
    let actionTitle: String
    let actionSymbol: String
    let prominent: Bool
    let locked: Bool
    let identifier: String
    let action: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(RingbloomTheme.ivory)
                    .accessibilityAddTraits(.isHeader)

                Text(subtitle)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(RingbloomTheme.ivory)

                if let detail {
                    Text(detail)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(RingbloomTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("\(identifier)Detail")
                }
            }

            if let progress {
                VStack(spacing: 4) {
                    HStack {
                        Text(progress.caption)
                        Spacer()
                        Text("\(progress.value) / \(progress.total)")
                            .contentTransition(.numericText())
                    }
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(RingbloomTheme.muted)

                    ProgressView(value: Double(progress.value), total: Double(progress.total))
                        .tint(RingbloomTheme.mint)
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(title.capitalized) unlock progress")
                .accessibilityValue(progress.accessibilityValue)
                .accessibilityIdentifier("\(identifier)Progress")
            }

            Button(action: action) {
                Label(actionTitle, systemImage: actionSymbol)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(RingbloomButtonStyle(prominent: prominent))
            .disabled(locked)
            .accessibilityHint(locked ? detail ?? "" : "")
            .accessibilityIdentifier(identifier)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(RingbloomTheme.inkLifted.opacity(locked ? 0.58 : 0.92))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    prominent
                        ? RingbloomTheme.saffron
                        : RingbloomTheme.ivory.opacity(contrast == .increased ? 0.42 : 0.16),
                    lineWidth: prominent ? 2 : 1
                )
        }
        .opacity(locked ? 0.82 : 1)
    }
}

enum FlowerShowRulesPresentation: Equatable {
    case preClass
    case inGame
}

struct FlowerShowRulesView: View {
    let definition: FlowerShowClassDefinition
    let completedCount: Int
    let seenIntroductions: Set<FlowerShowRule>
    let presentation: FlowerShowRulesPresentation
    let begin: () -> Void
    let close: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var briefingRevealed = false

    private var newRule: FlowerShowRule? {
        guard presentation == .preClass, let rule = definition.introducedRule else { return nil }
        return seenIntroductions.contains(rule) ? nil : rule
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    closeButton
                    title

                    if let newRule {
                        NewRuleDiagram(rule: newRule)
                        ruleCard(for: newRule, emphasised: true)
                    } else if presentation == .preClass {
                        classChanges
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        if presentation == .inGame {
                            ForEach(definition.activeRules) { rule in
                                ruleCard(for: rule, emphasised: false)
                            }

                            Divider().overlay(RingbloomTheme.ivory.opacity(0.16))
                        }

                        classStats

                        Label(
                            "1 HINT · 1 EXACT UNDO",
                            systemImage: "wand.and.stars.inverse"
                        )
                        .foregroundStyle(RingbloomTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .font(.system(.footnote, design: .rounded, weight: .medium))
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RingbloomTheme.inkLifted, in: RoundedRectangle(cornerRadius: 18))
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("flowerShowRules")

                    Button(action: begin) {
                        Label(actionTitle, systemImage: presentation == .preClass ? "play.fill" : "arrow.left")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(RingbloomButtonStyle(prominent: true))
                    .accessibilityIdentifier("flowerShowBeginButton")

                    Spacer(minLength: 12)
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollIndicators(.hidden)
        }
        .task(id: definition.number) {
            let milestone = definition.isRosetteClass
                || definition.number == 30
                || (definition.isChampionCircuit && (definition.number - 30).isMultiple(of: 8))
            briefingRevealed = presentation == .inGame || reduceMotion || milestone == false
            guard briefingRevealed == false else { return }
            try? await Task.sleep(nanoseconds: 180_000_000)
            withAnimation(.easeOut(duration: 0.2)) {
                briefingRevealed = true
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
            .accessibilityLabel(presentation == .preClass ? "Close class rules" : "Return to class")
            .accessibilityIdentifier("flowerShowRulesCloseButton")
        }
    }

    private var title: some View {
        VStack(spacing: 8) {
            Text(classLabel)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(RingbloomTheme.muted)

            if briefingBadge.isEmpty == false {
                Label(briefingBadge, systemImage: titleSymbol)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(RingbloomTheme.saffron)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(RingbloomTheme.saffron.opacity(0.12), in: Capsule())
            }

            Text(briefingHeadline)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .tracking(1.2)
                .multilineTextAlignment(.center)
                .foregroundStyle(RingbloomTheme.ivory)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("flowerShowRulesTitle")

            Text(briefingDetail)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(RingbloomTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var classChanges: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(definition.changesFromPrevious) { change in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: change.symbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(RingbloomTheme.saffron)
                        .frame(width: 26)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(change.title)
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(RingbloomTheme.ivory)
                        Text(change.detail)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(RingbloomTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RingbloomTheme.saffron.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(RingbloomTheme.saffron.opacity(0.55), lineWidth: 1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("flowerShowChange_\(change.id)")
            }
        }
        .opacity(briefingRevealed ? 1 : 0)
        .offset(y: briefingRevealed ? 0 : 10)
    }

    private var classStats: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TO WIN")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(RingbloomTheme.saffron)
            Label("\(definition.targetBlooms) blooms", systemImage: "leaf.fill")
            ForEach(definition.activeRules) { rule in
                Label(objectiveBrief(rule), systemImage: rule.symbol)
            }
            Divider().overlay(RingbloomTheme.ivory.opacity(0.15))
            Label(
                "\(definition.moveBudget) moves · \(definition.activeKindCount) petal kinds",
                systemImage: "arrow.clockwise"
            )
            Label(
                "Radiant: \(definition.radiantPar) moves or fewer · no Hint · no Undo",
                systemImage: "sparkles"
            )
        }
        .font(.system(.footnote, design: .rounded, weight: .medium))
        .foregroundStyle(RingbloomTheme.ivory)
        .accessibilityIdentifier("flowerShowClassStats")
    }

    private func classStat(title: String, value: Int, symbol: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .foregroundStyle(RingbloomTheme.mint)
                .accessibilityHidden(true)
            Text(value.formatted())
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(RingbloomTheme.ivory)
            Text(title)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(RingbloomTheme.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 68)
        .background(RingbloomTheme.ink, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title.capitalized)
        .accessibilityValue(value.formatted())
    }

    private var rosetteProgress: some View {
        let rosetteCount = min(
            FlowerShowClassDefinition.classCount / FlowerShowClassDefinition.rosetteInterval,
            completedCount / FlowerShowClassDefinition.rosetteInterval
        )

        return VStack(spacing: 8) {
            HStack {
                Text("ROSETTES")
                Spacer()
                Text("\(rosetteCount) / 6")
            }
            .font(.system(.caption2, design: .rounded, weight: .semibold))
            .tracking(1.1)
            .foregroundStyle(RingbloomTheme.muted)

            HStack(spacing: 12) {
                ForEach(1 ... 6, id: \.self) { number in
                    Image(systemName: number <= rosetteCount ? "seal.fill" : "seal")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(number <= rosetteCount ? RingbloomTheme.saffron : RingbloomTheme.muted)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RingbloomTheme.inkLifted.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Flower Show rosettes")
        .accessibilityValue("\(rosetteCount) of 6 earned")
        .accessibilityIdentifier("flowerShowRosetteProgress")
    }

    @ViewBuilder
    private func ruleCard(for rule: FlowerShowRule, emphasised: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: rule.symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(emphasised ? RingbloomTheme.saffron : RingbloomTheme.mint)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(rule.title.uppercased())
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(RingbloomTheme.ivory)
                Text(rule.instruction)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(RingbloomTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var actionTitle: String {
        presentation == .preClass ? "BEGIN CLASS" : "RETURN TO CLASS"
    }

    private var briefingTitle: String {
        if presentation == .inGame { return "CLASS RULES" }
        if newRule != nil { return "NEW RULE" }
        if definition.number == FlowerShowClassDefinition.classCount { return "GRAND CHAMPION FINAL" }
        if definition.isRosetteClass { return "ROSETTE CLASS" }
        if definition.isChampionCircuit { return "CHAMPION CIRCUIT" }
        return "NEW THIS CLASS"
    }

    private var briefingBadge: String {
        if presentation == .inGame { return "CLASS RULES" }
        if newRule != nil { return definition.introductionID == .doubleHarmony ? "RULE UPGRADE" : "NEW RULE" }
        if definition.number == 30 { return "GRAND CHAMPION FINAL" }
        if definition.isChampionCircuit, (definition.number - 30).isMultiple(of: 8) { return "CIRCUIT CUP" }
        if definition.isRosetteClass { return "ROSETTE CLASS" }
        return ""
    }

    private var briefingHeadline: String {
        if presentation == .inGame { return "HOW TO WIN" }
        return definition.changesFromPrevious.first?.title ?? briefingTitle
    }

    private var briefingDetail: String {
        if presentation == .inGame {
            return "Every active objective must be complete before the moves run out."
        }
        return definition.changesFromPrevious.first?.detail
            ?? "Complete every visible objective before the moves run out."
    }

    private func objectiveBrief(_ rule: FlowerShowRule) -> String {
        switch rule {
        case .ringHarmony:
            "Score after turning Inner, Middle and Outer"
        case .doubleHarmony:
            "Score twice after turning each ring"
        case .unbroken:
            "\(definition.objectives.unbrokenChain ?? 0) scoring turns in a row"
        case .bindweed:
            "Clear every tangled spoke"
        case .twinBloom:
            "\(definition.objectives.twinBloomTurns) Twin Bloom \(definition.objectives.twinBloomTurns == 1 ? "turn" : "turns")"
        case .prizeBouquet:
            "Bloom all four petal kinds"
        case .judgesOrder:
            definition.objectives.judgesOrder.map(\.displayName).joined(separator: " → ")
        }
    }

    private var titleSymbol: String {
        if let newRule { return newRule.symbol }
        if definition.number == FlowerShowClassDefinition.classCount { return "trophy.fill" }
        if definition.isRosetteClass { return "seal.fill" }
        return "medal.fill"
    }

    private var classLabel: String {
        definition.isChampionCircuit
            ? "CHAMPION CIRCUIT · CLASS \(definition.number)"
            : "\(definition.stageTitle.uppercased()) · CLASS \(definition.number) OF \(FlowerShowClassDefinition.classCount)"
    }

    private var progressCaption: String {
        if definition.isChampionCircuit {
            return "Endless Champion Circuit"
        }
        return "\(completedCount) of \(FlowerShowClassDefinition.classCount) judged classes complete"
    }
}

private struct NewRuleDiagram: View {
    let rule: FlowerShowRule

    var body: some View {
        Group {
            switch rule {
            case .ringHarmony:
                HStack(spacing: 10) {
                    diagramSymbol("i.circle.fill")
                    diagramSymbol("m.circle.fill")
                    diagramSymbol("o.circle.fill")
                    Image(systemName: "arrow.right")
                    diagramSymbol("sparkles")
                }
            case .unbroken:
                HStack(spacing: 8) {
                    ForEach(0 ..< 3, id: \.self) { index in
                        diagramSymbol("sparkle")
                        if index < 2 { Image(systemName: "link") }
                    }
                }
            case .bindweed:
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        diagramSymbol("leaf.fill")
                        Image(systemName: "arrow.right")
                        diagramSymbol("leaf.fill")
                        Image(systemName: "plus")
                        diagramSymbol("leaf.fill")
                    }
                    Text("SPREADING ADDS A STEM")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .tracking(1)
                }
            case .twinBloom:
                HStack(spacing: 12) {
                    diagramSymbol("arrow.clockwise")
                    Image(systemName: "arrow.right")
                    diagramSymbol("sparkles")
                    diagramSymbol("sparkles")
                }
            case .prizeBouquet:
                HStack(spacing: 12) {
                    ForEach(PetalKind.allCases) { kind in
                        Text(kind.glyph)
                            .font(.title2.weight(.bold))
                    }
                }
            case .doubleHarmony:
                HStack(spacing: 10) {
                    diagramSymbol("i.circle.fill")
                    diagramSymbol("m.circle.fill")
                    diagramSymbol("o.circle.fill")
                    Text("×2")
                        .font(.title2.bold())
                }
            case .judgesOrder:
                HStack(spacing: 10) {
                    diagramSymbol("i.circle.fill")
                    Image(systemName: "arrow.right")
                    diagramSymbol("m.circle.fill")
                    Image(systemName: "arrow.right")
                    diagramSymbol("o.circle.fill")
                }
            }
        }
        .foregroundStyle(RingbloomTheme.ivory)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, minHeight: 86)
        .background(RingbloomTheme.saffron.opacity(0.13), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(RingbloomTheme.saffron.opacity(0.7), lineWidth: 2)
        }
        .accessibilityHidden(true)
        .accessibilityIdentifier("newRuleDiagram")
    }

    private func diagramSymbol(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 26, weight: .semibold))
            .foregroundStyle(RingbloomTheme.saffron)
    }
}

struct FlowerShowAttentionBanner: View {
    let message: FlowerShowAttentionMessage

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: message.symbol)
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(RingbloomTheme.saffron)
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 3) {
                Text(message.title)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(RingbloomTheme.ivory)
                Text(message.detail)
                    .font(.system(.footnote, design: .rounded, weight: .medium))
                    .foregroundStyle(RingbloomTheme.ivory.opacity(0.84))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RingbloomTheme.saffron.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    RingbloomTheme.saffron.opacity(contrast == .increased ? 1 : 0.72),
                    lineWidth: 2
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message.title)
        .accessibilityValue(message.detail)
        .accessibilityIdentifier("flowerShowAttention")
    }
}

struct FlowerShowObjectiveProgress: View {
    let definition: FlowerShowClassDefinition
    let harmonyRings: Set<Ring>
    let streak: Int
    let bestStreak: Int
    let harmonyCredits: RingCredits
    let infectedSpokes: Set<Int>
    let bindweedSpreadCountdown: Int?
    let twinBloomTurns: Int
    let bouquetKinds: PetalKindMask
    let judgesOrderIndex: Int

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var showsGoals = false
    @AccessibilityFocusState private var goalsFocused: Bool

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 7) {
                    Button {
                        showsGoals = true
                    } label: {
                        Label("GOALS", systemImage: "checklist")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(RingbloomButtonStyle())
                    .accessibilityValue(goalsSummary)
                    .accessibilityFocused($goalsFocused)
                    .accessibilityIdentifier("flowerShowGoalsButton")

                    if infectedSpokes.isEmpty == false, bindweedSpreadCountdown == 1 {
                        Text("Bindweed spreads after 1 more turn")
                            .font(.system(.footnote, design: .rounded, weight: .bold))
                            .foregroundStyle(RingbloomTheme.saffron)
                            .accessibilityIdentifier("flowerShowUrgentGoal")
                    }
                }
            } else {
                objectiveRows
            }
        }
        .sheet(isPresented: $showsGoals, onDismiss: { goalsFocused = true }) {
            NavigationStack {
                ScrollView {
                    objectiveRows
                        .padding(20)
                }
                .background(RingbloomTheme.background.ignoresSafeArea())
                .navigationTitle("Class goals")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showsGoals = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("flowerShowObjectives")
    }

    @ViewBuilder
    private var objectiveRows: some View {
        VStack(spacing: 8) {
            if definition.objectives.requiresHarmony { harmonyProgress }
            if let requiredChain = definition.objectives.requiredUnbrokenChain {
                objectiveRow(
                    title: "UNBROKEN",
                    symbol: "link",
                    value: bestStreak >= requiredChain
                        ? "COMPLETE"
                        : "CURRENT \(min(streak, requiredChain)) / \(requiredChain) · BEST \(min(bestStreak, requiredChain))",
                    complete: bestStreak >= requiredChain,
                    accessibilityValue: bestStreak >= requiredChain
                        ? "Complete, chain of \(requiredChain) achieved"
                        : "Current run \(streak) of \(requiredChain), best \(bestStreak)",
                    identifier: "unbrokenProgress"
                )
            }
            if definition.objectives.startingBindweedSpokes.isEmpty == false {
                objectiveRow(
                    title: "CLEAR BINDWEED",
                    symbol: infectedSpokes.isEmpty ? "checkmark.seal.fill" : "leaf.arrow.triangle.circlepath",
                    value: bindweedValue,
                    complete: infectedSpokes.isEmpty,
                    accessibilityValue: bindweedAccessibilityValue,
                    identifier: "bindweedProgress"
                )
            }
            if definition.objectives.requiresTwinBloom {
                let required = definition.objectives.twinBloomTurns
                objectiveRow(
                    title: "TWIN BLOOM",
                    symbol: twinBloomTurns >= required ? "sparkles.rectangle.stack.fill" : "sparkles.rectangle.stack",
                    value: "\(min(twinBloomTurns, required)) / \(required)",
                    complete: twinBloomTurns >= required,
                    accessibilityValue: "\(min(twinBloomTurns, required)) of \(required) qualifying turns",
                    identifier: "twinBloomProgress"
                )
            }
            if definition.objectives.bouquetKinds.isEmpty == false {
                bouquetProgress
            }
            if definition.objectives.judgesOrder.isEmpty == false {
                judgesOrderProgress
            }
        }
    }

    private func objectiveRow(
        title: String,
        symbol: String,
        value: String,
        complete: Bool,
        accessibilityValue: String,
        identifier: String
    ) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 5) {
                    Label(title, systemImage: symbol)
                    Text(value)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 8) {
                    Label(title, systemImage: symbol)
                    Spacer(minLength: 8)
                    Text(value)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .font(.system(.caption2, design: .rounded, weight: .semibold))
        .tracking(0.9)
        .foregroundStyle(complete ? RingbloomTheme.mint : RingbloomTheme.ivory)
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(RingbloomTheme.inkLifted.opacity(0.94), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    complete
                        ? RingbloomTheme.mint
                        : RingbloomTheme.ivory.opacity(contrast == .increased ? 0.52 : 0.14),
                    lineWidth: complete ? 2 : 1
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) objective")
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier(identifier)
    }

    private var harmonyProgress: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 6))
            : AnyLayout(HStackLayout(spacing: 6))

        return VStack(alignment: .leading, spacing: 6) {
            Text("RING HARMONY")
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(RingbloomTheme.muted)

            layout {
                ForEach(Ring.allCases) { ring in
                    let required = definition.objectives.harmonyCreditsPerRing
                    let credit = min(harmonyCredits[ring], required)
                    let complete = credit >= required
                    Label("\(ring.shortName) \(credit)/\(required)", systemImage: complete ? "checkmark.circle.fill" : "circle")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(complete ? RingbloomTheme.mint : RingbloomTheme.ivory)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(RingbloomTheme.inkLifted.opacity(0.94), in: RoundedRectangle(cornerRadius: 10))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    complete
                                        ? RingbloomTheme.mint
                                        : RingbloomTheme.ivory.opacity(contrast == .increased ? 0.52 : 0.14),
                                    lineWidth: complete ? 2 : 1
                                )
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(ring.displayName) ring")
                        .accessibilityValue("\(credit) of \(required) Harmony credits")
                        .accessibilityIdentifier("harmony\(ring.displayName)Progress")
                }
            }
        }
    }

    private var bouquetProgress: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("PRIZE BOUQUET")
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(RingbloomTheme.muted)
            HStack(spacing: 6) {
                ForEach(PetalKind.allCases) { kind in
                    let collected = bouquetKinds.contains(PetalKindMask(kind))
                    VStack(spacing: 3) {
                        Text(kind.glyph)
                            .font(.headline)
                        Text(kind.displayName.uppercased())
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(collected ? RingbloomTheme.mint : RingbloomTheme.ivory)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(RingbloomTheme.inkLifted, in: RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(collected ? RingbloomTheme.mint : RingbloomTheme.ivory.opacity(0.16), lineWidth: collected ? 2 : 1)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(kind.displayName)
                    .accessibilityValue(collected ? "Collected" : "Still needed")
                }
            }
        }
        .accessibilityIdentifier("bouquetProgress")
    }

    private var judgesOrderProgress: some View {
        let order = definition.objectives.judgesOrder
        return VStack(alignment: .leading, spacing: 7) {
            Text("JUDGES' ORDER")
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(RingbloomTheme.muted)
            HStack(spacing: 6) {
                ForEach(Array(order.enumerated()), id: \.offset) { index, ring in
                    let complete = index < judgesOrderIndex
                    let next = index == judgesOrderIndex
                    VStack(spacing: 2) {
                        Text(ring.shortName)
                        if next { Text("NEXT").font(.system(size: 8, weight: .bold)) }
                    }
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(complete ? RingbloomTheme.mint : (next ? RingbloomTheme.saffron : RingbloomTheme.ivory))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(RingbloomTheme.inkLifted, in: RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(next ? RingbloomTheme.saffron : RingbloomTheme.ivory.opacity(0.14), lineWidth: next ? 2 : 1)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Judges' Order")
        .accessibilityValue(orderAccessibilityValue)
        .accessibilityIdentifier("judgesOrderProgress")
    }

    private var orderAccessibilityValue: String {
        let order = definition.objectives.judgesOrder
        guard judgesOrderIndex < order.count else { return "Complete" }
        let remaining = order.dropFirst(judgesOrderIndex).map(\.displayName).joined(separator: ", then ")
        return "\(judgesOrderIndex) of \(order.count) complete. \(remaining)"
    }

    private var goalsSummary: String {
        let objectives = definition.objectives
        let completionByID: [FlowerShowObjectiveID: Bool] = [
            .harmony: harmonyCredits.satisfies(objectives.harmonyCreditsPerRing),
            .unbroken: objectives.unbrokenChain.map { bestStreak >= $0 } ?? false,
            .bindweed: infectedSpokes.isEmpty,
            .twinBloom: twinBloomTurns >= objectives.twinBloomTurns,
            .prizeBouquet: bouquetKinds.isSuperset(of: objectives.bouquetKinds),
            .judgesOrder: judgesOrderIndex >= objectives.judgesOrder.count,
        ]
        let active = objectives.activeIDs
        let complete = active.filter { completionByID[$0] == true }.count
        return "\(complete) of \(active.count) goals complete. Double tap for details."
    }

    private var bindweedValue: String {
        guard infectedSpokes.isEmpty == false else { return "CLEARED" }
        let countdown = bindweedSpreadCountdown ?? FlowerShowClassDefinition.bindweedSpreadInterval
        return "\(infectedSpokes.count) LEFT · SPREADS IN \(countdown)"
    }

    private var bindweedAccessibilityValue: String {
        guard infectedSpokes.isEmpty == false else { return "Complete, all Bindweed cleared" }
        let countdown = bindweedSpreadCountdown ?? FlowerShowClassDefinition.bindweedSpreadInterval
        let stems = infectedSpokes.count == 1 ? "stem" : "stems"
        return "\(infectedSpokes.count) tangled \(stems) left. Clear all Bindweed to win. Spreads in \(countdown) turns"
    }
}
