import XCTest

enum RecipePlannerUITestIdentifiers {
    static let homeTab = "tab.home"
    static let favoritesTab = "tab.favorites"
    static let calendarTab = "tab.calendar"
    static let seasonalTab = "tab.seasonal"
    static let waterTrackerTab = "tab.waterTracker"
    static let profileTab = "tab.profile"
    static let settingsTab = "tab.settings"
    static let navigationBar = "navigation.bar"
    static let emailField = "auth.email"
    static let passwordField = "auth.password"
    static let loginButton = "auth.login"
    static let minimumAgeConsent = "consent.minimumAge"
    static let healthDataConsent = "consent.healthData"
    static let consentContinue = "consent.continue"
}

extension XCTestCase {
    @MainActor
    @discardableResult
    func waitForCustomTab(
        in app: XCUIApplication,
        identifier: String,
        name: String,
        timeout: TimeInterval = 15
    ) -> XCUIElement {
        let tab = app.buttons[identifier]
        if !tab.waitForExistence(timeout: 5) {
            prepareAuthenticatedStateIfNeeded(in: app)
        }

        XCTAssertTrue(tab.waitForExistence(timeout: timeout), "The \(name) navigation control should be visible.")
        return tab
    }

    @MainActor
    private func prepareAuthenticatedStateIfNeeded(in app: XCUIApplication) {
        if completeConsentIfNeeded(in: app) {
            return
        }

        let environment = ProcessInfo.processInfo.environment
        guard let email = environment["WICKED_RECIPE_UI_TEST_EMAIL"], !email.isEmpty,
              let password = environment["WICKED_RECIPE_UI_TEST_PASSWORD"], !password.isEmpty else {
            XCTFail(
                "UI navigation tests require an authenticated, consented Firebase test account. "
                + "Set WICKED_RECIPE_UI_TEST_EMAIL and WICKED_RECIPE_UI_TEST_PASSWORD; production authentication is not bypassed."
            )
            return
        }

        let emailField = app.textFields[RecipePlannerUITestIdentifiers.emailField]
        let passwordField = app.secureTextFields[RecipePlannerUITestIdentifiers.passwordField]
        let loginButton = app.buttons[RecipePlannerUITestIdentifiers.loginButton]

        guard emailField.waitForExistence(timeout: 10),
              passwordField.waitForExistence(timeout: 10),
              loginButton.waitForExistence(timeout: 10) else {
            XCTFail("The login screen did not become ready for the configured UI test account.")
            return
        }

        emailField.tap()
        emailField.typeText(email)
        passwordField.tap()
        passwordField.typeText(password)
        loginButton.tap()

        _ = completeConsentIfNeeded(in: app)
    }

    @MainActor
    @discardableResult
    private func completeConsentIfNeeded(in app: XCUIApplication) -> Bool {
        let continueButton = app.buttons[RecipePlannerUITestIdentifiers.consentContinue]
        guard continueButton.waitForExistence(timeout: 5) else { return false }

        let minimumAgeToggle = app.switches[RecipePlannerUITestIdentifiers.minimumAgeConsent]
        let healthDataToggle = app.switches[RecipePlannerUITestIdentifiers.healthDataConsent]

        if minimumAgeToggle.waitForExistence(timeout: 5),
           (minimumAgeToggle.value as? String) != "1" {
            minimumAgeToggle.tap()
        }
        if healthDataToggle.waitForExistence(timeout: 5),
           (healthDataToggle.value as? String) != "1" {
            healthDataToggle.tap()
        }

        XCTAssertTrue(continueButton.isEnabled, "The configured UI test profile must be age-eligible before consent can continue.")
        continueButton.tap()
        return true
    }

    @MainActor
    @discardableResult
    func tapCustomTab(
        in app: XCUIApplication,
        identifier: String,
        name: String,
        timeout: TimeInterval = 15
    ) -> XCUIElement {
        let tab = waitForCustomTab(in: app, identifier: identifier, name: name, timeout: timeout)

        if !tab.isHittable {
            let navigationScrollView = app.descendants(matching: .any)
                .matching(identifier: RecipePlannerUITestIdentifiers.navigationBar)
                .firstMatch

            XCTAssertTrue(
                navigationScrollView.waitForExistence(timeout: 5),
                "The custom navigation bar should be available before tapping \(name)."
            )

            for _ in 0..<6 where !tab.isHittable {
                navigationScrollView.swipeLeft()
            }
        }

        XCTAssertTrue(tab.isHittable, "The \(name) navigation control should be tappable.")
        tab.tap()
        return tab
    }
}
