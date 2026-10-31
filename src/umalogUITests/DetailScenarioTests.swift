//
//  DetailScenarioTests.swift
//  umalogUITests
//
//  Created by neko3cs on 2026/10/31.
//

import XCTest

// MARK: - Base

/// レース詳細画面から始まるシナリオの共通操作。
class 詳細画面UIテストケース: UIテストケース {
    /// レースを登録し、そのレースの詳細画面を開く。
    /// - Parameter name: 登録するレース名。
    func addRaceAndOpenDetail(name: String) {
        openAddRaceForm()
        XCTAssertTrue(app.navigationBars["レースを追加"].waitForExistence(timeout: 5))
        let raceNameField = app.textFields["レース名（任意）"]
        tapWhenReady(raceNameField)
        raceNameField.typeText(name)
        app.buttons["追加"].tap()
        tapWhenReady(app.staticTexts[name])
        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 5))
    }

    /// 詳細画面から出走馬を 1 頭追加する。馬番は登録済みの最大馬番 + 1 で自動採番される。
    /// - Parameter horseName: 追加する馬名。
    func addEntry(horseName: String) {
        tapWhenReady(findElement("add-entry-button"))
        XCTAssertTrue(app.navigationBars["出走馬を追加"].waitForExistence(timeout: 5))
        let horseNameField = app.textFields["馬名"]
        tapWhenReady(horseNameField)
        horseNameField.typeText(horseName)
        app.navigationBars["出走馬を追加"].buttons["追加"].tap()
        XCTAssertTrue(app.staticTexts[horseName].waitForExistence(timeout: 10))
    }

    /// 詳細画面から馬券追加フォームを開き、さらに買い目入力シートを開く。
    func openSelectionForm() {
        app.swipeUp()
        tapWhenReady(findElement("add-bet-button"))
        XCTAssertTrue(app.navigationBars["馬券を追加"].waitForExistence(timeout: 5))
        app.buttons["買い目を追加"].tap()
        XCTAssertTrue(app.navigationBars["買い目を追加"].waitForExistence(timeout: 5))
    }

    /// 行を左にスワイプして削除ボタンを押す。
    /// - Parameter label: 削除する行に表示されている文字列。
    func swipeToDelete(rowLabeled label: String) {
        let texts = app.staticTexts.matching(identifier: label)
        XCTAssertTrue(texts.firstMatch.waitForExistence(timeout: 5))
        // 閉じたシートの同じ文字列が要素ツリーに残ることがあるため、画面上で触れる要素を選ぶ
        let row = texts.allElementsBoundByIndex.first(where: \.isHittable) ?? texts.firstMatch
        let deleteButton = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == 'Delete' OR label == '削除'"))
            .firstMatch
        // 文字列要素の中心から swipeLeft() すると移動距離が足りないため、行の右端からドラッグする。
        // 左端まで引くとフルスワイプで削除ボタンを出さずに消えるので、削除ボタンが出る程度で止める
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: 360, dy: row.frame.midY))
        let end = origin.withOffset(CGVector(dx: 220, dy: row.frame.midY))
        // 合成ジェスチャーは不発や即座に閉じることがあるため、出現を検知した時点ですぐタップする
        var revealed = false
        for _ in 0 ..< 3 {
            start.press(forDuration: 0.05, thenDragTo: end)
            if deleteButton.waitForExistence(timeout: 2) {
                revealed = true
                break
            }
        }
        XCTAssertTrue(revealed)
        deleteButton.tap()
    }

    /// 買い目入力シートの `LabeledContent` 行。ラベルと値が「ラベル, 値」の 1 要素として公開される。
    func sheetValue(_ label: String, _ value: String) -> XCUIElement {
        app.staticTexts["\(label), \(value)"]
    }
}

// MARK: - メモ

final class メモTest: 詳細画面UIテストケース {
    /// メモ編集シートの入力欄に文字を打つ。
    /// - Parameter text: 入力する文字列。
    private func typeIntoMemoEditor(_ text: String) {
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        // 入力欄の上端はナビゲーションバーと重なるため、少し下をタップする。
        // シートの表示アニメーション中にタップするとフォーカスが入らないため、キーボードが出るまでタップし直す
        for _ in 0 ..< 3 where !app.keyboards.firstMatch.exists {
            editor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()
            _ = app.keyboards.firstMatch.waitForExistence(timeout: 2)
        }
        editor.typeText(text)
    }

