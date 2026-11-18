import AVFoundation

/// Keeps the music and soft game cues in sync with the saved sound preferences.
final class AudioManager: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioManager()

    private var musicPlayer: AVAudioPlayer?
    private var activeEffects: [ObjectIdentifier: AVAudioPlayer] = [:]
    private var musicEnabled = true
    private var effectsEnabled = true

    private override init() {
        super.init()
        configureAudioSession()
        prepareMusic()
    }

    func updateSettings(musicEnabled: Bool, effectsEnabled: Bool) {
        setEffectsEnabled(effectsEnabled)
        setMusicEnabled(musicEnabled)
    }

    func setEffectsEnabled(_ enabled: Bool) {
        effectsEnabled = enabled
        if !enabled {
            activeEffects.values.forEach { $0.stop() }
            activeEffects.removeAll()
        }
    }

    func setMusicEnabled(_ enabled: Bool) {
        musicEnabled = enabled
        guard let musicPlayer else {
            if enabled { prepareMusic() }
            return
        }
        if enabled {
            if !musicPlayer.isPlaying { musicPlayer.play() }
        } else {
            musicPlayer.pause()
        }
    }

    /// The chime's playback rate rises in small steps, so clean passes build a gentle sense of lift.
    func playGateChime(gate: Int) {
        let rate = min(1.48, 1.0 + Float(max(0, gate - 1)) * 0.004)
        playEffect(named: "gate_chime", rate: rate)
    }

    func playMilestoneChime() {
        playEffect(named: "milestone_chime", rate: 1)
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // Audio can still play with the system's current session configuration.
        }
    }

    private func prepareMusic() {
        guard musicPlayer == nil,
              let url = Bundle.main.url(forResource: "ambient_loop", withExtension: "m4a") else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0.34
            player.prepareToPlay()
            musicPlayer = player
            if musicEnabled { player.play() }
        } catch {
            musicPlayer = nil
        }
    }

    private func playEffect(named name: String, rate: Float) {
        guard effectsEnabled,
              let url = Bundle.main.url(forResource: name, withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.delegate = self
        player.enableRate = true
        player.rate = rate
        player.volume = name == "gate_chime" ? 0.24 : 0.34
        activeEffects[ObjectIdentifier(player)] = player
        player.prepareToPlay()
        player.play()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        activeEffects.removeValue(forKey: ObjectIdentifier(player))
    }
}
