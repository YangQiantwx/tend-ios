import XCTest

extension TendUITests {
    @MainActor func testFitbitDemoConnectionSyncAndDisconnectPersist() {
        launchFreshApp()
        onboard()
        selectTab("Settings")
        tap(app.buttons["profile.fitbit"])
        XCTAssertTrue(labelContaining("Demo disconnected").waitForExistence(timeout: 5))
        app.buttons["fitbit.connect"].tap()
        app.alerts.buttons["Use demo connection"].tap()
        XCTAssertTrue(labelContaining("Demo connection active").waitForExistence(timeout: 5))
        app.buttons["fitbit.sync"].tap()
        XCTAssertTrue(labelContaining("Simulated data").waitForExistence(timeout: 5))
        capture("fitbit-demo-synced")

        relaunchKeepingData()
        selectTab("Settings")
        tap(app.buttons["profile.fitbit"])
        XCTAssertTrue(labelContaining("Demo connection active").waitForExistence(timeout: 5))
        app.buttons["fitbit.disconnect"].tap()
        XCTAssertTrue(labelContaining("Demo disconnected").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["fitbit.sync"].exists)
        let samples = labelContaining("Simulated readings")
        revealResearchList(samples)
        XCTAssertTrue(samples.exists, "Sample history remains clearly labeled after disconnect.")
        capture("fitbit-demo-disconnected")
    }

    @MainActor func testLocalSupportDraftEditAndShare() {
        launchFreshApp()
        onboard()
        selectTab("Q&A")
        tap(app.buttons["qa.technicalSupport"])
        app.buttons["support.compose"].tap()
        let subject = app.textFields["support.subject"]
        XCTAssertTrue(subject.waitForExistence(timeout: 5))
        subject.tap()
        subject.typeText("Audio question")
        let message = app.textViews["support.message"]
        message.tap()
        message.typeText("How do I turn spoken guidance on?")
        hideSupportKeyboard()
        revealResearchList(app.buttons["support.saveDraft"])
        app.buttons["support.saveDraft"].tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "support.request.")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Draft"))

        relaunchKeepingData()
        selectTab("Q&A")
        tap(app.buttons["qa.technicalSupport"])
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        app.buttons["support.edit"].tap()
        hideSupportKeyboard()
        revealResearchList(app.buttons["support.saveRequest"])
        app.buttons["support.saveRequest"].tap()
        XCTAssertTrue(app.staticTexts["Request saved on this device"].waitForExistence(timeout: 5))
        XCTAssertTrue(labelContaining("Not sent. The study team has not received").exists)
        capture("support-request-saved-locally")
        app.buttons["support.share"].tap()
        let copyAction = app.cells["Copy"]
        XCTAssertTrue(copyAction.waitForExistence(timeout: 5), "The system share sheet offers an explicit copy action.")
        capture("support-system-share")
        copyAction.tap()
        let dismissed = expectation(for: NSPredicate(format: "exists == false"),
                                    evaluatedWith: app.otherElements["ActivityListView"])
        wait(for: [dismissed], timeout: 5)
    }

    @MainActor func testStudyTeamCanSaveQuestionWithoutSubject() {
        launchFreshApp()
        onboard()
        selectTab("Q&A")
        tap(app.buttons["qa.contact"])
        app.buttons["support.compose"].tap()
        let message = app.textViews["support.message"]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        message.tap()
        message.typeText("Can I change my check-in times?")
        hideSupportKeyboard()
        revealResearchList(app.buttons["support.saveRequest"])
        app.buttons["support.saveRequest"].tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "support.request.")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("General question"))
        XCTAssertTrue(row.label.contains("not sent"))
    }

    @MainActor private func hideSupportKeyboard() {
        let done = app.buttons["support.dismissKeyboard"]
        if done.exists && done.isHittable { done.tap() }
    }
}
