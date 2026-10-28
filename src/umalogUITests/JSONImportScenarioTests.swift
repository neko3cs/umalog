//
//  JSONImportScenarioTests.swift
//  umalogUITests
//
//  Created by neko3cs on 2026/10/28.
//

import XCTest

// MARK: - Scenario: JSONで取り込み

final class JSON取り込みTest: UIテストケース {
    /// 出走馬を 1 行ずつの JSON にする。
    private func entryJSON(_ number: Int, _ name: String, mark: String) -> String {
        "{\"horseNumber\":\(number),\"horseName\":\"\(name)\",\"jockeyName\":\"騎手\",\"trainerName\":\"\",\"mark\":\"\(mark)\"}"
    }

    /// 取り込み用の 1 行の JSON を作る。
    private func importJSON(raceNumber: Int = 11, entries: [String]) -> String {
        "{\"schemaVersion\":1,\"race\":{\"date\":\"2026-10-25\",\"venue\":\"東京\",\"raceNumber\":\(raceNumber),"
            + "\"raceName\":\"取込テスト\",\"distance\":2000,\"trackType\":\"turf\",\"trackCondition\":\"良\","
            + "\"grade\":\"G1\",\"firstPlaceHorseNumber\":0,\"secondPlaceHorseNumber\":0,\"thirdPlaceHorseNumber\":0},"
            + "\"entries\":[\(entries.joined(separator: ","))]}"
    }

    /// レース一覧の + メニューから取り込み画面を開く。
    private func openImportFromList() {
        XCTAssertTrue(app.navigationBars["Umalog"].waitForExistence(timeout: 5))
        tapWhenReady(findElement("add-race-button"))
        tapWhenReady(findElement("import-race-button"))
        XCTAssertTrue(app.navigationBars["JSONで取り込み"].waitForExistence(timeout: 5))
    }

    /// 取り込んだレースの詳細を開き、編集メニューから「JSONで更新」を開く。
    private func openImportFromDetail() {
        openImportedRace()
        tapWhenReady(findElement("race-edit-menu"))
        tapWhenReady(findElement("import-update-button"))
        XCTAssertTrue(app.navigationBars["JSONで更新"].waitForExistence(timeout: 5))
    }

    /// 取り込み画面に JSON を入力して確認する。
    private func enterAndCheck(_ json: String) {
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
        tapWhenReady(app.staticTexts["取込テスト"])
        XCTAssertTrue(app.navigationBars["取込テスト"].waitForExistence(timeout: 5))
    }

    /// レース一覧から 2 頭のレースを取り込んで保存する。
    private func importInitialRace() {
        openImportFromList()
        enterAndCheck(importJSON(entries: [entryJSON(1, "取込ウマA", mark: "◎"), entryJSON(2, "取込ウマB", mark: "")]))
        tapWhenReady(findElement("import-save-button"))
        XCTAssertTrue(app.navigationBars["Umalog"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testレース一覧から取り込むとプレビューが出て保存するとレースと出走馬が登録される() {
        openImportFromList()
        enterAndCheck(importJSON(entries: [entryJSON(1, "取込ウマA", mark: "◎"), entryJSON(2, "取込ウマB", mark: "")]))
        XCTAssertTrue(label("import-race-status").contains("新規作成"))
        XCTAssertTrue(label("import-entry-1").contains("新規作成"))

        tapWhenReady(findElement("import-save-button"))
        XCTAssertTrue(app.navigationBars["Umalog"].waitForExistence(timeout: 5))

        openImportedRace()
        XCTAssertTrue(app.staticTexts["取込ウマA"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["取込ウマB"].exists)
        XCTAssertTrue(app.staticTexts["◎"].exists)
    }

    @MainActor
    func testレース詳細からJSONで更新すると差分がプレビューされ保存すると更新される() {
        importInitialRace()

        openImportFromDetail()
        enterAndCheck(importJSON(entries: [entryJSON(1, "取込ウマA", mark: "○"), entryJSON(3, "取込ウマC", mark: "▲")]))
        XCTAssertTrue(label("import-race-status").contains("変更なし"))
        XCTAssertTrue(label("import-entry-1").contains("更新"))
        XCTAssertTrue(label("import-entry-1").contains("印: ◎ → ○"))
        XCTAssertTrue(label("import-entry-2").contains("削除"))
        XCTAssertTrue(label("import-entry-3").contains("新規作成"))

        tapWhenReady(findElement("import-save-button"))
        XCTAssertTrue(app.navigationBars["取込テスト"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["取込ウマC"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["取込ウマB"].exists)
        XCTAssertTrue(app.staticTexts["○"].exists)
        XCTAssertTrue(app.staticTexts["▲"].exists)
    }

    @MainActor
    func testレース詳細からレース番号が違うJSONで更新しても開いているレースが更新される() {
        importInitialRace()

        openImportFromDetail()
        enterAndCheck(importJSON(raceNumber: 10, entries: [entryJSON(1, "取込ウマA", mark: "◎"), entryJSON(3, "取込ウマC", mark: "")]))
        XCTAssertTrue(label("import-race-status").contains("R11"))
        XCTAssertTrue(label("import-entry-3").contains("新規作成"))

        tapWhenReady(findElement("import-save-button"))
        XCTAssertTrue(app.navigationBars["取込テスト"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["取込ウマC"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["レース番号, R11"].exists)

        tapWhenReady(app.navigationBars["取込テスト"].buttons["Umalog"])
        XCTAssertTrue(app.navigationBars["Umalog"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "取込テスト")).count, 1)
    }

    @MainActor
    func testレース一覧から登録済みのレースを取り込むと既にあるというエラーになる() {
        importInitialRace()

        openImportFromList()
        enterAndCheck(importJSON(entries: [entryJSON(1, "取込ウマA", mark: "○")]))
        XCTAssertTrue(label("import-error-text").contains("既に登録されています"))
        XCTAssertFalse(findElement("import-save-button").exists)
    }

    @MainActor
    func test長いJSONを貼って確認してもエラーが画面内に表示される() {
        importInitialRace()

        // 改行を含む長い JSON は入力欄を縦に伸ばすため、エラーが入力欄の下にあると画面外に押し出されて見えなくなる
        openImportFromList()
        let entries = (1 ... 12).map { entryJSON($0, "Horse\($0)", mark: "") }
        enterAndCheck(importJSON(entries: entries).replacingOccurrences(of: ",", with: ",\n"))
        let error = findElement("import-error-text")
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertTrue(error.label.contains("既に登録されています"))
        XCTAssertTrue(error.isHittable, "エラーが画面外に表示されている")
    }

    @MainActor
    func test不正な印のJSONは原因のフィールドを示すエラーになり何も保存されない() {
        openImportFromList()
        enterAndCheck(importJSON(entries: [entryJSON(1, "取込ウマA", mark: "★")]))
        XCTAssertTrue(label("import-error-text").contains("entries[0].mark"))
        XCTAssertTrue(findElement("copy-import-error-button").exists)
        XCTAssertTrue(findElement("copy-import-prompt-button").exists)

        tapWhenReady(findElement("import-cancel-button"))
        XCTAssertTrue(app.navigationBars["Umalog"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["取込テスト"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testプレビューでキャンセルすると何も保存されない() {
        openImportFromList()
        enterAndCheck(importJSON(entries: [entryJSON(1, "取込ウマA", mark: "◎")]))
        XCTAssertTrue(label("import-race-status").contains("新規作成"))

        tapWhenReady(findElement("import-cancel-button"))
        XCTAssertTrue(app.navigationBars["Umalog"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["取込テスト"].waitForExistence(timeout: 2))
    }
}
