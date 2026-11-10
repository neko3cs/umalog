//
//  ZipImporter.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import Foundation
import SwiftData
import ZIPFoundation

/// ZIP バックアップを取り込めないときのエラー。
enum ZipImportError: LocalizedError, Equatable {
    /// races.csv の date 列が `yyyy/MM/dd` として読めない。
    /// - Parameters:
    ///   - line: races.csv の行番号（ヘッダーが 1 行目）。
    ///   - value: 読めなかった値。
    case invalidDate(line: Int, value: String)
    /// races.csv の行の列が、必須の 8 列（date〜category）に足りない。
    /// - Parameter line: races.csv の行番号（ヘッダーが 1 行目）。
    case missingColumns(line: Int)
    /// CSV が UTF-8 として読めない（UTF-8 以外の文字コードで保存された、中身が壊れている など）。
    /// - Parameter path: 読めなかったファイルのアーカイブ内のパス。
    case unreadableText(path: String)

    /// 利用者に示す説明。
    var errorDescription: String? {
        switch self {
        case let .invalidDate(line, value):
            "races.csv の \(line) 行目の日付「\(value)」を読めません（yyyy/MM/dd で書いてください）。データは変更していません。"
        case let .missingColumns(line):
            "races.csv の \(line) 行目の列が足りません（date から category までの 8 列が必要です）。データは変更していません。"
        case let .unreadableText(path):
            // 中身が壊れている場合は保存し直しても直らないので、「UTF-8 で保存し直して」とは書かない
            "\(path) を読めません（文字コードが UTF-8 でないか、ファイルが壊れています）。データは変更していません。"
        }
    }
}

/// ZIP バックアップから読み込み、検証まで済ませた内容。既存データを消す前に、取り込むファイルをすべてここへ読む。
struct ZipBackupContents {
    /// ヘッダー行を含む races.csv の行。`ZipImporter.validateRaceRows` で確かめてある。
    let raceRows: [[String]]
    /// entries.csv の内容。
    let entriesText: String
    /// bets.csv の内容。
    let betsText: String
    /// bet_selections.csv の内容。nil なら旧フォーマット（bets.csv に券種・買い目を直接持つ形式）。
    let betSelectionsText: String?
    /// メモファイルのベース名（`memo/` と `.md` を除いたもの）→ メモ。読めないファイル・空のファイルは含まない。
    let memos: [String: String]
}

/// ZIP バックアップからレースデータを復元するユーティリティ。旧フォーマットのバックアップにも対応する。
/// - Note: 読み込み・検証の段階（`readBackup`）と削除・復元の段階（`restore`）を分け、削除のあとでファイルを読まない。
///   読めないファイルに気づいた時点で既存データが消えていると、何も復元できないため。
enum ZipImporter {
    /// ZIP バックアップを読み込み、既存のレースデータをすべて置き換えて復元する。競馬場・券種マスターは保持する。
    /// - Parameters:
    ///   - url: 読み込む ZIP ファイルの URL。
    ///   - context: 復元先の ModelContext。
    ///   - undoManager: 成功したら履歴を消す UndoManager。取り込みは記録をすべて置き換えるので、
    ///     古い削除を取り消すと、置き換えたデータに取り込み前の記録が混ざるため。
    /// - Throws: 取り込めないときのエラー。どの段階で失敗しても、既存のデータは取り込み前のまま残る。
    static func importZip(from url: URL, context: ModelContext, undoManager: UndoManager? = nil) throws {
        let contents = try readBackup(from: url)
        try restore(contents, context: context)
        undoManager?.removeAllActions()
    }

    /// ZIP バックアップの取り込むファイルをすべて読み、races.csv の行を検証する。ModelContext には触れない。
    /// - Parameter url: 読み込む ZIP ファイルの URL。
    /// - Returns: 読み込んだ内容。
    /// - Throws: 必須の CSV が無い・展開できない・UTF-8 として読めない、races.csv に取り込めない行がある、のいずれか。
    private static func readBackup(from url: URL) throws -> ZipBackupContents {
        let archive = try Archive(url: url, accessMode: .read)
        let raceRows = try parseCSV(readEntry(archive, path: "races.csv"))
        try validateRaceRows(raceRows)
        return try ZipBackupContents(
            raceRows: raceRows,
            entriesText: readEntry(archive, path: "entries.csv"),
            betsText: readEntry(archive, path: "bets.csv"),
            betSelectionsText: archive["bet_selections.csv"] == nil
                ? nil : readEntry(archive, path: "bet_selections.csv"),
            memos: readMemos(from: archive),
        )
    }

