//
//  ZipImporterTicketTypeTests.swift
//  umalogTests
//
//  Created by neko3cs on 2026/10/24.
//

import Foundation
import SwiftData
import Testing
@testable import umalog
import ZIPFoundation

@MainActor
struct ZIP取り込みの券種紐付けTest {
    let container: ModelContainer

    init() throws {
        let schema = Schema([Race.self, Bet.self, BetSelection.self, RaceEntry.self, Venue.self, TicketType.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    /// 指定した CSV を持つ ZIP を一時ディレクトリに作り、URL を返す。
    /// - Parameters:
    ///   - name: ZIP のファイル名。
    ///   - files: ZIP 内のパスと内容の組。
    /// - Returns: 作成した ZIP の URL。
    private func makeZip(name: String, files: [(String, String)]) throws -> URL {
        let zipURL = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: zipURL)
        let archive = try Archive(url: zipURL, accessMode: .create)
        for (path, content) in files {
            let data = Data(content.utf8)
            try archive.addEntry(
                with: path, type: .file, uncompressedSize: Int64(data.count),
            ) { _, size in data.subdata(in: 0 ..< size) }
        }
        return zipURL
    }

    private let racesCSV = """
    date,venue,race_number,race_name,distance,track_type,track_condition,category
    2026/10/24,,11,,1600,芝,良,中央
    """
    private let entriesCSV = "date,venue,race_number,horse_number,horse_name,jockey_name,trainer_name,prediction_mark"

    @Test func 現行形式のzip取り込みで買い目が同名の券種マスターに紐付く() throws {
        let ctx = container.mainContext
        let umaren = TicketType(name: "馬連", sortIndex: 3); ctx.insert(umaren)
        let sanrenpuku = TicketType(name: "三連複", sortIndex: 6); ctx.insert(sanrenpuku)
        let zipURL = try makeZip(name: "ticket_type_new_format.zip", files: [
            ("races.csv", racesCSV),
            ("entries.csv", entriesCSV),
            ("bets.csv", """
            date,venue,race_number,bet_sort_index,purchase_amount,payout_amount,balance
            2026/10/24,,11,0,400,0,-400
            """),
            ("bet_selections.csv", """
            date,venue,race_number,bet_sort_index,ticket_type,selection,unit_price,combination_count,sort_index
            2026/10/24,,11,0,馬連,1-2,100,1,0
            2026/10/24,,11,0,三連複,"1,2,3[BOX]",300,1,1
            """),
        ])
        defer { try? FileManager.default.removeItem(at: zipURL) }

        try ZipImporter.importZip(from: zipURL, context: ctx)

        let selections = try ctx.fetch(FetchDescriptor<BetSelection>(sortBy: [SortDescriptor(\.sortIndex)]))
        #expect(selections.count == 2)
        #expect(selections.map { $0.ticketType?.persistentModelID } == [
            umaren.persistentModelID, sanrenpuku.persistentModelID,
        ])
        #expect(selections.map(\.ticketTypeName) == ["馬連", "三連複"])
    }

    @Test func 旧形式のzip取り込みで買い目が同名の券種マスターに紐付く() throws {
        let ctx = container.mainContext
        let wide = TicketType(name: "ワイド", sortIndex: 4); ctx.insert(wide)
        let zipURL = try makeZip(name: "ticket_type_legacy_format.zip", files: [
            ("races.csv", racesCSV),
            ("entries.csv", entriesCSV),
            ("bets.csv", """
            date,venue,race_number,ticket_type,selection,unit_price,combination_count,purchase_amount,payout_amount,balance
            2026/10/24,,11,ワイド,3-5,100,1,100,0,-100
            """),
        ])
        defer { try? FileManager.default.removeItem(at: zipURL) }

        try ZipImporter.importZip(from: zipURL, context: ctx)

        let selections = try ctx.fetch(FetchDescriptor<BetSelection>())
        #expect(selections.count == 1)
        #expect(selections.first?.ticketType?.persistentModelID == wide.persistentModelID)
        #expect(selections.first?.ticketTypeName == "ワイド")
    }

    @Test func 券種マスターにない券種名の買い目は券種名だけで取り込まれる() throws {
        let ctx = container.mainContext
        ctx.insert(TicketType(name: "馬連", sortIndex: 3))
        let zipURL = try makeZip(name: "ticket_type_unknown.zip", files: [
            ("races.csv", racesCSV),
            ("entries.csv", entriesCSV),
            ("bets.csv", """
            date,venue,race_number,bet_sort_index,purchase_amount,payout_amount,balance
            2026/10/24,,11,0,100,0,-100
            """),
            ("bet_selections.csv", """
            date,venue,race_number,bet_sort_index,ticket_type,selection,unit_price,combination_count,sort_index
            2026/10/24,,11,0,WIN5,1-2-3-4-5,100,1,0
            """),
        ])
        defer { try? FileManager.default.removeItem(at: zipURL) }

        try ZipImporter.importZip(from: zipURL, context: ctx)

        let selections = try ctx.fetch(FetchDescriptor<BetSelection>())
        #expect(selections.count == 1)
        #expect(selections.first?.ticketType == nil)
        #expect(selections.first?.ticketTypeName == "WIN5")
    }

    @Test func 書き出したzipを取り込むと券種マスターとの紐付けが復元される() throws {
        let ctx = container.mainContext
        let umatan = TicketType(name: "馬単", sortIndex: 5); ctx.insert(umatan)
        let race = Race(raceNumber: 11); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 100); ctx.insert(bet)
        let sel = BetSelection(bet: bet, ticketType: umatan, ticketTypeName: "馬単", selection: "1-2")
        ctx.insert(sel)
        bet.selections = [sel]
        race.bets = [bet]
        let url = try ZipExporter.export(races: [race])
        defer { try? FileManager.default.removeItem(at: url) }

        try ZipImporter.importZip(from: url, context: ctx)

        let selections = try ctx.fetch(FetchDescriptor<BetSelection>())
        #expect(selections.count == 1)
        #expect(selections.first?.ticketType?.persistentModelID == umatan.persistentModelID)
    }
}
