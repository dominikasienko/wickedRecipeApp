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

    /// Testuje wydajność uruchamiania aplikacji.
    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
