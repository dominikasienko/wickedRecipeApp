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

    /// Testuje, czy główne zakładki dolnego menu (TabBar) są widoczne i klikalne.
    @MainActor
    func testNavigationTabBarItemsExist() throws {
        let tabBar = app.tabBars.firstMatch
        
        // Sprawdzenie czy ikony z AppTabView.swift są widoczne
        XCTAssertTrue(tabBar.buttons["Home"].exists, "The Home tab should be visible.")
        XCTAssertTrue(tabBar.buttons["Calendar"].exists, "The Calendar tab should be visible.")
        XCTAssertTrue(tabBar.buttons["Water tracker"].exists, "The Water tracker tab should be visible.")
        XCTAssertTrue(tabBar.buttons["Profile"].exists, "The Profile tab should be visible.")
    }

    /// Symuluje przejście do ekranu dodawania wody i sprawdza interakcję.
    @MainActor
    func testWaterTrackerNavigation() throws {
        let waterTab = app.tabBars.buttons["Water tracker"]
        XCTAssertTrue(waterTab.exists)
        waterTab.tap()
        
        let waterHeader = app.staticTexts["Daily Intake"]
        XCTAssertTrue(waterHeader.waitForExistence(timeout: 2), "The water screen should load.")
    }

    /// Testuje proces nawigacji do ustawień profilu.
    @MainActor
    func testProfileSettingsNavigation() throws {
        app.tabBars.buttons["Profile"].tap()
        
        let settingsButton = app.buttons["gear"] 
        if settingsButton.exists {
            settingsButton.tap()
            XCTAssertTrue(app.staticTexts["Settings"].exists, "The settings screen should appear.")
        }
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
