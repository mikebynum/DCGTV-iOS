//
//  DCG_Booster_ClubUITests.swift
//  DCG Booster ClubUITests
//
//  Created by Mike Bynum on 10/28/26.
//

import XCTest

final class DCG_Booster_ClubUITests: XCTestCase {

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
    func testHomeBrandingSponsorAndScheduleNavigation() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.images["dcgtv.home.hero"].waitForExistence(timeout: 10))
        let hero = app.images["dcgtv.home.hero"]
        XCTAssertEqual(hero.frame.width / hero.frame.height, 2, accuracy: 0.02)
        XCTAssertEqual(hero.frame.minX, app.frame.minX, accuracy: 1)
        XCTAssertEqual(hero.frame.maxX, app.frame.maxX, accuracy: 1)
        let viewport = app.scrollViews.firstMatch
        XCTAssertTrue(viewport.exists)
        // iPad retains its native top tab controls; iPhone artwork reaches y=0.
        if UIDevice.current.userInterfaceIdiom == .phone {
            XCTAssertEqual(viewport.frame.minY, app.frame.minY, accuracy: 1)
        }
        XCTAssertGreaterThan(hero.frame.minY, viewport.frame.minY)
        XCTAssertTrue(hero.label.contains("Charter Bank"))
        XCTAssertFalse(app.descendants(matching: .any)["DCGTV livestreams presented by Charter Bank"].exists)
        let home = XCTAttachment(screenshot: app.screenshot())
        home.name = "Sponsored hero Home"
        home.lifetime = .keepAlways
        add(home)

        let schedule = app.buttons["View Broadcast Schedule"]
        for _ in 0..<6 {
            if schedule.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(schedule.isHittable)
        let broadcast = XCTAttachment(screenshot: app.screenshot())
        broadcast.name = "Featured broadcast and schedule link"
        broadcast.lifetime = .keepAlways
        add(broadcast)
        schedule.tap()
        XCTAssertTrue(app.buttons["dcgtv.schedule.Upcoming"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label == %@ AND selected == true", "Schedule")).firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Shows")).firstMatch.exists)
        app.buttons["Watch"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["DCGTV livestreams presented by Charter Bank"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHomeAtAccessibilityTextSize() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.images["dcgtv.home.hero"].waitForExistence(timeout: 10))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Home accessibility text size"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label == %@ AND selected == true", "Home")).firstMatch.exists)
    }

    @MainActor
    func testScheduleSelectionsAndFavoritePicker() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Schedule"].firstMatch.tap()
        let upcoming = app.buttons["dcgtv.schedule.Upcoming"]
        XCTAssertTrue(upcoming.waitForExistence(timeout: 10))
        XCTAssertTrue(upcoming.isSelected)
        app.buttons["dcgtv.schedule.Starred"].tap()
        XCTAssertTrue(app.buttons["dcgtv.schedule.Starred"].isSelected)
        app.buttons["dcgtv.schedule.All Sports"].tap()
        XCTAssertTrue(app.buttons["dcgtv.schedule.All Sports"].isSelected)
        app.buttons["dcgtv.schedule.favorites"].tap()
        XCTAssertTrue(app.navigationBars["Favorite Sports"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Schedule standard size"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let details = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Game details, ")).firstMatch
        for _ in 0..<5 {
            if details.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(details.isHittable, "Live schedule should expose event details")
        let events = XCTAttachment(screenshot: app.screenshot())
        events.name = "Schedule event cards"
        events.lifetime = .keepAlways
        add(events)
        details.tap()
        XCTAssertTrue(app.navigationBars["Game Details"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testScheduleAtAccessibilityTextSize() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.buttons["Schedule"].firstMatch.tap()
        let upcoming = app.buttons["dcgtv.schedule.Upcoming"]
        XCTAssertTrue(upcoming.waitForExistence(timeout: 10))
        for _ in 0..<5 {
            if app.buttons["dcgtv.schedule.All Sports"].isHittable { break }
            app.swipeUp()
        }
        let all = app.buttons["dcgtv.schedule.All Sports"]
        XCTAssertTrue(all.isHittable)
        XCTAssertLessThanOrEqual(all.frame.maxX, app.frame.maxX)
        all.tap()
        XCTAssertTrue(all.isSelected)
        // Let the button's native pressed appearance finish before capturing.
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Schedule accessibility text size"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
