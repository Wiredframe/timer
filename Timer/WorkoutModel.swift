import Foundation
import Observation
import UIKit

struct WorkoutConfig {
    var sets: Int
    var work: Int
    var rest: Int
    var skipLastRest: Bool

    static let prepare = 10

    /// Number of rest phases actually played.
    var restCount: Int {
        guard rest > 0 else { return 0 }
        return skipLastRest ? sets - 1 : sets
    }

    /// Duration without the preparation countdown.
    var total: Int { sets * work + restCount * rest }
}

/// Runs a workout. Time is derived from wall-clock dates, so it stays exact
/// even if the app is briefly suspended or the screen is locked.
@Observable
final class WorkoutModel {
    enum Kind { case prepare, work, rest }

    struct Step {
        let kind: Kind
        let set: Int
        let duration: TimeInterval
    }

    let config: WorkoutConfig
    let steps: [Step]
    private(set) var index = 0
    private(set) var isPaused = false
    private(set) var isFinished = false

    @ObservationIgnored private var accumulated: TimeInterval = 0
    @ObservationIgnored private var resumedAt: Date? = .now
    @ObservationIgnored private var lastTick: Int?
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private let sound: SoundPlayer
    @ObservationIgnored private let haptics = UINotificationFeedbackGenerator()

    init(config: WorkoutConfig, sound: SoundPlayer) {
        self.config = config
        self.sound = sound

        var steps = [Step(kind: .prepare, set: 0, duration: TimeInterval(WorkoutConfig.prepare))]
        for set in 1...max(1, config.sets) {
            steps.append(Step(kind: .work, set: set, duration: TimeInterval(config.work)))
            let isLast = set == config.sets
            if config.rest > 0 && !(isLast && config.skipLastRest) {
                steps.append(Step(kind: .rest, set: set, duration: TimeInterval(config.rest)))
            }
        }
        self.steps = steps

        UIApplication.shared.isIdleTimerDisabled = true
        haptics.prepare()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.update()
                try? await Task.sleep(for: .milliseconds(40))
            }
        }
    }

    var current: Step { steps[index] }

    func elapsed(at date: Date) -> TimeInterval {
        accumulated + (resumedAt.map { max(0, date.timeIntervalSince($0)) } ?? 0)
    }

    func progress(at date: Date) -> Double {
        guard current.duration > 0 else { return 1 }
        return min(1, max(0, elapsed(at: date) / current.duration))
    }

    /// Whole seconds left in the current step, rounded up like a countdown.
    /// Never shows 0 while a step is running: the step ends at that moment.
    func remaining(at date: Date) -> Int {
        let left = Int((current.duration - elapsed(at: date)).rounded(.up))
        return min(Int(current.duration), max(1, left))
    }

    /// Seconds left in the whole workout, preparation excluded.
    func totalRemaining(at date: Date) -> Int {
        if current.kind == .prepare { return config.total }
        let later = steps[(index + 1)...].reduce(0) { $0 + Int($1.duration) }
        return remaining(at: date) + later
    }

    // MARK: - Controls

    func togglePause() {
        guard !isFinished else { return }
        let now = Date.now
        if isPaused {
            resumedAt = now
            sound.start()
        } else {
            accumulated = elapsed(at: now)
            resumedAt = nil
            // While paused the app may sleep: release audio and let the screen lock.
            sound.deactivate(after: .seconds(1))
        }
        isPaused.toggle()
        UIApplication.shared.isIdleTimerDisabled = !isPaused
    }

    func skipForward() {
        guard !isFinished else { return }
        advance(carry: 0, at: .now)
    }

    /// Restarts the current step, or goes back one step if it has only just begun.
    func skipBack() {
        guard !isFinished else { return }
        let now = Date.now
        if elapsed(at: now) < 2, index > 0 {
            index -= 1
            restart(carry: 0, at: now)
            announce(current.kind)
        } else {
            restart(carry: 0, at: now)
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // MARK: - Ticking

    private func update() {
        guard !isFinished, !isPaused else { return }
        let now = Date.now

        // Catch up on every step that ended (also after a long suspension),
        // but only announce the step we land in.
        var moved = false
        while elapsed(at: now) >= current.duration {
            let carry = elapsed(at: now) - current.duration
            guard index + 1 < steps.count else {
                finish()
                return
            }
            index += 1
            restart(carry: carry, at: now)
            moved = true
        }
        if moved { announce(current.kind) }

        let left = remaining(at: now)
        if left <= 3, left != lastTick, current.duration > 3, elapsed(at: now) > 0.2 {
            lastTick = left
            sound.play(.tick)
        }
    }

    private func advance(carry: TimeInterval, at now: Date) {
        guard index + 1 < steps.count else {
            finish()
            return
        }
        index += 1
        restart(carry: carry, at: now)
        announce(current.kind)
    }

    private func finish() {
        isFinished = true
        isPaused = false
        sound.play(.finish)
        sound.deactivate(after: .seconds(1.5))
        haptics.notificationOccurred(.success)
        stop()
    }

    private func restart(carry: TimeInterval, at now: Date) {
        accumulated = carry
        resumedAt = isPaused ? nil : now
        // A tick for the current second must not repeat after a restart.
        lastTick = nil
    }

    private func announce(_ kind: Kind) {
        switch kind {
        case .work: sound.play(.work)
        case .rest: sound.play(.rest)
        case .prepare: return
        }
        haptics.notificationOccurred(.warning)
    }
}
