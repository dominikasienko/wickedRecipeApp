//
//  RecipePlannerIOSUITests.swift
//  RecipePlannerIOSUITests
//
//  Created by Dominika Sieńko on 26/12/2025.
//

import XCTest

final class RecipePlannerIOSUITests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        // Zatrzymuje testy w momencie wystąpienia pierwszego błędu
        continueAfterFailure = false
        // Uruchamia aplikację przed każdym testem
        app.launch()
    }

    /// Tests that the main custom navigation controls are visible and available.
    @MainActor
    func testNavigationTabBarItemsExist() throws {
        // AppTabView uses a custom horizontal navigation bar, not a native TabView.
        XCTAssertTrue(
            waitForCustomTab(in: app, identifier: RecipePlannerUITestIdentifiers.homeTab, name: "Home").exists,
            "The Home tab should be visible."
        )
        XCTAssertTrue(
            waitForCustomTab(in: app, identifier: RecipePlannerUITestIdentifiers.calendarTab, name: "Calendar").exists,
            "The Calendar tab should be visible."
        )
        XCTAssertTrue(
            waitForCustomTab(in: app, identifier: RecipePlannerUITestIdentifiers.waterTrackerTab, name: "Water tracker").exists,
            "The Water tracker tab should be visible."
        )
        XCTAssertTrue(
            waitForCustomTab(in: app, identifier: RecipePlannerUITestIdentifiers.profileTab, name: "Profile").exists,
            "The Profile tab should be visible."
        )
    }

    /// Symuluje przejście do ekranu dodawania wody i sprawdza interakcję.
    @MainActor
    func testWaterTrackerNavigation() throws {
        tapCustomTab(
            in: app,
            identifier: RecipePlannerUITestIdentifiers.waterTrackerTab,
            name: "Water tracker"
        )

        XCTAssertTrue(
            app.navigationBars["Hydration Tracker"].waitForExistence(timeout: 10),
            "The Hydration Tracker screen should load after selecting Water tracker."
        )
    }

    /// Testuje proces nawigacji do ustawień profilu.
    @MainActor
    func testProfileSettingsNavigation() throws {
        // Profile and Settings are separate destinations in the current custom bar.
        tapCustomTab(
            in: app,
            identifier: RecipePlannerUITestIdentifiers.profileTab,
            name: "Profile"
        )
        XCTAssertTrue(
            app.navigationBars["My Profile"].waitForExistence(timeout: 10),
            "The profile screen should appear after selecting Profile."
        )

        tapCustomTab(
            in: app,
            identifier: RecipePlannerUITestIdentifiers.settingsTab,
            name: "Settings"
        )
        XCTAssertTrue(
            app.navigationBars["Settings"].waitForExistence(timeout: 10),
            "The settings screen should appear after selecting Settings."
        )
    }

    /// Verifies the unauthenticated form remains available in portrait and a short landscape viewport.
    @MainActor
    func testLoginLayoutAdaptsToCompactAndWideLayouts() throws {
        addTeardownBlock {
            XCUIDevice.shared.orientation = .portrait
        }

        let emailField = app.textFields[RecipePlannerUITestIdentifiers.emailField]
        let passwordField = app.secureTextFields[RecipePlannerUITestIdentifiers.passwordField]
        let loginButton = app.buttons[RecipePlannerUITestIdentifiers.loginButton]

        XCTAssertTrue(emailField.waitForExistence(timeout: 10), "The login form should load.")
        XCTAssertTrue(passwordField.exists, "The password field should remain in the login form.")
        XCTAssertTrue(loginButton.exists, "The login action should remain available.")
        XCTAssertFalse(app.keyboards.firstMatch.exists, "The keyboard should open only after the user focuses a field.")
        attachScreenshot(named: "Login portrait")

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(emailField.waitForExistence(timeout: 10), "The email field should survive rotation.")
        XCTAssertTrue(passwordField.exists, "The password field should survive rotation.")
        XCTAssertTrue(loginButton.exists, "The login action should survive rotation.")
        XCTAssertEqual(XCUIDevice.shared.orientation, .landscapeLeft)

        let loginScrollView = app.scrollViews.firstMatch
        XCTAssertTrue(loginScrollView.exists, "The login content should remain scrollable in the shorter viewport.")
        for _ in 0..<4 where !loginButton.isHittable {
            loginScrollView.swipeUp()
        }
        XCTAssertTrue(loginButton.isHittable, "The login action should be reachable by scrolling in landscape.")
        attachScreenshot(named: "Login landscape")

        for _ in 0..<4 where !emailField.isHittable {
            loginScrollView.swipeDown()
        }
        XCTAssertTrue(emailField.isHittable, "The email field should remain reachable after scrolling.")
        emailField.tap()

        let keyboardTipContinue = app.buttons["Continue"]
        if keyboardTipContinue.exists {
            keyboardTipContinue.tap()
        }
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "Focusing Email should show the keyboard.")
        attachScreenshot(named: "Login landscape with keyboard")

        for _ in 0..<4 where !loginButton.isHittable {
            loginScrollView.swipeUp()
        }
        XCTAssertTrue(loginButton.isHittable, "Scrolling with the keyboard open should make the login action reachable.")
    }

    /// Testuje wydajność uruchamiania aplikacji.
    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }

    @MainActor
    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
