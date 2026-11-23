import XCTest

/// Prints the accessibility tree of each screen, to find elements for the recorder.
final class Explore: XCTestCase {
    func testExplore() {
        let app = XCUIApplication(bundleIdentifier: "com.nikhilmath.licenseplategame")
        app.launchArguments = ["-DemoMode"]
        app.launch()
        _ = app.buttons["All"].waitForExistence(timeout: 10)
        print("TREE-PLATES\n" + app.debugDescription)
        app.buttons["Leaderboard"].firstMatch.tap()
        sleep(2)
        print("TREE-LEADERBOARD\n" + app.debugDescription)
    }
}
