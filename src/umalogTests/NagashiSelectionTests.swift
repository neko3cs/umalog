//
//  NagashiSelectionTests.swift
//  umalogTests
//
//  Created by neko3cs on 2026/10/19.
//

import Foundation
import SwiftData
import Testing
@testable import umalog
import ZIPFoundation

@MainActor
struct 流し買い目Test {
    // MARK: - パース / 表記

    @Test func 着順指定なしの流しをパースできる() throws {
        let nagashi = try #require(NagashiSelection(selection: "1>2,3,4[流し]"))
        #expect(nagashi.axes == [1])
        #expect(nagashi.opponents == [2, 3, 4])
        #expect(nagashi.axisPositions.isEmpty)
        #expect(nagashi.isMulti == false)
    }

    @Test func `軸 2 頭の着順指定流しをパースできる`() throws {
        let nagashi = try #require(NagashiSelection(selection: "5,7>1,2[1・3着流し]"))
        #expect(nagashi.axes == [5, 7])
        #expect(nagashi.opponents == [1, 2])
        #expect(nagashi.axisPositions == [1, 3])
        #expect(nagashi.isMulti == false)
    }

    @Test func 流しマルチをパースできる() throws {
        let nagashi = try #require(NagashiSelection(selection: "1>2,3[流しマルチ]"))
        #expect(nagashi.axes == [1])
        #expect(nagashi.isMulti == true)
        #expect(nagashi.axisPositions.isEmpty)
    }

    @Test(arguments: [
        "1>2,3,4[流し]", "1,2>3,4[流し]", "1>2,3[1着流し]", "1>2,3[2着流し]",
        "1,2>3,4[2・3着流し]", "1>2,3[流しマルチ]", "1,2>3,4[流しマルチ]",
    ])
    func パースした流しの表記が元の買い目文字列に戻る(selection: String) throws {
        let nagashi = try #require(NagashiSelection(selection: selection))
        #expect(nagashi.notation == selection)
    }

    @Test(arguments: [
        "", "1-2-3", "1,2,3[BOX]", "1,2/3,4,5", "1>2,3", "1>2,3[BOX]", "1>2,3[その他]",
        ">2,3[流し]", "1>[流し]", "1>2>3[流し]", "1,2>3,4[1着流し]", "1>2,3[x着流し]", "1>2,3[着流し]",
    ])
    func 流しの書式でない買い目文字列はパースされない(selection: String) {
        #expect(NagashiSelection(selection: selection) == nil)
    }

    // MARK: - 組合せ点数: 着順を区別しない券種

    @Test(arguments: ["馬連", "ワイド", "枠連"])
    func `2頭系の軸1頭流しは相手の頭数が点数になる`(ticketTypeName: String) {
        #expect(Bet.combinationCount(selection: "1>2,3,4[流し]", ticketTypeName: ticketTypeName) == 3)
    }

    @Test func `三連複の軸 1 頭流しは相手n頭から 2 頭を選ぶ組合せ数になる`() {
        #expect(Bet.combinationCount(selection: "1>2,3,4,5[流し]", ticketTypeName: "三連複") == 6)
    }

    @Test func `三連複の軸 2 頭流しは相手の頭数が点数になる`() {
        #expect(Bet.combinationCount(selection: "1,2>3,4,5[流し]", ticketTypeName: "三連複") == 3)
    }

    @Test func 着順を区別しない券種では着順指定とマルチ指定を無視する() {
        #expect(Bet.combinationCount(selection: "1>2,3,4,5[2着流し]", ticketTypeName: "三連複") == 6)
        #expect(Bet.combinationCount(selection: "1>2,3,4[流しマルチ]", ticketTypeName: "馬連") == 3)
    }

    // MARK: - 組合せ点数: 馬単

    @Test func `馬単の 1 着流しは相手の頭数が点数になる`() {
        #expect(Bet.combinationCount(selection: "1>2,3,4[1着流し]", ticketTypeName: "馬単") == 3)
    }

