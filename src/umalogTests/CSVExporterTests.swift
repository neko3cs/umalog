//
//  CSVExporterTests.swift
//  umalog
//
//  Created by neko3cs on 2026/06/12.
//

import Foundation
import Testing
import SwiftData
@testable import umalog

@Suite @MainActor
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
        #expect(output.contains("date,venue,race_number,race_name,distance,track_type,track_condition,category,total_purchase,total_payout,balance,memo"))
    }

    @Test func export_entriesSection_hasCorrectColumnHeaders() {
        let output = CSVExporter.export(races: [])
        #expect(output.contains("date,venue,race_number,horse_number,horse_name,jockey_name,trainer_name,prediction_mark,finish_position"))
    }

    @Test func export_betsSection_hasCorrectColumnHeaders() {
        let output = CSVExporter.export(races: [])
        #expect(output.contains("date,venue,race_number,ticket_type,selection,purchase_amount,payout_amount,balance"))
    }

    // MARK: - Race row

    @Test func export_raceRow_containsDate() throws {
        let race = Race(raceNumber: 1); container.mainContext.insert(race)
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(formatDate(race.date)))
    }

    @Test func export_raceRow_containsRaceNumber() throws {
        let race = Race(raceNumber: 5); container.mainContext.insert(race)
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",5,"))
    }

    @Test func export_raceRow_turfTrackType() throws {
        let race = Race(trackType: "turf"); container.mainContext.insert(race)
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",芝,"))
    }

    @Test func export_raceRow_dirtTrackType() throws {
        let race = Race(trackType: "dirt"); container.mainContext.insert(race)
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",ダート,"))
    }

    @Test func export_raceRow_centralCategory() throws {
        let race = Race(category: "central"); container.mainContext.insert(race)
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",中央,"))
    }

    @Test func export_raceRow_localCategory() throws {
        let race = Race(category: "local"); container.mainContext.insert(race)
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",地方,"))
    }

    @Test func export_raceRow_containsTotalPurchase() throws {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 1500, payoutAmount: 0); ctx.insert(bet)
        race.bets = [bet]
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",1500,"))
    }

    @Test func export_raceRow_containsTotalPayout() throws {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 1000, payoutAmount: 3200); ctx.insert(bet)
        race.bets = [bet]
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",3200,"))
    }

    @Test func export_raceRow_containsBalance() throws {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 1000, payoutAmount: 3000); ctx.insert(bet)
        race.bets = [bet]
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",2000"))
    }

    // MARK: - Entry row

    @Test func export_entryRow_containsHorseName() throws {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let entry = RaceEntry(race: race, horseNumber: 3, horseName: "テスト馬"); ctx.insert(entry)
        race.entries = [entry]
        let output = CSVExporter.export(races: [race])
        #expect(output.contains("テスト馬"))
    }

    @Test func export_entryRow_containsHorseNumber() throws {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let entry = RaceEntry(race: race, horseNumber: 7, horseName: "テスト馬"); ctx.insert(entry)
        race.entries = [entry]
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",7,"))
    }

    @Test func export_entryRow_containsPredictionMark() throws {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let entry = RaceEntry(race: race, horseName: "テスト馬", predictionMark: "◎"); ctx.insert(entry)
        race.entries = [entry]
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",◎,"))
    }

    @Test func export_entryRow_withNoPredictionMark_includesHorseName() throws {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let entry = RaceEntry(race: race, horseName: "テスト馬", predictionMark: nil); ctx.insert(entry)
        race.entries = [entry]
        let output = CSVExporter.export(races: [race])
        #expect(output.contains("テスト馬"))
    }

    // MARK: - Bet row

    @Test func export_betRow_containsTicketTypeAndSelection() throws {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, ticketTypeName: "単勝", selection: "1", purchaseAmount: 100); ctx.insert(bet)
        race.bets = [bet]
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",単勝,"))
        #expect(output.contains(",1,"))
    }

    @Test func export_betRow_containsPurchaseAndPayout() throws {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, selection: "1-2", purchaseAmount: 500, payoutAmount: 1200); ctx.insert(bet)
        race.bets = [bet]
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",500,"))
        #expect(output.contains(",1200,"))
    }

    // MARK: - CSV escaping

    @Test func export_valueWithComma_isQuoted() throws {
        let race = Race(raceName: "東京,大賞典"); container.mainContext.insert(race)
        let output = CSVExporter.export(races: [race])
        #expect(output.contains("\"東京,大賞典\""))
    }

    @Test func export_valueWithDoubleQuote_isEscaped() throws {
        let race = Race(raceName: "\"特別\"レース"); container.mainContext.insert(race)
        let output = CSVExporter.export(races: [race])
        #expect(output.contains("\"\"\"特別\"\"レース\""))
    }

    @Test func export_normalValue_isNotQuoted() throws {
        let race = Race(raceName: "天皇賞春"); container.mainContext.insert(race)
        let output = CSVExporter.export(races: [race])
        #expect(output.contains(",天皇賞春,"))
        #expect(!output.contains("\"天皇賞春\""))
    }

    @Test func export_memoWithNewline_isReplacedWithSpace() throws {
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
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let race1 = Race(date: today,     raceNumber: 1); ctx.insert(race1)
        let race2 = Race(date: yesterday, raceNumber: 2); ctx.insert(race2)

        let output = CSVExporter.export(races: [race1, race2])
        let lines = output.components(separatedBy: "\n")
        let idx1 = lines.firstIndex { $0.contains(formatDate(yesterday)) } ?? Int.max
        let idx2 = lines.firstIndex { $0.contains(formatDate(today)) }     ?? Int.max
        #expect(idx1 < idx2)
    }
}
