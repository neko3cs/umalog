//
//  ZipExporter.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import Foundation
import ZIPFoundation

/// レースデータをセクション別 CSV とメモ Markdown ファイルにまとめた ZIP バックアップを生成するユーティリティ。
enum ZipExporter {
    /// レースデータを CSV 群とメモファイルにまとめた ZIP バックアップを一時ディレクトリに生成する。
    /// - Parameter races: エクスポート対象のレース配列。日付昇順に並べ替えて出力する。
    /// - Returns: 生成した ZIP ファイルの URL。
    static func export(races: [Race]) throws -> URL {
        let sorted = races.sorted { $0.date < $1.date }

        let filename = "umalog_backup.zip"
        let zipURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: zipURL)

        let archive = try Archive(url: zipURL, accessMode: .create)

        try addEntry(archive, name: "races.csv", content: CSVExporter.racesCSV(sorted, includeMemo: false))
        try addEntry(archive, name: "entries.csv", content: CSVExporter.entriesCSV(sorted))
        try addEntry(archive, name: "bets.csv", content: CSVExporter.betsCSV(sorted))
        try addEntry(archive, name: "bet_selections.csv", content: CSVExporter.betSelectionsCSV(sorted))

        for race in sorted {
            guard !race.memo.isEmpty else { continue }
            let baseName = memoBaseName(
                date: race.date,
                venueName: race.venue?.name ?? "",
                raceNumber: race.raceNumber,
                raceName: race.raceName,
            )
            try addEntry(archive, name: "memo/\(baseName).md", content: race.memo)
        }

        return zipURL
    }

    /// メモファイルのベース名（拡張子なし）を現行形式「日付_競馬場_R番号_レース名」で組み立てる。
    /// - Note: 同日・同レース名のレースが複数競馬場に存在してもファイル名が衝突しないよう、競馬場とレース番号を含める。
    /// - Parameters:
    ///   - date: レースの開催日。
    ///   - venueName: 競馬場名。空文字なら省略される。
    ///   - raceNumber: レース番号。
    ///   - raceName: レース名。空文字なら省略される。
    /// - Returns: メモファイルのベース名。
    static func memoBaseName(date: Date, venueName: String, raceNumber: Int, raceName: String) -> String {
        var components = [CSVExporter.formatFilenameDate(date)]
        if !venueName.isEmpty {
            components.append(sanitizeForFilename(venueName))
        }
        components.append("R\(raceNumber)")
        if !raceName.isEmpty {
            components.append(sanitizeForFilename(raceName))
        }
        return components.joined(separator: "_")
    }

    /// 旧バックアップとの互換用メモファイルベース名「日付_レース名」を組み立てる。
    /// - Parameters:
    ///   - date: レースの開催日。
    ///   - raceNumber: レース番号。レース名が空のときのフォールバックに使う。
    ///   - raceName: レース名。
    /// - Returns: 旧形式のメモファイルベース名。
    static func legacyMemoBaseName(date: Date, raceNumber: Int, raceName: String) -> String {
        let base = raceName.isEmpty ? "R\(raceNumber)" : sanitizeForFilename(raceName)
        return "\(CSVExporter.formatFilenameDate(date))_\(base)"
    }

    /// ファイル名に使えない文字（`/` `:` `\`）を `_` に置換する。
    /// - Parameter name: 置換対象の文字列。
    /// - Returns: 置換後の文字列。
    static func sanitizeForFilename(_ name: String) -> String {
        name.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
    }

    /// アーカイブへ UTF-8 テキストのファイルエントリを追加する。
    /// - Parameters:
    ///   - archive: 追加先のアーカイブ。
    ///   - name: アーカイブ内のパス。
    ///   - content: ファイル内容のテキスト。
    private static func addEntry(_ archive: Archive, name: String, content: String) throws {
        let data = Data(content.utf8)
        try archive.addEntry(
            with: name, type: .file, uncompressedSize: Int64(data.count),
        ) { _, size in data.subdata(in: 0 ..< size) }
    }
}
