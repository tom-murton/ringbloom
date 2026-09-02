import Combine
import Foundation
import UIKit

/// Centralizes optional tactile feedback. UIKit feedback generators are
/// main-thread APIs, so the service is explicitly main-actor isolated.
@MainActor
final class FeedbackService: ObservableObject {
    enum Feedback: Sendable {
        case selection
        case rotation
        case bloom
        case success
        case failure
    }

    static let shared = FeedbackService()

    @Published var isHapticsEnabled: Bool {
        didSet {
            guard isHapticsEnabled != oldValue else { return }
            defaults.set(isHapticsEnabled, forKey: Self.hapticsEnabledKey)

            if isHapticsEnabled {
                prepare()
            }
        }
    }

    /// Convenience spelling for call sites that do not use the `is` prefix.
    var hapticsEnabled: Bool {
        get { isHapticsEnabled }
        set { isHapticsEnabled = newValue }
    }

    private static let hapticsEnabledKey = "ringbloom.hapticsEnabled"

    private let defaults: UserDefaults
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let rotationGenerator = UIImpactFeedbackGenerator(style: .light)
    private let bloomGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isHapticsEnabled = defaults.object(forKey: Self.hapticsEnabledKey) as? Bool ?? true

        if isHapticsEnabled {
            prepare()
        }
    }

    @discardableResult
    func toggleHaptics() -> Bool {
        isHapticsEnabled.toggle()
        return isHapticsEnabled
    }

    func setHapticsEnabled(_ enabled: Bool) {
        isHapticsEnabled = enabled
    }

    func prepare() {
        guard isHapticsEnabled else { return }
        selectionGenerator.prepare()
        rotationGenerator.prepare()
        bloomGenerator.prepare()
        notificationGenerator.prepare()
    }

    func play(_ feedback: Feedback) {
        guard isHapticsEnabled else { return }

        switch feedback {
        case .selection:
            selectionGenerator.selectionChanged()
            selectionGenerator.prepare()
        case .rotation:
            rotationGenerator.impactOccurred(intensity: 0.55)
            rotationGenerator.prepare()
        case .bloom:
            bloomGenerator.impactOccurred(intensity: 0.8)
            bloomGenerator.prepare()
        case .success:
            notificationGenerator.notificationOccurred(.success)
            notificationGenerator.prepare()
        case .failure:
            notificationGenerator.notificationOccurred(.warning)
            notificationGenerator.prepare()
        }
    }

    func selectionChanged() {
        play(.selection)
    }

    func rotation() {
        play(.rotation)
    }

    func bloom() {
        play(.bloom)
    }

    func success() {
        play(.success)
    }

    func failure() {
        play(.failure)
    }
}
