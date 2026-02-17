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
        captureScreenshot(name: "01_HomeScreen", app: app)

        // 2. Przejście do kalendarza i zrzut
        let calendarTab = app.tabBars.buttons["Calendar"]
        if calendarTab.waitForExistence(timeout: 5) {
            calendarTab.tap()
            captureScreenshot(name: "02_CalendarScreen", app: app)
        }

        // 3. Przejście do monitora wody
        let waterTab = app.tabBars.buttons["Water tracker"]
        if waterTab.exists {
            waterTab.tap()
            captureScreenshot(name: "03_WaterTrackerScreen", app: app)
        }

        // 4. Przejście do profilu
        let profileTab = app.tabBars.buttons["Profile"]
        if profileTab.exists {
            profileTab.tap()
            captureScreenshot(name: "04_ProfileScreen", app: app)
        }
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
