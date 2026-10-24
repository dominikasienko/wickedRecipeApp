//
//  RecipePlannerIOSUITestsLaunchTests.swift
//  RecipePlannerIOSUITests
//
//  Created by Dominika Sieńko on 26/12/2025.
//

import XCTest

final class RecipePlannerIOSUITestsLaunchTests: XCTestCase {

    // Dzięki temu test uruchomi się dla różnych konfiguracji (np. Portrait/Landscape)
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchAndCaptureKeyScreens() throws {
        let app = XCUIApplication()
        app.launch()

        // 1. Zrzut ekranu: Ekran startowy (Home)
        XCTAssertTrue(
            waitForCustomTab(in: app, identifier: RecipePlannerUITestIdentifiers.homeTab, name: "Home").exists,
            "The launch test requires an authenticated, consented test account."
        )
        captureScreenshot(name: "01_HomeScreen", app: app)

        // 2. Przejście do kalendarza i zrzut
        tapCustomTab(in: app, identifier: RecipePlannerUITestIdentifiers.calendarTab, name: "Calendar")
        XCTAssertTrue(app.navigationBars["Meal Plan"].waitForExistence(timeout: 10))
        captureScreenshot(name: "02_CalendarScreen", app: app)

        // 3. Przejście do monitora wody
        tapCustomTab(in: app, identifier: RecipePlannerUITestIdentifiers.waterTrackerTab, name: "Water tracker")
        XCTAssertTrue(app.navigationBars["Hydration Tracker"].waitForExistence(timeout: 10))
        captureScreenshot(name: "03_WaterTrackerScreen", app: app)

        // 4. Przejście do profilu
        tapCustomTab(in: app, identifier: RecipePlannerUITestIdentifiers.profileTab, name: "Profile")
        XCTAssertTrue(app.navigationBars["My Profile"].waitForExistence(timeout: 10))
        captureScreenshot(name: "04_ProfileScreen", app: app)
    }

    /// Funkcja pomocnicza do robienia zrzutów ekranu
    @MainActor
    private func captureScreenshot(name: String, app: XCUIApplication) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways // Zrzut zostanie zachowany w wynikach testu
        add(attachment)
    }
}
