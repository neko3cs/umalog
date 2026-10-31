//
//  CSVExporter.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import Foundation

/// レースデータを CSV テキストへ変換するユーティリティ。
/// テキスト共有用の連結形式（`export(races:)`）と、ZIP バックアップ用のセクション別 CSV の両方を生成する。
enum CSVExporter {
    /// 全セクションをヘッダー付きで 1 つのテキストに連結した CSV を生成する。
    /// - Parameter races: エクスポート対象のレース配列。日付昇順に並べ替えて出力する。
    /// - Returns: `=== RACES ===` などのセクション見出しで区切られた CSV テキスト。
    static func export(races: [Race]) -> String {
        let sorted = races.sorted { $0.date < $1.date }
        return [
            "=== RACES ===\n" + racesCSV(sorted, includeMemo: true),
            "=== ENTRIES ===\n" + entriesCSV(sorted),
            "=== BETS ===\n" + betsCSV(sorted),
            "=== BET_SELECTIONS ===\n" + betSelectionsCSV(sorted),
        ].joined(separator: "\n\n")
    }

    /// races セクションの CSV（ヘッダー行 + レース行）を生成する。
    /// - Parameters:
    ///   - races: 出力対象のレース配列。呼び出し側で並べ替え済みであること。
    ///   - includeMemo: memo 列を含めるか。ZIP バックアップではメモを別ファイルに出力するため false を指定する。
    /// - Returns: races セクションの CSV テキスト。
    static func racesCSV(_ races: [Race], includeMemo: Bool) -> String {
        var header = "date,venue,race_number,race_name,distance,track_type,track_condition," +
            "category,grade,first_place_horse,second_place_horse,third_place_horse," +
            "total_purchase,total_payout,balance"
        if includeMemo {
            header += ",memo"
        }
        var lines = [header]
        for race in races {
            var row: [String] = [
                formatDate(race.date),
                race.venue?.name ?? "",
                "\(race.raceNumber)",
                race.raceName,
                "\(race.distance)",
                race.trackType == "turf" ? "芝" : "ダート",
                race.trackCondition,
                race.categoryValue.shortName,
                race.grade,
                horseNumberString(race.firstPlaceHorseNumber),
                horseNumberString(race.secondPlaceHorseNumber),
                horseNumberString(race.thirdPlaceHorseNumber),
                "\(race.totalPurchase)",
                "\(race.totalPayout)",
                "\(race.balance)",
            ]
            if includeMemo {
                row.append(race.memo.replacingOccurrences(of: "\n", with: " "))
            }
            lines.append(row.map { escape($0) }.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    /// entries セクションの CSV（ヘッダー行 + 出走馬行）を生成する。
    /// - Parameter races: 出力対象のレース配列。呼び出し側で並べ替え済みであること。
    /// - Returns: entries セクションの CSV テキスト。
    static func entriesCSV(_ races: [Race]) -> String {
        var lines = ["date,venue,race_number,horse_number,horse_name,jockey_name,trainer_name,prediction_mark"]
        for race in races {
            for entry in (race.entries ?? []).sorted(by: { $0.sortIndex < $1.sortIndex }) {
                let row: [String] = [
                    formatDate(race.date),
                    race.venue?.name ?? "",
                    "\(race.raceNumber)",
                    "\(entry.horseNumber)",
                    entry.horseName,
                    entry.jockeyName,
                    entry.trainerName,
                    entry.predictionMark ?? "",
                ]
                lines.append(row.map { escape($0) }.joined(separator: ","))
            }
        }
        return lines.joined(separator: "\n")
    }

    /// bets セクションの CSV（ヘッダー行 + 馬券行）を生成する。
    /// - Parameter races: 出力対象のレース配列。呼び出し側で並べ替え済みであること。
    /// - Returns: bets セクションの CSV テキスト。
    static func betsCSV(_ races: [Race]) -> String {
        var lines = ["date,venue,race_number,bet_sort_index,purchase_amount,payout_amount,balance"]
        for race in races {
            for bet in (race.bets ?? []).sorted(by: { $0.sortIndex < $1.sortIndex }) {
                let row: [String] = [
                    formatDate(race.date),
                    race.venue?.name ?? "",
                    "\(race.raceNumber)",
                    "\(bet.sortIndex)",
                    "\(bet.purchaseAmount)",
                    "\(bet.payoutAmount)",
                    "\(bet.balance)",
                ]
                lines.append(row.map { escape($0) }.joined(separator: ","))
            }
        }
        return lines.joined(separator: "\n")
    }

    /// bet_selections セクションの CSV（ヘッダー行 + 買い目行）を生成する。
    /// - Parameter races: 出力対象のレース配列。呼び出し側で並べ替え済みであること。
    /// - Returns: bet_selections セクションの CSV テキスト。
    static func betSelectionsCSV(_ races: [Race]) -> String {
        let header = "date,venue,race_number,bet_sort_index,ticket_type,selection," +
            "unit_price,combination_count,sort_index"
        var lines = [header]
        for race in races {
            for bet in (race.bets ?? []).sorted(by: { $0.sortIndex < $1.sortIndex }) {
                for sel in (bet.selections ?? []).sorted(by: { $0.sortIndex < $1.sortIndex }) {
                    let row: [String] = [
                        formatDate(race.date),
                        race.venue?.name ?? "",
                        "\(race.raceNumber)",
                        "\(bet.sortIndex)",
                        sel.displayTicketTypeName,
                        sel.selection,
                        "\(sel.unitPrice)",
                        "\(sel.combinationCount)",
                        "\(sel.sortIndex)",
                    ]
                    lines.append(row.map { escape($0) }.joined(separator: ","))
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    /// CSV の値をエスケープする。カンマ・ダブルクォート・改行を含む場合のみクォートで囲む。
    /// - Parameter value: エスケープ対象の値。
    /// - Returns: エスケープ済みの値。
    static func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else {
            return value
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// CSV の date 列に使う `yyyy/MM/dd` 形式で日付をフォーマットする。
    /// - Parameter date: フォーマット対象の日付。
    /// - Returns: フォーマット済み文字列。
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }

    /// ファイル名に使う `yyyyMMdd` 形式で日付をフォーマットする。
    /// - Parameter date: フォーマット対象の日付。
    /// - Returns: フォーマット済み文字列。
    static func formatFilenameDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }

    /// 0 を未入力として空文字に変換するヘルパー
    static func horseNumberString(_ number: Int) -> String {
        number > 0 ? "\(number)" : ""
    }
}
