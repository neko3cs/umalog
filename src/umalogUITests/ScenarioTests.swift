//
//  ScenarioTests.swift
//  umalogUITests
//
//  Created by neko3cs on 2026/06/19.
//

import XCTest

// MARK: - Base

class UITestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--UITesting"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }
}

// MARK: - Scenario 1: タブバーナビゲーション

final class TabBarNavigationTests: UITestCase {
    /// アプリ起動時にタブバーが表示され、3つのタブが存在する
    @MainActor
    func testTabBarExists() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        XCTAssertTrue(tabBar.buttons["レース"].exists)
        XCTAssertTrue(tabBar.buttons["収支"].exists)
        XCTAssertTrue(tabBar.buttons["設定"].exists)
    }

    /// 各タブに切り替えられる
    @MainActor
    func testTabSwitching() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        tabBar.buttons["収支"].tap()
        XCTAssertTrue(app.navigationBars["収支"].waitForExistence(timeout: 5))

        tabBar.buttons["設定"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 5))

        tabBar.buttons["レース"].tap()
        XCTAssertTrue(app.navigationBars["Umalog"].waitForExistence(timeout: 5))
    }
}

// MARK: - Scenario 2: レース追加

final class AddRaceTests: UITestCase {
    /// + ボタンをタップするとレース追加フォームが表示される
    @MainActor
    func testAddRaceFormAppears() {
        XCTAssertTrue(app.navigationBars["Umalog"].waitForExistence(timeout: 5))
        app.navigationBars["Umalog"].buttons["Add"].tap()
        XCTAssertTrue(app.navigationBars["レースを追加"].waitForExistence(timeout: 5))
    }

    /// キャンセルするとフォームが閉じる
    @MainActor
    func testAddRaceCancel() {
        app.navigationBars["Umalog"].buttons["Add"].tap()
        XCTAssertTrue(app.navigationBars["レースを追加"].waitForExistence(timeout: 5))
        app.buttons["キャンセル"].tap()
        XCTAssertTrue(app.navigationBars["Umalog"].waitForExistence(timeout: 5))
    }

    /// レースを追加するとリストに表示される
    @MainActor
    func testAddRaceSuccess() {
        XCTAssertTrue(app.navigationBars["Umalog"].waitForExistence(timeout: 5))
        app.navigationBars["Umalog"].buttons["Add"].tap()
        XCTAssertTrue(app.navigationBars["レースを追加"].waitForExistence(timeout: 5))

        let raceNameField = app.textFields["レース名（任意）"]
        raceNameField.tap()
        raceNameField.typeText("テストレース")

        app.buttons["追加"].tap()
        XCTAssertTrue(app.navigationBars["Umalog"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["テストレース"].waitForExistence(timeout: 5))
    }
}

// MARK: - Scenario 3: レース詳細・出走馬追加

final class RaceDetailTests: UITestCase {
    private func addRace(name: String = "シナリオレース") {
        app.navigationBars["Umalog"].buttons["Add"].tap()
        XCTAssertTrue(app.navigationBars["レースを追加"].waitForExistence(timeout: 5))
        let raceNameField = app.textFields["レース名（任意）"]
        raceNameField.tap()
        raceNameField.typeText(name)
        app.buttons["追加"].tap()
        XCTAssertTrue(app.navigationBars["Umalog"].waitForExistence(timeout: 5))
    }

    /// レースタップで詳細画面に遷移する
    @MainActor
    func testNavigateToRaceDetail() {
        addRace()
        app.staticTexts["シナリオレース"].tap()
        XCTAssertTrue(app.navigationBars["シナリオレース"].waitForExistence(timeout: 5))
    }

    /// 詳細画面に「出走馬を追加」ボタンがある
    @MainActor
    func testRaceDetailHasAddEntryButton() {
        addRace()
        app.staticTexts["シナリオレース"].tap()
        XCTAssertTrue(app.navigationBars["シナリオレース"].waitForExistence(timeout: 5))

        let addEntryButton = app.buttons["add-entry-button"]
        XCTAssertTrue(addEntryButton.waitForExistence(timeout: 5))
    }

