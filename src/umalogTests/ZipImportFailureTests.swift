//
//  ZipImportFailureTests.swift
//  umalog
//
//  Created by neko3cs on 2026/11/10.
//

import Foundation
import SwiftData
import Testing
@testable import umalog
import ZIPFoundation

/// ZIP バックアップの取り込みに失敗したとき、既存のデータが取り込み前のまま残ることを確かめる。
/// - Note: 「既存のデータが残る」は、レース・出走馬・馬券・買い目が取り込み前と同じで、
///   `ModelContext` に未保存の削除も残っていない（あとの自動保存で消えない）ことを指す。
@MainActor
struct ZIP取り込みの失敗Test {
    let container: ModelContainer

    init() throws {
        let schema = Schema([Race.self, Bet.self, BetSelection.self, RaceEntry.self, Venue.self, TicketType.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    /// 現行形式の ZIP の各ファイルの内容（UTF-8）。テストごとに一部を差し替えて使う。
    private static let validFiles: [String: String] = [
        "races.csv": """
        date,venue,race_number,race_name,distance,track_type,track_condition,category
        2026/11/10,東京,11,取り込むレース,2000,芝,良,中央
        """,
        "entries.csv": """
        date,venue,race_number,horse_number,horse_name,jockey_name,trainer_name,prediction_mark
        2026/11/10,東京,11,1,取り込む馬,騎手,調教師,
        """,
        "bets.csv": """
        date,venue,race_number,bet_sort_index,purchase_amount,payout_amount,balance
        2026/11/10,東京,11,0,100,0,-100
        """,
        "bet_selections.csv": """
        date,venue,race_number,bet_sort_index,ticket_type,selection,unit_price,combination_count,sort_index
        2026/11/10,東京,11,0,単勝,1,100,1,0
        """,
    ]

    /// 取り込み前に登録・保存しておくレース・出走馬・馬券・買い目を作る。
    private func insertExistingRace() throws {
        let context = container.mainContext
        let race = Race(raceNumber: 1, raceName: "既存レース")
        context.insert(race)
        context.insert(RaceEntry(race: race, horseNumber: 3, horseName: "既存の馬"))
        let bet = Bet(race: race, purchaseAmount: 300, payoutAmount: 0, sortIndex: 0)
        context.insert(bet)
        context.insert(BetSelection(
            bet: bet, ticketTypeName: "複勝", selection: "3", unitPrice: 300, combinationCount: 1, sortIndex: 0,
        ))
        try context.save()
    }

    /// 既存のデータが取り込み前のまま残り、未保存の変更も無いことを確かめる。
    /// - Parameter label: 失敗したときに示す、テストケースの説明。
    private func expectExistingDataRemains(_ label: String = "") throws {
        let context = container.mainContext
        #expect(try context.fetch(FetchDescriptor<Race>()).map(\.raceName) == ["既存レース"], "\(label)")
        #expect(try context.fetch(FetchDescriptor<RaceEntry>()).map(\.horseName) == ["既存の馬"], "\(label)")
        #expect(try context.fetch(FetchDescriptor<Bet>()).map(\.purchaseAmount) == [300], "\(label)")
        #expect(try context.fetch(FetchDescriptor<BetSelection>()).map(\.selection) == ["3"], "\(label)")
        #expect(!context.hasChanges, "未保存の変更が残っている \(label)")
    }

    /// 指定したファイルを持つ ZIP を一時ディレクトリに作る。
    /// - Parameters:
    ///   - files: アーカイブ内のパス → 中身のバイト列。
    ///   - deflating: deflate で圧縮するファイルのパス。ほかは圧縮しない（アプリの書き出しと同じ）。
    /// - Returns: 作った ZIP の URL。
    private func makeZip(_ files: [String: Data], deflating: Set<String> = []) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("zip_failure_\(UUID()).zip")
        let archive = try Archive(url: url, accessMode: .create)
        for (path, data) in files.sorted(by: { $0.key < $1.key }) {
            try archive.addEntry(
                with: path, type: .file, uncompressedSize: Int64(data.count),
                compressionMethod: deflating.contains(path) ? .deflate : .none,
            ) { position, size in data.subdata(in: Int(position) ..< Int(position) + size) }
        }
        return url
    }

    /// 現行形式の ZIP の、指定したファイルだけを差し替えた中身を返す。
    /// - Parameter replacements: アーカイブ内のパス → 差し替える中身。nil ならそのファイルを入れない。
    /// - Returns: アーカイブ内のパス → 中身のバイト列。
    private func files(replacing replacements: [String: Data?] = [:]) -> [String: Data] {
        var files = Self.validFiles.mapValues { Data($0.utf8) }
        for (path, data) in replacements {
            files[path] = data
        }
        return files
    }

    /// 日本語を含むテキストを Shift_JIS で符号化する。UTF-8 として読めないことも確かめる。
    /// - Parameter text: 符号化するテキスト。
    /// - Returns: Shift_JIS のバイト列。
    private func shiftJIS(_ text: String) throws -> Data {
        let data = try #require(text.data(using: .shiftJIS))
        try #require(String(data: data, encoding: .utf8) == nil, "Shift_JIS のバイト列が UTF-8 として読めてしまう")
        return data
    }

    // MARK: - UTF-8 として読めない CSV

    @Test(arguments: ["races.csv", "entries.csv", "bets.csv", "bet_selections.csv"])
    func `UTF-8 として読めない CSV があればファイル名を示すエラーにして既存のデータを残す`(path: String) throws {
        try insertExistingRace()
        let url = try makeZip(files(replacing: [path: shiftJIS(Self.validFiles[path] ?? "")]))
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(throws: ZipImportError.unreadableText(path: path), "\(path)") {
            try ZipImporter.importZip(from: url, context: container.mainContext)
        }
        try expectExistingDataRemains(path)
    }

    @Test func `UTF-8 として読めない CSV のエラー文はファイル名と原因の候補と何も変えていないことを示す`() {
        #expect(
            ZipImportError.unreadableText(path: "races.csv").errorDescription
                == "races.csv を読めません（文字コードが UTF-8 でないか、ファイルが壊れています）。データは変更していません。",
        )
    }

    // MARK: - 展開できない bet_selections.csv

    @Test func `bet_selections.csv の中身が壊れていて展開できなければエラーにして既存のデータを残す`() throws {
        try insertExistingRace()
        let path = "bet_selections.csv"
        let url = try makeZip(files(), deflating: [path])
        defer { try? FileManager.default.removeItem(at: url) }
        // ローカルファイルヘッダー（30 バイト + ファイル名 + 拡張フィールド）の直後が圧縮データ。
        // ファイル名はローカルファイルヘッダーで初めて現れ、その 30 バイト前がヘッダーの先頭
        var zipData = try Data(contentsOf: url)
        let nameRange = try #require(zipData.range(of: Data(path.utf8)))
        let headerStart = nameRange.lowerBound - 30
        let extraLength = Int(zipData[headerStart + 28]) | Int(zipData[headerStart + 29]) << 8
        let dataStart = nameRange.upperBound + extraLength
        // deflate の最初のブロックの種類（2〜3 ビット目）を、使われていない 11 にして展開を失敗させる
        zipData[dataStart] |= 0b0000_0110
        try zipData.write(to: url)

        #expect(throws: (any Error).self) {
            try ZipImporter.importZip(from: url, context: container.mainContext)
        }
        try expectExistingDataRemains()
    }