    /// 読み込んだ内容で、既存のレースデータをすべて置き換える。
    /// - Parameters:
    ///   - contents: `readBackup` で読み込んだ内容。
    ///   - context: 復元先の ModelContext。
    private static func restore(_ contents: ZipBackupContents, context: ModelContext) throws {
        let venues = try context.fetch(FetchDescriptor<Venue>())
        let ticketTypes = try context.fetch(FetchDescriptor<TicketType>())
        try replaceAllRaceData(in: context) {
            let (raceMap, memoNameMap) = importRaces(contents.raceRows, venues: venues, context: context)
            importEntries(contents.entriesText, raceMap: raceMap, context: context)
            if let betSelectionsText = contents.betSelectionsText {
                importBetsNewFormat(
                    betsText: contents.betsText, betSelectionsText: betSelectionsText,
                    raceMap: raceMap, ticketTypes: ticketTypes, context: context,
                )
            } else {
                importBetsLegacyFormat(
                    betsText: contents.betsText, raceMap: raceMap, ticketTypes: ticketTypes, context: context,
                )
            }
            for (name, memo) in contents.memos {
                memoNameMap[name]?.memo = memo
            }
        }
    }

    /// 既存のレースデータを消して `insertRecords` で作り直し、保存する。途中で失敗したら既存のデータに戻す。
    /// - Parameters:
    ///   - context: 対象の ModelContext。
    ///   - insertRecords: 消したあとに記録を挿入する処理。
    /// - Throws: 保存待ちの変更の保存、削除、`insertRecords`、最後の保存のいずれかのエラー。
    /// - Note: 消す直前に保存待ちの変更（自動保存前のスワイプ削除や編集）を保存しておく。
    ///   そうしないと、失敗時の `rollback()` が取り込みと関係ない変更まで戻し、削除の Undo とも食い違う
    ///   （戻ったレースを Undo でもう一度復元すると 2 件になる）。
    static func replaceAllRaceData(in context: ModelContext, insertRecords: () throws -> Void) throws {
        try context.save()
        do {
            try deleteAllRaceData(in: context)
            try insertRecords()
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    /// 既存のレース・出走馬・馬券・買い目をすべて削除する。競馬場・券種マスターは残す。
    /// - Parameter context: 削除対象の ModelContext。
    private static func deleteAllRaceData(in context: ModelContext) throws {
        try context.fetch(FetchDescriptor<BetSelection>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<Bet>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<RaceEntry>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<Race>()).forEach { context.delete($0) }
    }

    /// races.csv の行がすべて取り込めるか確かめる。既存データを消してから行を飛ばすと記録が欠けるので、消す前に呼ぶ。
    /// - Parameter raceRows: ヘッダー行を含む races.csv の行。空行は飛ばす。
    /// - Throws: 列が足りない行があれば `ZipImportError.missingColumns`、読めない日付があれば `ZipImportError.invalidDate`。
    ///   どちらも最初の 1 件を示す。
    private static func validateRaceRows(_ raceRows: [[String]]) throws {
        for (idx, row) in raceRows.enumerated().dropFirst() where row != [""] {
            guard row.count >= 8 else { throw ZipImportError.missingColumns(line: idx + 1) }
            guard parseDate(row[0]) != nil else { throw ZipImportError.invalidDate(line: idx + 1, value: row[0]) }
        }
    }

    /// races.csv からレースを復元する。グレード・着順の列が無い旧フォーマットにも対応する。
    /// - Parameters:
    ///   - raceRows: ヘッダー行を含む races.csv の行。`validateRaceRows` で確かめておく。
    ///   - venues: 復元先の競馬場マスター。CSV の競馬場名と同名の競馬場に紐付ける。
    ///   - context: 復元先の ModelContext。
    /// - Returns: レースキー → レースのマップと、メモファイルのベース名（現行・旧形式の両方）→ レースのマップ。
    private static func importRaces(
        _ raceRows: [[String]],
        venues: [Venue],
        context: ModelContext,
    ) -> (raceMap: [String: Race], memoNameMap: [String: Race]) {
        var raceMap: [String: Race] = [:]
        // レースの venue が DB に存在しない場合でもメモを復元できるよう、ベース名は CSV 行の競馬場名から組み立てる
        var memoNameMap: [String: Race] = [:]
        let raceHeader = raceRows.first ?? []
        let hasFinishPlaces = raceHeader.contains("first_place_horse")
        let hasGrade = raceHeader.contains("grade")
        for (idx, row) in raceRows.dropFirst().enumerated() {
            guard row.count >= 8, let date = parseDate(row[0]) else { continue }
            let grade = hasGrade && row.count > 8 ? row[8] : ""
            let placeOffset = hasGrade ? 9 : 8
            let firstPlace = hasFinishPlaces && row.count > placeOffset ? Int(row[placeOffset]) ?? 0 : 0
            let secondPlace = hasFinishPlaces && row.count > placeOffset + 1 ? Int(row[placeOffset + 1]) ?? 0 : 0
            let thirdPlace = hasFinishPlaces && row.count > placeOffset + 2 ? Int(row[placeOffset + 2]) ?? 0 : 0
            let race = Race(
                date: date,
                venue: venues.first { $0.name == row[1] },
                raceNumber: Int(row[2]) ?? 1,
                raceName: row[3],
                distance: Int(row[4]) ?? 1600,
                trackType: (TrackType.allCases.first { $0.displayName == row[5] } ?? .dirt).rawValue,
                trackCondition: row[6],
                category: (RaceCategory.allCases.first { $0.shortName == row[7] } ?? .local).rawValue,
                grade: grade,
                firstPlaceHorseNumber: firstPlace,
                secondPlaceHorseNumber: secondPlace,
                thirdPlaceHorseNumber: thirdPlace,
                sortIndex: idx,
            )
            context.insert(race)
            raceMap[key(date: row[0], venue: row[1], raceNumber: row[2])] = race
            let memoNames = [
                ZipExporter.memoBaseName(
                    date: race.date, venueName: row[1],
                    raceNumber: race.raceNumber, raceName: race.raceName,
                ),
                ZipExporter.legacyMemoBaseName(
                    date: race.date, raceNumber: race.raceNumber, raceName: race.raceName,
                ),
            ]
            for name in memoNames where memoNameMap[name] == nil {
                memoNameMap[name] = race
            }
        }
        return (raceMap, memoNameMap)
    }

    /// entries.csv から出走馬を復元する。対応するレースが無い行は読み飛ばす。
    /// - Parameters:
    ///   - entriesText: entries.csv の内容。
    ///   - raceMap: レースキー → レースのマップ。
    ///   - context: 復元先の ModelContext。
    private static func importEntries(_ entriesText: String, raceMap: [String: Race], context: ModelContext) {
        for (idx, row) in parseCSV(entriesText).dropFirst().enumerated() {
            guard row.count >= 5,
                  let race = raceMap[key(date: row[0], venue: row[1], raceNumber: row[2])] else { continue }
            context.insert(RaceEntry(
                race: race,
                horseNumber: Int(row[3]) ?? 0,
                horseName: row[4],
                jockeyName: row.count > 5 ? row[5] : "",
                trainerName: row.count > 6 ? row[6] : "",
                predictionMark: row.count > 7 && !row[7].isEmpty ? row[7] : nil,
                sortIndex: idx,
            ))
        }
    }

    /// memo/ 以下の Markdown ファイルを読む。メモは任意なので、読めないファイル・空のファイルは飛ばし、取り込みを止めない。
    /// - Parameter archive: 読み込み中のアーカイブ。
    /// - Returns: メモファイルのベース名（`memo/` と `.md` を除いたもの）→ メモ。
    private static func readMemos(from archive: Archive) -> [String: String] {
        var memos: [String: String] = [:]
        for entry in archive where entry.path.hasPrefix("memo/") && entry.path.hasSuffix(".md") {
            var data = Data()
            _ = try? archive.extract(entry) { data.append($0) }
            guard let memo = String(data: data, encoding: .utf8), !memo.isEmpty else { continue }
            memos[String(entry.path.dropFirst("memo/".count).dropLast(".md".count))] = memo
        }
        return memos
    }

    /// 現行フォーマット（bets.csv + bet_selections.csv）の馬券・買い目を復元する。
    /// - Parameters:
    ///   - betsText: bets.csv の内容。
    ///   - betSelectionsText: bet_selections.csv の内容。
    ///   - raceMap: レースキー → レースのマップ。
    ///   - ticketTypes: 復元先の券種マスター。買い目の券種名と同名の券種に紐付ける。
    ///   - context: 復元先の ModelContext。
    private static func importBetsNewFormat(
        betsText: String,
        betSelectionsText: String,
        raceMap: [String: Race],
        ticketTypes: [TicketType],
        context: ModelContext,
    ) {
        var betMap: [String: Bet] = [:]
        for (idx, row) in parseCSV(betsText).dropFirst().enumerated() {
            guard row.count >= 5,
                  let race = raceMap[key(date: row[0], venue: row[1], raceNumber: row[2])] else { continue }
            let betSortIndex = Int(row[3]) ?? idx
            let purchaseAmount = Int(row[4]) ?? 0
            let payoutAmount = row.count > 5 ? Int(row[5]) ?? 0 : 0
            let newBet = Bet(
                race: race, purchaseAmount: purchaseAmount,
                payoutAmount: payoutAmount, sortIndex: betSortIndex,
            )
            context.insert(newBet)
            betMap[betKey(date: row[0], venue: row[1], raceNumber: row[2], betSortIndex: row[3])] = newBet
        }
        for (selIdx, row) in parseCSV(betSelectionsText).dropFirst().enumerated() {
            guard row.count >= 7,
                  let bet = betMap[betKey(
                      date: row[0], venue: row[1], raceNumber: row[2], betSortIndex: row[3],
                  )] else { continue }
            let count = row.count > 7 ? Int(row[7]) ?? 1 : 1
            let sortIndex = row.count > 8 ? Int(row[8]) ?? selIdx : selIdx
            context.insert(BetSelection(
                bet: bet,
                ticketType: ticketTypes.first { $0.name == row[4] },
                ticketTypeName: row[4],
                selection: row[5],
                unitPrice: Int(row[6]) ?? 100,
                combinationCount: count,
                sortIndex: sortIndex,
            ))
        }
    }

    /// 旧フォーマット（bets.csv に券種・買い目を直接持つ形式）の馬券を復元し、対応する買い目も生成する。
    /// - Parameters:
    ///   - betsText: bets.csv の内容。
    ///   - raceMap: レースキー → レースのマップ。
    ///   - ticketTypes: 復元先の券種マスター。買い目の券種名と同名の券種に紐付ける。
    ///   - context: 復元先の ModelContext。
    private static func importBetsLegacyFormat(
        betsText: String,
        raceMap: [String: Race],
        ticketTypes: [TicketType],
        context: ModelContext,
    ) {
        let betRows = parseCSV(betsText)
        let betHeader = betRows.first ?? []
        let hasUnitPrice = betHeader.contains("unit_price")
        for (idx, row) in betRows.dropFirst().enumerated() {
            guard row.count >= 6,
                  let race = raceMap[key(date: row[0], venue: row[1], raceNumber: row[2])] else { continue }
            let ticketTypeName = row[3]
            let selection = row[4]
            let combinationCount = Bet.combinationCount(selection: selection, ticketTypeName: ticketTypeName)
            let unitPrice: Int
            let purchaseAmount: Int
            let payoutAmount: Int
            if hasUnitPrice {
                unitPrice = Int(row[5]) ?? 100
                purchaseAmount = row.count > 7 ? Int(row[7]) ?? 0 : 0
                payoutAmount = row.count > 8 ? Int(row[8]) ?? 0 : 0
            } else {
                purchaseAmount = Int(row[5]) ?? 0
                payoutAmount = row.count > 6 ? Int(row[6]) ?? 0 : 0
                unitPrice = combinationCount > 0 ? purchaseAmount / combinationCount : 100
            }
            let newBet = Bet(
                race: race, ticketTypeName: ticketTypeName, selection: selection,
                unitPrice: unitPrice, purchaseAmount: purchaseAmount,
                payoutAmount: payoutAmount, sortIndex: idx,
            )
            context.insert(newBet)
            context.insert(BetSelection(
                bet: newBet,
                ticketType: ticketTypes.first { $0.name == ticketTypeName },
                ticketTypeName: ticketTypeName,
                selection: selection,
                unitPrice: unitPrice,
                combinationCount: max(1, combinationCount),
                sortIndex: 0,
            ))
        }
    }

    /// レースを一意に識別するキー（日付|競馬場|レース番号）を組み立てる。
    /// - Parameters:
    ///   - date: CSV の date 列の値。
    ///   - venue: CSV の venue 列の値。
    ///   - raceNumber: CSV の race_number 列の値。
    /// - Returns: レースキー文字列。
    private static func key(date: String, venue: String, raceNumber: String) -> String {
        "\(date)|\(venue)|\(raceNumber)"
    }

    /// 馬券を一意に識別するキー（レースキー|馬券ソート順）を組み立てる。
    /// - Parameters:
    ///   - date: CSV の date 列の値。
    ///   - venue: CSV の venue 列の値。
    ///   - raceNumber: CSV の race_number 列の値。
    ///   - betSortIndex: CSV の bet_sort_index 列の値。
    /// - Returns: 馬券キー文字列。
    private static func betKey(date: String, venue: String, raceNumber: String, betSortIndex: String) -> String {
        "\(key(date: date, venue: venue, raceNumber: raceNumber))|\(betSortIndex)"
    }

    /// アーカイブ内の指定パスのエントリを UTF-8 テキストとして読み出す。
    /// - Parameters:
    ///   - archive: 読み込み対象のアーカイブ。
    ///   - path: アーカイブ内のパス。
    /// - Returns: エントリの内容。
    /// - Throws: 存在しなければ `CocoaError(.fileNoSuchFile)`、展開できなければ ZIPFoundation のエラー、
    ///   中身が CRC と合わなければ `Archive.ArchiveError.invalidCRC32`、
    ///   UTF-8 として読めなければ `ZipImportError.unreadableText`。
    private static func readEntry(_ archive: Archive, path: String) throws -> String {
        guard let entry = archive[path] else { throw CocoaError(.fileNoSuchFile) }
        var data = Data()
        // extract(_:consumer:) は CRC を計算して返すだけで照合しない。書き出しは無圧縮なので、
        // 照合しないと、UTF-8 として読めるまま壊れた中身を黙って取り込んでしまう
        let checksum = try archive.extract(entry) { data.append($0) }
        guard checksum == entry.checksum else { throw Archive.ArchiveError.invalidCRC32 }
        guard let text = String(data: data, encoding: .utf8) else { throw ZipImportError.unreadableText(path: path) }
        return text
    }

    /// CSV の date 列の値（`yyyy/MM/dd`）を Date に変換する。
    /// - Parameter string: 変換対象の文字列。
    /// - Returns: 変換結果。形式が不正な場合は nil。
    private static func parseDate(_ string: String) -> Date? {
        let date = FileDate.slashed.date(from: string)
        // isLenient = false でも "2026-10-31" や "2026/1/5" を受け付けるため、書き戻して一致を確かめる
        return date.map(FileDate.slashed.string(from:)) == string ? date : nil
    }

    /// CSV テキストを行×列の二次元配列にパースする。クォート・エスケープ・CRLF に対応する。
    /// - Parameter text: パース対象の CSV テキスト。
    /// - Returns: 行ごとのフィールド配列。
    private static func parseCSV(_ text: String) -> [[String]] {
        var result: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        let chars = Array(text)
        var idx = 0
        while idx < chars.count {
            let char = chars[idx]
            if inQuotes {
                if char == "\"" {
                    if idx + 1 < chars.count, chars[idx + 1] == "\"" {
                        field.append("\""); idx += 2; continue
                    }
                    inQuotes = false
                } else {
                    field.append(char)
                }
            } else {
                switch char {
                case "\"": inQuotes = true
                case ",": row.append(field); field = ""
                case "\r":
                    if idx + 1 < chars.count, chars[idx + 1] == "\n" {
                        idx += 1
                    }
                    fallthrough
                case "\n":
                    row.append(field); field = ""
                    result.append(row)
                    row = []
                default: field.append(char)
                }
            }
            idx += 1
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field); result.append(row)
        }
        return result
    }
}
