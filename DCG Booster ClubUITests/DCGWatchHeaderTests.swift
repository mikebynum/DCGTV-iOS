import XCTest

final class DCGWatchHeaderTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCompactHeaderAndTabNavigation() throws {
        try checkHeader(accessibility: false)
    }

    @MainActor
    func testCompactHeaderAtAccessibilityTextSize() throws {
        try checkHeader(accessibility: true)
    }

    @MainActor
    private func checkHeader(accessibility: Bool) throws {
        let app = XCUIApplication()
        if accessibility {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        app.buttons.matching(NSPredicate(format: "label == %@", "Watch")).firstMatch.tap()
        let logo = app.images["dcgtv.watch.logo"]
        XCTAssertTrue(logo.waitForExistence(timeout: 10))
        XCTAssertTrue(logo.isHittable)
        XCTAssertEqual(logo.frame.width, 96, accuracy: 1)
        let sponsor = app.descendants(matching: .any)["DCGTV livestreams presented by Charter Bank"]
        XCTAssertTrue(sponsor.isHittable)
        XCTAssertGreaterThanOrEqual(sponsor.frame.height, 44)
        XCTAssertGreaterThanOrEqual(sponsor.frame.minY, logo.frame.maxY)
        XCTAssertLessThanOrEqual(sponsor.frame.maxX, app.frame.maxX - 15)
        XCTAssertFalse(app.staticTexts["Watch Mustang games live or on demand"].exists)
        if UIDevice.current.userInterfaceIdiom == .phone,
           let statusBar = app.statusBars.allElementsBoundByIndex.first {
            XCTAssertGreaterThanOrEqual(logo.frame.minY, statusBar.frame.maxY)
        }
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = accessibility ? "Watch compact header accessibility" : "Watch compact header"
        capture.lifetime = .keepAlways
        add(capture)
        app.buttons.matching(NSPredicate(format: "label == %@", "Home")).firstMatch.tap()
        XCTAssertTrue(app.images["dcgtv.home.hero"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testReplayStillOpensVideoBrowser() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons.matching(NSPredicate(format: "label == %@", "Watch")).firstMatch.tap()
        XCTAssertTrue(app.images["dcgtv.watch.logo"].waitForExistence(timeout: 10))
        let replay = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Watch Replay")).firstMatch
        // CMS content is live; scroll through away streams and replays if available.
        for _ in 0..<20 {
            if replay.isHittable { break }
            app.swipeUp()
        }
        guard replay.isHittable else {
            throw XCTSkip("No replay is available in the connected CMS data")
        }
        replay.tap()
        let close = app.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "Done", "Close")).firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 10), "Replay browser hierarchy: \(app.debugDescription)")
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Existing replay browser"
        capture.lifetime = .keepAlways
        add(capture)
        close.tap()
        XCTAssertFalse(close.exists)
    }
}
