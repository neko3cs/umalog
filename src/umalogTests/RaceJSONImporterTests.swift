//
//  RaceJSONImporterTests.swift
//  umalogTests
//
//  Created by neko3cs on 2026/10/28.
//

import Foundation
import SwiftData
import Testing
@testable import umalog

@MainActor
struct JSON取り込みTest {
    let container: ModelContainer

    init() throws {
        let schema = Schema([Race.self, Bet.self, BetSelection.self, RaceEntry.self, Venue.self, TicketType.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        Venue.insertMissingPresets(into: container.mainContext)
    }

    /// テスト用のレース部分を返す。
    /// - Returns: スキーマに沿ったレースの辞書。
    nonisolated static func raceObject() -> [String: Any] {
        [
            "date": "2026-10-25", "venue": "東京", "raceNumber": 11, "raceName": "天皇賞（秋）",
            "distance": 2000, "trackType": "turf", "trackCondition": "良", "grade": "G1",
            "firstPlaceHorseNumber": 0, "secondPlaceHorseNumber": 0, "thirdPlaceHorseNumber": 0,
        ]
    }

    /// テスト用の出走馬 1 頭分を返す。
    /// - Parameters:
    ///   - number: 馬番。
    ///   - name: 馬名。
    ///   - mark: 予想印。
    /// - Returns: スキーマに沿った出走馬の辞書。
    nonisolated static func entryObject(_ number: Int, _ name: String, mark: String = "") -> [String: Any] {
        ["horseNumber": number, "horseName": name, "jockeyName": "騎手\(number)", "trainerName": "調教師\(number)", "mark": mark]
    }

    /// テスト用の JSON 文字列を作る。
    /// - Parameters:
    ///   - race: レース部分を書き換えるクロージャ。
    ///   - entries: 出走馬。
    ///   - schemaVersion: スキーマのバージョン。
    /// - Returns: JSON 文字列。
    nonisolated static func json(
        race modify: (inout [String: Any]) -> Void = { _ in },
        entries: [[String: Any]] = [entryObject(1, "ウマA", mark: "◎"), entryObject(2, "ウマB", mark: "○")],
        schemaVersion: Int = 1,
    ) -> String {
        var race = raceObject()
        modify(&race)
        let root: [String: Any] = ["schemaVersion": schemaVersion, "race": race, "entries": entries]
        let data = (try? JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])) ?? Data()
        return String(bytes: data, encoding: .utf8) ?? ""
    }

    /// 取り込みエラーの原因のパスを返す。
    /// - Parameter text: 取り込むテキスト。
    /// - Returns: 原因のパスの一覧。エラーにならなければ空。
    private func issuePaths(_ text: String) -> [String] {
        do {
            _ = try RaceJSONImporter.parse(text)
            return []
        } catch let error as RaceImportError {
            return error.issues.map(\.path)
        } catch {
            return ["unexpected"]
        }
    }

    /// テキストを解析して既存データと照合する。
    /// - Parameter text: 取り込むテキスト。
    /// - Returns: 取り込み計画。
    private func plan(_ text: String) throws -> RaceImportPlan {
        try RaceJSONImporter.makePlan(for: RaceJSONImporter.parse(text), in: container.mainContext)
    }

    /// 全レースを取得する。
    /// - Returns: 保存されている全レース。
    private func races() throws -> [Race] {
        try container.mainContext.fetch(FetchDescriptor<Race>())
    }

    // MARK: - 解析

