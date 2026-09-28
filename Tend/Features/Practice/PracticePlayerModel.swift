import Foundation
import Observation

/// A foreground-only timer. Monotonic time measures active time, not clock changes.
@MainActor @Observable
final class PracticePlayerModel {
    let id = UUID()
    let plannedSeconds: Double
    private(set) var startedAt = Date()
    private(set) var elapsed: Double = 0
    private(set) var isPaused = true
    private(set) var hasStarted = false
    private(set) var pausedForBackground = false
    private(set) var audioEnabled: Bool
    private(set) var audioError: String?
    private var accumulated: Double = 0
    private var runningSince: TimeInterval?
    private let narration: PracticeNarrationPlayer

    init(practice: Practice, audioEnabled: Bool) {
        plannedSeconds = Double(max(1, practice.durationSeconds))
        narration = PracticeNarrationPlayer(practiceID: practice.id, script: practice.audioScript)
        self.audioEnabled = audioEnabled
        narration.onError = { [weak self] message in self?.audioError = message }
        narration.onInterruption = { [weak self] in self?.pause() }
    }

    var timerFinished: Bool { elapsed >= plannedSeconds }
    var remaining: Int { max(0, Int(ceil(plannedSeconds - elapsed))) }
    var progress: Double { min(1, elapsed / plannedSeconds) }
    var expansion: Double {
        let phase = elapsed.truncatingRemainder(dividingBy: 10)
        return phase < 4 ? phase / 4 : 1 - (phase - 4) / 6
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        startedAt = Date()
        resume()
    }

    func tick() {
        guard let runningSince else { return }
        elapsed = min(plannedSeconds, accumulated + ProcessInfo.processInfo.systemUptime - runningSince)
        if timerFinished { pause() }
    }

    func pause(forBackground: Bool = false) {
        if let runningSince {
            elapsed = min(plannedSeconds, accumulated + ProcessInfo.processInfo.systemUptime - runningSince)
            accumulated = elapsed
        }
        runningSince = nil
        isPaused = true
        pausedForBackground = forBackground && !timerFinished
        narration.pause()
    }

    func resume() {
        guard !timerFinished else { return }
        pausedForBackground = false
        runningSince = ProcessInfo.processInfo.systemUptime
        isPaused = false
        if audioEnabled { narration.resume() }
    }

    func setAudioEnabled(_ enabled: Bool) {
        audioEnabled = enabled
        audioError = nil
        if enabled && !isPaused {
            narration.resume()
        } else if !enabled {
            narration.stop()
        }
    }

    func stop() {
        pause()
        narration.stop()
    }

    func session(participantID: String, practiceID: String, checkInID: UUID?,
                 completed: Bool, endedAt: Date, helpfulness: Int? = nil, note: String? = nil) -> PracticeSession {
        PracticeSession(id: id, participantID: participantID, practiceID: practiceID,
                        checkInID: checkInID, startedAt: startedAt, endedAt: endedAt,
                        durationSeconds: elapsed, completed: completed, helpfulness: helpfulness,
                        note: note, completionSource: "self_report")
    }

}
