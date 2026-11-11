import XCTest

final class DCGShowsLayoutTests: XCTestCase {
    private let shows = [("full_gallop", "Mustang Full Gallop"), ("senior_spotlight", "Senior Spotlight")]

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testBannerAndBothShowEpisodePages() throws {
        try checkBrowsing(accessibility: false)
    }

    @MainActor
    func testBrowsingAtAccessibilityTextSize() throws {
        try checkBrowsing(accessibility: true)
    }

    @MainActor
    private func checkBrowsing(accessibility: Bool) throws {
        let app = XCUIApplication()
        if accessibility {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        app.buttons["Shows"].firstMatch.tap()
        let banner = app.images["dcgtv.shows.header"]
        XCTAssertTrue(banner.waitForExistence(timeout: 10))
        XCTAssertEqual(banner.frame.width / banner.frame.height, 3, accuracy: 0.02)
        XCTAssertLessThanOrEqual(banner.frame.width, 760)
        XCTAssertTrue(banner.label.contains("Charter Bank"))
        capture(app, accessibility ? "Shows header accessibility" : "Shows supplied header")

        for (key, title) in shows {
            let card = app.buttons["dcgtv.shows.\(key)"]
            XCTAssertTrue(card.waitForExistence(timeout: 20))
            for _ in 0..<10 {
                if card.isHittable { break }
                app.scrollViews.firstMatch.swipeUp()
            }
            XCTAssertTrue(card.isHittable)
            XCTAssertGreaterThanOrEqual(card.frame.height, 44)
            XCTAssertLessThanOrEqual(card.frame.maxX, app.frame.maxX)
            card.tap()
            let navigation = app.navigationBars[title]
            XCTAssertTrue(navigation.waitForExistence(timeout: 5))
            capture(app, "\(title) episodes\(accessibility ? " accessibility" : "")")
            navigation.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(banner.waitForExistence(timeout: 5))
        }

        let browse = app.links["Browse All DCGTV Videos"]
        let home = app.buttons["Home"].firstMatch
        for _ in 0..<14 {
            if browse.isHittable && (UIDevice.current.userInterfaceIdiom != .phone || browse.frame.maxY <= home.frame.minY) { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(browse.isHittable)
        if UIDevice.current.userInterfaceIdiom == .phone {
            XCTAssertLessThanOrEqual(browse.frame.maxY, home.frame.minY)
        }
        capture(app, accessibility ? "Shows cards and footer accessibility" : "Shows cards and footer")
        home.tap()
        XCTAssertTrue(app.images["dcgtv.home.hero"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testEpisodeStillOpensAndClosesVideoBrowser() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Shows"].firstMatch.tap()
        for (key, title) in shows {
            let card = app.buttons["dcgtv.shows.\(key)"]
            XCTAssertTrue(card.waitForExistence(timeout: 20))
            card.tap()
            let navigation = app.navigationBars[title]
            XCTAssertTrue(navigation.waitForExistence(timeout: 5))
            let episode = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "dcgtv.shows.episode.")).firstMatch
            if episode.waitForExistence(timeout: 5) {
                for _ in 0..<8 {
                    if episode.isHittable { break }
                    app.scrollViews.firstMatch.swipeUp()
                }
                episode.tap()
                let close = app.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "Done", "Close")).firstMatch
                XCTAssertTrue(close.waitForExistence(timeout: 10))
                capture(app, "Existing episode video browser")
                close.tap()
                XCTAssertTrue(navigation.waitForExistence(timeout: 5))
                return
            }
            navigation.buttons.element(boundBy: 0).tap()
        }
        throw XCTSkip("Neither connected playlist currently contains a public episode")
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