    @Test func `スキーマに沿ったjsonを解析できる`() throws {
        let data = try RaceJSONImporter.parse(Self.json())
        #expect(data.venueName == "東京")
        #expect(data.raceNumber == 11)
        #expect(data.grade == .g1)
        #expect(data.entries.map(\.mark) == [.honmei, .taikou])
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: data.date)
        #expect(components.year == 2026 && components.month == 10 && components.day == 25 && components.hour == 0)
    }

    @Test func コードフェンスと前後の説明文が付いていても解析できる() throws {
        let text = "予想はこちらです。\n```json\n\(Self.json())\n```\n以上です。"
        #expect(try RaceJSONImporter.parse(text).raceName == "天皇賞（秋）")
    }

    @Test func 入力で全角の引用符に変わっていても解析できる() throws {
        let text = Self.json().replacingOccurrences(of: "\"schemaVersion\"", with: "\u{201C}schemaVersion\u{201D}")
        #expect(try RaceJSONImporter.parse(text).raceNumber == 11)
    }

    @Test func 印が空文字の出走馬は印なしになる() throws {
        let data = try RaceJSONImporter.parse(Self.json(entries: [Self.entryObject(1, "ウマA")]))
        #expect(data.entries.first?.mark == nil)
    }

    @Test func グレードが空文字なら未選択になる() throws {
        let data = try RaceJSONImporter.parse(Self.json(race: { $0["grade"] = "" }))
        #expect(data.grade == .unspecified)
    }

    // MARK: - 解析エラー

    @Test func `jsonが含まれないテキストはエラーになる`() {
        #expect(issuePaths("予想できませんでした") == ["(JSON)"])
    }

    @Test func `jsonの構文エラーはエラーになる`() {
        #expect(issuePaths("{ \"schemaVersion\": 1, ") == ["(JSON)"])
        #expect(issuePaths("{ \"schemaVersion\": 1, \"race\": }") == ["(JSON)"])
    }

    @Test func フィールドを省略するとそのフィールドがエラーになる() {
        var entry = Self.entryObject(2, "ウマB")
        entry.removeValue(forKey: "mark")
        #expect(issuePaths(Self.json(entries: [Self.entryObject(1, "ウマA"), entry])) == ["entries[1].mark"])
    }

    @Test func nullを指定するとそのフィールドがエラーになる() {
        #expect(issuePaths(Self.json(race: { $0["raceName"] = NSNull() })) == ["race.raceName"])
    }

    @Test func 型が違うとそのフィールドがエラーになる() {
        #expect(issuePaths(Self.json(race: { $0["raceNumber"] = "11" })) == ["race.raceNumber"])
    }

    @Test func `8 種類以外の印はエラーになる`() throws {
        let error = try #require(throws: RaceImportError.self) {
            try RaceJSONImporter.parse(Self.json(entries: [Self.entryObject(1, "ウマA", mark: "★")]))
        }
        #expect(error.issues.map(\.path) == ["entries[0].mark"])
        #expect(error.issues.first?.message.contains("◎ ○ ▲ △ ☆ 注 押 消") == true)
    }

    @Test func 存在しない競馬場はエラーになる() {
        #expect(issuePaths(Self.json(race: { $0["venue"] = "東京競馬場" })) == ["race.venue"])
    }

    @Test(arguments: ["2026-13-01", "2026-1-5", "2026/10/25", ""])
    func 日付の形式が違うとエラーになる(date: String) {
        #expect(issuePaths(Self.json(race: { $0["date"] = date })) == ["race.date"])
    }

    @Test func 対応していないスキーマのバージョンはエラーになる() {
        #expect(issuePaths(Self.json(schemaVersion: 2)) == ["schemaVersion"])
    }

    @Test func 範囲外のレース番号と距離はエラーになる() {
        #expect(issuePaths(Self.json(race: { $0["raceNumber"] = 13; $0["distance"] = 0 })) == ["race.raceNumber", "race.distance"])
    }

    @Test func 使えないトラック種別と馬場状態とグレードはエラーになる() {
        let paths = issuePaths(Self.json(race: { $0["trackType"] = "芝"; $0["trackCondition"] = "稍"; $0["grade"] = "GI" }))
        #expect(paths == ["race.trackType", "race.trackCondition", "race.grade"])
    }

    @Test func 馬番の重複と空の馬名はエラーになる() {
        let paths = issuePaths(Self.json(entries: [Self.entryObject(1, "ウマA"), Self.entryObject(1, "")]))
        #expect(paths == ["entries[1].horseNumber", "entries[1].horseName"])
    }

    @Test func 出走馬にない馬番や重複した着順はエラーになる() {
        let paths = issuePaths(Self.json(race: {
            $0["firstPlaceHorseNumber"] = 1; $0["secondPlaceHorseNumber"] = 1; $0["thirdPlaceHorseNumber"] = 9
        }))
        #expect(paths == ["race.secondPlaceHorseNumber", "race.thirdPlaceHorseNumber"])
    }

    @Test func `aiに渡すエラー文に原因のフィールドがすべて含まれる`() throws {
        let error = try #require(throws: RaceImportError.self) {
            try RaceJSONImporter.parse(Self.json(race: { $0["venue"] = "どこか" }, entries: [Self.entryObject(1, "ウマA", mark: "X")]))
        }
        #expect(error.reportForAI.contains("- race.venue:"))
        #expect(error.reportForAI.contains("- entries[0].mark:"))
        #expect(error.reportForAI.contains("JSON だけを出力し直してください"))
    }

    // MARK: - 照合・差分

    @Test func 同じレースが無ければレースと出走馬が新規作成になる() throws {
        let plan = try plan(Self.json())
        #expect(plan.raceKind == .create)
        #expect(plan.entries.map(\.kind) == [.create, .create])
        #expect(plan.hasChanges)
    }

    @Test func 差分を計算しただけでは何も保存されない() throws {
        _ = try plan(Self.json())
        #expect(try races().isEmpty)
        #expect(try container.mainContext.fetch(FetchDescriptor<RaceEntry>()).isEmpty)
    }

    @Test func 同じ内容を取り込み直すと変更なしになる() throws {
        try RaceJSONImporter.apply(plan(Self.json()), in: container.mainContext)
        let plan = try plan(Self.json())
        #expect(plan.raceKind == .unchanged)
        #expect(plan.entries.map(\.kind) == [.unchanged, .unchanged])
        #expect(plan.hasChanges == false)
    }

    @Test func 変わったフィールドだけが更新として出る() throws {
        try RaceJSONImporter.apply(plan(Self.json()), in: container.mainContext)
        let plan = try plan(Self.json(
            race: { $0["trackCondition"] = "重"; $0["firstPlaceHorseNumber"] = 2 },
            entries: [Self.entryObject(1, "ウマA", mark: "○"), Self.entryObject(2, "ウマB", mark: "○")],
        ))
        #expect(plan.raceKind == .update)
        #expect(plan.raceChanges == [
            RaceImportFieldChange(label: "馬場状態", oldValue: "良", newValue: "重"),
            RaceImportFieldChange(label: "1着", oldValue: "未確定", newValue: "2番"),
        ])
        #expect(plan.entries.map(\.kind) == [.update, .unchanged])
        #expect(plan.entries.first?.changes == [RaceImportFieldChange(label: "印", oldValue: "◎", newValue: "○")])
    }

    @Test func `新しい馬番は新規作成になりjsonに無い馬番は削除になる`() throws {
        try RaceJSONImporter.apply(plan(Self.json()), in: container.mainContext)
        let plan = try plan(Self.json(entries: [Self.entryObject(1, "ウマA", mark: "◎"), Self.entryObject(3, "ウマC")]))
        #expect(plan.entries.map(\.horseNumber) == [1, 2, 3])
        #expect(plan.entries.map(\.kind) == [.unchanged, .delete, .create])
    }

    @Test(arguments: [
        ("date", "2026-10-26" as Any), ("venue", "京都" as Any), ("raceNumber", 10 as Any),
    ])
    func 日付か競馬場かレース番号が違えば別のレースとして新規作成になる(key: String, value: Any) throws {
        try RaceJSONImporter.apply(plan(Self.json()), in: container.mainContext)
        #expect(try plan(Self.json(race: { $0[key] = value })).raceKind == .create)
    }

    @Test func 時刻付きで登録したレースも同じ日付なら照合される() throws {
        let ctx = container.mainContext
        let tokyo = try #require(try ctx.fetch(FetchDescriptor<Venue>()).first { $0.name == "東京" })
        let date = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 15, minute: 40)))
        ctx.insert(Race(date: date, venue: tokyo, raceNumber: 11, raceName: "手入力"))
        let plan = try plan(Self.json())
        #expect(plan.raceKind == .update)
        #expect(plan.raceChanges.first == RaceImportFieldChange(label: "レース名", oldValue: "手入力", newValue: "天皇賞（秋）"))
    }

    // MARK: - 保存

    @Test func 新規作成を保存するとレースと出走馬が登録され区分は競馬場から決まる() throws {
        let race = try RaceJSONImporter.apply(plan(Self.json(race: { $0["venue"] = "大井"; $0["firstPlaceHorseNumber"] = 1 })), in: container.mainContext)
        #expect(try races().count == 1)
        #expect(race.venue?.name == "大井")
        #expect(race.category == "local")
        #expect(race.grade == "G1")
        #expect(race.firstPlaceHorseNumber == 1)
        let entries = (race.entries ?? []).sorted { $0.horseNumber < $1.horseNumber }
        #expect(entries.map(\.horseName) == ["ウマA", "ウマB"])
        #expect(entries.map(\.mark) == [.honmei, .taikou])
        #expect(entries.map(\.jockeyName) == ["騎手1", "騎手2"])
        #expect(Set(entries.map(\.sortIndex)).count == 2)
    }

    @Test func 更新を保存すると同じレースが更新され出走馬が追加削除され馬券は残る() throws {
        let ctx = container.mainContext
        let race = try RaceJSONImporter.apply(plan(Self.json()), in: ctx)
        ctx.insert(Bet(race: race, purchaseAmount: 100))
        try ctx.save()

        try RaceJSONImporter.apply(plan(Self.json(
            race: { $0["distance"] = 2400 },
            entries: [Self.entryObject(1, "ウマA", mark: ""), Self.entryObject(3, "ウマC", mark: "▲")],
        )), in: ctx)

        #expect(try races().count == 1)
        #expect(race.distance == 2400)
        let entries = (race.entries ?? []).sorted { $0.horseNumber < $1.horseNumber }
        #expect(entries.map(\.horseNumber) == [1, 3])
        #expect(entries.map(\.mark) == [nil, .tanana])
        #expect(try ctx.fetch(FetchDescriptor<RaceEntry>()).count == 2)
        #expect(race.bets?.count == 1)
    }

    // MARK: - プロンプト

    @Test func `ai向けプロンプトに全競馬場と全予想印が含まれる`() {
        let prompt = RaceJSONImporter.promptForAI
        #expect(venuePresets.allSatisfy { prompt.contains($0.name) })
        #expect(PredictionMark.allCases.allSatisfy { prompt.contains("\"\($0.rawValue)\"") })
        #expect(prompt.contains("\"schemaVersion\": 1"))
    }

    @Test func `ai向けプロンプトの例のjsonはそのまま取り込める`() throws {
        let data = try RaceJSONImporter.parse(RaceJSONImporter.promptForAI)
        #expect(data.raceName == "天皇賞（秋）")
    }
}
