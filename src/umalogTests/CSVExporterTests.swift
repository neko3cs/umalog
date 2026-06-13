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

@MainActor
struct CSVExporterTests {
    let container: ModelContainer

    init() throws {
        let schema = Schema([Race.self, Bet.self, RaceEntry.self, Venue.self, TicketType.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd"
        return f.string(from: date)
    }

    // MARK: - Section headers

    @Test func export_alwaysContainsRacesHeader() {
        #expect(CSVExporter.export(races: []).contains("=== RACES ==="))
    }

    @Test func export_alwaysContainsEntriesHeader() {
        #expect(CSVExporter.export(races: []).contains("=== ENTRIES ==="))
    }

    @Test func export_alwaysContainsBetsHeader() {
        #expect(CSVExporter.export(races: []).contains("=== BETS ==="))
    }

    @Test func export_racesSection_hasCorrectColumnHeaders() {
        let output = CSVExporter.export(races: [])
        let expected = "date,venue,race_number,race_name,distance,track_type,track_condition," +
            "category,total_purchase,total_payout,balance,memo"
        #expect(output.contains(expected))
    }

    @Test func export_entriesSection_hasCorrectColumnHeaders() {
        let output = CSVExporter.export(races: [])
        #expect(output.contains("date,venue,race_number,horse_number,horse_name,jockey_name,trainer_name,prediction_mark,finish_position"))
    }

    @Test func export_betsSection_hasCorrectColumnHeaders() {
        let output = CSVExporter.export(races: [])
        let expected = "date,venue,race_number,ticket_type,selection," +
            "unit_price,combination_count,purchase_amount,payout_amount,balance"
        #expect(output.contains(expected))
    }

    // MARK: - Race row

    @Test func export_raceRow_containsDate() {
        let race = Race(raceNumber: 1); container.mainContext.insert(race)
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(formatDate(race.date)))
    }

    @Test func export_raceRow_containsRaceNumber() {
        let race = Race(raceNumber: 5); container.mainContext.insert(race)
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",5,"))
    }

    @Test func export_raceRow_turfTrackType() {
        let race = Race(trackType: "turf"); container.mainContext.insert(race)
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",芝,"))
    }

    @Test func export_raceRow_dirtTrackType() {
        let race = Race(trackType: "dirt"); container.mainContext.insert(race)
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",ダート,"))
    }

    @Test func export_raceRow_centralCategory() {
        let race = Race(category: "central"); container.mainContext.insert(race)
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",中央,"))
    }

    @Test func export_raceRow_localCategory() {
        let race = Race(category: "local"); container.mainContext.insert(race)
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",地方,"))
    }

    @Test func export_raceRow_containsTotalPurchase() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 1500, payoutAmount: 0); ctx.insert(bet)
        race.bets = [bet]
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",1500,"))
    }

    @Test func export_raceRow_containsTotalPayout() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 1000, payoutAmount: 3200); ctx.insert(bet)
        race.bets = [bet]
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",3200,"))
    }

    @Test func export_raceRow_containsBalance() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 1000, payoutAmount: 3000); ctx.insert(bet)
        race.bets = [bet]
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",2000"))
    }

    // MARK: - Entry row

    @Test func export_entryRow_containsHorseName() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let entry = RaceEntry(race: race, horseNumber: 3, horseName: "テスト馬"); ctx.insert(entry)
        race.entries = [entry]
        let output = CSVExporter.export(races: [race])
        #expect(output.contains("テスト馬"))
    }

    @Test func export_entryRow_containsHorseNumber() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let entry = RaceEntry(race: race, horseNumber: 7, horseName: "テスト馬"); ctx.insert(entry)
        race.entries = [entry]
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",7,"))
    }

    @Test func export_entryRow_containsPredictionMark() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let entry = RaceEntry(race: race, horseName: "テスト馬", predictionMark: "◎"); ctx.insert(entry)
        race.entries = [entry]
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",◎,"))
    }

    @Test func export_entryRow_withNoPredictionMark_includesHorseName() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let entry = RaceEntry(race: race, horseName: "テスト馬", predictionMark: nil); ctx.insert(entry)
        race.entries = [entry]
        let output = CSVExporter.export(races: [race])
        #expect(output.contains("テスト馬"))
    }

    // MARK: - Bet row

    @Test func export_betRow_containsTicketTypeAndSelection() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, ticketTypeName: "単勝", selection: "1", purchaseAmount: 100); ctx.insert(bet)
        race.bets = [bet]
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",単勝,"))
        #expect(output.contains(",1,"))
    }

    @Test func export_betRow_containsPurchaseAndPayout() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, selection: "1-2", purchaseAmount: 500, payoutAmount: 1200); ctx.insert(bet)
        race.bets = [bet]
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",500,"))
        #expect(output.contains(",1200,"))
    }

    // MARK: - CSV escaping

    @Test func export_valueWithComma_isQuoted() {
        let race = Race(raceName: "東京,大賞典"); container.mainContext.insert(race)
        let output = CSVExporter.export(races: [race])
        #expect(output.contains("\"東京,大賞典\""))
    }

    @Test func export_valueWithDoubleQuote_isEscaped() {
        let race = Race(raceName: "\"特別\"レース"); container.mainContext.insert(race)
        let output = CSVExporter.export(races: [race])
        #expect(output.contains("\"\"\"特別\"\"レース\""))
    }

    @Test func export_normalValue_isNotQuoted() {
        let race = Race(raceName: "天皇賞春"); container.mainContext.insert(race)
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",天皇賞春,"))
        #expect(!output.contains("\"天皇賞春\""))
    }

    @Test func export_memoWithNewline_isReplacedWithSpace() {
        let race = Race(); container.mainContext.insert(race)
        race.memo = "1行目\n2行目"
        let output = CSVExporter.export(races: [race])
        #expect(output.contains("1行目 2行目"))
        #expect(!output.contains("1行目\n2行目"))
    }

    // MARK: - Sorting

    @Test func export_racesAreSortedByDateAscending() throws {
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

    // MARK: - escape / formatDate / formatFilenameDate

    @Test func escape_normalString_isNotQuoted() {
        #expect(CSVExporter.escape("普通の文字") == "普通の文字")
    }

    @Test func escape_stringWithComma_isQuoted() {
        #expect(CSVExporter.escape("a,b") == "\"a,b\"")
    }

    @Test func escape_stringWithDoubleQuote_isEscapedAndQuoted() {
        #expect(CSVExporter.escape("a\"b") == "\"a\"\"b\"")
    }

    @Test func escape_stringWithNewline_isQuoted() {
        #expect(CSVExporter.escape("a\nb") == "\"a\nb\"")
    }

    @Test func formatDate_returnsSlashFormat() throws {
        let calendar = Calendar(identifier: .gregorian)
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 13)))
        #expect(CSVExporter.formatDate(date) == "2026/06/13")
    }

    @Test func formatFilenameDate_returnsCompactFormat() throws {
        let calendar = Calendar(identifier: .gregorian)
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 13)))
        #expect(CSVExporter.formatFilenameDate(date) == "20260613")
    }

    // MARK: - ZipExporter / ZipImporter round-trip

    @Test func zipExporter_producesZipFileAtTemporaryDirectory() throws {
        let ctx = container.mainContext
        let race = Race(raceNumber: 7); ctx.insert(race)
        let url = try ZipExporter.export(races: [race])
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(url.pathExtension == "zip")
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test func zipExporter_zipImporter_roundTrip_preservesData() throws {
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
            memo: "テストメモ"
        )
        exportCtx.insert(race)
        let entry = RaceEntry(race: race, horseNumber: 5, horseName: "テスト馬", predictionMark: "◎")
        exportCtx.insert(entry)
        race.entries = [entry]
        let bet = Bet(race: race, ticketTypeName: "馬連", selection: "1,2,3[BOX]", unitPrice: 100, purchaseAmount: 300, payoutAmount: 800)
        exportCtx.insert(bet)
        race.bets = [bet]

        let url = try ZipExporter.export(races: [race])
        defer { try? FileManager.default.removeItem(at: url) }

        // Import into a fresh container
        let schema = Schema([Race.self, Bet.self, RaceEntry.self, Venue.self, TicketType.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let importContainer = try ModelContainer(for: schema, configurations: [config])
        let importCtx = importContainer.mainContext
        importCtx.insert(Venue(name: "東京")) // 復元時に競馬場参照を解決するため先にシード

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
        #expect(restoredBet.unitPrice == 100)
        #expect(restoredBet.purchaseAmount == 300)
        #expect(restoredBet.payoutAmount == 800)
        #expect(restoredBet.selection == "1,2,3[BOX]")
        #expect(restoredBet.ticketTypeName == "馬連")
    }

    @Test func zipImporter_replacesExistingRaceData() throws {
        // 既存レースを 1 件投入
        let pre = Race(raceNumber: 99); container.mainContext.insert(pre)
        try container.mainContext.save()

        // 別レースを ZIP 化
        let exportSchema = Schema([Race.self, Bet.self, RaceEntry.self, Venue.self, TicketType.self])
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

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }
}
