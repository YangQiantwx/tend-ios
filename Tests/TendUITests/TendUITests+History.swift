import XCTest

extension TendUITests {
    @MainActor func testTodayCategoriesLeadToPracticesAndSavedItemsPersist() {
        launchFreshApp()
        onboard()
        openPracticeFromToday(category: "mindfulness", id: "mindful-breathing")
        tap(app.buttons["practice.save"])
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        openSavedFromToday()
        tap(app.buttons["practice.list.mindful-breathing"])
        XCTAssertTrue(app.buttons["practice.start"].waitForExistence(timeout: 5))
        capture("saved-practice-opens")

        relaunchKeepingData()
        openSavedFromToday()
        XCTAssertTrue(app.buttons["practice.list.mindful-breathing"].waitForExistence(timeout: 5))
    }

    @MainActor func testPracticeHistoryFilterRepeatAndSavedEmptyRecovery() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-test-data", "--seed-journey"]
        app.launch()
        selectTab("Journey")
        tap(app.buttons["journey.allPractices"])
        tap(app.buttons["history.practiceFilter"])
        tap(app.buttons["Ended early"])
        let record = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "journey.session.")).firstMatch
        revealResearchList(record)
        record.tap()
        XCTAssertTrue(label("Status, Ended early").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["journey.feedback"].exists)
        let repeatPractice = app.buttons["journey.repeat"]
        revealResearchList(repeatPractice)
        repeatPractice.tap()
        tap(app.buttons["practice.start"])
        tap(app.buttons["practice.close"])
        XCTAssertTrue(app.alerts.buttons["End practice"].waitForExistence(timeout: 5))
        app.alerts.buttons["End practice"].tap()
        XCTAssertTrue(app.buttons["practice.start"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let linked = app.buttons["journey.linkedCheckIn"]
        revealResearchList(linked)
        linked.tap()
        XCTAssertTrue(app.navigationBars["Your check-in"].waitForExistence(timeout: 5))
        capture("refresh-12-repeat-and-linked-check-in")

        openSavedFromToday()
        XCTAssertTrue(app.staticTexts["Nothing saved yet"].waitForExistence(timeout: 5))
        tap(app.buttons["saved.explore"])
        tap(app.buttons["today.category.movement"])
        XCTAssertTrue(app.buttons["practice.list.short-walk"].waitForExistence(timeout: 5))
        capture("refresh-13-saved-empty-state-recovery")
    }
}
