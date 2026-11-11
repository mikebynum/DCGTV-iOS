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
        let header = app.descendants(matching: .any)["dcgtv.watch.header"]
        XCTAssertTrue(header.waitForExistence(timeout: 10))
        XCTAssertTrue(header.isHittable)
        XCTAssertEqual(header.frame.width / header.frame.height, 3, accuracy: 0.02)
        XCTAssertEqual(header.frame.minX, app.frame.minX + 16, accuracy: 1)
        XCTAssertEqual(header.frame.maxX, app.frame.maxX - 16, accuracy: 1)
        XCTAssertTrue(header.label.contains("Charter Bank"))
        XCTAssertFalse(app.images["dcgtv.watch.logo"].exists)
        XCTAssertFalse(app.staticTexts["Presented by"].exists)
        if UIDevice.current.userInterfaceIdiom == .phone,
           let statusBar = app.statusBars.allElementsBoundByIndex.first {
            XCTAssertGreaterThanOrEqual(header.frame.minY, statusBar.frame.maxY)
        }
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = accessibility ? "Watch banner accessibility" : "Watch banner"
        capture.lifetime = .keepAlways
        add(capture)
        let browse = app.links["Browse All Broadcasts"]
        for _ in 0..<25 {
            if browse.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(browse.isHittable)
        let home = app.buttons.matching(NSPredicate(format: "label == %@", "Home")).firstMatch
        if UIDevice.current.userInterfaceIdiom == .phone {
            XCTAssertLessThanOrEqual(browse.frame.maxY, home.frame.minY)
        }
        let replays = XCTAttachment(screenshot: app.screenshot())
        replays.name = accessibility ? "Watch replay cards accessibility" : "Watch replay cards"
        replays.lifetime = .keepAlways
        add(replays)
        home.tap()
        XCTAssertTrue(app.images["dcgtv.home.hero"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testReplayStillOpensVideoBrowser() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons.matching(NSPredicate(format: "label == %@", "Watch")).firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["dcgtv.watch.header"].waitForExistence(timeout: 10))
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
