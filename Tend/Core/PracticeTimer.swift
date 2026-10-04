import Foundation

/// Accumulates active monotonic time. Paused intervals never count toward practice time.
struct PracticeTimer {
    let plannedSeconds: Double
    private(set) var elapsed: Double = 0
    private(set) var isPaused = true
    private var accumulated: Double = 0
    private var runningSince: TimeInterval?

    init(plannedSeconds: Double) { self.plannedSeconds = max(1, plannedSeconds) }

    var isFinished: Bool { elapsed >= plannedSeconds }

    mutating func resume(at uptime: TimeInterval) {
        guard isPaused, !isFinished else { return }
        runningSince = uptime
        isPaused = false
    }

    mutating func tick(at uptime: TimeInterval) {
        guard let runningSince else { return }
        elapsed = min(plannedSeconds, accumulated + max(0, uptime - runningSince))
        if isFinished { pause(at: uptime) }
    }

    mutating func pause(at uptime: TimeInterval) {
        if let runningSince {
            elapsed = min(plannedSeconds, accumulated + max(0, uptime - runningSince))
            accumulated = elapsed
        }
        runningSince = nil
        isPaused = true
    }
}