    @MainActor
    func testメモを書いて保存すると詳細画面とメモ画面に表示される() {
        addRaceAndOpenDetail(name: "メモレース")
        app.swipeUp()
        tapWhenReady(app.staticTexts["タップして追加"])
        XCTAssertTrue(app.navigationBars["メモ"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["メモなし"].waitForExistence(timeout: 5))

        app.navigationBars["メモ"].buttons["編集"].tap()
        XCTAssertTrue(app.navigationBars["メモを編集"].waitForExistence(timeout: 5))
        typeIntoMemoEditor("Paddock looks good")
        app.navigationBars["メモを編集"].buttons["保存"].tap()

        XCTAssertTrue(app.navigationBars["メモ"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Paddock looks good"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["メモなし"].exists)

        // 戻るボタンのラベルは前の画面のタイトルになるため、「編集」以外のボタンとして探す
        app.navigationBars["メモ"].buttons.matching(NSPredicate(format: "label != '編集'")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["メモレース"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Paddock looks good"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testメモの編集をキャンセルすると元のメモのまま変わらない() {
        addRaceAndOpenDetail(name: "メモ取消レース")
        app.swipeUp()
        tapWhenReady(app.staticTexts["タップして追加"])
        XCTAssertTrue(app.navigationBars["メモ"].waitForExistence(timeout: 5))

        app.navigationBars["メモ"].buttons["編集"].tap()
        XCTAssertTrue(app.navigationBars["メモを編集"].waitForExistence(timeout: 5))
        typeIntoMemoEditor("Discard me")
        app.navigationBars["メモを編集"].buttons["キャンセル"].tap()

        XCTAssertTrue(app.navigationBars["メモ"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["メモなし"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Discard me"].exists)
    }
}

// MARK: - 出走馬・馬券の削除

final class 出走馬馬券削除Test: 詳細画面UIテストケース {
    @MainActor
    func test出走馬をスワイプして削除すると頭数が減る() {
        addRaceAndOpenDetail(name: "出走馬削除レース")
        addEntry(horseName: "削除馬")
        XCTAssertTrue(app.staticTexts["出走馬 1頭"].waitForExistence(timeout: 5))

        swipeToDelete(rowLabeled: "削除馬")

        XCTAssertTrue(app.staticTexts["出走馬 0頭"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["削除馬"].exists)
    }

    @MainActor
    func test馬券をスワイプして削除すると枚数が減る() {
        addRaceAndOpenDetail(name: "馬券削除レース")
        openSelectionForm()
        let selectionTextField = app.textFields["買い目（例: 1-2-3）"]
        tapWhenReady(selectionTextField)
        selectionTextField.typeText("1-2")
        app.navigationBars["買い目を追加"].buttons["追加"].tap()
        XCTAssertTrue(app.navigationBars["馬券を追加"].waitForExistence(timeout: 5))
        app.navigationBars["馬券を追加"].buttons["追加"].tap()
        XCTAssertTrue(app.navigationBars["馬券削除レース"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["馬券 1枚"].waitForExistence(timeout: 5))

        swipeToDelete(rowLabeled: "1-2")

        XCTAssertTrue(app.staticTexts["馬券 0枚"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["1-2"].exists)
    }
}

// MARK: - 出走馬の入力候補

final class 出走馬入力候補Test: 詳細画面UIテストケース {
    @MainActor
    func test騎手名と調教師名はプリセットの候補をタップして入力できる() {
        addRaceAndOpenDetail(name: "候補レース")
        tapWhenReady(findElement("add-entry-button"))
        XCTAssertTrue(app.navigationBars["出走馬を追加"].waitForExistence(timeout: 5))
        let horseNameField = app.textFields["馬名"]
        tapWhenReady(horseNameField)
        horseNameField.typeText("候補馬")

        let jockeyField = app.textFields["騎手名"]
        tapWhenReady(jockeyField)
        jockeyField.typeText("ルメ")
        tapWhenReady(app.buttons["C.ルメール"])
        XCTAssertEqual(jockeyField.value as? String, "C.ルメール")

        let trainerField = app.textFields["調教師名（任意）"]
        tapWhenReady(trainerField)
        trainerField.typeText("国枝")
        tapWhenReady(app.buttons["国枝栄"])
        XCTAssertEqual(trainerField.value as? String, "国枝栄")

        app.navigationBars["出走馬を追加"].buttons["追加"].tap()
        XCTAssertTrue(app.navigationBars["候補レース"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["C.ルメール"].waitForExistence(timeout: 5))
    }

    @MainActor
    func test馬名は過去に入力した馬名の候補をタップして入力できる() {
        addRaceAndOpenDetail(name: "馬名候補レース")
        addEntry(horseName: "サクラテスト")

        tapWhenReady(findElement("add-entry-button"))
        XCTAssertTrue(app.navigationBars["出走馬を追加"].waitForExistence(timeout: 5))
        let horseNameField = app.textFields["馬名"]
        tapWhenReady(horseNameField)
        horseNameField.typeText("サクラ")
        tapWhenReady(app.buttons["サクラテスト"])
        XCTAssertEqual(horseNameField.value as? String, "サクラテスト")
    }
}

// MARK: - 馬番選択の買い方

final class 馬番選択買い方Test: 詳細画面UIテストケース {
    /// レースと出走馬を登録し、買い目入力シートで券種と買い方を選ぶ。
    /// - Parameters:
    ///   - ticketTypeName: 選ぶ券種名。
    ///   - betStyle: 選ぶ買い方。
    ///   - horseCount: 登録する出走馬の頭数。
    private func openSelectionForm(ticketTypeName: String, betStyle: String, horseCount: Int) {
        addRaceAndOpenDetail(name: "買い方テストレース")
        for idx in 1 ... horseCount {
            addEntry(horseName: "買い方馬\(idx)")
        }
        openSelectionForm()
        tapWhenReady(findElement("ticket-type-picker"))
        tapWhenReady(app.buttons[ticketTypeName])
        tapWhenReady(app.buttons[betStyle])
    }

    @MainActor
    func test馬連のボックスで馬を選ぶと点数と購入額が算出され保存できる() {
        openSelectionForm(ticketTypeName: "馬連", betStyle: "ボックス", horseCount: 3)

        tapWhenReady(app.buttons["1番 買い方馬1"])
        tapWhenReady(app.buttons["2番 買い方馬2"])
        tapWhenReady(app.buttons["3番 買い方馬3"])
        XCTAssertTrue(sheetValue("買い目", "1,2,3[BOX]").waitForExistence(timeout: 5))
        XCTAssertTrue(sheetValue("この買い目の購入額", "¥100 × 3点 = ¥300").waitForExistence(timeout: 5))

        // 選んだ馬をもう一度タップすると選択が外れる
        tapWhenReady(app.buttons["3番 買い方馬3"])
        XCTAssertTrue(sheetValue("買い目", "1,2[BOX]").waitForExistence(timeout: 5))

        app.navigationBars["買い目を追加"].buttons["追加"].tap()
        XCTAssertTrue(app.navigationBars["馬券を追加"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1,2[BOX]"].waitForExistence(timeout: 5))
    }

    @MainActor
    func test三連単のフォーメーションで軸ごとに馬を選ぶと点数が算出される() {
        openSelectionForm(ticketTypeName: "三連単", betStyle: "フォーメーション", horseCount: 3)

        tapWhenReady(findElement("formation-leg1-1"))
        tapWhenReady(findElement("formation-leg2-2"))
        tapWhenReady(findElement("formation-leg2-3"))
        tapWhenReady(findElement("formation-leg3-2"))
        tapWhenReady(findElement("formation-leg3-3"))
        XCTAssertTrue(sheetValue("買い目", "1/2,3/2,3").waitForExistence(timeout: 5))
        app.swipeUp()
        // 同じ馬が複数の着順に入る組合せは除くので 1-2-3 と 1-3-2 の 2 点
        XCTAssertTrue(sheetValue("この買い目の購入額", "¥100 × 2点 = ¥200").waitForExistence(timeout: 5))

        app.navigationBars["買い目を追加"].buttons["追加"].tap()
        XCTAssertTrue(app.navigationBars["馬券を追加"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1/2,3/2,3"].waitForExistence(timeout: 5))
    }
}

// MARK: - フィルターの日付範囲

final class フィルター日付範囲Test: UIテストケース {
    @MainActor
    func test開始日と終了日の指定をタップすると日付の入力欄が出て再度タップで消える() {
        tapWhenReady(findElement("filter-button"))
        XCTAssertTrue(app.navigationBars["フィルター"].waitForExistence(timeout: 5))

        let fromRow = app.buttons["開始日を指定"]
        for _ in 0 ..< 5 where !(fromRow.exists && fromRow.isHittable) {
            app.swipeUp()
        }
        fromRow.tap()
        // DatePicker 自体にはラベルが付かず、行の見出しが別の StaticText として公開される
        XCTAssertTrue(app.staticTexts["開始日"].waitForExistence(timeout: 5))

        let toRow = app.buttons["終了日を指定"]
        for _ in 0 ..< 5 where !(toRow.exists && toRow.isHittable) {
            app.swipeUp()
        }
        toRow.tap()
        XCTAssertTrue(app.staticTexts["終了日"].waitForExistence(timeout: 5))

        tapWhenReady(app.buttons["開始日を指定"])
        XCTAssertFalse(app.staticTexts["開始日"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["終了日"].exists)
    }
}

// MARK: - ZIP バックアップ・復元

final class ZIPバックアップ復元Test: UIテストケース {
    /// ドキュメントピッカーのキャンセルボタン。言語設定で表記が変わるため両方で探す。
    /// - Note: 保存先選択のピッカーではボタンではなく Other 要素として公開されるため、要素の種類を問わず探す。
    private var pickerCancelButton: XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == 'Cancel' OR label == 'キャンセル'"))
            .firstMatch
    }

    @MainActor
    func testZIPバックアップをタップすると保存先の選択画面が開きキャンセルで戻る() {
        app.tabBars.firstMatch.buttons["設定"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 5))

        tapWhenReady(app.buttons["ZIPバックアップ"])
        XCTAssertTrue(pickerCancelButton.waitForExistence(timeout: 15))
        pickerCancelButton.tap()

        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.alerts["バックアップエラー"].exists)
    }

    @MainActor
    func testZIPから復元をタップするとファイルの選択画面が開きキャンセルで戻る() {
        app.tabBars.firstMatch.buttons["設定"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 5))

        tapWhenReady(app.buttons["ZIPから復元"])
        XCTAssertTrue(pickerCancelButton.waitForExistence(timeout: 15))
        pickerCancelButton.tap()

        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.alerts["データを復元"].exists)
    }
}

/// システムのファイル選択画面を飛ばして起動し、ZIP の書き出しから復元までの流れを確かめる。
/// - Note: ファイル選択画面を実際に操作するテストは、並列実行用のシミュレーター複製ではファイルのタップが効かず安定しなかった（#43）。
///   ファイル選択画面そのものは `ZIPバックアップ復元Test` の開閉テストと、コーディネーターのユニットテストで確かめる。
final class ZIP往復Test: UIテストケース {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["--UITesting", "--UITestingSkipDocumentPicker"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }

    /// レース名を入力してレースを1件追加する。
    /// - Parameter name: 追加するレースの名前。
    private func addRace(name: String) {
        openAddRaceForm()
        let raceNameField = app.textFields["レース名（任意）"]
        tapWhenReady(raceNameField)
        raceNameField.typeText(name)
        app.buttons["追加"].tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
    }

    @MainActor
    func testZIPに書き出したバックアップから復元するとバックアップ時点のレースに戻る() {
        addRace(name: "バックアップ前レース")

        app.tabBars.firstMatch.buttons["設定"].tap()
        tapWhenReady(app.buttons["ZIPバックアップ"])
        let savedAlert = app.alerts["バックアップ完了"]
        XCTAssertTrue(savedAlert.waitForExistence(timeout: 10))
        savedAlert.buttons["OK"].tap()

        app.tabBars.firstMatch.buttons["レース"].tap()
        addRace(name: "バックアップ後レース")

        app.tabBars.firstMatch.buttons["設定"].tap()
        tapWhenReady(app.buttons["ZIPから復元"])
        let confirmAlert = app.alerts["データを復元"]
        XCTAssertTrue(confirmAlert.waitForExistence(timeout: 10))
        confirmAlert.buttons["復元"].tap()
        let restoredAlert = app.alerts["復元完了"]
        XCTAssertTrue(restoredAlert.waitForExistence(timeout: 10))
        restoredAlert.buttons["OK"].tap()

        app.tabBars.firstMatch.buttons["レース"].tap()
        XCTAssertTrue(app.staticTexts["バックアップ前レース"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["バックアップ後レース"].exists)
    }

    @MainActor
    func test復元の確認でキャンセルするとレースはそのまま残る() {
        addRace(name: "残るレース")

        app.tabBars.firstMatch.buttons["設定"].tap()
        tapWhenReady(app.buttons["ZIPバックアップ"])
        let savedAlert = app.alerts["バックアップ完了"]
        XCTAssertTrue(savedAlert.waitForExistence(timeout: 10))
        savedAlert.buttons["OK"].tap()

        app.tabBars.firstMatch.buttons["レース"].tap()
        addRace(name: "追加したレース")

        app.tabBars.firstMatch.buttons["設定"].tap()
        tapWhenReady(app.buttons["ZIPから復元"])
        let confirmAlert = app.alerts["データを復元"]
        XCTAssertTrue(confirmAlert.waitForExistence(timeout: 10))
        confirmAlert.buttons["キャンセル"].tap()

        app.tabBars.firstMatch.buttons["レース"].tap()
        XCTAssertTrue(app.staticTexts["残るレース"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["追加したレース"].exists)
    }
}
