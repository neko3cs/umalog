//
//  ZipDateTests.swift
//  umalog
//
//  Created by neko3cs on 2026/11/06.
//

import Foundation
import SwiftData
import Testing
@testable import umalog
import ZIPFoundation

/// CSV・ZIP バックアップの日付が、端末の暦法によらず西暦で読み書きされることを確かめる。
/// - Note: ユニットテストはシミュレーターの暦法（西暦）で動き、アプリの中から暦法を切り替えられない。
///   和暦・仏暦の端末での書き出しと取り込みは、UI テストの `暦法の違うZIP往復Test` が `-AppleLocale` を変えて確かめる。
///   和暦の端末でのメモの紐付けと、元号の年（`0008` など）で書かれた既存バックアップの取り込みは、
///   フォーマッターが端末の暦法を読まないこと（`FileDate` の設定）と、同じ入力を西暦の端末で確かめることの 2 つで担保する。
@MainActor
struct ZIPの日付Test {
    let container: ModelContainer

    init() throws {
        let schema = Schema([Race.self, Bet.self, BetSelection.self, RaceEntry.self, Venue.self, TicketType.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    /// 期待する開催日を組み立てる・読み出すためのグレゴリオ暦。
    private static let gregorian = Calendar(identifier: .gregorian)

    /// 指定した races.csv の日付とメモファイルを持つ ZIP を一時ディレクトリに作り、取り込む。
    /// - Parameters:
    ///   - date: races.csv の date 列の値。
    ///   - memoFilename: `memo/` 以下に置くメモのファイル名。nil ならメモを置かない。
    /// - Returns: 取り込んだレース。
    private func importZip(date: String, memoFilename: String? = nil) throws -> Race {
        try importZip(raceRows: "\(date),東京,11,天皇賞,2000,芝,良,中央", memoFilename: memoFilename)
        return try #require(try container.mainContext.fetch(FetchDescriptor<Race>()).first)
    }

    /// races.csv のデータ行を指定した ZIP を一時ディレクトリに作り、取り込む。
    /// - Parameters:
    ///   - raceRows: races.csv のヘッダーより後ろの内容。
    ///   - memoFilename: `memo/` 以下に置くメモのファイル名。nil ならメモを置かない。
    private func importZip(raceRows: String, memoFilename: String? = nil) throws {
        let zipURL = FileManager.default.temporaryDirectory.appendingPathComponent("zip_date_\(UUID()).zip")
        defer { try? FileManager.default.removeItem(at: zipURL) }
        let archive = try Archive(url: zipURL, accessMode: .create)
        var files = [
            ("races.csv", """
            date,venue,race_number,race_name,distance,track_type,track_condition,category
            \(raceRows)
            """),
            ("entries.csv", "date,venue,race_number,horse_number,horse_name,jockey_name,trainer_name,prediction_mark"),
            ("bets.csv", "date,venue,race_number,bet_sort_index,purchase_amount,payout_amount,balance"),
        ]
        if let memoFilename {
            files.append(("memo/\(memoFilename)", "メモ"))
        }
        for (path, content) in files {
            let data = Data(content.utf8)
            try archive.addEntry(
                with: path, type: .file, uncompressedSize: Int64(data.count),
            ) { _, size in data.subdata(in: 0 ..< size) }
        }
        try ZipImporter.importZip(from: zipURL, context: container.mainContext)
    }

    // MARK: - 書き出し

    @Test(arguments: [
        ("令和の日付", DateComponents(year: 2026, month: 10, day: 31), "2026/10/31", "20261031"),
        ("平成最後の日", DateComponents(year: 2019, month: 4, day: 30), "2019/04/30", "20190430"),
    ])
    func `書き出す日付の列とメモファイル名は西暦になる`(
        era: String, raceDate: DateComponents, dateColumn: String, filenameDate: String,
    ) throws {
        let date = try #require(Self.gregorian.date(from: raceDate))
        #expect(CSVExporter.formatDate(date) == dateColumn, "\(era)")
        #expect(CSVExporter.formatFilenameDate(date) == filenameDate, "\(era)")
    }

    // MARK: - 取り込み

    @Test(arguments: [
        ("西暦の年", "2026/10/31", DateComponents(year: 2026, month: 10, day: 31)),
        ("元号の年で書かれた 4 桁未満の年", "0008/10/31", DateComponents(year: 8, month: 10, day: 31)),
    ])
    func `取り込んだ日付の列はファイルの通り西暦として読まれる`(
        year: String, dateColumn: String, raceDate: DateComponents,
    ) throws {
        let race = try importZip(date: dateColumn)
        #expect(Self.gregorian.dateComponents([.year, .month, .day], from: race.date) == raceDate, "\(year)")
    }

    // MARK: - メモの紐付け

    @Test(arguments: [
        ("現行形式のファイル名", "2026/10/31", "20261031_東京_R11_天皇賞.md"),
        ("旧形式のファイル名", "2026/10/31", "20261031_天皇賞.md"),
        ("元号の年で書かれた日付とファイル名", "0008/10/31", "00081031_東京_R11_天皇賞.md"),
    ])
    func `取り込んだレースに同じ日付のメモファイルが付く`(
        filenameKind: String, dateColumn: String, memoFilename: String,
    ) throws {
        let race = try importZip(date: dateColumn, memoFilename: memoFilename)
        #expect(race.memo == "メモ", "\(filenameKind)")
    }

    // MARK: - 端末の暦法を読まないこと

    @Test func `ファイルの日付のフォーマッターは端末の設定によらずグレゴリオ暦と en_US_POSIX を使う`() {
        for formatter in [FileDate.slashed, FileDate.compact, FileDate.hyphenated] {
            #expect(formatter.calendar.identifier == .gregorian, "\(formatter.dateFormat ?? "")")
            #expect(formatter.locale.identifier == "en_US_POSIX", "\(formatter.dateFormat ?? "")")
        }
    }

    // MARK: - 読めない日付

    @Test(arguments: [
        ("2026-10-31,東京,11,天皇賞,2000,芝,良,中央", ZipImportError.invalidDate(line: 2, value: "2026-10-31")),
        ("2026/1/5,東京,11,天皇賞,2000,芝,良,中央", ZipImportError.invalidDate(line: 2, value: "2026/1/5")),
        ("2026/10/31,東京,11,天皇賞,2000,芝,良,中央\n2026/11/01,東京,11", ZipImportError.missingColumns(line: 3)),
    ])
    func 取り込めない行があれば既存のレースを消さずに中止する(raceRows: String, error: ZipImportError) throws {
        container.mainContext.insert(Race(raceNumber: 1, raceName: "既存レース"))
        try container.mainContext.save()

        #expect(throws: error) {
            try importZip(raceRows: raceRows)
        }
        let races = try container.mainContext.fetch(FetchDescriptor<Race>())
        #expect(races.map(\.raceName) == ["既存レース"])
    }

    @Test func `races.csv の空行は飛ばして取り込む`() throws {
        try importZip(raceRows: "2026/10/31,東京,11,天皇賞,2000,芝,良,中央\n\n")
        let races = try container.mainContext.fetch(FetchDescriptor<Race>())
        #expect(races.map(\.raceName) == ["天皇賞"])
    }
}