    @Test func `馬単の 2 着流しは相手の頭数が点数になる`() {
        #expect(Bet.combinationCount(selection: "1>2,3,4[2着流し]", ticketTypeName: "馬単") == 3)
    }

    @Test func `馬単の流しマルチは 1 着流しと 2 着流しの合計になる`() {
        #expect(Bet.combinationCount(selection: "1>2,3,4[流しマルチ]", ticketTypeName: "馬単") == 6)
    }

    @Test func `馬単で着順指定がない流しは 1 着流しとして数える`() {
        #expect(Bet.combinationCount(selection: "1>2,3,4[流し]", ticketTypeName: "馬単") == 3)
    }

    // MARK: - 組合せ点数: 三連単

    @Test(arguments: ["1着流し", "2着流し", "3着流し"])
    func `三連単の軸 1 頭着順指定流しは相手n頭の順列数になる`(tag: String) {
        #expect(Bet.combinationCount(selection: "1>2,3,4,5[\(tag)]", ticketTypeName: "三連単") == 12)
    }

    @Test func `三連単の軸 1 頭流しマルチは着順指定流しの 3 倍になる`() {
        #expect(Bet.combinationCount(selection: "1>2,3,4,5[流しマルチ]", ticketTypeName: "三連単") == 36)
    }

    @Test(arguments: ["1・2着流し", "1・3着流し", "2・3着流し"])
    func `三連単の軸 2 頭着順指定流しは相手の頭数が点数になる`(tag: String) {
        #expect(Bet.combinationCount(selection: "1,2>3,4,5[\(tag)]", ticketTypeName: "三連単") == 3)
    }

    @Test func `三連単の軸 2 頭流しマルチは着順指定流しの 6 倍になる`() {
        #expect(Bet.combinationCount(selection: "1,2>3,4,5[流しマルチ]", ticketTypeName: "三連単") == 18)
    }

    @Test func `三連単の軸 2 頭着順指定は軸の並び順どおりの着順に置く`() {
        // 2 番が 1 着、1 番が 3 着。相手 1 頭なら組は 2→3→1 の 1 点だけ
        #expect(Bet.combinationCount(selection: "2,1>3[1・3着流し]", ticketTypeName: "三連単") == 1)
    }

    // MARK: - 組合せ点数: 不成立・重複

    @Test func 相手に軸と同じ馬番が含まれていても重複して数えない() {
        #expect(Bet.combinationCount(selection: "1>1,2,3[流し]", ticketTypeName: "馬連") == 2)
        #expect(Bet.combinationCount(selection: "1>2,2,3[流し]", ticketTypeName: "馬連") == 2)
    }

    @Test func `軸の頭数が券種の頭数以上の場合は点数が 0 になる`() {
        #expect(Bet.combinationCount(selection: "1,2>3,4[流し]", ticketTypeName: "馬連") == 0)
        #expect(Bet.combinationCount(selection: "1,2>3,4[1・2着流し]", ticketTypeName: "馬単") == 0)
    }

    @Test func `軸に同じ馬番が重複している場合は点数が 0 になる`() {
        #expect(Bet.combinationCount(selection: "1,1>2,3[流し]", ticketTypeName: "三連複") == 0)
    }

    @Test func `券種の頭数を超える着順指定は点数が 0 になる`() {
        #expect(Bet.combinationCount(selection: "1>2,3[3着流し]", ticketTypeName: "馬単") == 0)
        #expect(Bet.combinationCount(selection: "1>2,3[4着流し]", ticketTypeName: "三連単") == 0)
        #expect(Bet.combinationCount(selection: "1>2,3[0着流し]", ticketTypeName: "三連単") == 0)
    }

    @Test func `軸 2 頭の着順が重複している場合は点数が 0 になる`() {
        #expect(Bet.combinationCount(selection: "1,2>3,4[1・1着流し]", ticketTypeName: "三連単") == 0)
    }

    @Test func `相手が足りない場合は点数が 0 になる`() {
        #expect(Bet.combinationCount(selection: "1>2[流し]", ticketTypeName: "三連複") == 0)
        #expect(Bet.combinationCount(selection: "1>1[流し]", ticketTypeName: "馬連") == 0)
    }

