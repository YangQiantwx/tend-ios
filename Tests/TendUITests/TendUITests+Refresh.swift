import XCTest

extension TendUITests {
    @MainActor func testOceanThemeLearnAndAccountHelp() {
        launchFreshApp(window: "open")
        onboard()
        XCTAssertTrue(app.buttons["home.scheduled.morning"].isHittable)
        XCTAssertTrue(app.buttons["home.checkIn"].exists)
        capture("deep-01-scheduled-first")

        selectTab("Settings")
        tap(app.buttons["profile.learn"])
        XCTAssertTrue(app.staticTexts["Stress, mind, and body"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.links["NIMH: Stress and anxiety"].exists)
        capture("deep-02-learning-preview")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        let ocean = app.buttons["profile.colorTheme.ocean"]
        reveal(ocean, direction: .down)
        XCTAssertTrue(ocean.isSelected)
        tap(app.buttons["profile.colorTheme.forest"])
        let forest = app.buttons["profile.colorTheme.forest"]
        reveal(forest)
        XCTAssertTrue(forest.isSelected)
        tap(app.buttons["profile.colorTheme.ocean"])
        reveal(app.buttons["profile.accountDetails"])
        tap(app.buttons["profile.accountDetails"])
        XCTAssertTrue(labelContaining("Sign-in and account recovery are not connected").waitForExistence(timeout: 5))
        capture("deep-03-account-boundary")
    }

    @MainActor func testImmediatePostPracticeDistressIsPairedButHistoryCannotBackfill() {
        launchFreshApp()
        onboard()
        tap(app.buttons["home.checkIn"])
        completeCheckIn(checkBackNavigation: false)
        tap(app.buttons["options.movement"])
        tap(app.buttons["practice.start"])
        tap(app.buttons["practice.finish"])
        XCTAssertTrue(app.alerts.buttons["I completed this"].waitForExistence(timeout: 5))
        app.alerts.buttons["I completed this"].tap()
        let after = app.buttons["feedback.postDistress.2"]
        tap(after)
        XCTAssertEqual(after.value as? String, "Selected")
        tap(app.buttons["feedback.done"])
        app.navigationBars.buttons.element(boundBy: 0).tap()
        tap(app.buttons["options.done"])

        selectTab("Journey")
        XCTAssertTrue(labelContaining("Distress").waitForExistence(timeout: 5))
        XCTAssertTrue(labelContaining("after practice 2 of 5").waitForExistence(timeout: 5))
        let pair = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "journey.distressPair.")).firstMatch
        for _ in 0..<8 where !pair.isHittable {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.8))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.25))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(pair.isHittable)
        pair.tap()
        XCTAssertTrue(labelContaining("After-practice distress, 2 of 5").waitForExistence(timeout: 5))
        tap(app.buttons["journey.feedback"])
        XCTAssertTrue(app.navigationBars["Edit reflection"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["feedback.postDistress.2"].exists)
        capture("deep-04-history-cannot-backfill-distress")
    }

    @MainActor func testDiscardingDraftDoesNotReuseAnswersAndCorruptDraftRecovers() {
        launchFreshApp()
        onboard()
        tap(app.buttons["home.checkIn"])
        tap(app.buttons["ema.distress.2"])
        tap(app.buttons["ema.willingness.4"])
        tap(app.buttons["ema.close"])
        tap(app.buttons["Save and close"])
        tap(app.buttons["home.checkIn"])
        tap(app.buttons["ema.close"])
        // iOS 27 exposes the confirmation action twice in the accessibility tree.
        // Choose the visible copy instead of scrolling the check-in behind the dialog.
        let discard = app.buttons.matching(identifier: "ema.discard").allElementsBoundByIndex
            .first(where: { $0.isHittable })
        XCTAssertNotNil(discard)
        discard?.tap()
        tap(app.buttons["home.checkIn"])
        XCTAssertTrue(app.buttons["ema.distress.2"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["ema.distress.2"].value as? String, "Not selected")
        XCTAssertFalse(app.buttons["ema.continue"].isEnabled)
        capture("refresh-01-start-fresh")
        completeCheckIn(checkBackNavigation: false)
        tap(app.buttons["options.skip"])

        app.terminate()
        app.launchArguments = ["--uitesting", "--corrupt-draft"]
        app.launch()
        XCTAssertTrue(app.alerts["Your saved records are safe"].waitForExistence(timeout: 10))
        app.alerts.buttons["OK"].tap()
        selectTab("Journey")
        assertTodayCounts(scheduled: 0, onDemand: 1)
        selectTab("Today")
        tap(app.buttons["home.checkIn"])
        XCTAssertTrue(app.buttons["ema.continue"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["ema.continue"].isEnabled)
        capture("refresh-02-recovered-after-corrupt-draft")
    }

    @MainActor func testCompletionSurvivesExitBeforeFeedbackAndCanBeUpdated() {
        launchFreshApp()
        onboard()
        openPracticeFromToday(category: "mindfulness", id: "mindful-breathing")
        tap(app.buttons["practice.start"])
        tap(app.buttons["practice.finish"])
        let confirm = app.alerts.buttons["I completed this"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(app.buttons["feedback.done"].waitForExistence(timeout: 8))
        // Deliberately terminate before Done. The completion must already be durable.
        relaunchKeepingData()
        selectTab("Journey")
        openPracticeHistory()
        tap(app.staticTexts["Mindful breathing"])
        XCTAssertTrue(labelContaining("Not rated").waitForExistence(timeout: 5))
        tap(app.buttons["journey.feedback"])
        tap(app.buttons["feedback.rating.4"])
        tap(app.buttons["feedback.done"])
        XCTAssertTrue(labelContaining("Helpfulness, 4 of 5").waitForExistence(timeout: 5))
        capture("refresh-03-completion-survived-with-later-feedback")
        relaunchKeepingData()
        selectTab("Journey")
        openPracticeHistory()
        tap(app.staticTexts["Mindful breathing"])
        XCTAssertTrue(labelContaining("Helpfulness, 4 of 5").waitForExistence(timeout: 5))
    }

    @MainActor func testInteractiveChartsDayDetailsAndFullHistory() {
        launchJourneyFixture()
        selectTab("Journey")
        XCTAssertTrue(app.staticTexts["Test history"].waitForExistence(timeout: 5))
        tap(app.segmentedControls["journey.chartKind"].buttons["Check-ins"])
        tap(app.segmentedControls["journey.range"].buttons["28 days"])
        XCTAssertTrue(app.segmentedControls["journey.range"].buttons["28 days"].isSelected)
        capture("refresh-04-28-day-check-in-chart")
        tap(app.segmentedControls["journey.range"].buttons["This week"])
        XCTAssertTrue(app.segmentedControls["journey.range"].buttons["This week"].isSelected)
        // On Monday the current week has only one elapsed day. Select a past
        // date in the 28-day range so this interaction is valid every weekday.
        tap(app.segmentedControls["journey.range"].buttons["28 days"])
        let graph = app.otherElements.matching(identifier: "journey.checkInChart").firstMatch
        // A Chart is a non-tappable accessibility container even while its plot
        // accepts touches; isHittable on the container is not its visibility test.
        XCTAssertTrue(graph.waitForExistence(timeout: 5))
        XCTAssertTrue(app.frame.intersects(graph.frame))
        let selectedDay = app.buttons["journey.selectedCheckInDay"]
        let before = selectedDay.label
        graph.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)).tap()
        let changed = expectation(for: NSPredicate(format: "label != %@", before), evaluatedWith: selectedDay)
        wait(for: [changed], timeout: 5)
        tap(selectedDay)
        XCTAssertTrue(app.navigationBars["A day in your journey"].waitForExistence(timeout: 5))
        capture("refresh-05-selected-day-records")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        reveal(app.segmentedControls["journey.chartKind"], direction: .down)
        tap(app.segmentedControls["journey.chartKind"].buttons["Practices"])
        reveal(app.buttons["journey.selectedPracticeDay"])
        capture("refresh-06-practice-minutes-chart")
        reveal(app.segmentedControls["journey.chartKind"], direction: .down)
        tap(app.segmentedControls["journey.chartKind"].buttons["Ratings"])
        reveal(app.buttons["journey.selectedRatingDay"])
        capture("refresh-07-original-ema-ratings")
        XCTAssertFalse(app.staticTexts["Recent check-ins"].exists)
        XCTAssertFalse(app.staticTexts["Recent practices"].exists)
        tap(app.buttons["journey.allCheckIns"])
        XCTAssertTrue(app.navigationBars["Check-ins"].waitForExistence(timeout: 5))
        let period = app.segmentedControls["history.period"]
        XCTAssertTrue(period.buttons["All"].isSelected)
        XCTAssertFalse(app.buttons["history.previousPeriod"].exists)
        for slot in ["Morning", "Afternoon", "Evening"] {
            let namedRecord = app.buttons.matching(NSPredicate(
                format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@",
                "journey.checkin.", "\(slot) check-in,")).firstMatch
            revealResearchList(namedRecord)
            XCTAssertTrue(namedRecord.exists, "History identifies the original \(slot.lowercased()) slot.")
        }
        revealResearchList(period, direction: .down)
        period.buttons["Month"].tap()
        XCTAssertTrue(period.buttons["Month"].isSelected)
        let periodTitle = app.staticTexts["history.periodTitle"]
        XCTAssertTrue(periodTitle.waitForExistence(timeout: 5))
        let previousPeriod = app.buttons["history.previousPeriod"]
        let nextPeriod = app.buttons["history.nextPeriod"]
        XCTAssertEqual(previousPeriod.label, "Previous month")
        XCTAssertFalse(nextPeriod.isEnabled, "The latest recorded month cannot advance into an empty future.")
        let latestMonth = periodTitle.label
        // The relative thirteen-day fixture crosses a month only near its start.
        if previousPeriod.isEnabled {
            previousPeriod.tap()
            XCTAssertNotEqual(periodTitle.label, latestMonth)
            XCTAssertTrue(nextPeriod.isEnabled)
            nextPeriod.tap()
            XCTAssertEqual(periodTitle.label, latestMonth)
        }
        // Changing the period returns to the latest recorded week.
        period.buttons["Week"].tap()
        XCTAssertTrue(period.buttons["Week"].isSelected)
        XCTAssertEqual(previousPeriod.label, "Previous week")
        XCTAssertTrue(previousPeriod.isEnabled)
        XCTAssertFalse(nextPeriod.isEnabled)
        let latestWeek = periodTitle.label
        let latestRecord = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "journey.checkin.")).firstMatch
        let latestRecordID = latestRecord.identifier
        previousPeriod.tap()
        XCTAssertNotEqual(periodTitle.label, latestWeek)
        XCTAssertNotEqual(latestRecord.identifier, latestRecordID, "Moving weeks changes the visible records.")
        XCTAssertTrue(nextPeriod.isEnabled)
        nextPeriod.tap()
        XCTAssertEqual(periodTitle.label, latestWeek)
        XCTAssertEqual(latestRecord.identifier, latestRecordID)
        capture("history-week-navigation")
        period.buttons["All"].tap()
        XCTAssertTrue(period.buttons["All"].isSelected)
        XCTAssertFalse(previousPeriod.exists)
        let record = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "journey.checkin.")).firstMatch
        revealResearchList(record)
        record.tap()
        XCTAssertTrue(app.navigationBars["Your check-in"].waitForExistence(timeout: 5))
        let suggestion = app.buttons["journey.recommendation.mindful-breathing"]
        if suggestion.exists {
            revealResearchList(suggestion)
            suggestion.tap()
            XCTAssertTrue(app.buttons["practice.start"].waitForExistence(timeout: 5))
        } else {
            let historicalName = labelContaining("Mindful breathing")
            revealResearchList(historicalName)
            XCTAssertTrue(historicalName.exists)
            XCTAssertFalse(app.buttons["practice.start"].exists)
        }
        capture("refresh-08-historical-suggestion-window")
    }

    @MainActor func testUpdatedResearchLabelsAndExportAreReachable() {
        launchJourneyFixture()
        selectTab("Settings")
        tap(app.buttons["profile.research"])
        let protocolLink = app.buttons["research.protocol"]
        revealResearchList(protocolLink)
        protocolLink.tap()
        capture("refresh-09-research-phase-and-labels")
        let labels = app.buttons["research.labels"]
        revealResearchList(labels)
        labels.tap()
        XCTAssertTrue(app.switches["research.knownOnly"].waitForExistence(timeout: 5))
        app.switches["research.knownOnly"].switches.firstMatch.tap()
        XCTAssertEqual(app.switches["research.knownOnly"].value as? String, "1")
        XCTAssertTrue(labelContaining("Prior seven-day median").waitForExistence(timeout: 5))
        capture("refresh-10-causal-history-thresholds")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let transitions = app.buttons["research.transitions"]
        revealResearchList(transitions)
        transitions.tap()
        XCTAssertTrue(app.switches["research.evaluableOnly"].waitForExistence(timeout: 5))
        app.switches["research.evaluableOnly"].switches.firstMatch.tap()
        XCTAssertEqual(app.switches["research.evaluableOnly"].value as? String, "1")
        // LabeledContent has an accessible combined value; its text-only child
        // does not expose a hit target. Read the label rather than trying to tap it.
        let interval = labelContaining("Observed interval,")
        XCTAssertTrue(interval.waitForExistence(timeout: 5))
        XCTAssertTrue(interval.label.hasSuffix("hours"))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let export = app.buttons["research.export"]
        revealResearchList(export)
        export.tap()
        XCTAssertTrue(app.buttons["research.share"].waitForExistence(timeout: 5))
        capture("refresh-11-updated-json-export")
    }

    @MainActor private func launchJourneyFixture() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-test-data", "--seed-journey"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10))
    }
}
