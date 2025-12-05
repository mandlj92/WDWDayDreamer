import XCTest

final class OnboardingUITests: XCTestCase {

    func testLoginScreenDisplaysAuthOptions() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["Continue with Apple"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Continue with Google"].exists)
        XCTAssertTrue(app.buttons["Forgot Password?"].exists)
    }
}