    @Test(arguments: ["単勝", "複勝", "未知の券種"])
    func `流しに対応しない券種は点数が 0 になる`(ticketTypeName: String) {
        #expect(Bet.combinationCount(selection: "1>2,3[流し]", ticketTypeName: ticketTypeName) == 0)
    }

    @Test func `流しに対応しない券種の買い目ドラフトは最低 1 点として購入額を計算する`() {
        let draft = BetSelectionDraft(ticketTypeName: "単勝", selection: "1>2,3[流し]", unitPrice: 200)
        #expect(draft.combinationCount == 1)
        #expect(draft.purchaseAmount == 200)
    }

    @Test func 流しの買い目ドラフトは単価と点数から購入額を計算する() {
        let draft = BetSelectionDraft(
            ticketTypeName: "三連単", selection: "1>2,3,4,5[流しマルチ]", unitPrice: 100,
        )
        #expect(draft.combinationCount == 36)
        #expect(draft.purchaseAmount == 3600)
    }

    // MARK: - Property-Based Tests

    @Test func 任意の相手頭数で流しの点数が公式に従う() {
        for n in 1 ... 17 {
            let opponents = (2 ... (n + 1)).map { "\($0)" }.joined(separator: ",")
            let pairs = n * (n - 1) / 2
            let perms = n * (n - 1)
            #expect(Bet.combinationCount(selection: "1>\(opponents)[流し]", ticketTypeName: "馬連") == n)
            #expect(Bet.combinationCount(selection: "1>\(opponents)[流しマルチ]", ticketTypeName: "馬単") == n * 2)
            #expect(Bet.combinationCount(selection: "1>\(opponents)[流し]", ticketTypeName: "三連複") == pairs)
            #expect(Bet.combinationCount(selection: "1>\(opponents)[1着流し]", ticketTypeName: "三連単") == perms)
            #expect(Bet.combinationCount(selection: "1>\(opponents)[流しマルチ]", ticketTypeName: "三連単") == perms * 3)
        }
    }

    @Test func `任意の相手頭数で軸 2 頭流しの点数が公式に従う`() {
        for n in 1 ... 16 {
            let opponents = (3 ... (n + 2)).map { "\($0)" }.joined(separator: ",")
            #expect(Bet.combinationCount(selection: "1,2>\(opponents)[流し]", ticketTypeName: "三連複") == n)
            #expect(Bet.combinationCount(selection: "1,2>\(opponents)[2・3着流し]", ticketTypeName: "三連単") == n)
            #expect(Bet.combinationCount(selection: "1,2>\(opponents)[流しマルチ]", ticketTypeName: "三連単") == n * 6)
        }
    }

    // MARK: - 着順指定の選択肢

    @Test func `馬単の着順の選択肢は 1 着と 2 着とマルチになる`() {
        let labels = NagashiPlacement.options(horseCount: 2, axisCount: 1).map(\.label)
        #expect(labels == ["1着", "2着", "マルチ"])
    }

    @Test func `三連単軸 1 頭の着順の選択肢は 1 着から 3 着とマルチになる`() {
        let labels = NagashiPlacement.options(horseCount: 3, axisCount: 1).map(\.label)
        #expect(labels == ["1着", "2着", "3着", "マルチ"])
    }

    @Test func `三連単軸 2 頭の着順の選択肢は 2 つの着順の組合せとマルチになる`() {
        let labels = NagashiPlacement.options(horseCount: 3, axisCount: 2).map(\.label)
        #expect(labels == ["1・2着", "1・3着", "2・3着", "マルチ"])
    }

    @Test func `既定の着順指定は軸を 1 着から順に置く`() {
        #expect(NagashiPlacement.leading(axisCount: 1).positions == [1])
        #expect(NagashiPlacement.leading(axisCount: 2).positions == [1, 2])
    }
}

// MARK: - CSV / ZIP

@MainActor
struct 流し買い目エクスポートTest {
    let container: ModelContainer

