import AVFoundation

/// Keeps the music and soft game cues in sync with the saved sound preferences.
///
/// Chimes go through an AVAudioEngine that is started once and kept running.
/// Each chime is just a pre-decoded buffer scheduled on a player node, done on a
/// background queue. Earlier, AVAudioPlayer.play() ran on the main thread at the
/// moment the puck passed a gate and stalled the game for 2–3 frames.
final class AudioManager {
    static let shared = AudioManager()

    private struct Voice {
        let player: AVAudioPlayerNode
        let varispeed: AVAudioUnitVarispeed
    }

    private var musicPlayer: AVAudioPlayer?
    private var musicEnabled = true
    private var effectsEnabled = true

    private let engine = AVAudioEngine()
    private let audioQueue = DispatchQueue(label: "northernlights.audio", qos: .userInitiated)
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var voices: [String: [Voice]] = [:]
    private var nextVoice: [String: Int] = [:]
    private static let effectVolume: [String: Float] = ["gate_chime": 0.24, "milestone_chime": 0.34]

    private init() {
        configureAudioSession()
        prepareMusic()
        audioQueue.async { self.setUpEffects() }
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil) { [weak self] _ in
            self?.audioQueue.async { self?.startEngineIfNeeded() }
        }
    }

    func updateSettings(musicEnabled: Bool, effectsEnabled: Bool) {
        setEffectsEnabled(effectsEnabled)
        setMusicEnabled(musicEnabled)
    }

    func setEffectsEnabled(_ enabled: Bool) {
        effectsEnabled = enabled
        if !enabled {
            audioQueue.async { self.voices.values.flatMap { $0 }.forEach { $0.player.stop() } }
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

    /// Kept for callers; effects load in the background at launch.
    func preloadEffects() {}

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

    // MARK: - Effects engine (audioQueue only)

    private func setUpEffects() {
        for (name, count) in [("gate_chime", 4), ("milestone_chime", 2)] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
                  let file = try? AVAudioFile(forReading: url),
                  let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                frameCapacity: AVAudioFrameCount(file.length)),
                  (try? file.read(into: buffer)) != nil else { continue }
            buffers[name] = buffer
            voices[name] = (0..<count).map { _ in
                let player = AVAudioPlayerNode()
                let varispeed = AVAudioUnitVarispeed()
                engine.attach(player)
                engine.attach(varispeed)
                engine.connect(player, to: varispeed, format: buffer.format)
                engine.connect(varispeed, to: engine.mainMixerNode, format: buffer.format)
                player.volume = Self.effectVolume[name] ?? 0.3
                return Voice(player: player, varispeed: varispeed)
            }
        }
        engine.prepare()
        startEngineIfNeeded()
    }

    private func startEngineIfNeeded() {
        guard !engine.isRunning else { return }
        try? engine.start()
    }

    private func playEffect(named name: String, rate: Float) {
        guard effectsEnabled else { return }
        audioQueue.async {
            guard let buffer = self.buffers[name], let pool = self.voices[name], !pool.isEmpty else { return }
            self.startEngineIfNeeded()
            // Round-robin so overlapping chimes don't cut each other off.
            let index = self.nextVoice[name, default: 0] % pool.count
            self.nextVoice[name] = index + 1
            let voice = pool[index]
            voice.varispeed.rate = rate
            voice.player.stop()
            voice.player.scheduleBuffer(buffer, at: nil, options: [])
            voice.player.play()
        }
    }
}
