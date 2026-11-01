import AVFoundation

/// Synthesizes and plays the timer's sound effects.
///
/// The sounds are modelled on soft sine "bells": a short high click for the
/// countdown, a rising octave for "go", a falling fifth for "rest" and a
/// descending three-note phrase for the end.
final class SoundPlayer {
    enum Effect: CaseIterable {
        case tick, work, rest, finish
    }

    static let enabledKey = "soundOn"

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: Synth.rate, channels: 1)!
    private var buffers: [Effect: AVAudioPCMBuffer] = [:]
    private var isActive = false
    private var deactivation: Task<Void, Never>?
    private var observers: [Task<Void, Never>] = []

    init() {
        engine.attach(player)
        try? engine.connectNode(player, to: engine.mainMixerNode, format: format)
        for effect in Effect.allCases {
            buffers[effect] = makeBuffer(Synth.samples(for: effect))
        }

        // Headphones plugged in/out, sample rate changes: the engine stops and must be restarted.
        observers.append(Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .AVAudioEngineConfigurationChange) {
                self?.resume()
            }
        })
        // After a phone call, Siri or an alarm: the workout goes on, so always resume.
        observers.append(Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: AVAudioSession.resumptionRecommendationNotification) {
                self?.resume()
            }
        })
        // Media services were reset: rebuild nothing, just start again.
        observers.append(Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: AVAudioSession.mediaServicesWereResetNotification) {
                self?.resume()
            }
        })
    }

    /// Activates the audio session for a workout. Other audio (music, podcasts) keeps playing.
    /// Keeping the engine running also keeps the timer alive while the screen is locked.
    func start() {
        deactivation?.cancel()
        deactivation = nil
        isActive = true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        startEngine()
    }

    func stop() {
        deactivation?.cancel()
        deactivation = nil
        guard isActive else { return }
        isActive = false
        player.stop()
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Lets a last sound ring out, then releases audio so the app can sleep.
    func deactivate(after delay: Duration) {
        deactivation?.cancel()
        deactivation = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    func play(_ effect: Effect) {
        let enabled = UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
        guard enabled, isActive, let buffer = buffers[effect] else { return }
        if !engine.isRunning { resume() }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying { try? player.playAudio(at: nil) }
    }

    private func resume() {
        guard isActive else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        startEngine()
    }

    private func startEngine() {
        if !engine.isRunning {
            engine.prepare()
            try? engine.start()
        }
        if engine.isRunning, !player.isPlaying { try? player.playAudio(at: nil) }
    }

    private func makeBuffer(_ samples: [Float]) -> AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { src in
            buffer.floatChannelData![0].update(from: src.baseAddress!, count: samples.count)
        }
        return buffer
    }
}

/// Pure sample synthesis, no state.
nonisolated enum Synth {
    static let rate = 44_100.0

    static func samples(for effect: SoundPlayer.Effect) -> [Float] {
        switch effect {
        case .tick:
            click()
        case .work:  // G5 -> G6
            bells([(783.99, 0), (1567.98, 0.16)], tail: 0.5)
        case .rest:  // D5 -> G4
            bells([(587.33, 0), (392.00, 0.16)], tail: 0.5)
        case .finish:  // G5 -> D5 -> G4
            bells([(783.99, 0), (587.33, 0.14), (392.00, 0.28)], tail: 0.7)
        }
    }

    /// A very short, bright tick.
    static func click() -> [Float] {
        let count = Int(rate * 0.035)
        var out = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let t = Double(i) / rate
            let env = min(1, t / 0.0008) * exp(-t * 140)
            let s = sin(2 * .pi * 4000 * t) + 0.45 * sin(2 * .pi * 9100 * t) * exp(-t * 200)
            out[i] = Float(s * env)
        }
        return normalized(out, peak: 0.55)
    }

    /// Soft bell notes with a quick attack and an exponential decay.
    static func bells(_ notes: [(freq: Double, start: Double)], tail: Double) -> [Float] {
        let total = (notes.map(\.start).max() ?? 0) + tail
        var out = [Float](repeating: 0, count: Int(rate * total))
        for note in notes {
            let first = Int(note.start * rate)
            for i in first..<out.count {
                let t = Double(i - first) / rate
                let env = min(1, t / 0.004) * exp(-t * 9)
                let w = 2 * .pi * note.freq * t
                let s = sin(w)
                    + 0.22 * sin(2 * w) * exp(-t * 14)
                    + 0.06 * sin(3 * w) * exp(-t * 22)
                out[i] += Float(s * env)
            }
        }
        // Short fade at the very end against a click.
        let fade = Int(rate * 0.03)
        for k in 0..<fade {
            out[out.count - 1 - k] *= Float(k) / Float(fade)
        }
        return normalized(out, peak: 0.7)
    }

    static func normalized(_ s: [Float], peak: Float) -> [Float] {
        let m = s.map(abs).max() ?? 1
        return m > 0 ? s.map { $0 / m * peak } : s
    }
}