    init() throws {
        let schema = Schema([Race.self, Bet.self, BetSelection.self, RaceEntry.self, Venue.self, TicketType.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    @Test func 流しの買い目はカンマを含むためcsvでクォートされる() {
        let ctx = container.mainContext
        let race = Race(raceNumber: 1); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 300); ctx.insert(bet)
        let sel = BetSelection(bet: bet, ticketTypeName: "馬単", selection: "1>2,3,4[1着流し]", combinationCount: 3)
        ctx.insert(sel)
        bet.selections = [sel]
        race.bets = [bet]
        #expect(CSVExporter.betSelectionsCSV([race]).contains("\"1>2,3,4[1着流し]\""))
    }

    @Test func 流しの買い目がzipエクスポートとインポートで欠落なく復元される() throws {
        let exportCtx = container.mainContext
        let race = Race(raceNumber: 11, raceName: "流しレース")
        exportCtx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 3900); exportCtx.insert(bet)
        let selections = [
            ("馬連", "1>2,3,4[流し]", 3),
            ("三連単", "1>2,3,4,5[流しマルチ]", 36),
            ("三連単", "1,2>3,4,5[1・3着流し]", 3),
        ]
        bet.selections = selections.enumerated().map { idx, item in
            let sel = BetSelection(
                bet: bet, ticketTypeName: item.0, selection: item.1,
                unitPrice: 100, combinationCount: item.2, sortIndex: idx,
            )
            exportCtx.insert(sel)
            return sel
        }
        race.bets = [bet]

        let url = try ZipExporter.export(races: [race])
        defer { try? FileManager.default.removeItem(at: url) }

        let schema = Schema([Race.self, Bet.self, BetSelection.self, RaceEntry.self, Venue.self, TicketType.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let importContainer = try ModelContainer(for: schema, configurations: [config])
        let importCtx = importContainer.mainContext
        try ZipImporter.importZip(from: url, context: importCtx)

        let restored = try importCtx.fetch(FetchDescriptor<BetSelection>()).sorted { $0.sortIndex < $1.sortIndex }
        #expect(restored.map(\.ticketTypeName) == selections.map(\.0))
        #expect(restored.map(\.selection) == selections.map(\.1))
        #expect(restored.map(\.combinationCount) == selections.map(\.2))
    }

    @Test func レガシーフォーマットのzipインポートで流しの点数が算出される() throws {
        let racesCSV = """
        date,venue,race_number,race_name,distance,track_type,track_condition,category
        2026/10/19,,1,,1600,芝,良,中央
        """
        let entriesCSV = "date,venue,race_number,horse_number,horse_name,jockey_name,trainer_name,prediction_mark"
        let legacyBetsCSV = """
        date,venue,race_number,ticket_type,selection,unit_price,combination_count,purchase_amount,payout_amount,balance
        2026/10/19,,1,馬単,"1>2,3,4[流しマルチ]",100,6,600,0,-600
        """
        let zipURL = FileManager.default.temporaryDirectory.appendingPathComponent("legacy_nagashi_test.zip")
        try? FileManager.default.removeItem(at: zipURL)
        let archive = try Archive(url: zipURL, accessMode: .create)
        defer { try? FileManager.default.removeItem(at: zipURL) }

        func addEntry(name: String, content: String) throws {
            let data = Data(content.utf8)
            try archive.addEntry(
                with: name, type: .file, uncompressedSize: Int64(data.count),
            ) { _, size in data.subdata(in: 0 ..< size) }
        }
        try addEntry(name: "races.csv", content: racesCSV)
        try addEntry(name: "entries.csv", content: entriesCSV)
        try addEntry(name: "bets.csv", content: legacyBetsCSV)

        try ZipImporter.importZip(from: zipURL, context: container.mainContext)

        let selections = try container.mainContext.fetch(FetchDescriptor<BetSelection>())
        #expect(selections.count == 1)
        #expect(selections.first?.selection == "1>2,3,4[流しマルチ]")
        #expect(selections.first?.combinationCount == 6)
    }
}
