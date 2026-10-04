import Foundation
import Testing
@testable import TendCore

struct PracticeTimerTests {
    @Test func pausesExcludeBackgroundTimeAndDuplicateResumeDoesNotLoseTime() {
        var timer = PracticeTimer(plannedSeconds: 60)
        timer.resume(at: 100)
        timer.tick(at: 110)
        timer.resume(at: 111)
        timer.pause(at: 115)
        #expect(timer.elapsed == 15)
        timer.tick(at: 1000)
        #expect(timer.elapsed == 15)
        timer.resume(at: 1000)
        timer.tick(at: 1010)
        #expect(timer.elapsed == 25)
        #expect(!timer.isPaused)
    }

    @Test func timerStopsAtPlannedDurationAndNeverRestartsFinishedTime() {
        var timer = PracticeTimer(plannedSeconds: 60)
        timer.resume(at: 100)
        timer.tick(at: 170)
        #expect(timer.elapsed == 60)
        #expect(timer.isFinished)
        #expect(timer.isPaused)
        timer.resume(at: 200)
        timer.tick(at: 300)
        #expect(timer.elapsed == 60)
        #expect(timer.isPaused)
    }

    @Test func pauseCapturesTimeSinceLastUITick() {
        var timer = PracticeTimer(plannedSeconds: 60)
        timer.resume(at: 100)
        timer.tick(at: 103)
        timer.pause(at: 103.75)
        #expect(timer.elapsed == 3.75)
        timer.pause(at: 110)
        #expect(timer.elapsed == 3.75)
    }
}
