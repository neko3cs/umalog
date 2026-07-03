//
//  ScenarioTests.swift
//  umalogUITests
//
//  Created by neko3cs on 2026/06/19.
//

import XCTest

// MARK: - Base

class UIテストケース: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["--UITesting"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // iOS 26 では List ボタンの要素タイプが button 以外になる場合があるため
    // descendants(matching: .any) で全タイプから識別子検索する
    func findElement(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// SwiftUI List 内の要素はレイアウト完了前にタップすると
    /// "Invalid frame dimension" 警告が出るため isHittable を待ってからタップする
    func tapWhenReady(_ element: XCUIElement, timeout: TimeInterval = 5) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout))
        let hittable = NSPredicate(format: "isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: hittable, object: element)
        _ = XCTWaiter.wait(for: [expectation], timeout: timeout)
        element.tap()
    }
}

// MARK: - Scenario 1: タブバーナビゲーション

final class タブバーナビゲーションTest: UIテストケース {
    @MainActor
    func testタブバーが表示され3つのタブが存在する() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        XCTAssertTrue(tabBar.buttons["レース"].exists)
        XCTAssertTrue(tabBar.buttons["収支"].exists)
        XCTAssertTrue(tabBar.buttons["設定"].exists)
    }

    @MainActor
    func testタブをタップして各画面に切り替えられる() {
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

final class レース追加Test: UIテストケース {
    @MainActor
    func testプラスボタンをタップするとレース追加フォームが表示される() {
        XCTAssertTrue(app.navigationBars["Umalog"].waitForExistence(timeout: 5))
        tapWhenReady(findElement("add-race-button"))
        XCTAssertTrue(app.navigationBars["レースを追加"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testキャンセルボタンをタップするとフォームが閉じる() {
        tapWhenReady(findElement("add-race-button"))
        XCTAssertTrue(app.navigationBars["レースを追加"].waitForExistence(timeout: 5))
        app.buttons["キャンセル"].tap()
        XCTAssertTrue(app.navigationBars["Umalog"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testレース名を入力して追加するとリストに表示される() {
        XCTAssertTrue(app.navigationBars["Umalog"].waitForExistence(timeout: 5))
        tapWhenReady(findElement("add-race-button"))
        XCTAssertTrue(app.navigationBars["レースを追加"].waitForExistence(timeout: 5))

        let raceNameField = app.textFields["レース名（任意）"]
        tapWhenReady(raceNameField)
        raceNameField.typeText("テストレース")

        app.buttons["追加"].tap()
        XCTAssertTrue(app.navigationBars["Umalog"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["テストレース"].waitForExistence(timeout: 5))
    }
}

// MARK: - Scenario 3: レース詳細・出走馬追加

final class レース詳細Test: UIテストケース {
    private func addRace(name: String = "シナリオレース") {
        tapWhenReady(findElement("add-race-button"))
        XCTAssertTrue(app.navigationBars["レースを追加"].waitForExistence(timeout: 5))
        let raceNameField = app.textFields["レース名（任意）"]
        tapWhenReady(raceNameField)
        raceNameField.typeText(name)
        app.buttons["追加"].tap()
        XCTAssertTrue(app.navigationBars["Umalog"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testレースセルをタップすると詳細画面に遷移する() {
        addRace()
        tapWhenReady(app.staticTexts["シナリオレース"])
        XCTAssertTrue(app.navigationBars["シナリオレース"].waitForExistence(timeout: 5))
    }

    @MainActor
    func test詳細画面に出走馬追加ボタンが表示される() {
        addRace()
        tapWhenReady(app.staticTexts["シナリオレース"])
        XCTAssertTrue(app.navigationBars["シナリオレース"].waitForExistence(timeout: 5))

        let addEntryButton = findElement("add-entry-button")
        XCTAssertTrue(addEntryButton.waitForExistence(timeout: 10))
    }

    @MainActor
    func test出走馬を追加すると詳細画面に表示される() {
        addRace()
        tapWhenReady(app.staticTexts["シナリオレース"])
        XCTAssertTrue(app.navigationBars["シナリオレース"].waitForExistence(timeout: 5))

        tapWhenReady(findElement("add-entry-button"))
        XCTAssertTrue(app.navigationBars["出走馬を追加"].waitForExistence(timeout: 5))

        let horseNameField = app.textFields["馬名"]
        tapWhenReady(horseNameField)
        horseNameField.typeText("テスト馬")

        app.buttons["追加"].tap()
        XCTAssertTrue(app.navigationBars["シナリオレース"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["テスト馬"].waitForExistence(timeout: 5))
    }

    @MainActor
    func test出走馬に予想印を付けると詳細画面に印が表示される() {
        addRace()
        tapWhenReady(app.staticTexts["シナリオレース"])
        XCTAssertTrue(app.navigationBars["シナリオレース"].waitForExistence(timeout: 5))

        tapWhenReady(findElement("add-entry-button"))
        XCTAssertTrue(app.navigationBars["出走馬を追加"].waitForExistence(timeout: 5))

        let horseNameField = app.textFields["馬名"]
        tapWhenReady(horseNameField)
        horseNameField.typeText("本命馬")
        // キーボードを閉じてからマークボタンをタップする（keyboard 表示中はボタンが隠れる）
        app.buttons["完了"].tap()

        // iOS 26 では button["◎"] が identifier 検索になるため accessibilityIdentifier を使用
        tapWhenReady(findElement("mark-button-◎"))
        app.buttons["追加"].tap()

        XCTAssertTrue(app.navigationBars["シナリオレース"].waitForExistence(timeout: 5))
        XCTAssertTrue(findElement("entry-mark-display").waitForExistence(timeout: 5))
    }

    @MainActor
    func test詳細画面に馬券追加ボタンが表示される() {
        addRace()
        tapWhenReady(app.staticTexts["シナリオレース"])
        XCTAssertTrue(app.navigationBars["シナリオレース"].waitForExistence(timeout: 5))

        // 馬券セクションはリスト下部にあるためスクロール
        app.swipeUp()
        let addBetButton = findElement("add-bet-button")
        XCTAssertTrue(addBetButton.waitForExistence(timeout: 10))
    }
}

// MARK: - Scenario 4: 馬券追加（出走馬なし・テキスト入力モード）

final class 馬券追加Test: UIテストケース {
    private func setupRaceAndNavigateToDetail(name: String = "馬券テストレース") {
        tapWhenReady(findElement("add-race-button"))
        XCTAssertTrue(app.navigationBars["レースを追加"].waitForExistence(timeout: 5))
        let raceNameField = app.textFields["レース名（任意）"]
        tapWhenReady(raceNameField)
        raceNameField.typeText(name)
        app.buttons["追加"].tap()
        XCTAssertTrue(app.navigationBars["Umalog"].waitForExistence(timeout: 5))
        tapWhenReady(app.staticTexts[name])
        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 5))
        // 馬券セクションはリスト下部にあるためスクロール
        app.swipeUp()
    }

    @MainActor
    func test馬券追加ボタンをタップすると馬券追加フォームが開く() {
        setupRaceAndNavigateToDetail()
        tapWhenReady(findElement("add-bet-button"))
        XCTAssertTrue(app.navigationBars["馬券を追加"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testキャンセルすると詳細画面に戻る() {
        setupRaceAndNavigateToDetail()
        tapWhenReady(findElement("add-bet-button"))
        XCTAssertTrue(app.navigationBars["馬券を追加"].waitForExistence(timeout: 5))
        app.buttons["キャンセル"].tap()
        XCTAssertTrue(app.navigationBars["馬券テストレース"].waitForExistence(timeout: 5))
    }

    @MainActor
    func test出走馬なしの場合にテキスト入力で買い目を追加できる() {
        setupRaceAndNavigateToDetail()
        tapWhenReady(findElement("add-bet-button"))
        XCTAssertTrue(app.navigationBars["馬券を追加"].waitForExistence(timeout: 5))

        app.buttons["買い目を追加"].tap()
        XCTAssertTrue(app.navigationBars["買い目を追加"].waitForExistence(timeout: 5))

        let selectionTextField = app.textFields["買い目（例: 1-2-3）"]
        XCTAssertTrue(selectionTextField.waitForExistence(timeout: 5))
        tapWhenReady(selectionTextField)
        selectionTextField.typeText("1-2")

        // 「買い目を追加」シート上の「追加」に限定（親 BetFormView の「追加」も tree に残るため）
        app.navigationBars["買い目を追加"].buttons["追加"].tap()
        XCTAssertTrue(app.navigationBars["馬券を追加"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1-2"].waitForExistence(timeout: 5))

        app.buttons["追加"].tap()
        XCTAssertTrue(app.navigationBars["馬券テストレース"].waitForExistence(timeout: 5))
    }
}

// MARK: - Scenario 5: レース削除

final class レース削除Test: UIテストケース {
    private func addRace(name: String) {
        tapWhenReady(findElement("add-race-button"))
        XCTAssertTrue(app.navigationBars["レースを追加"].waitForExistence(timeout: 5))
        let raceNameField = app.textFields["レース名（任意）"]
        tapWhenReady(raceNameField)
        raceNameField.typeText(name)
        app.buttons["追加"].tap()
        XCTAssertTrue(app.navigationBars["Umalog"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testレースをスワイプして削除できる() {
        addRace(name: "削除対象レース")

        let raceCell = app.staticTexts["削除対象レース"].firstMatch
        XCTAssertTrue(raceCell.waitForExistence(timeout: 5))
        let hittable = NSPredicate(format: "isHittable == true")
        _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: hittable, object: raceCell)], timeout: 5)

        raceCell.swipeLeft()
        // iOS 26 ではシステム生成の削除ボタンを identifier ではなくラベルで検索する
        let deleteButton = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == 'Delete' OR label == '削除'"))
            .firstMatch
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3))
        deleteButton.tap()

        XCTAssertFalse(app.staticTexts["削除対象レース"].waitForExistence(timeout: 3))
    }
}

// MARK: - Scenario 6: 収支サマリー

final class 収支サマリーTest: UIテストケース {
    @MainActor
    func test収支タブをタップすると収支画面が表示される() {
        app.tabBars.firstMatch.buttons["収支"].tap()
        XCTAssertTrue(app.navigationBars["収支"].waitForExistence(timeout: 5))
    }

    @MainActor
    func test集計単位を日月年期間で切り替えられる() {
        app.tabBars.firstMatch.buttons["収支"].tap()
        XCTAssertTrue(app.navigationBars["収支"].waitForExistence(timeout: 5))

        let dailyButton = app.buttons["日"]
        XCTAssertTrue(dailyButton.waitForExistence(timeout: 5))
        dailyButton.tap()

        app.buttons["年"].tap()
        app.buttons["期間"].tap()
        app.buttons["月"].tap()
    }

    @MainActor
    func test購入合計のラベルが表示される() {
        app.tabBars.firstMatch.buttons["収支"].tap()
        XCTAssertTrue(app.navigationBars["収支"].waitForExistence(timeout: 5))
        // iOS 26 では Text() が staticText 以外の型になる場合があるため descendants で検索
        let purchaseTotalElement = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == '購入合計'"))
            .firstMatch
        XCTAssertTrue(purchaseTotalElement.waitForExistence(timeout: 5))
    }

    @MainActor
    func test今日ボタンが収支画面に表示される() {
        app.tabBars.firstMatch.buttons["収支"].tap()
        XCTAssertTrue(app.navigationBars["収支"].waitForExistence(timeout: 5))
        XCTAssertTrue(findElement("today-button").waitForExistence(timeout: 5))
    }

    @MainActor
    func test日モードで前へボタンで移動後に今日ボタンで今日の日付に戻る() {
        app.tabBars.firstMatch.buttons["収支"].tap()
        XCTAssertTrue(app.navigationBars["収支"].waitForExistence(timeout: 5))

        let dailyButton = app.buttons["日"]
        XCTAssertTrue(dailyButton.waitForExistence(timeout: 5))
        dailyButton.tap()

        let titleElement = findElement("period-title")
        XCTAssertTrue(titleElement.waitForExistence(timeout: 5))
        let todayTitle = titleElement.label

        tapWhenReady(findElement("period-prev-button"))
        XCTAssertNotEqual(titleElement.label, todayTitle)

        tapWhenReady(findElement("today-button"))
        XCTAssertEqual(titleElement.label, todayTitle)
    }

    @MainActor
    func test期間モードで今日ボタンをタップすると開始日と終了日が今日にリセットされる() {
        app.tabBars.firstMatch.buttons["収支"].tap()
        XCTAssertTrue(app.navigationBars["収支"].waitForExistence(timeout: 5))

        let rangeButton = app.buttons["期間"]
        XCTAssertTrue(rangeButton.waitForExistence(timeout: 5))
        rangeButton.tap()

        let titleElement = findElement("period-title")
        XCTAssertTrue(titleElement.waitForExistence(timeout: 5))
        // "31日間" のように "1日間" を部分文字列として含む日数と誤判定しないよう括弧込みで比較する
        XCTAssertFalse(titleElement.label.contains("(1日間)"))

        tapWhenReady(findElement("today-button"))
        XCTAssertTrue(titleElement.label.contains("(1日間)"))
    }
}

// MARK: - Scenario 7: 設定画面

final class 設定Test: UIテストケース {
    @MainActor
    func test設定タブをタップすると設定画面が表示される() {
        app.tabBars.firstMatch.buttons["設定"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 5))
    }

    @MainActor
    func test設定画面にライセンスリンクが表示される() {
        app.tabBars.firstMatch.buttons["設定"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 5))
        let licensesButton = findElement("licenses-link")
        XCTAssertTrue(licensesButton.waitForExistence(timeout: 10))
    }

    @MainActor
    func testライセンスリンクをタップするとライセンス一覧に遷移する() {
        app.tabBars.firstMatch.buttons["設定"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 5))

        findElement("licenses-link").tap()
        XCTAssertTrue(app.navigationBars["ライセンス"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["swift-markdown-ui"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testライセンスをタップすると詳細画面に遷移する() {
        app.tabBars.firstMatch.buttons["設定"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 5))

        findElement("licenses-link").tap()
        XCTAssertTrue(app.navigationBars["ライセンス"].waitForExistence(timeout: 5))

        // パッケージセルをタップして詳細画面へ
        app.staticTexts["swift-markdown-ui"].tap()
        // ライセンス本文は単一の長い Text ブロックなので nav タイトルで到達を確認
        XCTAssertTrue(app.navigationBars["swift-markdown-ui"].waitForExistence(timeout: 5))
    }
}

// MARK: - Scenario 8: データ初期化

final class データ初期化Test: UIテストケース {
    private func navigateToSettings() {
        app.tabBars.firstMatch.buttons["設定"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testデータを初期化ボタンをタップすると確認ダイアログが表示される() {
        navigateToSettings()
        tapWhenReady(findElement("reset-all-data-button"))
        XCTAssertTrue(app.alerts["データを初期化"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testキャンセルをタップするとダイアログが閉じる() {
        navigateToSettings()
        tapWhenReady(findElement("reset-all-data-button"))
        XCTAssertTrue(app.alerts["データを初期化"].waitForExistence(timeout: 5))
        app.alerts["データを初期化"].buttons["キャンセル"].tap()
        XCTAssertFalse(app.alerts["データを初期化"].exists)
    }

    @MainActor
    func test初期化後にレース一覧が空になる() {
        // レースを追加する
        tapWhenReady(findElement("add-race-button"))
        XCTAssertTrue(app.navigationBars["レースを追加"].waitForExistence(timeout: 5))
        let raceNameField = app.textFields["レース名（任意）"]
        tapWhenReady(raceNameField)
        raceNameField.typeText("初期化対象レース")
        app.buttons["追加"].tap()
        XCTAssertTrue(app.staticTexts["初期化対象レース"].waitForExistence(timeout: 5))

        // 設定画面でデータを初期化する
        navigateToSettings()
        tapWhenReady(findElement("reset-all-data-button"))
        XCTAssertTrue(app.alerts["データを初期化"].waitForExistence(timeout: 5))
        app.alerts["データを初期化"].buttons["初期化"].tap()

        // 完了アラートが表示されることを確認する
        XCTAssertTrue(app.alerts["初期化完了"].waitForExistence(timeout: 5))
        app.alerts["初期化完了"].buttons["OK"].tap()

        // レース一覧が空になっていることを確認する
        app.tabBars.firstMatch.buttons["レース"].tap()
        XCTAssertTrue(app.navigationBars["Umalog"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["初期化対象レース"].waitForExistence(timeout: 3))
    }
}

// MARK: - Scenario 9: エンドツーエンド（レース記録フルフロー）

final class フルフローTest: UIテストケース {
    @MainActor
    func testレース追加から収支確認まで一連の操作が完結する() {
        // 1. レースを追加
        XCTAssertTrue(app.navigationBars["Umalog"].waitForExistence(timeout: 5))
        tapWhenReady(findElement("add-race-button"))
        XCTAssertTrue(app.navigationBars["レースを追加"].waitForExistence(timeout: 5))

        let raceNameField = app.textFields["レース名（任意）"]
        tapWhenReady(raceNameField)
        raceNameField.typeText("フルフローレース")
        app.buttons["追加"].tap()
        XCTAssertTrue(app.navigationBars["Umalog"].waitForExistence(timeout: 5))

        // 2. レース詳細へ移動
        tapWhenReady(app.staticTexts["フルフローレース"])
        XCTAssertTrue(app.navigationBars["フルフローレース"].waitForExistence(timeout: 5))

        // 3. 出走馬を追加
        tapWhenReady(findElement("add-entry-button"))
        XCTAssertTrue(app.navigationBars["出走馬を追加"].waitForExistence(timeout: 5))

        let horseNameField = app.textFields["馬名"]
        tapWhenReady(horseNameField)
        horseNameField.typeText("テスト馬1")
        app.buttons["追加"].tap()
        XCTAssertTrue(app.navigationBars["フルフローレース"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["テスト馬1"].waitForExistence(timeout: 5))

        // 4. 馬券フォームを開いてキャンセル
        //    （出走馬あり時は馬番 Picker での選択が必要になり UI テストが複雑なため
        //    フォームの開閉のみを確認し、テキスト入力での馬券追加は 馬券追加Test でカバー）
        app.swipeUp()
        tapWhenReady(findElement("add-bet-button"))
        XCTAssertTrue(app.navigationBars["馬券を追加"].waitForExistence(timeout: 5))
        app.buttons["キャンセル"].tap()
        XCTAssertTrue(app.navigationBars["フルフローレース"].waitForExistence(timeout: 5))

        // 5. 収支タブで確認
        app.tabBars.firstMatch.buttons["収支"].tap()
        XCTAssertTrue(app.navigationBars["収支"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["レース数"].waitForExistence(timeout: 5))
    }
}
