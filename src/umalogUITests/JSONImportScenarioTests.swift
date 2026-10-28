//
//  JSONImportScenarioTests.swift
//  umalogUITests
//
//  Created by neko3cs on 2026/10/28.
//

import XCTest

// MARK: - Scenario: テキストから取り込み

final class JSON取り込みTest: UIテストケース {
    /// 出走馬を 1 行ずつの JSON にする。
    private func entryJSON(_ number: Int, _ name: String, mark: String) -> String {
        "{\"horseNumber\":\(number),\"horseName\":\"\(name)\",\"jockeyName\":\"騎手\",\"trainerName\":\"\",\"mark\":\"\(mark)\"}"
    }

    /// 取り込み用の 1 行の JSON を作る。
    private func importJSON(entries: [String]) -> String {
        "{\"schemaVersion\":1,\"race\":{\"date\":\"2026-10-25\",\"venue\":\"東京\",\"raceNumber\":11,"
            + "\"raceName\":\"取込テスト\",\"distance\":2000,\"trackType\":\"turf\",\"trackCondition\":\"良\","
            + "\"grade\":\"G1\",\"firstPlaceHorseNumber\":0,\"secondPlaceHorseNumber\":0,\"thirdPlaceHorseNumber\":0},"
            + "\"entries\":[\(entries.joined(separator: ","))]}"
    }

    /// 設定画面から取り込み画面を開き、JSON を入力して確認する。
    private func enterAndCheck(_ json: String) {
        app.tabBars.firstMatch.buttons["設定"].tap()
        tapWhenReady(findElement("import-json-button"))
        XCTAssertTrue(app.navigationBars["テキストから取り込み"].waitForExistence(timeout: 5))
        let editor = app.textViews["import-json-editor"]
        tapWhenReady(editor)
        editor.typeText(json)
        tapWhenReady(findElement("import-check-button"))
    }

    /// 取り込み画面の行の読み上げラベルを返す。
    private func label(_ identifier: String) -> String {
        let element = findElement(identifier)
        XCTAssertTrue(element.waitForExistence(timeout: 5), "\(identifier) が表示されない")
        return element.label
    }

    /// レース一覧から取り込んだレースの詳細を開く。
    private func openImportedRace() {
        app.tabBars.firstMatch.buttons["レース"].tap()
        tapWhenReady(app.staticTexts["取込テスト"])
        XCTAssertTrue(app.navigationBars["取込テスト"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testJSONを貼り付けるとプレビューが出て保存するとレースと出走馬が登録される() {
        enterAndCheck(importJSON(entries: [entryJSON(1, "取込ウマA", mark: "◎"), entryJSON(2, "取込ウマB", mark: "")]))
        XCTAssertTrue(label("import-race-status").contains("新規作成"))
        XCTAssertTrue(label("import-entry-1").contains("新規作成"))

        tapWhenReady(findElement("import-save-button"))
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 5))

        openImportedRace()
        XCTAssertTrue(app.staticTexts["取込ウマA"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["取込ウマB"].exists)
        XCTAssertTrue(app.staticTexts["◎"].exists)
    }

    @MainActor
    func test同じレースのJSONを貼り直すと差分がプレビューされ保存すると更新される() {
        enterAndCheck(importJSON(entries: [entryJSON(1, "取込ウマA", mark: "◎"), entryJSON(2, "取込ウマB", mark: "")]))
        tapWhenReady(findElement("import-save-button"))
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 5))

        enterAndCheck(importJSON(entries: [entryJSON(1, "取込ウマA", mark: "○"), entryJSON(3, "取込ウマC", mark: "▲")]))
        XCTAssertTrue(label("import-race-status").contains("変更なし"))
        XCTAssertTrue(label("import-entry-1").contains("更新"))
        XCTAssertTrue(label("import-entry-1").contains("印: ◎ → ○"))
        XCTAssertTrue(label("import-entry-2").contains("削除"))
        XCTAssertTrue(label("import-entry-3").contains("新規作成"))

        tapWhenReady(findElement("import-save-button"))
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 5))

        openImportedRace()
        XCTAssertTrue(app.staticTexts["取込ウマC"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["取込ウマB"].exists)
        XCTAssertTrue(app.staticTexts["○"].exists)
        XCTAssertTrue(app.staticTexts["▲"].exists)
    }

    @MainActor
    func test不正な印のJSONは原因のフィールドを示すエラーになり何も保存されない() {
        enterAndCheck(importJSON(entries: [entryJSON(1, "取込ウマA", mark: "★")]))
        XCTAssertTrue(label("import-error-text").contains("entries[0].mark"))
        XCTAssertTrue(findElement("copy-import-error-button").exists)
        XCTAssertTrue(findElement("copy-import-prompt-button").exists)

        tapWhenReady(findElement("import-cancel-button"))
        app.tabBars.firstMatch.buttons["レース"].tap()
        XCTAssertTrue(app.navigationBars["Umalog"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["取込テスト"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testプレビューでキャンセルすると何も保存されない() {
        enterAndCheck(importJSON(entries: [entryJSON(1, "取込ウマA", mark: "◎")]))
        XCTAssertTrue(label("import-race-status").contains("新規作成"))

        tapWhenReady(findElement("import-cancel-button"))
        app.tabBars.firstMatch.buttons["レース"].tap()
        XCTAssertTrue(app.navigationBars["Umalog"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["取込テスト"].waitForExistence(timeout: 2))
    }
}
