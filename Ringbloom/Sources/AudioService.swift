import AVFoundation
import Combine
import Foundation

/// Owns Ringbloom's short sound effects and keeps all AVFoundation state on the
/// main actor. Audio is optional: a missing file or unavailable audio device is
/// treated as silence rather than a fatal error.
@MainActor
final class AudioService: ObservableObject {
    enum Sound: String, CaseIterable, Sendable {
        case rotate
        case bloom
        case win
        case lose
    }

    static let shared = AudioService()

    @Published var isSoundEnabled: Bool {
        didSet {
            guard isSoundEnabled != oldValue else { return }
            defaults.set(isSoundEnabled, forKey: Self.soundEnabledKey)

            if isSoundEnabled {
                configureAudioSession()
                preparePlayers()
            } else {
                stopAll()
            }
        }
    }

    /// Convenience spelling for call sites that do not use the `is` prefix.
    var soundEnabled: Bool {
        get { isSoundEnabled }
        set { isSoundEnabled = newValue }
    }

    private static let soundEnabledKey = "ringbloom.soundEnabled"

    private let defaults: UserDefaults
    private var players: [Sound: AVAudioPlayer] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isSoundEnabled = defaults.object(forKey: Self.soundEnabledKey) as? Bool ?? true

        configureAudioSession()
        preparePlayers()
    }

    @discardableResult
    func toggleSound() -> Bool {
        isSoundEnabled.toggle()
        return isSoundEnabled
    }

    func setSoundEnabled(_ enabled: Bool) {
        isSoundEnabled = enabled
    }

    func play(_ sound: Sound) {
        guard isSoundEnabled else { return }

        configureAudioSession()

        if players[sound] == nil {
            players[sound] = makePlayer(for: sound)
        }

        guard let player = players[sound] else { return }
        player.currentTime = 0
        player.play()
    }

    func playRotate() {
        play(.rotate)
    }

    func playBloom() {
        play(.bloom)
    }

    func playWin() {
        play(.win)
    }

    func playLose() {
        play(.lose)
    }

    func stopAll() {
        for player in players.values {
            player.stop()
            player.currentTime = 0
        }
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()

        // Ambient audio respects the mute switch and mixes with audio the player
        // already has running, which suits a calm puzzle game.
        do {
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // Audio can be unavailable on Simulator or during an interruption.
            // The next sound attempt will retry; gameplay remains unaffected.
        }
    }

    private func preparePlayers() {
        guard isSoundEnabled else { return }

        for sound in Sound.allCases where players[sound] == nil {
            players[sound] = makePlayer(for: sound)
        }
    }

    private func makePlayer(for sound: Sound) -> AVAudioPlayer? {
        guard let url = resourceURL(for: sound) else { return nil }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = 0
            player.volume = 1
            player.prepareToPlay()
            return player
        } catch {
            return nil
        }
    }

    private func resourceURL(for sound: Sound) -> URL? {
        let bundle = Bundle.main

        // Xcode normally flattens file resources into the bundle root, while
        // folder-reference based projects preserve the Audio directory.
        return bundle.url(forResource: sound.rawValue, withExtension: "mp3")
            ?? bundle.url(forResource: sound.rawValue, withExtension: "mp3", subdirectory: "Audio")
            ?? bundle.url(forResource: sound.rawValue, withExtension: "mp3", subdirectory: "Resources/Audio")
    }
}