    // MARK: - 取り込めるもの

    @Test func `bet_selections.csv が無い旧形式の bets.csv は旧形式として取り込む`() throws {
        try insertExistingRace()
        let legacyBets = """
        date,venue,race_number,ticket_type,selection,unit_price,combination_count,purchase_amount,payout_amount,balance
        2026/11/10,東京,11,馬連,1-2,100,1,100,500,400
        """
        let url = try makeZip(files(replacing: ["bets.csv": Data(legacyBets.utf8), "bet_selections.csv": nil]))
        defer { try? FileManager.default.removeItem(at: url) }

        try ZipImporter.importZip(from: url, context: container.mainContext)

        let context = container.mainContext
        #expect(try context.fetch(FetchDescriptor<Race>()).map(\.raceName) == ["取り込むレース"])
        #expect(try context.fetch(FetchDescriptor<Bet>()).map(\.payoutAmount) == [500])
        #expect(try context.fetch(FetchDescriptor<BetSelection>()).map(\.selection) == ["1-2"])
    }

    @Test func `現行形式の ZIP は既存のデータを置き換えて取り込む`() throws {
        try insertExistingRace()
        let url = try makeZip(files())
        defer { try? FileManager.default.removeItem(at: url) }

        try ZipImporter.importZip(from: url, context: container.mainContext)

        let context = container.mainContext
        #expect(try context.fetch(FetchDescriptor<Race>()).map(\.raceName) == ["取り込むレース"])
        #expect(try context.fetch(FetchDescriptor<RaceEntry>()).map(\.horseName) == ["取り込む馬"])
        #expect(try context.fetch(FetchDescriptor<BetSelection>()).map(\.ticketTypeName) == ["単勝"])
        #expect(!context.hasChanges)
    }

