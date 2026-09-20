import FeedbackKit
import SwiftUI

enum AppFeedbackConfiguration {
    static let value = FeedbackConfiguration(
        dataAPIEndpoint: URL(
            string: "https://ep-ancient-mode-za1m98g1.apirest.c-2.eu-west-2.aws.neon.tech/app_services/rest/v1"
        )!,
        authEndpoint: URL(
            string: "https://ep-ancient-mode-za1m98g1.neonauth.c-2.eu-west-2.aws.neon.tech/app_services/auth"
        )!,
        appID: "ringbloom",
        appName: "Ringbloom"
    )
}

enum FeedbackSource: String {
    case home
    case settings
    case afterSession = "after_session"
}

struct AppFeedbackSheet: View {
    let source: FeedbackSource

    @EnvironmentObject private var analytics: ProductAnalytics
    @EnvironmentObject private var prompts: FeedbackPromptCoordinator
    @State private var recordedOpen = false

    var body: some View {
        FeedbackSheet(
            configuration: AppFeedbackConfiguration.value,
            source: source.rawValue,
            sender: Self.sender,
            successButtonTextColor: RingbloomTheme.ink,
            onSendEvent: { event in
                let name = switch event.kind {
                case .attempt: "feedback_send_attempted"
                case .success: "feedback_send_succeeded"
                case .failure: "feedback_send_failed"
                }
                analytics.capture(name, properties: ["source": event.source])
            },
            onSubmitted: { _ in prompts.recordFeedbackSubmitted() }
        )
        .tint(RingbloomTheme.saffron)
        .onAppear {
            guard !recordedOpen else { return }
            recordedOpen = true
            prompts.recordFeedbackOpened()
            analytics.capture("feedback_opened", properties: ["source": source.rawValue])
        }
    }

    private static var sender: (any FeedbackSending)? {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--feedback-offline") {
                return OfflineFeedbackSender()
            }
        #endif
        return nil
    }
}

#if DEBUG
    private struct OfflineFeedbackSender: FeedbackSending {
        func send(_: FeedbackSubmission) async throws {
            throw FeedbackError.unavailable
        }
    }
#endif

struct HomeFeedbackCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(.title3, weight: .semibold))
                    .foregroundStyle(RingbloomTheme.saffron)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Help Ringbloom grow")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(RingbloomTheme.ivory)

                    Text("Share an idea, feature request or suggestion. Your feedback can help shape what comes next.")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(RingbloomTheme.muted)

                    Text("Anonymous. No email needed, and we can’t reply individually.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(RingbloomTheme.muted)
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RingbloomTheme.muted)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(RingbloomTheme.inkLifted)
            .clipShape(.rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(RingbloomTheme.saffron.opacity(0.3), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the anonymous feedback form for ideas, suggestions and problems")
        .accessibilityIdentifier("home.feedback")
    }
}

struct FeedbackNudgeCallout: View {
    let viewportHeight: CGFloat
    let openFeedback: () -> Void
    let dismiss: () -> Void

    @EnvironmentObject private var analytics: ProductAnalytics
    @EnvironmentObject private var prompts: FeedbackPromptCoordinator
    @State private var recordedDisplay = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Help shape the next bloom", systemImage: "sparkles")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(RingbloomTheme.ivory)

            Text("Enjoyed a Garden or spotted something that could be better? Share an idea for what Ringbloom grows into next.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(RingbloomTheme.muted)

            ViewThatFits {
                HStack(spacing: 10) { actions }
                VStack(spacing: 10) { actions }
            }

            Text("Feedback is anonymous, with no individual reply channel.")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(RingbloomTheme.muted)
        }
        .multilineTextAlignment(.leading)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RingbloomTheme.inkLifted)
        .clipShape(.rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(RingbloomTheme.saffron.opacity(0.35), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("feedbackNudge")
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        recordDisplayIfVisible(proxy.frame(in: .named("gameResultScroll")))
                    }
                    .onChange(of: proxy.frame(in: .named("gameResultScroll"))) { _, frame in
                        recordDisplayIfVisible(frame)
                    }
            }
        }
    }

    private func recordDisplayIfVisible(_ frame: CGRect) {
        guard !recordedDisplay else { return }
        let visibleHeight = min(frame.maxY, viewportHeight) - max(frame.minY, 0)
        guard visibleHeight >= min(44, frame.height * 0.25) else { return }
        recordedDisplay = true
        if prompts.markFeedbackNudgeShown() {
            analytics.capture("feedback_nudge_shown", properties: [
                "source": FeedbackSource.afterSession.rawValue,
            ])
        }
    }

    @ViewBuilder
    private var actions: some View {
        Button("Share an idea", action: openFeedback)
            .buttonStyle(RingbloomButtonStyle(prominent: true))
            .accessibilityHint("Opens the anonymous feedback form")
            .accessibilityIdentifier("feedbackNudge.share")

        Button("Not now") {
            prompts.dismissFeedbackNudge()
            analytics.capture("feedback_nudge_dismissed", properties: [
                "reason": "not_now",
                "source": FeedbackSource.afterSession.rawValue,
            ])
            dismiss()
        }
        .buttonStyle(RingbloomButtonStyle())
        .accessibilityIdentifier("feedbackNudge.notNow")
    }
}

