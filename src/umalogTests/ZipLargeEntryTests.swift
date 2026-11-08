//
//  ZipLargeEntryTests.swift
//  umalog
//
//  Created by neko3cs on 2026/11/08.
//

import Foundation
import SwiftData
import Testing
@testable import umalog
import ZIPFoundation

/// ZIPFoundation の書き込み単位（16 KiB）を超えるファイルが、ZIP バックアップに壊れずに書かれることを確かめる。
/// - Note: ZIPFoundation はエントリの中身を 16 KiB ごとに、読み出し位置を進めながら受け取る。
///   位置を無視すると 16 KiB を超えた部分が先頭の繰り返しになるため、境界の前後と、境界をまたぐ多バイト文字を確かめる。
@MainActor
struct ZIPの大きなファイルTest {
    let container: ModelContainer

    init() throws {
        container = try Self.makeContainer()
    }

    /// ZIPFoundation がエントリを書き込む単位のバイト数（`defaultWriteChunkSize`）。
    private static let chunkSize = 16384

    /// 期待する開催日を組み立てるためのグレゴリオ暦。
    private static let gregorian = Calendar(identifier: .gregorian)

    /// メモを書き出すレースの開催日。
    private static let raceDate = gregorian.date(from: DateComponents(year: 2026, month: 11, day: 8)) ?? Date()

