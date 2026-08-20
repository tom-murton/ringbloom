import SwiftUI

struct FlowerShowClassBookView: View {
    let ratings: [Int: FlowerShowRating]
    let nextCampaignClass: Int
    let savedAttempt: FlowerShowAttemptContext?
    let grandChampion: Bool
    let perfectShow: Bool
    let radiantCount: Int
    let accessState: FlowerShowAccessState
    let selectClass: (Int) -> Void
    let purchase: (Int) -> Void
    let close: () -> Void

    @AccessibilityFocusState private var focusedClass: Int?

    private let stages: [(name: String, range: ClosedRange<Int>)] = [
        ("Harmony Heats", 1 ... 5),
        ("Unbroken Heats", 6 ... 10),
        ("Bindweed Trials", 11 ... 15),
        ("Twin Bloom Heats", 16 ... 20),
        ("Bouquet Selection", 21 ... 25),
        ("Championship", 26 ... 30),
    ]

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 20) {
                    header
                    masterySummary

                    if let savedAttempt {
                        Label(savedAttemptLabel(savedAttempt), systemImage: "bookmark.fill")
                            .font(.system(.footnote, design: .rounded, weight: .semibold))
                            .foregroundStyle(RingbloomTheme.saffron)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RingbloomTheme.saffron.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                            .accessibilityIdentifier("classBookSavedAttempt")
                    }

                    ForEach(stages, id: \.name) { stage in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(stage.name.uppercased())
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .tracking(1.1)
                                .foregroundStyle(RingbloomTheme.ivory)
                                .accessibilityAddTraits(.isHeader)

                            classGrid(stage.range)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityIdentifier("flowerShowClassBook")
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("CLASS BOOK")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .tracking(1.3)
                    .foregroundStyle(RingbloomTheme.ivory)
                    .accessibilityAddTraits(.isHeader)
                Text("Replay completed Classes to improve their rating.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(RingbloomTheme.muted)
            }
            Spacer()
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .foregroundStyle(RingbloomTheme.ivory)
            .accessibilityLabel("Close Class Book")
            .accessibilityIdentifier("classBookCloseButton")
        }
        .padding(.top, 12)
    }

    private var masterySummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            if grandChampion {
                Label("GRAND CHAMPION", systemImage: "trophy.fill")
            } else {
                Label("\(ratings.count) OF 30 COMPLETE", systemImage: "medal.fill")
            }
            Label("\(radiantCount) RADIANT CLASS RATINGS", systemImage: "sparkles")
            if perfectShow {
                Label("PERFECT SHOW", systemImage: "crown.fill")
            }
        }
        .font(.system(.subheadline, design: .rounded, weight: .bold))
        .foregroundStyle(RingbloomTheme.ivory)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RingbloomTheme.inkLifted, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(perfectShow ? RingbloomTheme.saffron : RingbloomTheme.ivory.opacity(0.16), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("classBookMasterySummary")
    }

    @ViewBuilder
    private func classGrid(_ range: ClosedRange<Int>) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(range), id: \.self, content: classTile)
        }
    }

    private func classTile(_ number: Int) -> some View {
        let definition = FlowerShowClassDefinition.classNumber(number)
        let rating = ratings[number]
        let progressionUnlocked = rating != nil || number == nextCampaignClass
        let purchaseLocked = number > FlowerShowAccessPolicy.freeClasses.upperBound && accessState == .sample
        let accessChecking = number > FlowerShowAccessPolicy.freeClasses.upperBound && accessState == .checking
        let playable = progressionUnlocked && !purchaseLocked && !accessChecking
        let interactive = playable || purchaseLocked
        let isCurrent = number == nextCampaignClass && rating == nil

        return Button {
            if purchaseLocked {
                focusedClass = number
                purchase(number)
                return
            }
            guard playable else { return }
            focusedClass = number
            selectClass(number)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isCurrent ? RingbloomTheme.saffron : RingbloomTheme.ink)
                    Text(number.formatted())
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(isCurrent ? RingbloomTheme.ink : RingbloomTheme.ivory)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("CLASS \(number)")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .tracking(0.7)
                        if definition.isRosetteClass {
                            Image(systemName: "seal.fill")
                                .foregroundStyle(RingbloomTheme.saffron)
                                .accessibilityHidden(true)
                        }
                    }
                    Text(
                        tileStatus(
                            rating: rating,
                            current: isCurrent,
                            progressionUnlocked: progressionUnlocked,
                            purchaseLocked: purchaseLocked,
                            accessChecking: accessChecking
                        )
                    )
                        .font(.system(.footnote, design: .rounded, weight: .semibold))
                        .foregroundStyle(rating == .radiant ? RingbloomTheme.saffron : RingbloomTheme.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: playable ? "chevron.right" : "lock.fill")
                    .foregroundStyle(RingbloomTheme.muted)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(RingbloomTheme.inkLifted.opacity(interactive ? 0.95 : 0.48), in: RoundedRectangle(cornerRadius: 15))
            .overlay {
                RoundedRectangle(cornerRadius: 15)
                    .stroke(isCurrent ? RingbloomTheme.saffron : RingbloomTheme.ivory.opacity(0.12), lineWidth: isCurrent ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(
            accessibilityLabel(
                number: number,
                rating: rating,
                current: isCurrent,
                progressionUnlocked: progressionUnlocked,
                purchaseLocked: purchaseLocked,
                accessChecking: accessChecking
            )
        )
        .accessibilityHint(
            accessChecking
                ? "Access is being checked."
                : (purchaseLocked
                ? "Open the Flower Show purchase screen"
                : (rating != nil ? "Replay Class" : (isCurrent ? "Begin current Class" : "")))
        )
        .accessibilityFocused($focusedClass, equals: number)
        .disabled(interactive == false)
        .accessibilityIdentifier("classBookClass\(number)")
    }

    private func tileStatus(
        rating: FlowerShowRating?,
        current: Bool,
        progressionUnlocked: Bool,
        purchaseLocked: Bool,
        accessChecking: Bool
    ) -> String {
        if let rating {
            let ratingText = rating.displayName.uppercased()
            if accessChecking { return "\(ratingText) · CHECKING…" }
            if purchaseLocked { return "\(ratingText) · FULL SHOW REQUIRED" }
            return ratingText
        }
        if accessChecking { return "CHECKING…" }
        if purchaseLocked { return "FULL SHOW REQUIRED" }
        if current { return "CURRENT" }
        return progressionUnlocked ? "AVAILABLE" : "LOCKED"
    }

    private func accessibilityLabel(
        number: Int,
        rating: FlowerShowRating?,
        current: Bool,
        progressionUnlocked: Bool,
        purchaseLocked: Bool,
        accessChecking: Bool
    ) -> String {
        let stage = FlowerShowClassDefinition.classNumber(number).stageTitle
        if let rating {
            if accessChecking {
                return "Class \(number), \(stage), completed, best Class rating \(rating.displayName). Access is being checked before replay."
            }
            if purchaseLocked {
                return "Class \(number), \(stage), completed, best Class rating \(rating.displayName). Full Flower Show required to replay."
            }
            return "Class \(number), \(stage), completed, best Class rating \(rating.displayName). Replay."
        }
        if accessChecking { return "Class \(number), \(stage), access is being checked." }
        if purchaseLocked { return "Class \(number), \(stage), locked. Full Flower Show required." }
        if current { return "Class \(number), \(stage), current. Begin Class." }
        return "Class \(number), \(stage), \(progressionUnlocked ? "available" : "locked")."
    }

    private func savedAttemptLabel(_ context: FlowerShowAttemptContext) -> String {
        switch context.kind {
        case .campaign: "SAVED CAMPAIGN · CLASS \(context.classNumber)"
        case .replay: "SAVED REPLAY · CLASS \(context.classNumber)"
        case .circuit: "SAVED CIRCUIT · CLASS \(context.classNumber)"
        }
    }
}