struct RingbloomSettingsView: View {
    let requestTutorial: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var analytics: ProductAnalytics
    @EnvironmentObject private var audio: AudioService
    @EnvironmentObject private var feedback: FeedbackService
    @EnvironmentObject private var prompts: FeedbackPromptCoordinator
    @State private var showsFeedback = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    settingsCard {
                        SettingsToggleRow(
                            title: "Sound",
                            detail: "Music and game sounds",
                            symbol: audio.isSoundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                            isOn: Binding(
                                get: { audio.isSoundEnabled },
                                set: { newValue in
                                    audio.setSoundEnabled(newValue)
                                    captureSetting("sound", enabled: newValue)
                                }
                            ),
                            identifier: "soundToggle"
                        )
                        Divider().overlay(RingbloomTheme.ivory.opacity(0.12))
                        SettingsToggleRow(
                            title: "Haptics",
                            detail: "Tactile turn and bloom feedback",
                            symbol: "waveform.path",
                            isOn: Binding(
                                get: { feedback.isHapticsEnabled },
                                set: { newValue in
                                    feedback.setHapticsEnabled(newValue)
                                    captureSetting("haptics", enabled: newValue)
                                }
                            ),
                            identifier: "hapticsToggle"
                        )
                    }

                    settingsCard {
                        Button {
                            showsFeedback = true
                        } label: {
                            SettingsActionRow(
                                title: "Send feedback",
                                detail: "Ideas, feature requests or problems. Collected anonymously; we can’t reply individually.",
                                symbol: "bubble.left.and.bubble.right.fill"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.feedback")

                        Divider().overlay(RingbloomTheme.ivory.opacity(0.12))

                        SettingsToggleRow(
                            title: "Feedback reminders",
                            detail: "Occasional invitations after a completed game",
                            symbol: "bell.badge",
                            isOn: Binding(
                                get: { prompts.feedbackRemindersEnabled },
                                set: { enabled in
                                    prompts.setFeedbackRemindersEnabled(enabled)
                                    captureSetting("feedback_reminders", enabled: enabled)
                                }
                            ),
                            identifier: "feedbackRemindersToggle"
                        )
                    }

                    settingsCard {
                        Button {
                            requestTutorial()
                            dismiss()
                        } label: {
                            SettingsActionRow(
                                title: "How to Play",
                                detail: "Replay the rules and first-bloom guide",
                                symbol: "questionmark.circle"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("howToPlayButton")

                        Divider().overlay(RingbloomTheme.ivory.opacity(0.12))

                        Button {
                            analytics.capture("rating_link_tapped", properties: [
                                "destination": RatingLink.destinationIdentifier,
                                "screen": "settings",
                            ])
                            openURL(RatingLink.url)
                        } label: {
                            SettingsActionRow(
                                title: "Rate Ringbloom",
                                detail: "Open Ringbloom’s App Store review page",
                                symbol: "star"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("rateRingbloomButton")
                    }

                    Text("Version \(version)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(RingbloomTheme.muted)
                }
                .padding(20)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
            }
            .background(RingbloomTheme.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("settingsDoneButton")
                }
            }
            .sheet(isPresented: $showsFeedback) {
                AppFeedbackSheet(source: .settings)
            }
        }
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private func captureSetting(_ setting: String, enabled: Bool) {
        analytics.capture("setting_changed", properties: [
            "enabled": enabled,
            "screen": "settings",
            "setting": setting,
        ])
    }

    private func settingsCard(@ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 12, content: content)
            .padding(16)
            .background(RingbloomTheme.inkLifted)
            .clipShape(.rect(cornerRadius: 16))
    }
}

private struct SettingsActionRow: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .frame(width: 24)
                .foregroundStyle(RingbloomTheme.saffron)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(RingbloomTheme.ivory)
                Text(detail)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(RingbloomTheme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(RingbloomTheme.muted)
                .accessibilityHidden(true)
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let detail: String
    let symbol: String
    @Binding var isOn: Bool
    let identifier: String

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .frame(width: 24)
                    .foregroundStyle(RingbloomTheme.saffron)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(RingbloomTheme.ivory)
                    Text(detail)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(RingbloomTheme.muted)
                }
            }
        }
        .tint(RingbloomTheme.saffron)
        .frame(minHeight: 44)
        .accessibilityIdentifier(identifier)
    }
}
