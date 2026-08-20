import XCTest

/// UI test that walks the main Toto Buddy screens and saves full-resolution
/// PNG screenshots for App Store Connect upload (run once per simulator size).
final class TotoScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureAllScreens() throws {
        let app = XCUIApplication()
        app.launch()

        // Output dir keyed by device name so multiple sim runs don't collide.
        let deviceName = UIDevice.current.name
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "'", with: "")
        let outDir = "/tmp/toto-shots/\(deviceName)"
        try FileManager.default.createDirectory(
            atPath: outDir, withIntermediateDirectories: true)

        func shot(_ name: String) throws {
            let png = XCUIScreen.main.screenshot().pngRepresentation
            let path = "\(outDir)/\(name).png"
            try png.write(to: URL(fileURLWithPath: path))
            print("SHOT_SAVED \(path)")
        }

        // 1 — Onboarding first page
        try shot("01-onboarding")

        let skip = app.buttons["Skip"]
        if skip.waitForExistence(timeout: 5) {
            skip.tap()
        }

        // 2 — Home with next draw + latest result
        _ = app.staticTexts["Next Draw"].waitForExistence(timeout: 20)
        // let data finish loading
        _ = app.staticTexts["Latest Result"].waitForExistence(timeout: 15)
        Thread.sleep(forTimeInterval: 1.5)
        try shot("02-home")

        // 3 — Home scrolled to Bust the Myths
        let mythLabel = app.staticTexts["Bust the Myths"]
        if mythLabel.waitForExistence(timeout: 5) {
            var attempts = 0
            while !(mythLabel.isHittable) && attempts < 5 {
                app.swipeUp()
                attempts += 1
                Thread.sleep(forTimeInterval: 0.4)
            }
        }
        Thread.sleep(forTimeInterval: 0.8)
        try shot("03-home-myths")

        // 4 — History (draws list)
        app.tabBars.buttons["History"].tap()
        _ = app.staticTexts["Draws"].waitForExistence(timeout: 10)
        Thread.sleep(forTimeInterval: 1.0)
        try shot("04-history")

        // 5 — History (numbers grid)
        app.buttons["Numbers"].tap()
        Thread.sleep(forTimeInterval: 1.0)
        try shot("05-history-numbers")

        // 6 — Calculator
        app.tabBars.buttons["Calculator"].tap()
        _ = app.staticTexts["Your budget"].waitForExistence(timeout: 10)
        Thread.sleep(forTimeInterval: 1.0)
        try shot("06-calculator")

        // 7 — Picks
        app.tabBars.buttons["Picks"].tap()
        _ = app.staticTexts["Your budget"].waitForExistence(timeout: 10)
        Thread.sleep(forTimeInterval: 1.0)
        try shot("07-picks")

        print("ALL_SHOTS_DONE")
    }
}
