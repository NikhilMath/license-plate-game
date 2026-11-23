import XCTest

/// Taps through Plate Chase in demo mode at a human pace while the simulator screen is recorded.
/// Each step prints `DEMO-MARK <unix time> <name>`, which `tools/record.py` turns into times in
/// the recording so the video can cut to them.
final class DemoRecorder: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication(bundleIdentifier: "com.nikhilmath.licenseplategame")
        app.launchArguments = ["-DemoMode"]
    }

    func testRecordDemo() {
        app.launch()
        XCTAssertTrue(app.buttons["All"].waitForExistence(timeout: 15))
        mark("launched")
        pause(2)

        // Intro: the whole grid of plates.
        tap(app.buttons["All"], "all")
        pause(1.2)
        mark("scroll-start")
        for _ in 0..<4 {
            drag(from: 0.74, to: 0.40, velocity: 380)
            pause(0.25)
        }
        mark("scroll-end")

        // Hook: Vermont. Bring it to the middle of the screen, then spot it.
        let vermont = plate("Vermont")
        var tries = 0
        var lastY = CGFloat.infinity
        while (!vermont.exists || vermont.frame.midY > app.frame.height * 0.52) && tries < 6 {
            // Stop once the list can't scroll any further.
            if vermont.exists && abs(vermont.frame.midY - lastY) < 2 { break }
            lastY = vermont.exists ? vermont.frame.midY : .infinity
            drag(from: 0.62, to: 0.48, velocity: 300)
            pause(0.2)
            tries += 1
        }
        pause(1.5)
        tap(vermont, "vt")
        pause(2.5)

        // Back to the top, then spot two more from the Needed list.
        for _ in 0..<6 { drag(from: 0.25, to: 0.85, velocity: 3000) }
        pause(1)
        tap(app.buttons["Needed"], "needed")
        pause(1.5)
        tap(plate("Kansas"), "ks")
        pause(1.5)
        tap(plate("Maine"), "me")
        pause(1.8)
        tap(app.buttons["Spotted"], "spotted")
        pause(1.6)
        tap(app.buttons["Needed"], "needed-2")
        pause(1.3)

        // Search.
        let search = app.searchFields.firstMatch
        if !search.exists || !search.isHittable {
            drag(from: 0.30, to: 0.42, velocity: 250)
            pause(0.6)
        }
        if search.exists {
            tap(search, "search")
            pause(0.6)
            for letter in "new" {
                search.typeText(String(letter))
                pause(0.25)
            }
            mark("typed")
            pause(2)
            // The button beside the search field closes the search.
            let close = ["Cancel", "Close"].map { app.buttons[$0].firstMatch }.first { $0.exists }
            if let close {
                tap(close, "cancel")
            } else {
                mark("cancel")
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.90, dy: 0.096)).tap()
            }
            pause(1.2)
            if !app.buttons["Maya"].firstMatch.exists { print("TREE-SEARCH\n" + app.debugDescription) }
        } else {
            mark("no-search")
        }

        // Players: switch to Leo, and show everyone's dots on the All tab.
        tap(app.buttons["Maya"].firstMatch, "switcher")
        pause(1.3)
        tap(app.buttons["Leo (24)"].firstMatch, "leo")
        pause(1.5)
        tap(app.buttons["All"], "all-2")
        pause(2.5)
        tap(app.buttons["Leo"].firstMatch, "switcher-2")
        pause(0.8)
        tap(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Maya ('")).firstMatch, "maya")
        pause(1.2)

        // Friend groups.
        tap(app.tabBars.buttons["Leaderboard"], "leaderboard")
        pause(2)
        tap(tile("Road Trip Crew"), "crew")
        pause(2)
        tap(tile("Family"), "family")
        pause(1.8)
        tap(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Group code'")).firstMatch, "copy")
        pause(1.8)
        // Slide the group cards over to reach Add Group.
        let addGroup = app.buttons["Add a friend group"].firstMatch
        mark("swipe-carousel")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.27))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.27)),
                   withVelocity: XCUIGestureVelocity(rawValue: 500), thenHoldForDuration: 0.1)
        pause(1)
        tap(addGroup, "add-group")
        pause(2)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        mark("dismiss")
        pause(1.2)

        // Modes: the podium, then co-op.
        drag(from: 0.70, to: 0.42, velocity: 260)
        mark("podium")
        pause(2.5)
        tap(app.buttons["Co-op"].firstMatch, "coop")
        pause(3)
        drag(from: 0.60, to: 0.48, velocity: 200)
        pause(2)
        tap(app.buttons["Competitive"].firstMatch, "competitive")
        pause(2.5)
        mark("done")
    }

    // MARK: Helpers

    private func mark(_ name: String) {
        print(String(format: "DEMO-MARK %.3f %@", Date().timeIntervalSince1970, name))
    }

    private func pause(_ seconds: Double) {
        Thread.sleep(forTimeInterval: seconds)
    }

    /// Taps an element and records when, with where on screen as fractions of the screen size.
    private func tap(_ element: XCUIElement, _ name: String) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing \(name)")
        let frame = element.frame
        let screen = app.frame
        let x = frame.midX / screen.width
        let y = frame.midY / screen.height
        print(String(format: "DEMO-MARK %.3f %@ %.4f %.4f", Date().timeIntervalSince1970, name, x, y))
        element.tap()
    }

    private func plate(_ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name),")).firstMatch
    }

    private func tile(_ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name),")).firstMatch
    }

    /// A finger drag from one height to another (fractions of the screen), held at the end so the
    /// list stops where the finger lifts.
    private func drag(from: CGFloat, to: CGFloat, velocity: CGFloat) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: from))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: to))
        start.press(forDuration: 0.05, thenDragTo: end,
                    withVelocity: XCUIGestureVelocity(rawValue: velocity), thenHoldForDuration: 0.1)
    }
}
