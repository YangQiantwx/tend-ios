import XCTest

final class TendUITests: XCTestCase {
    @MainActor var app: XCUIApplication!

    @MainActor func launchFreshApp(window: String? = nil) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-test-data"]
        if let window { app.launchArguments.append("--demo-window-\(window)") }
        app.launch()
    }

    @MainActor func testCheckInChoicesAndOnDemandCountsPersist() {
        launchFreshApp()
        onboard()
        capture("01-today-empty")
        tap(app.buttons["home.checkIn"])
        completeCheckIn(checkBackNavigation: true)
        capture("03-two-support-options")

        tap(app.buttons["options.save"])
        XCTAssertTrue(labelContaining("Today → Saved for later").waitForExistence(timeout: 5))
        tap(app.buttons["options.done"])
        openSavedFromToday()
        let recommendation = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "saved.recommendation.")).firstMatch
        XCTAssertTrue(recommendation.waitForExistence(timeout: 5))
        capture("04-saved-recommendations")
        tap(recommendation)
        XCTAssertTrue(app.buttons["practice.start"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        tap(app.buttons["home.checkIn"])
        completeCheckIn(checkBackNavigation: false)
        tap(app.buttons["options.skip"])
        selectTab("Journey")
        assertTodayCounts(scheduled: 0, onDemand: 2)
        capture("05-journey-on-demand")

        relaunchKeepingData()
        selectTab("Journey")
        assertTodayCounts(scheduled: 0, onDemand: 2)
        openSavedFromToday()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "saved.recommendation.")).firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor func testScheduledSlotCanBeOpenedWithoutNotificationPermission() {
        launchFreshApp(window: "open")
        onboard()
        tap(app.buttons["home.scheduled.morning"])
        completeCheckIn(checkBackNavigation: false)
        tap(app.buttons["options.skip"])
        XCTAssertFalse(app.buttons["home.scheduled.morning"].exists)
        selectTab("Journey")
        assertTodayCounts(scheduled: 1, onDemand: 0)
    }

    @MainActor func testPracticePausesInBackgroundAndSavesWithoutFeedback() {
        launchFreshApp()
        onboard()
        openPracticeFromToday(category: "mindfulness", id: "mindful-breathing")
        tap(app.buttons["practice.start"])
        XCTAssertTrue(app.staticTexts["practice.timer"].waitForExistence(timeout: 8))
        capture("06-breathing-player")

        tap(app.buttons["practice.pause"])
        XCTAssertTrue(button(identifier: "practice.pause", label: "Resume practice").waitForExistence(timeout: 5))
        let pausedTime = app.staticTexts["practice.timer"].label
        XCTAssertTrue(app.staticTexts["Practice paused"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["practice.timer"].label, pausedTime)
        tap(app.buttons["practice.pause"])
        XCTAssertTrue(button(identifier: "practice.pause", label: "Pause practice").waitForExistence(timeout: 5))

        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(button(identifier: "practice.pause", label: "Resume practice").waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["The timer paused while the app was away."].waitForExistence(timeout: 5))
        capture("07-background-pause")
        tap(app.buttons["practice.pause"])
        tap(app.buttons["practice.finish"])
        let confirmation = app.alerts.buttons["I completed this"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.tap()

        XCTAssertTrue(app.buttons["feedback.done"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Feedback is optional."].waitForExistence(timeout: 5))
        for rating in 1...5 {
            XCTAssertEqual(app.buttons["feedback.rating.\(rating)"].value as? String, "Not selected")
        }
        capture("08-optional-feedback-left-blank")
        tap(app.buttons["feedback.done"])
        XCTAssertTrue(app.buttons["practice.backToToday"].waitForExistence(timeout: 8))
        selectTab("Journey")
        assertTodayCounts(scheduled: 0, onDemand: 0)
        openPracticeHistory()
        let practiceRecord = app.staticTexts["Mindful breathing"]
        tap(practiceRecord)
        XCTAssertTrue(labelContaining("Not rated").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No note added"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["journey.repeat"].waitForExistence(timeout: 5))
        capture("09-completed-practice-record")

        relaunchKeepingData()
        selectTab("Journey")
        openPracticeHistory()
        tap(app.staticTexts["Mindful breathing"])
        XCTAssertTrue(labelContaining("Not rated").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No note added"].waitForExistence(timeout: 5))
    }

    @MainActor func testDraftRecoveryReminderEditorAndResearchExport() {
        launchFreshApp()
        onboard()
        tap(app.buttons["home.checkIn"])
        tap(app.buttons["ema.distress.2"])
        tap(app.buttons["ema.willingness.4"])
        tap(app.buttons["ema.close"])
        XCTAssertTrue(label("Come back when you're ready").waitForExistence(timeout: 5))
        tap(app.buttons["Save and close"])
        XCTAssertTrue(button(identifier: "home.checkIn", label: "Continue check-in").waitForExistence(timeout: 5))

        relaunchKeepingData()
        XCTAssertTrue(button(identifier: "home.checkIn", label: "Continue check-in").waitForExistence(timeout: 5))
        tap(app.buttons["home.checkIn"])
        XCTAssertTrue(app.buttons["ema.distress.2"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["ema.distress.2"].value as? String, "Selected")
        XCTAssertEqual(app.buttons["ema.willingness.4"].value as? String, "Selected")
        XCTAssertTrue(app.buttons["ema.continue"].isEnabled)
        capture("10-draft-restored-after-relaunch")
        tap(app.buttons["ema.close"])
        tap(app.buttons["Save and close"])

        selectTab("Settings")
        tap(app.buttons["profile.reminders"])
        let pickers = app.datePickers.matching(NSPredicate(format: "identifier BEGINSWITH %@", "reminders.time."))
        XCTAssertTrue(pickers.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(pickers.count, 3)
        for slot in ["morning", "afternoon", "evening"] {
            XCTAssertTrue(app.datePickers["reminders.time.\(slot)"].exists)
        }
        tap(app.buttons["reminders.save"])
        XCTAssertTrue(app.buttons["profile.reminders"].waitForExistence(timeout: 5))
        tap(app.buttons["profile.research"])

        let export = app.buttons["research.export"]
        revealResearchList(export)
        export.tap()
        XCTAssertTrue(app.buttons["research.share"].waitForExistence(timeout: 5))
        capture("11-local-json-export-ready")
        let loadSample = app.buttons["research.loadSample"]
        revealResearchList(loadSample, direction: .down)
        loadSample.tap()
        let sampleDays = app.staticTexts["Sample days"]
        XCTAssertTrue(sampleDays.waitForExistence(timeout: 5))
        // LabeledContent exposes its value as a combined accessibility label.
        // Read-only labels need to exist; they do not need to be tappable.
        XCTAssertTrue(label("Sample days, 7").waitForExistence(timeout: 5))
        XCTAssertTrue(label("Real Fitbit, Not connected").waitForExistence(timeout: 5))
        XCTAssertTrue(label("Demo connection, Disconnected").waitForExistence(timeout: 5))
        XCTAssertTrue(label("Missing sample metrics, 5").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Missing means unknown, not zero. Sample Fitbit data never affects practice suggestions."].waitForExistence(timeout: 5))
        capture("12-sample-wearable-missingness")
    }

    @MainActor func testOneMinutePracticeReachesZeroWithoutAutoCompleting() {
        launchFreshApp()
        onboard()
        openPracticeFromToday(category: "movement", id: "movement-break")
        tap(app.buttons["practice.start"])
        XCTAssertTrue(app.staticTexts["practice.timer"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Timer finished"].waitForExistence(timeout: 75))
        XCTAssertEqual(app.staticTexts["practice.timer"].label, "0 minutes and 0 seconds remaining")
        XCTAssertFalse(app.buttons["feedback.done"].exists)
        XCTAssertTrue(button(identifier: "practice.finish", label: "I completed this").waitForExistence(timeout: 5))
        capture("13-one-minute-timer-awaits-confirmation")
        tap(app.buttons["practice.finish"])
        let confirmation = app.alerts.buttons["I completed this"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.tap()
        XCTAssertTrue(app.buttons["feedback.done"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Feedback is optional."].waitForExistence(timeout: 5))
        tap(app.buttons["feedback.done"])
        XCTAssertTrue(app.buttons["practice.backToToday"].waitForExistence(timeout: 8))
        selectTab("Journey")
        openPracticeHistory()
        tap(app.staticTexts["Seated movement break"])
        XCTAssertTrue(labelContaining("1m 0s").waitForExistence(timeout: 5))
        XCTAssertTrue(labelContaining("Not rated").waitForExistence(timeout: 5))
        capture("14-one-minute-practice-record")
    }

    @MainActor func onboard() {
        tap(app.buttons["onboarding.continue"])
        XCTAssertTrue(app.textFields["onboarding.name"].waitForExistence(timeout: 5))
        tap(app.buttons["onboarding.continue"])
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 8))
    }

    @MainActor func completeCheckIn(checkBackNavigation: Bool) {
        let next = app.buttons["ema.continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 8))
        XCTAssertFalse(next.isEnabled)
        tap(app.buttons["ema.distress.3"])
        XCTAssertFalse(next.isEnabled)
        tap(app.buttons["ema.willingness.3"])
        XCTAssertTrue(next.isEnabled)
        if checkBackNavigation { capture("02-check-in-first-page") }
        tap(next)

        XCTAssertTrue(app.buttons["ema.fatigue.2"].waitForExistence(timeout: 5))
        XCTAssertFalse(next.isEnabled)
        tap(app.buttons["ema.fatigue.2"])
        tap(app.buttons["ema.pain.2"])
        if checkBackNavigation {
            tap(app.buttons["ema.back"])
            XCTAssertTrue(app.buttons["ema.distress.3"].waitForExistence(timeout: 5))
            XCTAssertEqual(app.buttons["ema.distress.3"].value as? String, "Selected")
            XCTAssertEqual(app.buttons["ema.willingness.3"].value as? String, "Selected")
            XCTAssertTrue(next.isEnabled)
            tap(next)
            XCTAssertTrue(app.buttons["ema.fatigue.2"].waitForExistence(timeout: 5))
            XCTAssertEqual(app.buttons["ema.fatigue.2"].value as? String, "Selected")
            XCTAssertEqual(app.buttons["ema.pain.2"].value as? String, "Selected")
        }
        tap(next)
        XCTAssertTrue(app.buttons["ema.physicalFunction.4"].waitForExistence(timeout: 5))
        XCTAssertFalse(next.isEnabled)
        tap(app.buttons["ema.physicalFunction.4"])
        XCTAssertFalse(next.isEnabled)
        tap(app.buttons["ema.time.tenTo30"])
        tap(next)
        XCTAssertTrue(app.buttons["options.movement"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["options.mindfulness"].waitForExistence(timeout: 5))
    }

    @MainActor func selectTab(_ title: String) {
        let tab = app.tabBars.buttons[title]
        XCTAssertTrue(tab.waitForExistence(timeout: 8))
        tab.tap()
    }

    @MainActor func openQuestions() {
        XCTAssertFalse(app.tabBars.buttons["Q&A"].exists)
        selectTab("Settings")
        for _ in 0..<6 where !app.buttons["profile.faq"].exists {
            let back = app.navigationBars.buttons.element(boundBy: 0)
            guard back.exists else { break }
            back.tap()
        }
        reveal(app.buttons["profile.faq"])
        app.buttons["profile.faq"].tap()
    }

    @MainActor func openSavedFromToday() {
        selectTab("Today")
        tap(app.buttons["today.saved"])
        XCTAssertTrue(app.scrollViews["saved.screen"].waitForExistence(timeout: 5))
    }

    @MainActor func openPracticeHistory() {
        tap(app.buttons["journey.allPractices"])
        XCTAssertTrue(app.navigationBars["All practices"].waitForExistence(timeout: 5))
    }

    @MainActor func testQandAOpensAnswersAndLocalSupport() {
        launchFreshApp()
        onboard()
        XCTAssertFalse(app.tabBars.buttons["Saved"].exists)
        openQuestions()
        XCTAssertTrue(app.buttons["qa.question.2"].waitForExistence(timeout: 5))
        XCTAssertFalse(labelContaining("Today → Saved for later").exists)
        capture("qa-collapsed")
        tap(app.buttons["qa.question.2"])
        XCTAssertTrue(labelContaining("Today → Saved for later").waitForExistence(timeout: 5))
        capture("qa-expanded")
        tap(app.buttons["qa.technicalSupport"])
        XCTAssertTrue(labelContaining("Messages on this device").waitForExistence(timeout: 5))
        selectTab("Settings")
        capture("settings-concise")
    }

    @MainActor func testBothPracticeChoicesRemainAvailableInOneCheckIn() {
        launchFreshApp()
        onboard()
        tap(app.buttons["home.checkIn"])
        completeCheckIn(checkBackNavigation: false)
        tap(app.buttons["options.movement"])
        capture("practice-detail")
        tap(app.buttons["practice.start"])
        tap(app.buttons["practice.finish"])
        tap(app.alerts.buttons["I completed this"])
        tap(app.buttons["feedback.done"])
        tap(app.buttons["practice.otherOption"])
        XCTAssertTrue(app.staticTexts["Mindful breathing"].waitForExistence(timeout: 5))
        tap(app.buttons["practice.start"])
        tap(app.buttons["practice.finish"])
        tap(app.alerts.buttons["I completed this"])
        tap(app.buttons["feedback.done"])
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["options.done"].waitForExistence(timeout: 5))
        tap(app.buttons["options.done"])
        XCTAssertTrue(app.buttons["home.checkIn"].waitForExistence(timeout: 5))
    }

    @MainActor func openPracticeFromToday(category: String, id: String) {
        selectTab("Today")
        tap(app.buttons["today.category.\(category)"])
        tap(app.buttons["practice.list.\(id)"])
    }

    @MainActor func assertTodayCounts(scheduled: Int, onDemand: Int) {
        let chartPicker = app.segmentedControls["journey.chartKind"]
        reveal(chartPicker)
        tap(chartPicker.buttons["Check-ins"])
        let summary = app.buttons["journey.selectedCheckInDay"]
        reveal(summary)
        XCTAssertTrue(summary.label.contains("\(scheduled) scheduled"), summary.label)
        XCTAssertTrue(summary.label.contains("\(onDemand) on demand"), summary.label)
    }

    @MainActor func relaunchKeepingData() {
        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["onboarding.continue"].exists)
    }

    @MainActor func button(identifier: String, label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == %@ AND label == %@", identifier, label)).firstMatch
    }

    @MainActor func label(_ value: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", value)).firstMatch
    }

    @MainActor func labelContaining(_ value: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", value)).firstMatch
    }

    @MainActor func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        reveal(element, file: file, line: line)
        element.tap()
    }

    enum ScrollDirection { case up, down }

    @MainActor func reveal(_ element: XCUIElement, direction: ScrollDirection = .up,
                        file: StaticString = #filePath, line: UInt = #line) {
        for attempt in 0..<7 {
            if element.waitForExistence(timeout: attempt == 0 ? 5 : 1), element.isHittable { return }
            let scrollView = app.scrollViews.firstMatch
            guard scrollView.exists else { break }
            if direction == .up { scrollView.swipeUp() } else { scrollView.swipeDown() }
        }
        XCTFail("Element could not be made visible: \(element)", file: file, line: line)
    }

    @MainActor func revealResearchList(_ element: XCUIElement, direction: ScrollDirection = .up,
                                              file: StaticString = #filePath, line: UInt = #line) {
        for attempt in 0..<8 {
            if element.waitForExistence(timeout: attempt == 0 ? 3 : 1), element.isHittable { return }
            let container: XCUIElement
            if app.collectionViews.firstMatch.exists { container = app.collectionViews.firstMatch }
            else if app.tables.firstMatch.exists { container = app.tables.firstMatch }
            else { container = app.scrollViews.firstMatch }
            guard container.exists else { break }
            if direction == .up { container.swipeUp() } else { container.swipeDown() }
        }
        XCTFail("Research list element could not be made visible: \(element)", file: file, line: line)
    }

    @MainActor func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
