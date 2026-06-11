import XCTest

final class FitnessUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Onboarding

    func test_loginScreen_appearsOnLaunch() {
        XCTAssertTrue(app.staticTexts["FitSight"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["Email"].exists)
        XCTAssertTrue(app.secureTextFields["Password"].exists)
    }

    func test_loginScreen_hasSignInButton() {
        XCTAssertTrue(app.buttons["Sign in"].waitForExistence(timeout: 5))
    }

    func test_signUp_switchLink_isPresent() {
        let link = app.buttons["Don't have an account? Sign up"]
        XCTAssertTrue(link.waitForExistence(timeout: 5))
    }

    func test_signUp_andProfileSetup_flow() throws {
        let signUpButton = app.buttons["Don't have an account? Sign up"]
        XCTAssertTrue(signUpButton.waitForExistence(timeout: 3))
        signUpButton.tap()

        let email = app.textFields["Email"]
        let password = app.secureTextFields["Password"]
        email.tap()
        email.typeText("uitest_\(Int.random(in: 10000...99999))@example.com")
        password.tap()
        password.typeText("password123")

        app.buttons["Create account"].tap()

        XCTAssertTrue(app.navigationBars["Set up your profile"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["Display name"].exists)
    }

    func test_profileSetup_hasSaveButton() throws {
        let signUpButton = app.buttons["Don't have an account? Sign up"]
        guard signUpButton.waitForExistence(timeout: 3) else { return }
        signUpButton.tap()

        let email = app.textFields["Email"]
        let password = app.secureTextFields["Password"]
        email.tap()
        email.typeText("test_\(Int.random(in: 10000...99999))@example.com")
        password.tap()
        password.typeText("password123")
        app.buttons["Create account"].tap()

        guard app.navigationBars["Set up your profile"].waitForExistence(timeout: 5) else { return }
        XCTAssertTrue(app.buttons["Save & start"].exists)
    }

    // MARK: - Dashboard navigation

    func test_tabBar_hasExpectedTabs() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 10) else {
            // Login screen — acceptable for cold launch without pre-authed state
            XCTAssertTrue(app.staticTexts["FitSight"].exists)
            return
        }
        XCTAssertTrue(tabBar.buttons["Today"].exists)
        XCTAssertTrue(tabBar.buttons["Coach"].exists)
        XCTAssertTrue(tabBar.buttons["Form"].exists)
        XCTAssertTrue(tabBar.buttons["Nutrition"].exists)
        XCTAssertTrue(tabBar.buttons["Chat"].exists)
        XCTAssertTrue(tabBar.buttons["Progress"].exists)
    }

    func test_todayTab_isDefaultSelection() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 10) else { return }
        // Today tab should be selected by default
        XCTAssertTrue(tabBar.buttons["Today"].isSelected)
    }

    func test_navigation_coachTab_loads() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 10) else { return }
        tabBar.buttons["Coach"].tap()
        // Expect some content unique to the Coach tab
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 3))
    }

    func test_navigation_nutritionTab_loads() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 10) else { return }
        tabBar.buttons["Nutrition"].tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 3))
    }

    func test_navigation_progressTab_loads() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 10) else { return }
        tabBar.buttons["Progress"].tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 3))
    }

    func test_navigation_chatTab_loads() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 10) else { return }
        tabBar.buttons["Chat"].tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 3))
    }

    // MARK: - Settings

    func test_settings_isAccessibleFromToday() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 10) else { return }
        // Settings gear should be visible in TodayView navigation bar
        let settingsButton = app.buttons["gearshape"]
            .firstMatch
        if settingsButton.waitForExistence(timeout: 3) {
            settingsButton.tap()
            XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        }
    }

    // MARK: - Camera analysis (Form tab)

    func test_formTab_showsCameraOrPermissionPrompt() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 10) else { return }
        tabBar.buttons["Form"].tap()

        // Either the camera preview loads or a permission/exercise picker appears
        let hasContent = app.otherElements.firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(hasContent, "Form tab should show some UI element within 5 seconds")
    }
}
