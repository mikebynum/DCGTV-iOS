import XCTest

final class DCGHomeHeroLayoutTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testHeroInDarkMode() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleInterfaceStyle", "Dark"]
        app.launch()
        let hero = app.images["dcgtv.home.hero"]
        XCTAssertTrue(hero.waitForExistence(timeout: 10))
        XCTAssertEqual(hero.frame.width / hero.frame.height, 2, accuracy: 0.02)
        XCTAssertEqual(hero.frame.minX, app.frame.minX, accuracy: 1)
        XCTAssertEqual(hero.frame.maxX, app.frame.maxX, accuracy: 1)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Home dark mode"
        capture.lifetime = .keepAlways
        add(capture)
    }

    @MainActor
    func testHeroAfterRotationAndReturningHome() throws {
        let app = XCUIApplication()
        app.launch()
        defer { XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .landscapeLeft
        let hero = app.images["dcgtv.home.hero"]
        XCTAssertTrue(hero.waitForExistence(timeout: 10))
        // Wait for the rotation to settle before checking screen geometry.
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate { _, _ in app.frame.width > app.frame.height }, evaluatedWith: app)], timeout: 5), .completed)
        XCTAssertEqual(hero.frame.width / hero.frame.height, 2, accuracy: 0.02)
        XCTAssertEqual(hero.frame.minX, app.frame.minX, accuracy: 1)
        XCTAssertEqual(hero.frame.maxX, app.frame.maxX, accuracy: 1)
        // Screen capture can lag the accessibility rotation on Simulator.
        Thread.sleep(forTimeInterval: 1)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Home landscape"
        capture.lifetime = .keepAlways
        add(capture)
        XCUIDevice.shared.orientation = .portrait
        app.buttons.matching(NSPredicate(format: "label == %@", "Watch")).firstMatch.tap()
        app.buttons.matching(NSPredicate(format: "label == %@", "Home")).firstMatch.tap()
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        XCTAssertEqual(hero.frame.minX, app.frame.minX, accuracy: 1)
        XCTAssertEqual(hero.frame.maxX, app.frame.maxX, accuracy: 1)
    }

    @MainActor
    func testCompactHomeKeepsFooterAboveTabsAndRemovesShortcuts() throws {
        try checkCompactHome(accessibility: false)
    }

    @MainActor
    func testCompactHomeAtAccessibilityTextSize() throws {
        try checkCompactHome(accessibility: true)
    }

    @MainActor
    private func checkCompactHome(accessibility: Bool) throws {
        let app = XCUIApplication()
        if accessibility {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        XCTAssertTrue(app.images["dcgtv.home.hero"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Live & Recent Broadcasts"].exists)
        XCTAssertFalse(app.buttons["Explore DCGTV Shows"].exists)
        XCTAssertFalse(app.buttons["See All Away Streams"].exists)

        let footer = app.links["Visit the DCG Booster Club"]
        for _ in 0..<12 {
            if footer.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(footer.isHittable)
        let homeTab = app.buttons.matching(NSPredicate(format: "label == %@", "Home")).firstMatch
        XCTAssertTrue(homeTab.isHittable)
        if UIDevice.current.userInterfaceIdiom == .phone {
            XCTAssertLessThanOrEqual(footer.frame.maxY, homeTab.frame.minY)
        }
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = accessibility ? "Compact Home accessibility results and footer" : "Compact Home results and footer"
        capture.lifetime = .keepAlways
        add(capture)
        app.buttons.matching(NSPredicate(format: "label == %@", "Shows")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["DCGTV Originals"].waitForExistence(timeout: 5))
        homeTab.tap()
        XCTAssertTrue(homeTab.isSelected)
    }

}
