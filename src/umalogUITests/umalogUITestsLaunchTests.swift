//
//  umalogUITestsLaunchTests.swift
//  umalogUITests
//
//  Created by neko3cs on 2026/06/11.
//

import XCTest

final class umalogUITestsLaunchTests: XCTestCase {
    override static var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--UITesting"]
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