    /// 出走馬を追加できる
    @MainActor
    func testAddHorseEntry() {
        addRace()
        app.staticTexts["シナリオレース"].tap()
        XCTAssertTrue(app.navigationBars["シナリオレース"].waitForExistence(timeout: 5))

        app.buttons["add-entry-button"].tap()
        XCTAssertTrue(app.navigationBars["出走馬を追加"].waitForExistence(timeout: 5))

        let horseNameField = app.textFields["馬名"]
        horseNameField.tap()
        horseNameField.typeText("テスト馬")

        app.buttons["追加"].tap()
        XCTAssertTrue(app.navigationBars["シナリオレース"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["テスト馬"].waitForExistence(timeout: 5))
    }

    /// 出走馬に予想印を付けられる
    @MainActor
    func testAddHorseEntryWithMark() {
        addRace()
        app.staticTexts["シナリオレース"].tap()
        XCTAssertTrue(app.navigationBars["シナリオレース"].waitForExistence(timeout: 5))

        app.buttons["add-entry-button"].tap()
        XCTAssertTrue(app.navigationBars["出走馬を追加"].waitForExistence(timeout: 5))

        let horseNameField = app.textFields["馬名"]
        horseNameField.tap()
        horseNameField.typeText("本命馬")

        app.buttons["◎"].tap()
        app.buttons["追加"].tap()

        XCTAssertTrue(app.navigationBars["シナリオレース"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["◎"].waitForExistence(timeout: 5))
    }

    /// 「馬券を追加」ボタンが詳細画面にある
    @MainActor
    func testRaceDetailHasAddBetButton() {
        addRace()
        app.staticTexts["シナリオレース"].tap()
        XCTAssertTrue(app.navigationBars["シナリオレース"].waitForExistence(timeout: 5))

        let addBetButton = app.buttons["add-bet-button"]
        XCTAssertTrue(addBetButton.waitForExistence(timeout: 5))
    }
}

// MARK: - Scenario 4: 馬券追加（出走馬なし・テキスト入力モード）

final class AddBetTests: UITestCase {
    private func setupRaceAndNavigateToDetail(name: String = "馬券テストレース") {
        app.navigationBars["Umalog"].buttons["Add"].tap()
        XCTAssertTrue(app.navigationBars["レースを追加"].waitForExistence(timeout: 5))
        let raceNameField = app.textFields["レース名（任意）"]
        raceNameField.tap()
        raceNameField.typeText(name)
        app.buttons["追加"].tap()
        XCTAssertTrue(app.navigationBars["Umalog"].waitForExistence(timeout: 5))
        app.staticTexts[name].tap()
        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 5))
    }

    /// 馬券追加フォームが開く
    @MainActor
    func testAddBetFormAppears() {
        setupRaceAndNavigateToDetail()
        app.buttons["add-bet-button"].tap()
        XCTAssertTrue(app.navigationBars["馬券を追加"].waitForExistence(timeout: 5))
    }

    /// 馬券追加をキャンセルできる
    @MainActor
    func testAddBetCancel() {
        setupRaceAndNavigateToDetail()
        app.buttons["add-bet-button"].tap()
        XCTAssertTrue(app.navigationBars["馬券を追加"].waitForExistence(timeout: 5))
        app.buttons["キャンセル"].tap()
        XCTAssertTrue(app.navigationBars["馬券テストレース"].waitForExistence(timeout: 5))
    }