    /// インメモリのストアを持つ ModelContainer を作る。
    /// - Returns: 作った ModelContainer。
    private static func makeContainer() throws -> ModelContainer {
        let schema = Schema([Race.self, Bet.self, BetSelection.self, RaceEntry.self, Venue.self, TicketType.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// 書き出した ZIP からエントリの中身を取り出す。
    /// - Parameters:
    ///   - url: ZIP ファイルの URL。
    ///   - path: アーカイブ内のパス。
    /// - Returns: エントリの中身のバイト列。
    private func entryData(in url: URL, path: String) throws -> Data {
        let archive = try Archive(url: url, accessMode: .read)
        let entry = try #require(archive[path], "\(path) が ZIP にない")
        var data = Data()
        _ = try archive.extract(entry) { data.append($0) }
        return data
    }

    /// 指定したメモを持つレースを 1 件書き出す。
    /// - Parameter memo: レースのメモ。
    /// - Returns: 書き出した ZIP の URL と、メモのアーカイブ内のパス。
    private func exportRace(memo: String) throws -> (url: URL, memoPath: String) {
        let race = Race(date: Self.raceDate, raceNumber: 11, raceName: "大きなメモ", memo: memo)
        container.mainContext.insert(race)
        let url = try ZipExporter.export(races: [race])
        let baseName = ZipExporter.memoBaseName(
            date: Self.raceDate, venueName: "", raceNumber: 11, raceName: "大きなメモ",
        )
        return (url, "memo/\(baseName).md")
    }

    // MARK: - エントリの中身が書き出す前のバイト列と一致する

    @Test(arguments: [
        ("書き込み単位より 1 バイト小さい", 16383),
        ("書き込み単位ちょうど", 16384),
        ("書き込み単位より 1 バイト大きい", 16385),
        ("書き込み単位 2 つと端数", 40000),
    ])
    func `書き出したメモのバイト列が書き出す前のテキストの UTF-8 と一致する`(
        boundary: String, byteCount: Int,
    ) throws {
        let memo = String((0 ..< byteCount).map { Character(String($0 % 10)) })
        let (url, memoPath) = try exportRace(memo: memo)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(try entryData(in: url, path: memoPath) == Data(memo.utf8), "\(boundary)")
    }

    @Test func `書き込み単位の境界をまたぐ日本語のメモが書き出しても取り込んでも元と一致する`() throws {
        // 「あ」は UTF-8 で 3 バイト。先頭の「あ」が 16,383〜16,385 バイト目（0 始まり）を占め、境界をまたぐ
        let memo = String(repeating: "a", count: Self.chunkSize - 1) + String(repeating: "あいう", count: 100)
        let (url, memoPath) = try exportRace(memo: memo)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(try entryData(in: url, path: memoPath) == Data(memo.utf8))

        let importContainer = try Self.makeContainer()
        try ZipImporter.importZip(from: url, context: importContainer.mainContext)
        let restored = try importContainer.mainContext.fetch(FetchDescriptor<Race>())
        #expect(restored.map(\.memo) == [memo])
    }

    // MARK: - 16 KiB を超えるデータを書き出して取り込むと元に戻る

    @Test func `races.csv が 16 KiB を超える件数のレースを書き出して取り込むと元のレースに戻る`() throws {
        let ctx = container.mainContext
        let venue = Venue(name: "東京"); ctx.insert(venue)
        let races = (0 ..< 400).map { index in
            Race(
                date: Self.gregorian.date(byAdding: .day, value: index, to: Self.raceDate) ?? Self.raceDate,
                venue: venue,
                raceNumber: index % 12 + 1,
                raceName: "レース\(index)",
            )
        }
        races.forEach(ctx.insert)
        let racesCSV = Data(CSVExporter.racesCSV(races, includeMemo: false).utf8)
        try #require(racesCSV.count > Self.chunkSize)

        let url = try ZipExporter.export(races: races)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(try entryData(in: url, path: "races.csv") == racesCSV)

        let importContainer = try Self.makeContainer()
        let importCtx = importContainer.mainContext
        importCtx.insert(Venue(name: "東京"))
        try ZipImporter.importZip(from: url, context: importCtx)

        // レースを比べるための、日付・競馬場・R・レース名の組。
        func key(_ race: Race) -> String {
            "\(CSVExporter.formatDate(race.date)),\(race.venue?.name ?? ""),\(race.raceNumber),\(race.raceName)"
        }
        let restored = try importCtx.fetch(FetchDescriptor<Race>()).map(key).sorted()
        #expect(restored == races.map(key).sorted())
    }

    @Test func `bets.csv と bet_selections.csv が 16 KiB を超える件数の馬券を書き出して取り込むと元の馬券に戻る`() throws {
        let ctx = container.mainContext
        let race = Race(date: Self.raceDate, raceNumber: 11, raceName: "馬券の多いレース")
        ctx.insert(race)
        let bets = (0 ..< 500).map { index in
            let bet = Bet(race: race, purchaseAmount: (index + 1) * 100, payoutAmount: index * 10, sortIndex: index)
            ctx.insert(bet)
            let selection = BetSelection(
                bet: bet, ticketTypeName: "馬連", selection: "\(index % 18 + 1)-\((index + 1) % 18 + 1)",
                unitPrice: (index + 1) * 100, combinationCount: 1, sortIndex: 0,
            )
            ctx.insert(selection)
            bet.selections = [selection]
            return bet
        }
        race.bets = bets
        let betsCSV = Data(CSVExporter.betsCSV([race]).utf8)
        let selectionsCSV = Data(CSVExporter.betSelectionsCSV([race]).utf8)
        try #require(betsCSV.count > Self.chunkSize)
        try #require(selectionsCSV.count > Self.chunkSize)

        let url = try ZipExporter.export(races: [race])
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(try entryData(in: url, path: "bets.csv") == betsCSV)
        #expect(try entryData(in: url, path: "bet_selections.csv") == selectionsCSV)

        let importContainer = try Self.makeContainer()
        try ZipImporter.importZip(from: url, context: importContainer.mainContext)

        // 馬券を比べるための、表示順・購入額・払戻額・買い目の組。
        func key(_ bet: Bet) -> String {
            let selections = (bet.selections ?? []).sorted { $0.sortIndex < $1.sortIndex }
                .map { "\($0.ticketTypeName),\($0.selection),\($0.unitPrice),\($0.combinationCount)" }
            return "\(bet.sortIndex),\(bet.purchaseAmount),\(bet.payoutAmount),\(selections)"
        }
        let restored = try importContainer.mainContext.fetch(FetchDescriptor<Bet>())
        #expect(restored.map(key).sorted() == bets.map(key).sorted())
        #expect(try importContainer.mainContext.fetchCount(FetchDescriptor<BetSelection>()) == bets.count)
    }

    @Test func `16 KiB を超えるメモを書き出して取り込むと元のメモに戻る`() throws {
        let line = "1コーナーで外に膨れた。次走は内枠なら買い。\n"
        let memo = String(repeating: line, count: Self.chunkSize / line.utf8.count + 50)
        try #require(memo.utf8.count > Self.chunkSize)
        let (url, _) = try exportRace(memo: memo)
        defer { try? FileManager.default.removeItem(at: url) }

        let importContainer = try Self.makeContainer()
        try ZipImporter.importZip(from: url, context: importContainer.mainContext)
        let restored = try importContainer.mainContext.fetch(FetchDescriptor<Race>())
        #expect(restored.map(\.memo) == [memo])
    }
}
