import XCTest

final class DCGTabConsistencyTests: XCTestCase {
    private let tabs = [
        ("Home", "dcgtv.home.hero", "Visit the DCG Booster Club"),
        ("Watch", "dcgtv.watch.header", "Browse All Broadcasts"),
        ("Schedule", "dcgtv.schedule.header", "Full YouTube Schedule"),
        ("Shows", "dcgtv.shows.header", "Browse All DCGTV Videos")
    ]

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testHeadersAndScrollingAcrossAllTabs() throws {
        let app = XCUIApplication()
        app.launch()
        let contentWidth = min(app.frame.width - 32, 760)
        for (name, identifier, _) in tabs {
            let tab = app.buttons.matching(NSPredicate(format: "label == %@", name)).firstMatch
            tab.tap()
            let header = app.descendants(matching: .any)[identifier]
            XCTAssertTrue(header.waitForExistence(timeout: 10))
            XCTAssertTrue(header.label.contains("Charter Bank"))
            XCTAssertEqual(header.frame.midX, app.frame.midX, accuracy: 1)
            if name == "Home" {
                XCTAssertEqual(header.frame.width, app.frame.width, accuracy: 1)
                XCTAssertEqual(header.frame.width / header.frame.height, 2, accuracy: 0.02)
                let heading = app.staticTexts["Featured Broadcast"]
                XCTAssertEqual(heading.frame.minX, app.frame.midX - contentWidth / 2, accuracy: 1)
            } else {
                XCTAssertEqual(header.frame.width, contentWidth, accuracy: 1)
                XCTAssertEqual(header.frame.width / header.frame.height, 3, accuracy: 0.02)
            }
            if let status = app.statusBars.allElementsBoundByIndex.first {
                XCTAssertGreaterThanOrEqual(header.frame.minY, status.frame.maxY - 1)
            }
            capture(app, "\(name) consistent header")
            app.scrollViews.firstMatch.swipeUp()
            XCTAssertTrue(tab.isHittable)
            capture(app, "\(name) while scrolling")
        }
    }

    @MainActor
    func testAllTabFootersClearSystemControls() throws {
        try checkFooters(accessibility: false)
    }

    @MainActor
    func testAllTabFootersAtAccessibilityTextSize() throws {
        try checkFooters(accessibility: true)
    }

    @MainActor
    private func checkFooters(accessibility: Bool) throws {
        let app = XCUIApplication()
        if accessibility {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        for (name, identifier, footerLabel) in tabs {
            let tab = app.buttons.matching(NSPredicate(format: "label == %@", name)).firstMatch
            tab.tap()
            XCTAssertTrue(app.descendants(matching: .any)[identifier].waitForExistence(timeout: 10))
            if name == "Schedule" {
                // Exercise the footer without traversing the live season's entire schedule.
                let search = app.textFields["dcgtv.schedule.search"]
                for _ in 0..<10 {
                    if search.isHittable { break }
                    app.scrollViews.firstMatch.swipeUp()
                }
                search.tap()
                search.typeText("unmatched-final-review\n")
            }
            let footer = app.links[footerLabel]
            for _ in 0..<30 {
                let clearsTabs = UIDevice.current.userInterfaceIdiom != .phone || footer.frame.maxY <= tab.frame.minY
                if footer.isHittable && clearsTabs { break }
                app.scrollViews.firstMatch.swipeUp()
            }
            XCTAssertTrue(footer.isHittable, "\(name) footer must be reachable")
            XCTAssertGreaterThanOrEqual(footer.frame.height, 44)
            XCTAssertGreaterThanOrEqual(footer.frame.minX, app.frame.minX)
            XCTAssertLessThanOrEqual(footer.frame.maxX, app.frame.maxX)
            if UIDevice.current.userInterfaceIdiom == .phone {
                XCTAssertLessThanOrEqual(footer.frame.maxY, tab.frame.minY)
            }
            XCTAssertTrue(tab.isHittable)
            capture(app, "\(name) footer\(accessibility ? " accessibility" : "")")
        }
    }

    @MainActor
    func testLandscapeHeadersAcrossAllTabs() throws {
        let app = XCUIApplication()
        app.launch()
        defer { XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .landscapeLeft
        let rotated = expectation(for: NSPredicate { _, _ in app.frame.width > app.frame.height }, evaluatedWith: app)
        XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 5), .completed)
        for (name, identifier, _) in tabs {
            let tab = app.buttons.matching(NSPredicate(format: "label == %@", name)).firstMatch
            tab.tap()
            let header = app.descendants(matching: .any)[identifier]
            XCTAssertTrue(header.waitForExistence(timeout: 10))
            XCTAssertEqual(header.frame.width / header.frame.height, name == "Home" ? 2 : 3, accuracy: 0.02)
            XCTAssertGreaterThanOrEqual(header.frame.minX, app.frame.minX - 1)
            XCTAssertLessThanOrEqual(header.frame.maxX, app.frame.maxX + 1)
            XCTAssertTrue(tab.isHittable)
            capture(app, "\(name) landscape")
        }
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
