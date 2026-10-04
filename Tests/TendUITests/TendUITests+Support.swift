import XCTest

extension TendUITests {
    @MainActor func testCancelConnectionAndMessageDoNotSaveAndPreviewShowsDemoStatus() {
        launchFreshApp()
        onboard()
        selectTab("Settings")
        tap(app.buttons["profile.fitbit"])
        tap(app.buttons["fitbit.connect"])
        app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(labelContaining("Demo disconnected").exists)
        XCTAssertFalse(app.buttons["fitbit.sync"].exists)
        tap(app.buttons["fitbit.connect"])
        app.alerts.buttons["Use demo connection"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        tap(app.buttons["profile.research"])
        revealResearchList(app.buttons["research.loadSample"])
        XCTAssertTrue(label("Demo connection, Active").exists)
        XCTAssertTrue(label("Real Fitbit, Not connected").exists)

        selectTab("Q&A")
        tap(app.buttons["qa.contact"])
        tap(app.buttons["support.compose"])
        XCTAssertFalse(app.buttons["support.saveRequest"].isEnabled)
        let message = app.textViews["support.message"]
        message.tap()
        message.typeText("Discard this temporary question")
        hideSupportKeyboard()
        app.navigationBars.buttons["Cancel"].tap()
        let discard = app.buttons.matching(NSPredicate(format: "label == %@", "Discard changes"))
            .allElementsBoundByIndex.first(where: { $0.isHittable })
        XCTAssertNotNil(discard)
        discard?.tap()
        XCTAssertTrue(app.staticTexts["No saved messages"].waitForExistence(timeout: 5))
    }

    @MainActor func testNameAudioAndThemePersistAfterRelaunch() {
        launchFreshApp()
        onboard()
        selectTab("Settings")
        tap(app.buttons["profile.editName"])
        let name = app.alerts.textFields.firstMatch
        name.tap()
        name.typeText("Taylor")
        app.alerts.buttons["Save"].tap()
        tap(app.buttons["profile.colorTheme.forest"])
        let audio = app.switches["profile.audio"]
        reveal(audio)
        XCTAssertEqual(audio.value as? String, "1")
        audio.tap()
        XCTAssertEqual(audio.value as? String, "0")
        relaunchKeepingData()
        selectTab("Settings")
        XCTAssertTrue(app.staticTexts["Taylor"].waitForExistence(timeout: 5))
        reveal(app.buttons["profile.colorTheme.forest"])
        XCTAssertTrue(app.buttons["profile.colorTheme.forest"].isSelected)
        reveal(audio)
        XCTAssertEqual(audio.value as? String, "0")
        audio.tap()
        reveal(app.buttons["profile.colorTheme.ocean"], direction: .down)
        tap(app.buttons["profile.colorTheme.ocean"])
    }

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
