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
    func testBpmEditPersistsAfterRelaunch() throws {
        let app = XCUIApplication()
        app.launch()

        let bpm = app.buttons["main-bpm"]
        XCTAssertTrue(bpm.waitForExistence(timeout: 5))
        let initialValue = bpm.label.components(separatedBy: " ").first
        bpm.tap()

        let input = app.textFields["BPM"]
        XCTAssertTrue(input.waitForExistence(timeout: 3))
        XCTAssertEqual(input.value as? String, initialValue)
        input.tap()
        input.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: initialValue?.count ?? 3) + "137")

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
        XCTAssertFalse(app.textFields["BPM"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
