//
//  CSVExporterTests.swift
//  umalog
//
//  Created by neko3cs on 2026/06/12.
//

import Foundation
import SwiftData
import Testing
@testable import umalog
import ZIPFoundation

@MainActor
struct CSVエクスポーターTest {
    let container: ModelContainer

    init() throws {
        let schema = Schema([Race.self, Bet.self, BetSelection.self, RaceEntry.self, Venue.self, TicketType.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }

    // MARK: - セクションヘッダー

    @Test func `エクスポート結果にraces・entries・bets・bet selectionsの全セクションヘッダーが含まれる`() {
        let output = CSVExporter.export(races: [])
        #expect(output.contains("=== RACES ==="))
        #expect(output.contains("=== ENTRIES ==="))
        #expect(output.contains("=== BETS ==="))
        #expect(output.contains("=== BET_SELECTIONS ==="))
        #expect(output.contains("date,venue,race_number,race_name,distance,track_type,track_condition," +
                "category,first_place_horse,second_place_horse,third_place_horse," +
                "total_purchase,total_payout,balance,memo"))
        #expect(output.contains("date,venue,race_number,horse_number,horse_name,jockey_name,trainer_name,prediction_mark"))
        #expect(output.contains("date,venue,race_number,bet_sort_index,purchase_amount,payout_amount,balance"))
        #expect(output.contains("date,venue,race_number,bet_sort_index,ticket_type,selection," +
                "unit_price,combination_count,sort_index"))
    }

    // MARK: - レース行

    @Test func レース行に日付が含まれる() {
        let race = Race(raceNumber: 1); container.mainContext.insert(race)
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(formatDate(race.date)))
    }

    @Test func レース行にレース番号が含まれる() {
        let race = Race(raceNumber: 5); container.mainContext.insert(race)
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",5,"))
    }

    @Test func トラック種別が芝の場合に芝と出力される() {
        let race = Race(trackType: "turf"); container.mainContext.insert(race)
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",芝,"))
    }

    @Test func トラック種別がダートの場合にダートと出力される() {
        let race = Race(trackType: "dirt"); container.mainContext.insert(race)
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",ダート,"))
    }

    @Test func カテゴリが中央の場合に中央と出力される() {
        let race = Race(category: "central"); container.mainContext.insert(race)
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",中央,"))
    }

    @Test func カテゴリが地方の場合に地方と出力される() {
        let race = Race(category: "local"); container.mainContext.insert(race)
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",地方,"))
    }

    @Test func トラック種別が未知の場合はダートとして出力される() {
        let race = Race(trackType: "unknown"); container.mainContext.insert(race)
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",ダート,"))
    }

    @Test func カテゴリが未知の場合は地方として出力される() {
        let race = Race(category: "unknown"); container.mainContext.insert(race)
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",地方,"))
    }

    @Test func レース行に購入合計が含まれる() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 1500, payoutAmount: 0); ctx.insert(bet)
        race.bets = [bet]
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",1500,"))
    }

    @Test func レース行に払戻合計が含まれる() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 1000, payoutAmount: 3200); ctx.insert(bet)
        race.bets = [bet]
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",3200,"))
    }

    @Test func レース行に収支が含まれる() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 1000, payoutAmount: 3000); ctx.insert(bet)
        race.bets = [bet]
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",2000"))
    }

    // MARK: - 出走馬行

    @Test func 出走馬行に馬名が含まれる() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let entry = RaceEntry(race: race, horseNumber: 3, horseName: "テスト馬"); ctx.insert(entry)
        race.entries = [entry]
        let output = CSVExporter.export(races: [race])
        #expect(output.contains("テスト馬"))
    }

    @Test func 出走馬行に馬番が含まれる() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let entry = RaceEntry(race: race, horseNumber: 7, horseName: "テスト馬"); ctx.insert(entry)
        race.entries = [entry]
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",7,"))
    }

    @Test func 出走馬行に予想印が含まれる() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let entry = RaceEntry(race: race, horseName: "テスト馬", predictionMark: "◎"); ctx.insert(entry)
        race.entries = [entry]
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",◎"))
    }

    // MARK: - 馬券行

    @Test func 馬券行に購入額と払戻額が含まれる() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 500, payoutAmount: 1200); ctx.insert(bet)
        race.bets = [bet]
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",500,"))
        #expect(output.contains(",1200,"))
    }

    @Test func 買い目行に券種と買い目が含まれる() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 100); ctx.insert(bet)
        let sel = BetSelection(bet: bet, ticketTypeName: "単勝", selection: "1", unitPrice: 100, combinationCount: 1)
        ctx.insert(sel)
        bet.selections = [sel]
        race.bets = [bet]
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",単勝,"))
        #expect(output.contains(",1,"))
    }

    // MARK: - CSVエスケープ

    @Test func カンマを含む値がクォートされる() {
        let race = Race(raceName: "東京,大賞典"); container.mainContext.insert(race)
        let output = CSVExporter.export(races: [race])
        #expect(output.contains("\"東京,大賞典\""))
    }

    @Test func ダブルクォートを含む値がエスケープされる() {
        let race = Race(raceName: "\"特別\"レース"); container.mainContext.insert(race)
        let output = CSVExporter.export(races: [race])
        #expect(output.contains("\"\"\"特別\"\"レース\""))
    }

    @Test func 通常の値はクォートされない() {
        let race = Race(raceName: "天皇賞春"); container.mainContext.insert(race)
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",天皇賞春,"))
        #expect(!output.contains("\"天皇賞春\""))
    }

    @Test func 改行を含むメモが空白に置換される() {
        let race = Race(); container.mainContext.insert(race)
        race.memo = "1行目\n2行目"
        let output = CSVExporter.export(races: [race])
        #expect(output.contains("1行目 2行目"))
        #expect(!output.contains("1行目\n2行目"))
    }

    // MARK: - ソート

    @Test func `馬券がsort index昇順で出力される`() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet1 = Bet(race: race, purchaseAmount: 100, sortIndex: 1); ctx.insert(bet1)
        let bet2 = Bet(race: race, purchaseAmount: 200, sortIndex: 0); ctx.insert(bet2)
        race.bets = [bet1, bet2]
        let output = CSVExporter.export(races: [race])
        let idx1 = output.range(of: ",100,")
        let idx2 = output.range(of: ",200,")
        if let r1 = idx1, let r2 = idx2 {
            #expect(r2.lowerBound < r1.lowerBound)
        } else {
            Issue.record("馬券行が出力に含まれていない")
        }
    }

    @Test func レースが日付昇順で出力される() throws {
        let ctx = container.mainContext
        let today = Date()
        let yesterday = try #require(Calendar.current.date(byAdding: .day, value: -1, to: today))
        let race1 = Race(date: today, raceNumber: 1); ctx.insert(race1)
        let race2 = Race(date: yesterday, raceNumber: 2); ctx.insert(race2)

        let output = CSVExporter.export(races: [race1, race2])
        let lines = output.components(separatedBy: "\n")
        let idx1 = lines.firstIndex { $0.contains(formatDate(yesterday)) } ?? Int.max
        let idx2 = lines.firstIndex { $0.contains(formatDate(today)) } ?? Int.max
        #expect(idx1 < idx2)
    }

    // MARK: - horseNumberString

    @Test func `horse number stringでゼロは空文字になる`() {
        #expect(CSVExporter.horseNumberString(0) == "")
    }

    @Test func `horse number stringで正数は文字列になる`() {
        #expect(CSVExporter.horseNumberString(1) == "1")
        #expect(CSVExporter.horseNumberString(18) == "18")
    }

    // MARK: - escape / formatDate / formatFilenameDate

    @Test func カンマを含む文字列がクォートされる() {
        #expect(CSVExporter.escape("a,b") == "\"a,b\"")
    }

    @Test func ダブルクォートを含む文字列がエスケープされクォートされる() {
        #expect(CSVExporter.escape("a\"b") == "\"a\"\"b\"")
    }

    @Test func 改行を含む文字列がクォートされる() {
        #expect(CSVExporter.escape("a\nb") == "\"a\nb\"")
    }

    @Test func 日付がスラッシュ区切り形式でフォーマットされる() throws {
        let calendar = Calendar(identifier: .gregorian)
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 13)))
        #expect(CSVExporter.formatDate(date) == "2026/06/13")
    }

    @Test func ファイル名用日付がコンパクト形式でフォーマットされる() throws {
        let calendar = Calendar(identifier: .gregorian)
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 13)))
        #expect(CSVExporter.formatFilenameDate(date) == "20260613")
    }

    @Test func 日本語短縮日付文字列がスラッシュ区切り形式になる() throws {
        let calendar = Calendar(identifier: .gregorian)
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 13)))
        #expect(date.japaneseShortDateString == "2026/06/13")
    }

    // MARK: - ZipExporter / ZipImporter

    @Test func `zipエクスポートで 一 時ディレクトリにzipファイルが生成される`() throws {
        let ctx = container.mainContext
        let race = Race(raceNumber: 7); ctx.insert(race)
        let url = try ZipExporter.export(races: [race])
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(url.pathExtension == "zip")
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test func zipエクスポートとインポートでデータが完全に復元される() throws {
        let exportCtx = container.mainContext
        let venue = Venue(name: "東京"); exportCtx.insert(venue)
        let race = Race(
            date: makeDate(2026, 6, 13),
            venue: venue,
            raceNumber: 11,
            raceName: "テストレース",
            distance: 1600,
            trackType: "turf",
            trackCondition: "良",
            category: "central",
            memo: "テストメモ",
        )
        exportCtx.insert(race)
        let entry = RaceEntry(race: race, horseNumber: 5, horseName: "テスト馬", predictionMark: "◎")
        exportCtx.insert(entry)
        race.entries = [entry]
        let bet = Bet(race: race, purchaseAmount: 300, payoutAmount: 800)
        exportCtx.insert(bet)
        let betSelection = BetSelection(
            bet: bet, ticketTypeName: "馬連", selection: "1,2,3[BOX]",
            unitPrice: 100, combinationCount: 3, sortIndex: 0,
        )
        exportCtx.insert(betSelection)
        bet.selections = [betSelection]
        race.bets = [bet]

        let url = try ZipExporter.export(races: [race])
        defer { try? FileManager.default.removeItem(at: url) }

        let schema = Schema([Race.self, Bet.self, BetSelection.self, RaceEntry.self, Venue.self, TicketType.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let importContainer = try ModelContainer(for: schema, configurations: [config])
        let importCtx = importContainer.mainContext
        importCtx.insert(Venue(name: "東京"))

        try ZipImporter.importZip(from: url, context: importCtx)

        let races = try importCtx.fetch(FetchDescriptor<Race>())
        #expect(races.count == 1)
        let restored = try #require(races.first)
        #expect(restored.raceName == "テストレース")
        #expect(restored.raceNumber == 11)
        #expect(restored.distance == 1600)
        #expect(restored.trackType == "turf")
        #expect(restored.category == "central")
        #expect(restored.memo == "テストメモ")
        #expect(restored.venue?.name == "東京")

        let entries = try importCtx.fetch(FetchDescriptor<RaceEntry>())
        #expect(entries.count == 1)
        #expect(entries.first?.horseName == "テスト馬")
        #expect(entries.first?.predictionMark == "◎")

        let bets = try importCtx.fetch(FetchDescriptor<Bet>())
        #expect(bets.count == 1)
        let restoredBet = try #require(bets.first)
        #expect(restoredBet.purchaseAmount == 300)
        #expect(restoredBet.payoutAmount == 800)

        let selections = try importCtx.fetch(FetchDescriptor<BetSelection>())
        #expect(selections.count == 1)
        let restoredSel = try #require(selections.first)
        #expect(restoredSel.selection == "1,2,3[BOX]")
        #expect(restoredSel.ticketTypeName == "馬連")
        #expect(restoredSel.unitPrice == 100)
        #expect(restoredSel.combinationCount == 3)
    }

    @Test func zipインポートで既存レースデータが新データに置き換わる() throws {
        let pre = Race(raceNumber: 99); container.mainContext.insert(pre)
        try container.mainContext.save()

        let exportSchema = Schema([Race.self, Bet.self, BetSelection.self, RaceEntry.self, Venue.self, TicketType.self])
        let exportConfig = ModelConfiguration(schema: exportSchema, isStoredInMemoryOnly: true)
        let exportContainer = try ModelContainer(for: exportSchema, configurations: [exportConfig])
        let exportCtx = exportContainer.mainContext
        let newRace = Race(raceNumber: 1, raceName: "新規")
        exportCtx.insert(newRace)
        let url = try ZipExporter.export(races: [newRace])
        defer { try? FileManager.default.removeItem(at: url) }

        try ZipImporter.importZip(from: url, context: container.mainContext)

        let races = try container.mainContext.fetch(FetchDescriptor<Race>())
        #expect(races.count == 1)
        #expect(races.first?.raceName == "新規")
    }

    // MARK: - 複数アイテム

    @Test func 複数の馬券と買い目を持つレースが全てエクスポートされる() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet1 = Bet(race: race, purchaseAmount: 100, sortIndex: 0); ctx.insert(bet1)
        let bet2 = Bet(race: race, purchaseAmount: 200, sortIndex: 1); ctx.insert(bet2)
        let sel1 = BetSelection(bet: bet1, ticketTypeName: "単勝", selection: "1", unitPrice: 100,
                                combinationCount: 1, sortIndex: 0)
        let sel2 = BetSelection(bet: bet2, ticketTypeName: "馬連", selection: "1-2", unitPrice: 200,
                                combinationCount: 1, sortIndex: 0)
        ctx.insert(sel1); ctx.insert(sel2)
        bet1.selections = [sel1]; bet2.selections = [sel2]
        race.bets = [bet1, bet2]
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",単勝,"))
        #expect(output.contains(",馬連,"))
    }

    @Test func 複数の買い目を持つ馬券のzipエクスポートとインポートで全件が復元される() throws {
        let ctx = container.mainContext
        let race = Race(raceNumber: 1); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 700, payoutAmount: 0); ctx.insert(bet)
        let sel1 = BetSelection(bet: bet, ticketTypeName: "馬連", selection: "1-2", unitPrice: 100,
                                combinationCount: 1, sortIndex: 0)
        let sel2 = BetSelection(bet: bet, ticketTypeName: "ワイド", selection: "1-3", unitPrice: 200,
                                combinationCount: 1, sortIndex: 1)
        let sel3 = BetSelection(bet: bet, ticketTypeName: "単勝", selection: "1", unitPrice: 400,
                                combinationCount: 1, sortIndex: 2)
        ctx.insert(sel1); ctx.insert(sel2); ctx.insert(sel3)
        bet.selections = [sel1, sel2, sel3]
        race.bets = [bet]
        let entry = RaceEntry(race: race, horseNumber: 1, horseName: "テスト馬A"); ctx.insert(entry)
        let entry2 = RaceEntry(race: race, horseNumber: 2, horseName: "テスト馬B"); ctx.insert(entry2)
        race.entries = [entry, entry2]

        let url = try ZipExporter.export(races: [race])
        defer { try? FileManager.default.removeItem(at: url) }

        let schema = Schema([Race.self, Bet.self, BetSelection.self, RaceEntry.self, Venue.self, TicketType.self])
        let cfg = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let importContainer = try ModelContainer(for: schema, configurations: [cfg])
        try ZipImporter.importZip(from: url, context: importContainer.mainContext)

        let sels = try importContainer.mainContext.fetch(FetchDescriptor<BetSelection>())
        #expect(sels.count == 3)
    }

    @Test func レガシーフォーマットのzipインポートで馬券から買い目が生成される() throws {
        let racesCSV = """
        date,venue,race_number,race_name,distance,track_type,track_condition,category
        2026/06/16,,1,,1600,芝,良,中央
        """
        let entriesCSV = "date,venue,race_number,horse_number,horse_name,jockey_name,trainer_name,prediction_mark"
        let legacyBetsCSV = """
        date,venue,race_number,ticket_type,selection,unit_price,combination_count,purchase_amount,payout_amount,balance
        2026/06/16,,1,単勝,1,100,1,100,200,100
        """
        let zipURL = FileManager.default.temporaryDirectory.appendingPathComponent("legacy_test.zip")
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

        let bets = try container.mainContext.fetch(FetchDescriptor<Bet>())
        #expect(bets.count == 1)
        #expect(bets.first?.purchaseAmount == 100)
        let selections = try container.mainContext.fetch(FetchDescriptor<BetSelection>())
        #expect(selections.count == 1)
        #expect(selections.first?.ticketTypeName == "単勝")
        #expect(selections.first?.selection == "1")
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }
}
