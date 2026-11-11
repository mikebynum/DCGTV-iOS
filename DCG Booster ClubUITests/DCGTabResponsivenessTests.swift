import XCTest

final class DCGTabResponsivenessTests: XCTestCase {
    @MainActor
    func testRepeatedTabSwitching() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        // Warm each tab before measuring repeated navigation with loaded data.
        for name in ["Schedule", "Shows", "Watch", "Home"] {
            app.buttons[name].firstMatch.tap()
        }
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTClockMetric()], options: options) {
            for (name, identifier) in [("Schedule", "dcgtv.schedule.header"),
                                        ("Shows", "dcgtv.shows.header"),
                                        ("Watch", "dcgtv.watch.header"),
                                        ("Home", "dcgtv.home.hero")] {
                app.buttons[name].firstMatch.tap()
                XCTAssertTrue(app.descendants(matching: .any)[identifier].firstMatch.waitForExistence(timeout: 5))
            }
        }
    }
}
