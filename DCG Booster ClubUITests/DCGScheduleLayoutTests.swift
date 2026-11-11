import XCTest

final class DCGScheduleLayoutTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testBannerSearchResetAndCompactGameDetails() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Schedule"].firstMatch.tap()
        let header = app.images["dcgtv.schedule.header"]
        XCTAssertTrue(header.waitForExistence(timeout: 10))
        XCTAssertEqual(header.frame.width / header.frame.height, 3, accuracy: 0.02)
        XCTAssertLessThanOrEqual(header.frame.width, 760)
        XCTAssertTrue(header.label.contains("Charter Bank"))
        XCTAssertFalse(app.staticTexts["Game day starts here."].exists)
        let banner = XCTAttachment(screenshot: app.screenshot())
        banner.name = "Schedule supplied banner and controls"
        banner.lifetime = .keepAlways
        add(banner)

        let search = app.textFields["dcgtv.schedule.search"]
        for _ in 0..<5 {
            if search.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(search.isHittable)
        XCTAssertTrue(app.buttons["dcgtv.schedule.sportFilter"].exists)
        XCTAssertTrue(app.buttons["dcgtv.schedule.levelFilter"].exists)
        search.tap()
        search.typeText("unmatched-event-dcgtv-789\n")
        let clear = app.buttons["Clear filters"]
        for _ in 0..<5 {
            if clear.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(clear.isHittable)
        XCTAssertTrue(app.staticTexts["No games match this selection"].exists)
        clear.tap()
        XCTAssertEqual(search.value as? String, "Search opponent or team")
        if app.keyboards.firstMatch.exists {
            search.typeText("\n")
        }
        let reset = XCTAttachment(screenshot: app.screenshot())
        reset.name = "Schedule after search reset"
        reset.lifetime = .keepAlways
        add(reset)

        let buttons = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Game details, "))
        var visible = buttons.allElementsBoundByIndex.first(where: { $0.isHittable })
        for _ in 0..<8 {
            if visible != nil { break }
            app.scrollViews.firstMatch.swipeUp()
            visible = buttons.allElementsBoundByIndex.first(where: { $0.isHittable })
        }
        let afterScroll = XCTAttachment(screenshot: app.screenshot())
        afterScroll.name = "Schedule after scrolling reset results"
        afterScroll.lifetime = .keepAlways
        add(afterScroll)
        let details = try XCTUnwrap(visible, "Schedule hierarchy after clearing search: \(app.debugDescription)")
        XCTAssertGreaterThanOrEqual(details.frame.height, 44)
        XCTAssertGreaterThanOrEqual(details.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(details.frame.maxX, app.frame.maxX)
        let cards = XCTAttachment(screenshot: app.screenshot())
        cards.name = "Schedule compact game cards"
        cards.lifetime = .keepAlways
        add(cards)
        details.tap()
        XCTAssertTrue(app.navigationBars["Game Details"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertFalse(app.navigationBars["Game Details"].exists)
    }
    @MainActor
    func testCompactGameAtAccessibilityTextSize() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.buttons["Schedule"].firstMatch.tap()
        XCTAssertTrue(app.images["dcgtv.schedule.header"].waitForExistence(timeout: 10))
        let details = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Game details, ")).firstMatch
        for _ in 0..<14 {
            if details.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(details.isHittable)
        XCTAssertLessThanOrEqual(details.frame.maxX, app.frame.maxX)
        XCTAssertGreaterThanOrEqual(details.frame.minX, app.frame.minX)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Schedule compact game accessibility"
        capture.lifetime = .keepAlways
        add(capture)
        details.tap()
        XCTAssertTrue(app.navigationBars["Game Details"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
    }

}
