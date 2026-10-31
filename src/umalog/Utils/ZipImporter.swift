//
//  ZipImporter.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import Foundation
import SwiftData
import ZIPFoundation

/// ZIP バックアップからレースデータを復元するユーティリティ。旧フォーマットのバックアップにも対応する。
enum ZipImporter {
    /// ZIP バックアップを読み込み、既存のレースデータをすべて置き換えて復元する。競馬場・券種マスターは保持する。
    /// - Parameters:
    ///   - url: 読み込む ZIP ファイルの URL。
    ///   - context: 復元先の ModelContext。
    static func importZip(from url: URL, context: ModelContext) throws {
        let archive = try Archive(url: url, accessMode: .read)

        // 必須の CSV を先に読み、欠けていれば既存データを消す前に中止する
        let racesText = try readEntry(archive, path: "races.csv")
        let entriesText = try readEntry(archive, path: "entries.csv")
        let betsText = try readEntry(archive, path: "bets.csv")
        let hasBetSelections = archive["bet_selections.csv"] != nil

        try deleteAllRaceData(in: context)

        let venues = try context.fetch(FetchDescriptor<Venue>())
        let ticketTypes = try context.fetch(FetchDescriptor<TicketType>())

        let (raceMap, memoNameMap) = importRaces(racesText, venues: venues, context: context)
        importEntries(entriesText, raceMap: raceMap, context: context)
        if hasBetSelections {
            try importBetsNewFormat(
                archive: archive, betsText: betsText, raceMap: raceMap, ticketTypes: ticketTypes, context: context,
            )
        } else {
            importBetsLegacyFormat(betsText: betsText, raceMap: raceMap, ticketTypes: ticketTypes, context: context)
        }
        importMemos(from: archive, memoNameMap: memoNameMap)

        try context.save()
    }

    /// 既存のレース・出走馬・馬券・買い目をすべて削除する。競馬場・券種マスターは残す。
    /// - Parameter context: 削除対象の ModelContext。
    private static func deleteAllRaceData(in context: ModelContext) throws {
        try context.fetch(FetchDescriptor<BetSelection>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<Bet>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<RaceEntry>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<Race>()).forEach { context.delete($0) }
    }

    /// races.csv からレースを復元する。グレード・着順の列が無い旧フォーマットにも対応する。
    /// - Parameters:
    ///   - racesText: races.csv の内容。
    ///   - venues: 復元先の競馬場マスター。CSV の競馬場名と同名の競馬場に紐付ける。
    ///   - context: 復元先の ModelContext。
    /// - Returns: レースキー → レースのマップと、メモファイルのベース名（現行・旧形式の両方）→ レースのマップ。
    private static func importRaces(
        _ racesText: String,
        venues: [Venue],
        context: ModelContext,
    ) -> (raceMap: [String: Race], memoNameMap: [String: Race]) {
        var raceMap: [String: Race] = [:]
        // レースの venue が DB に存在しない場合でもメモを復元できるよう、ベース名は CSV 行の競馬場名から組み立てる
        var memoNameMap: [String: Race] = [:]
        let raceRows = parseCSV(racesText)
        let raceHeader = raceRows.first ?? []
        let hasFinishPlaces = raceHeader.contains("first_place_horse")
        let hasGrade = raceHeader.contains("grade")
        for (idx, row) in raceRows.dropFirst().enumerated() {
            guard row.count >= 8 else { continue }
            let grade = hasGrade && row.count > 8 ? row[8] : ""
            let placeOffset = hasGrade ? 9 : 8
            let firstPlace = hasFinishPlaces && row.count > placeOffset ? Int(row[placeOffset]) ?? 0 : 0
            let secondPlace = hasFinishPlaces && row.count > placeOffset + 1 ? Int(row[placeOffset + 1]) ?? 0 : 0
            let thirdPlace = hasFinishPlaces && row.count > placeOffset + 2 ? Int(row[placeOffset + 2]) ?? 0 : 0
            let race = Race(
                date: parseDate(row[0]) ?? Date(),
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

    /// memo/ 以下の Markdown ファイルを、ファイル名（現行・旧形式）が一致するレースのメモに設定する。
    /// 読めないファイル・空のファイル・一致するレースが無いファイルは無視する。
    /// - Parameters:
    ///   - archive: 読み込み中のアーカイブ。
    ///   - memoNameMap: メモファイルのベース名 → レースのマップ。
    private static func importMemos(from archive: Archive, memoNameMap: [String: Race]) {
        for entry in archive where entry.path.hasPrefix("memo/") && entry.path.hasSuffix(".md") {
            var data = Data()
            _ = try? archive.extract(entry) { data.append($0) }
            guard let memo = String(data: data, encoding: .utf8), !memo.isEmpty else { continue }
            let filename = String(entry.path.dropFirst("memo/".count).dropLast(".md".count))
            memoNameMap[filename]?.memo = memo
        }
    }

    /// 現行フォーマット（bets.csv + bet_selections.csv）の馬券・買い目を復元する。
    /// - Parameters:
    ///   - archive: 読み込み中のアーカイブ。
    ///   - betsText: bets.csv の内容。
    ///   - raceMap: レースキー → レースのマップ。
    ///   - ticketTypes: 復元先の券種マスター。買い目の券種名と同名の券種に紐付ける。
    ///   - context: 復元先の ModelContext。
    private static func importBetsNewFormat(
        archive: Archive,
        betsText: String,
        raceMap: [String: Race],
        ticketTypes: [TicketType],
        context: ModelContext,
    ) throws {
        let betSelectionsText = try readEntry(archive, path: "bet_selections.csv")
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
                let count = Bet.combinationCount(selection: selection, ticketTypeName: ticketTypeName)
                unitPrice = count > 0 ? purchaseAmount / count : 100
            }
            let count = max(1, Bet.combinationCount(selection: selection, ticketTypeName: ticketTypeName))
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
                combinationCount: count,
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
        "\(date)|\(venue)|\(raceNumber)|\(betSortIndex)"
    }

    /// アーカイブ内の指定パスのエントリを UTF-8 テキストとして読み出す。
    /// - Parameters:
    ///   - archive: 読み込み対象のアーカイブ。
    ///   - path: アーカイブ内のパス。
    /// - Returns: エントリの内容。存在しない場合は `CocoaError(.fileNoSuchFile)` を投げる。
    private static func readEntry(_ archive: Archive, path: String) throws -> String {
        guard let entry = archive[path] else { throw CocoaError(.fileNoSuchFile) }
        var data = Data()
        _ = try archive.extract(entry) { data.append($0) }
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// CSV の date 列の値（`yyyy/MM/dd`）を Date に変換する。
    /// - Parameter string: 変換対象の文字列。
    /// - Returns: 変換結果。形式が不正な場合は nil。
    private static func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.date(from: string)
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
                    if !row.isEmpty {
                        result.append(row)
                    }
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