    @Test func `UTF-8 として読めないメモはそのメモだけを飛ばしてほかを取り込む`() throws {
        try insertExistingRace()
        let url = try makeZip(files(replacing: [
            "memo/20261110_東京_R11_取り込むレース.md": shiftJIS("読めないメモ"),
        ]))
        defer { try? FileManager.default.removeItem(at: url) }

        try ZipImporter.importZip(from: url, context: container.mainContext)

        let races = try container.mainContext.fetch(FetchDescriptor<Race>())
        #expect(races.map(\.raceName) == ["取り込むレース"])
        #expect(races.map(\.memo) == [""])
    }
}

// MARK: - 既存データを消したあとの失敗

extension ZIP取り込みの失敗Test {
    /// 置き換えの途中で失敗させるためのエラー。
    private struct RestoreFailure: Error {}

    @Test func `既存データを消したあとで失敗すると既存のデータを残す`() throws {
        try insertExistingRace()

        #expect(throws: RestoreFailure.self) {
            try ZipImporter.replaceAllRaceData(in: container.mainContext) {
                container.mainContext.insert(Race(raceNumber: 2, raceName: "途中まで復元したレース"))
                throw RestoreFailure()
            }
        }
        try expectExistingDataRemains()
    }

    @Test func `既存データを消したあとで失敗しても取り込みの前から保存待ちだった編集は残る`() throws {
        try insertExistingRace()
        let context = container.mainContext
        let race = try #require(try context.fetch(FetchDescriptor<Race>()).first)
        race.raceName = "保存待ちの編集"

        #expect(throws: RestoreFailure.self) {
            try ZipImporter.replaceAllRaceData(in: context) { throw RestoreFailure() }
        }
        #expect(try context.fetch(FetchDescriptor<Race>()).map(\.raceName) == ["保存待ちの編集"])
        #expect(!context.hasChanges)
    }

    @Test func `保存待ちのスワイプ削除があり取り込みが失敗したあとで削除を取り消すとレースが 1 件だけ戻る`() throws {
        let context = container.mainContext
        context.insert(Race(raceNumber: 1, raceName: "削除したレース"))
        try context.save()
        // レース一覧のスワイプ削除と同じく、スナップショットの復元を Undo に登録し、保存せずに削除する
        let undoManager = UndoManager()
        let race = try #require(try context.fetch(FetchDescriptor<Race>()).first)
        let snapshot = RaceSnapshot(from: race)
        undoManager.registerUndo(withTarget: context) { snapshot.restore(into: $0) }
        context.delete(race)

        #expect(throws: RestoreFailure.self) {
            try ZipImporter.replaceAllRaceData(in: context) { throw RestoreFailure() }
        }
        undoManager.undo()

        #expect(try context.fetch(FetchDescriptor<Race>()).map(\.raceName) == ["削除したレース"])
    }

    @Test func `取り込みに成功したら取り込み前の操作は取り消せない`() throws {
        let undoManager = UndoManager()
        undoManager.registerUndo(withTarget: container.mainContext) { _ in }
        try #require(undoManager.canUndo)
        let url = try makeZip(files())
        defer { try? FileManager.default.removeItem(at: url) }

        try ZipImporter.importZip(from: url, context: container.mainContext, undoManager: undoManager)

        #expect(!undoManager.canUndo)
    }

    @Test func `取り込みに失敗したら取り込み前の操作を取り消せる`() throws {
        let undoManager = UndoManager()
        undoManager.registerUndo(withTarget: container.mainContext) { _ in }
        let url = try makeZip(files(replacing: ["races.csv": shiftJIS(Self.validFiles["races.csv"] ?? "")]))
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(throws: (any Error).self) {
            try ZipImporter.importZip(from: url, context: container.mainContext, undoManager: undoManager)
        }
        #expect(undoManager.canUndo)
    }
}
