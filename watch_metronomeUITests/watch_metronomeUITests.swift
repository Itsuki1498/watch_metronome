//
//  watch_metronomeUITests.swift
//  watch_metronomeUITests
//
//  Created by 執行一生 on 2026/05/18.
//

import XCTest

final class watch_metronomeUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testThreeScreenNavigation() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["メトロノーム"].waitForExistence(timeout: 5))

        app.buttons["screen-index-0"].tap()
        XCTAssertTrue(app.navigationBars["複合拍子"].waitForExistence(timeout: 3))

        app.buttons["screen-index-2"].tap()
        XCTAssertTrue(app.navigationBars["プリセット"].waitForExistence(timeout: 3))

        app.buttons["screen-index-1"].tap()
        XCTAssertTrue(app.navigationBars["メトロノーム"].waitForExistence(timeout: 3))

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testBasicPresetCanBeSavedAppliedAndQueuedAfterRelaunch() throws {
        let app = XCUIApplication()
        app.launch()

        let bpm = app.buttons["main-bpm"]
        XCTAssertTrue(bpm.waitForExistence(timeout: 5))
        let expectedBpm = bpm.label
        let presetName = "QA-\(UUID().uuidString.prefix(8))"

        app.buttons["screen-index-2"].tap()
        let nameInput = app.textFields["preset-name-input"]
        XCTAssertTrue(nameInput.waitForExistence(timeout: 3))
        nameInput.tap()
        nameInput.typeText(presetName)

        let saveButton = app.buttons["save-preset"]
        if !saveButton.isHittable {
            app.swipeUp()
        }
        saveButton.tap()

        app.terminate()
        app.launch()
        app.buttons["screen-index-2"].tap()

        let applyButton = app.buttons["apply-preset-\(presetName)"]
        for _ in 0..<5 where !applyButton.exists {
            app.swipeUp()
        }
        XCTAssertTrue(applyButton.waitForExistence(timeout: 5))
        applyButton.tap()
        app.buttons["screen-index-1"].tap()
        XCTAssertEqual(bpm.label, expectedBpm)

        app.buttons["screen-index-2"].tap()
        let queueButton = app.buttons["queue-preset-\(presetName)"]
        XCTAssertTrue(queueButton.waitForExistence(timeout: 3))
        queueButton.tap()
        app.buttons["screen-index-1"].tap()
        XCTAssertTrue(app.staticTexts["予約済み"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testCompositePresetRetainsSectionsWhenAppliedAndQueued() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["screen-index-0"].tap()

        let moduleNames = app.textFields.matching(identifier: "meter-module-name")
        XCTAssertTrue(moduleNames.firstMatch.waitForExistence(timeout: 3))
        let originalCount = moduleNames.count
        app.buttons["add-meter-module"].tap()
        XCTAssertEqual(moduleNames.count, originalCount + 1)

        let presetName = "QA-Composite-\(UUID().uuidString.prefix(8))"
        app.buttons["screen-index-2"].tap()
        app.segmentedControls["preset-kind"].buttons["複合"].tap()
        let nameInput = app.textFields["preset-name-input"]
        nameInput.tap()
        nameInput.typeText(presetName)

        let saveButton = app.buttons["save-preset"]
        if !saveButton.isHittable {
            app.swipeUp()
        }
        saveButton.tap()

        app.terminate()
        app.launch()
        app.buttons["screen-index-2"].tap()
        let applyButton = app.buttons["apply-preset-\(presetName)"]
        for _ in 0..<5 where !applyButton.exists {
            app.swipeUp()
        }
        XCTAssertTrue(applyButton.waitForExistence(timeout: 5))
        applyButton.tap()
        app.buttons["screen-index-0"].tap()
        XCTAssertEqual(moduleNames.count, originalCount + 1)

        app.buttons["screen-index-2"].tap()
        app.buttons["queue-preset-\(presetName)"].tap()
        app.buttons["screen-index-1"].tap()
        XCTAssertTrue(app.staticTexts["予約済み"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testCompositeProgramCanAddAnotherMeterModule() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["screen-index-0"].tap()
        let moduleNames = app.textFields.matching(identifier: "meter-module-name")
        XCTAssertTrue(moduleNames.firstMatch.waitForExistence(timeout: 3))
        let initialModuleCount = moduleNames.count

        app.buttons["add-meter-module"].tap()

        XCTAssertEqual(moduleNames.count, initialModuleCount + 1)
        XCTAssertTrue(app.switches["composite-loop"].exists)
    }

    @MainActor
    func testCompositeMeterEditUpdatesPlayScreen() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["screen-index-0"].tap()

        let numerator = app.pickerWheels.firstMatch
        XCTAssertTrue(numerator.waitForExistence(timeout: 3))
        numerator.adjust(toPickerWheelValue: "5")
        XCTAssertTrue(app.staticTexts["5/4"].waitForExistence(timeout: 3))

        app.buttons["screen-index-1"].tap()
        XCTAssertTrue(app.staticTexts["5/4"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testQueuedMeterAppliesAtNextMeasure() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["screen-index-0"].tap()
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "5")
        app.buttons["screen-index-1"].tap()

        let currentMeter = app.staticTexts["current-meter"]
        XCTAssertTrue(currentMeter.waitForExistence(timeout: 3))
        XCTAssertEqual(currentMeter.label, "5/4")

        app.buttons["メトロノームを再生"].tap()
        let applyButton = app.buttons["次の小節から適用"].firstMatch
        for _ in 0..<3 where !applyButton.isHittable {
            app.swipeUp()
        }
        applyButton.tap()

        let applied = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "4/4"),
            object: currentMeter
        )
        XCTAssertEqual(XCTWaiter.wait(for: [applied], timeout: 8), .completed)
        app.buttons["メトロノームを停止"].tap()
    }

    @MainActor
    func testNextMeasureTempoControlsAreReachable() throws {
        let app = XCUIApplication()
        app.launch()

        let applyButton = app.buttons["次の小節から適用"].firstMatch
        for _ in 0..<3 where !applyButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(applyButton.waitForExistence(timeout: 3))
        applyButton.tap()

        let tempoDisclosure = app.buttons["tempo-automation-toggle"]
        for _ in 0..<2 where !tempoDisclosure.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(tempoDisclosure.waitForExistence(timeout: 3))
        tempoDisclosure.tap()
        let startAutomation = app.buttons["start-tempo-automation"]
        XCTAssertTrue(startAutomation.waitForExistence(timeout: 3))
        for _ in 0..<3 where !startAutomation.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(startAutomation.isHittable)
        startAutomation.tap()
        XCTAssertTrue(app.staticTexts["予約済み"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testNumericKeyboardCanBeDismissedFromInputButton() throws {
        let app = XCUIApplication()
        app.launch()

        let tempoDisclosure = app.buttons["tempo-automation-toggle"]
        for _ in 0..<3 where !tempoDisclosure.isHittable {
            app.swipeUp()
        }
        tempoDisclosure.tap()

        let targetBpm = app.textFields["目標BPM"].firstMatch
        for _ in 0..<3 where !targetBpm.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(targetBpm.waitForExistence(timeout: 3))
        targetBpm.tap()

        let doneButton = app.buttons["number-field-done"].firstMatch
        XCTAssertTrue(doneButton.waitForExistence(timeout: 3))
        doneButton.tap()

        XCTAssertFalse(app.keyboards.firstMatch.exists)
    }

    @MainActor
    func testBpmEditPersistsAfterRelaunch() throws {
        let app = XCUIApplication()
        app.launch()

        let bpm = app.buttons["main-bpm"]
        XCTAssertTrue(bpm.waitForExistence(timeout: 5))
        let initialValue = bpm.label.components(separatedBy: " ").first
        bpm.tap()

        let input = app.textFields["bpm-direct-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 3))
        XCTAssertEqual(input.value as? String, initialValue)
        input.tap()
        app.buttons["bpm-clear-input"].tap()
        input.typeText("137")

        app.buttons["完了"].tap()
        XCTAssertFalse(input.waitForExistence(timeout: 1))
        XCTAssertEqual(bpm.label, "137 BPM")

        app.terminate()
        app.launch()
        XCTAssertTrue(bpm.waitForExistence(timeout: 5))
        XCTAssertEqual(bpm.label, "137 BPM")
    }

    @MainActor
    func testBpmDragAdjustsTempoWithoutOpeningEntry() throws {
        let app = XCUIApplication()
        app.launch()

        let bpm = app.buttons["main-bpm"]
        XCTAssertTrue(bpm.waitForExistence(timeout: 5))
        let initialLabel = bpm.label
        let start = bpm.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        let end = bpm.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        start.press(forDuration: 0.1, thenDragTo: end)

        XCTAssertNotEqual(bpm.label, initialLabel)
        XCTAssertFalse(app.textFields["bpm-direct-input"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