    /// 出走馬なしの場合、テキスト入力で買い目を追加できる
    @MainActor
    func testAddBetWithTextInput() {
        setupRaceAndNavigateToDetail()
        app.buttons["add-bet-button"].tap()
        XCTAssertTrue(app.navigationBars["馬券を追加"].waitForExistence(timeout: 5))

        app.buttons["買い目を追加"].tap()
        XCTAssertTrue(app.navigationBars["買い目を追加"].waitForExistence(timeout: 5))

        let selectionTextField = app.textFields["買い目（例: 1-2-3）"]
        XCTAssertTrue(selectionTextField.waitForExistence(timeout: 5))
        selectionTextField.tap()
        selectionTextField.typeText("1-2")

        app.buttons["追加"].tap()
        XCTAssertTrue(app.navigationBars["馬券を追加"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1-2"].waitForExistence(timeout: 5))

        app.buttons["追加"].tap()
        XCTAssertTrue(app.navigationBars["馬券テストレース"].waitForExistence(timeout: 5))
    }
}

// MARK: - Scenario 5: レース削除

final class DeleteRaceTests: UITestCase {
    private func addRace(name: String) {
        app.navigationBars["Umalog"].buttons["Add"].tap()
        XCTAssertTrue(app.navigationBars["レースを追加"].waitForExistence(timeout: 5))
        let raceNameField = app.textFields["レース名（任意）"]
        raceNameField.tap()
        raceNameField.typeText(name)
        app.buttons["追加"].tap()
        XCTAssertTrue(app.navigationBars["Umalog"].waitForExistence(timeout: 5))
    }

    /// レースをスワイプ削除できる
    @MainActor
    func testDeleteRaceBySwipe() {
        addRace(name: "削除対象レース")

        let raceCell = app.staticTexts["削除対象レース"].firstMatch
        XCTAssertTrue(raceCell.waitForExistence(timeout: 5))

        raceCell.swipeLeft()
        app.buttons["Delete"].tap()

        XCTAssertFalse(app.staticTexts["削除対象レース"].waitForExistence(timeout: 3))
    }
}

// MARK: - Scenario 6: 収支サマリー

final class BalanceSummaryTests: UITestCase {
    /// 収支タブに切り替えると収支画面が表示される
    @MainActor
    func testBalanceSummaryTabNavigation() {
        app.tabBars.firstMatch.buttons["収支"].tap()
        XCTAssertTrue(app.navigationBars["収支"].waitForExistence(timeout: 5))
    }

    /// 集計単位（日・月・年・期間）を切り替えられる
    @MainActor
    func testBalanceSummaryPeriodSwitching() {
        app.tabBars.firstMatch.buttons["収支"].tap()
        XCTAssertTrue(app.navigationBars["収支"].waitForExistence(timeout: 5))

        let dailyButton = app.buttons["日"]
        XCTAssertTrue(dailyButton.waitForExistence(timeout: 5))
        dailyButton.tap()

        app.buttons["年"].tap()
        app.buttons["期間"].tap()
        app.buttons["月"].tap()
    }

    /// 集計セクションが表示されている
    @MainActor
    func testBalanceSummaryShowsSummarySection() {
        app.tabBars.firstMatch.buttons["収支"].tap()
        XCTAssertTrue(app.navigationBars["収支"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["購入合計"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["払戻合計"].exists)
        XCTAssertTrue(app.staticTexts["収支"].exists)
        XCTAssertTrue(app.staticTexts["レース数"].exists)
    }
}

// MARK: - Scenario 7: 設定画面

final class SettingsTests: UITestCase {
    /// 設定タブに切り替えると設定画面が表示される
    @MainActor
    func testSettingsTabNavigation() {
        app.tabBars.firstMatch.buttons["設定"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 5))
    }

    /// 設定画面にバージョン情報セクションが存在する
    @MainActor
    func testSettingsShowsAppInfo() {
        app.tabBars.firstMatch.buttons["設定"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 5))
        // LabeledContent の「バージョン」ラベルは iOS26 では Other 型として表れるため、
        // ナビゲーションタイトルで設定画面を確認済みとして次のセクション要素を確認する
        let licensesButton = app.buttons["licenses-link"]
        XCTAssertTrue(licensesButton.waitForExistence(timeout: 5))
    }

    /// ライセンス画面に遷移できる
    @MainActor
    func testSettingsNavigateToLicenses() {
        app.tabBars.firstMatch.buttons["設定"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 5))

        app.buttons["licenses-link"].tap()
        XCTAssertTrue(app.navigationBars["ライセンス"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["swift-markdown-ui"].waitForExistence(timeout: 5))
    }

    /// ライセンス詳細に遷移できる
    @MainActor
    func testSettingsNavigateToLicenseDetail() {
        app.tabBars.firstMatch.buttons["設定"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 5))

        app.buttons["licenses-link"].tap()
        XCTAssertTrue(app.navigationBars["ライセンス"].waitForExistence(timeout: 5))

        // パッケージセルをタップ（automation type mismatch 回避のため staticTexts でタップ）
        app.staticTexts["swift-markdown-ui"].tap()
        XCTAssertTrue(app.staticTexts["MIT"].waitForExistence(timeout: 5))
    }
}

// MARK: - Scenario 8: エンドツーエンド（レース記録フルフロー）

final class FullRaceRecordFlowTests: UITestCase {
    /// レース追加→出走馬追加→馬券追加→収支確認のフルフロー
    @MainActor
    func testFullRaceRecordFlow() {
        // 1. レースを追加
        XCTAssertTrue(app.navigationBars["Umalog"].waitForExistence(timeout: 5))
        app.navigationBars["Umalog"].buttons["Add"].tap()
        XCTAssertTrue(app.navigationBars["レースを追加"].waitForExistence(timeout: 5))

        let raceNameField = app.textFields["レース名（任意）"]
        raceNameField.tap()
        raceNameField.typeText("フルフローレース")
        app.buttons["追加"].tap()
        XCTAssertTrue(app.navigationBars["Umalog"].waitForExistence(timeout: 5))

        // 2. レース詳細へ移動
        app.staticTexts["フルフローレース"].tap()
        XCTAssertTrue(app.navigationBars["フルフローレース"].waitForExistence(timeout: 5))

        // 3. 出走馬を追加
        app.buttons["add-entry-button"].tap()
        XCTAssertTrue(app.navigationBars["出走馬を追加"].waitForExistence(timeout: 5))

        app.textFields["馬名"].tap()
        app.textFields["馬名"].typeText("テスト馬1")
        app.buttons["追加"].tap()
        XCTAssertTrue(app.navigationBars["フルフローレース"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["テスト馬1"].waitForExistence(timeout: 5))

        // 4. 馬券を追加（出走馬あり・テキスト入力にフォールバック）
        app.buttons["add-bet-button"].tap()
        XCTAssertTrue(app.navigationBars["馬券を追加"].waitForExistence(timeout: 5))

        app.buttons["買い目を追加"].tap()
        XCTAssertTrue(app.navigationBars["買い目を追加"].waitForExistence(timeout: 5))

        // 単勝を選択してから馬番ピッカーでテスト馬1を選択
        let ticketPicker = app.pickerWheels.firstMatch
        if ticketPicker.waitForExistence(timeout: 3) {
            ticketPicker.adjust(toPickerWheelValue: "単勝")
        }

        app.buttons["追加"].tap()
        XCTAssertTrue(app.navigationBars["馬券を追加"].waitForExistence(timeout: 5))
        app.buttons["追加"].tap()
        XCTAssertTrue(app.navigationBars["フルフローレース"].waitForExistence(timeout: 5))

        // 5. 収支タブで確認
        app.tabBars.firstMatch.buttons["収支"].tap()
        XCTAssertTrue(app.navigationBars["収支"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["レース数"].waitForExistence(timeout: 5))
    }
}
