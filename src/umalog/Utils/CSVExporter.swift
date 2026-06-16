//
//  CSVExporter.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import Foundation
import SwiftData
import ZIPFoundation

// MARK: - CSV Exporter

enum CSVExporter {
    static func export(races: [Race]) -> String {
        var lines: [String] = []
        let sorted = races.sorted { $0.date < $1.date }

        lines.append("=== RACES ===")
        lines.append(
            "date,venue,race_number,race_name,distance,track_type,track_condition," +
                "category,first_place_horse,second_place_horse,third_place_horse," +
                "total_purchase,total_payout,balance,memo"
        )
        for race in sorted {
            let row: [String] = [
                formatDate(race.date),
                race.venue?.name ?? "",
                "\(race.raceNumber)",
                race.raceName,
                "\(race.distance)",
                race.trackType == "turf" ? "芝" : "ダート",
                race.trackCondition,
                race.category == "central" ? "中央" : "地方",
                horseNumberString(race.firstPlaceHorseNumber),
                horseNumberString(race.secondPlaceHorseNumber),
                horseNumberString(race.thirdPlaceHorseNumber),
                "\(race.totalPurchase)",
                "\(race.totalPayout)",
                "\(race.balance)",
                race.memo.replacingOccurrences(of: "\n", with: " "),
            ]
            lines.append(row.map { escape($0) }.joined(separator: ","))
        }

        lines.append("")
        lines.append("=== ENTRIES ===")
        lines.append("date,venue,race_number,horse_number,horse_name,jockey_name,trainer_name,prediction_mark")
        for race in sorted {
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

        lines.append("")
        lines.append("=== BETS ===")
        lines.append("date,venue,race_number,bet_sort_index,purchase_amount,payout_amount,balance")
        for race in sorted {
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

        lines.append("")
        lines.append("=== BET_SELECTIONS ===")
        lines.append(
            "date,venue,race_number,bet_sort_index,ticket_type,selection," +
                "unit_price,combination_count,sort_index"
        )
        for race in sorted {
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

    static func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else {
            return value
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }

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

// MARK: - ZIP Exporter

enum ZipExporter {
    static func export(races: [Race]) throws -> URL {
        let sorted = races.sorted { $0.date < $1.date }

        let filename = "umalog_backup.zip"
        let zipURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: zipURL)

        let archive = try Archive(url: zipURL, accessMode: .create)

        try addEntry(archive, name: "races.csv", content: racesCSV(sorted))
        try addEntry(archive, name: "entries.csv", content: entriesCSV(sorted))
        try addEntry(archive, name: "bets.csv", content: betsCSV(sorted))
        try addEntry(archive, name: "bet_selections.csv", content: betSelectionsCSV(sorted))

        for race in sorted {
            guard !race.memo.isEmpty else { continue }
            let baseName = race.raceName.isEmpty ? "R\(race.raceNumber)" : race.raceName
            let safeName = baseName
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: ":", with: "_")
                .replacingOccurrences(of: "\\", with: "_")
            let name = "memo/\(CSVExporter.formatFilenameDate(race.date))_\(safeName).md"
            try addEntry(archive, name: name, content: race.memo)
        }

        return zipURL
    }

    private static func addEntry(_ archive: Archive, name: String, content: String) throws {
        let data = Data(content.utf8)
        try archive.addEntry(
            with: name, type: .file, uncompressedSize: Int64(data.count)
        ) { _, size in data.subdata(in: 0 ..< size) }
    }

    private static func racesCSV(_ races: [Race]) -> String {
        let header = "date,venue,race_number,race_name,distance,track_type,track_condition," +
            "category,first_place_horse,second_place_horse,third_place_horse," +
            "total_purchase,total_payout,balance"
        var lines = [header]
        for race in races {
            let row: [String] = [
                CSVExporter.formatDate(race.date),
                race.venue?.name ?? "",
                "\(race.raceNumber)",
                race.raceName,
                "\(race.distance)",
                race.trackType == "turf" ? "芝" : "ダート",
                race.trackCondition,
                race.category == "central" ? "中央" : "地方",
                CSVExporter.horseNumberString(race.firstPlaceHorseNumber),
                CSVExporter.horseNumberString(race.secondPlaceHorseNumber),
                CSVExporter.horseNumberString(race.thirdPlaceHorseNumber),
                "\(race.totalPurchase)",
                "\(race.totalPayout)",
                "\(race.balance)",
            ]
            lines.append(row.map { CSVExporter.escape($0) }.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    private static func entriesCSV(_ races: [Race]) -> String {
        var lines = ["date,venue,race_number,horse_number,horse_name,jockey_name,trainer_name,prediction_mark"]
        for race in races {
            for entry in (race.entries ?? []).sorted(by: { $0.sortIndex < $1.sortIndex }) {
                let row: [String] = [
                    CSVExporter.formatDate(race.date),
                    race.venue?.name ?? "",
                    "\(race.raceNumber)",
                    "\(entry.horseNumber)",
                    entry.horseName,
                    entry.jockeyName,
                    entry.trainerName,
                    entry.predictionMark ?? "",
                ]
                lines.append(row.map { CSVExporter.escape($0) }.joined(separator: ","))
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func betsCSV(_ races: [Race]) -> String {
        var lines = ["date,venue,race_number,bet_sort_index,purchase_amount,payout_amount,balance"]
        for race in races {
            for bet in (race.bets ?? []).sorted(by: { $0.sortIndex < $1.sortIndex }) {
                let row: [String] = [
                    CSVExporter.formatDate(race.date),
                    race.venue?.name ?? "",
                    "\(race.raceNumber)",
                    "\(bet.sortIndex)",
                    "\(bet.purchaseAmount)",
                    "\(bet.payoutAmount)",
                    "\(bet.balance)",
                ]
                lines.append(row.map { CSVExporter.escape($0) }.joined(separator: ","))
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func betSelectionsCSV(_ races: [Race]) -> String {
        let header = "date,venue,race_number,bet_sort_index,ticket_type,selection," +
            "unit_price,combination_count,sort_index"
        var lines = [header]
        for race in races {
            for bet in (race.bets ?? []).sorted(by: { $0.sortIndex < $1.sortIndex }) {
                for sel in (bet.selections ?? []).sorted(by: { $0.sortIndex < $1.sortIndex }) {
                    let row: [String] = [
                        CSVExporter.formatDate(race.date),
                        race.venue?.name ?? "",
                        "\(race.raceNumber)",
                        "\(bet.sortIndex)",
                        sel.displayTicketTypeName,
                        sel.selection,
                        "\(sel.unitPrice)",
                        "\(sel.combinationCount)",
                        "\(sel.sortIndex)",
                    ]
                    lines.append(row.map { CSVExporter.escape($0) }.joined(separator: ","))
                }
            }
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - ZIP Importer

enum ZipImporter {
    static func importZip(from url: URL, context: ModelContext) throws {
        let archive = try Archive(url: url, accessMode: .read)

        let racesText = try readEntry(archive, path: "races.csv")
        let entriesText = try readEntry(archive, path: "entries.csv")
        let betsText = try readEntry(archive, path: "bets.csv")
        let hasBetSelections = archive["bet_selections.csv"] != nil

        // 既存のレースデータを削除（競馬場・券種は保持）
        let existingSelections = try context.fetch(FetchDescriptor<BetSelection>())
        existingSelections.forEach { context.delete($0) }
        let existingBets = try context.fetch(FetchDescriptor<Bet>())
        existingBets.forEach { context.delete($0) }
        let existingEntries = try context.fetch(FetchDescriptor<RaceEntry>())
        existingEntries.forEach { context.delete($0) }
        let existingRaces = try context.fetch(FetchDescriptor<Race>())
        existingRaces.forEach { context.delete($0) }

        let venues = try context.fetch(FetchDescriptor<Venue>())

        // レースを作成しキーでマップ
        var raceMap: [String: Race] = [:]
        let raceRows = parseCSV(racesText)
        let raceHeader = raceRows.first ?? []
        let hasFinishPlaces = raceHeader.contains("first_place_horse")
        for (idx, row) in raceRows.dropFirst().enumerated() {
            guard row.count >= 8 else { continue }
            let firstPlace = hasFinishPlaces && row.count > 8 ? Int(row[8]) ?? 0 : 0
            let secondPlace = hasFinishPlaces && row.count > 9 ? Int(row[9]) ?? 0 : 0
            let thirdPlace = hasFinishPlaces && row.count > 10 ? Int(row[10]) ?? 0 : 0
            let race = Race(
                date: parseDate(row[0]) ?? Date(),
                venue: venues.first { $0.name == row[1] },
                raceNumber: Int(row[2]) ?? 1,
                raceName: row[3],
                distance: Int(row[4]) ?? 1600,
                trackType: row[5] == "芝" ? "turf" : "dirt",
                trackCondition: row[6],
                category: row[7] == "中央" ? "central" : "local",
                firstPlaceHorseNumber: firstPlace,
                secondPlaceHorseNumber: secondPlace,
                thirdPlaceHorseNumber: thirdPlace,
                sortIndex: idx
            )
            context.insert(race)
            raceMap[key(date: row[0], venue: row[1], raceNumber: row[2])] = race
        }

        // 出走馬を作成
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
                sortIndex: idx
            ))
        }

        if hasBetSelections {
            try importBetsNewFormat(archive: archive, betsText: betsText, raceMap: raceMap, context: context)
        } else {
            importBetsLegacyFormat(betsText: betsText, raceMap: raceMap, context: context)
        }

        // メモファイルをレースに紐付け
        for entry in archive where entry.path.hasPrefix("memo/") && entry.path.hasSuffix(".md") {
            var data = Data()
            _ = try? archive.extract(entry) { data.append($0) }
            guard let memo = String(data: data, encoding: .utf8), !memo.isEmpty else { continue }
            let filename = String(entry.path.dropFirst("memo/".count).dropLast(".md".count))
            for race in raceMap.values {
                let dateStr = CSVExporter.formatFilenameDate(race.date)
                let baseName = race.raceName.isEmpty ? "R\(race.raceNumber)" : race.raceName
                let safeName = baseName
                    .replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: ":", with: "_")
                if filename == "\(dateStr)_\(safeName)" {
                    race.memo = memo
                    break
                }
            }
        }

        try context.save()
    }

    private static func importBetsNewFormat(
        archive: Archive,
        betsText: String,
        raceMap: [String: Race],
        context: ModelContext
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
                payoutAmount: payoutAmount, sortIndex: betSortIndex
            )
            context.insert(newBet)
            betMap[betKey(date: row[0], venue: row[1], raceNumber: row[2], betSortIndex: row[3])] = newBet
        }
        for (selIdx, row) in parseCSV(betSelectionsText).dropFirst().enumerated() {
            guard row.count >= 7,
                  let bet = betMap[betKey(
                      date: row[0], venue: row[1], raceNumber: row[2], betSortIndex: row[3]
                  )] else { continue }
            let count = row.count > 7 ? Int(row[7]) ?? 1 : 1
            let sortIndex = row.count > 8 ? Int(row[8]) ?? selIdx : selIdx
            context.insert(BetSelection(
                bet: bet,
                ticketTypeName: row[4],
                selection: row[5],
                unitPrice: Int(row[6]) ?? 100,
                combinationCount: count,
                sortIndex: sortIndex
            ))
        }
    }

    private static func importBetsLegacyFormat(
        betsText: String,
        raceMap: [String: Race],
        context: ModelContext
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
                payoutAmount: payoutAmount, sortIndex: idx
            )
            context.insert(newBet)
            context.insert(BetSelection(
                bet: newBet,
                ticketTypeName: ticketTypeName,
                selection: selection,
                unitPrice: unitPrice,
                combinationCount: count,
                sortIndex: 0
            ))
        }
    }

    private static func key(date: String, venue: String, raceNumber: String) -> String {
        "\(date)|\(venue)|\(raceNumber)"
    }

    private static func betKey(date: String, venue: String, raceNumber: String, betSortIndex: String) -> String {
        "\(date)|\(venue)|\(raceNumber)|\(betSortIndex)"
    }

    private static func readEntry(_ archive: Archive, path: String) throws -> String {
        guard let entry = archive[path] else { throw CocoaError(.fileNoSuchFile) }
        var data = Data()
        _ = try archive.extract(entry) { data.append($0) }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.date(from: string)
    }

    // swiftlint:disable:next cyclomatic_complexity
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
                    if idx + 1 < chars.count, chars[idx + 1] == "\n" { idx += 1 }
                    fallthrough
                case "\n":
                    row.append(field); field = ""
                    if !row.isEmpty { result.append(row) }
                    row = []
                default: field.append(char)
                }
            }
            idx += 1
        }
        if !field.isEmpty || !row.isEmpty { row.append(field); result.append(row) }
        return result
    }
}

// MARK: - Date Display Helpers

extension Date {
    var japaneseShortDateString: String {
        formatted(
            Date.FormatStyle()
                .locale(Locale(identifier: "ja_JP"))
                .year(.defaultDigits)
                .month(.twoDigits)
                .day(.twoDigits)
        )
    }
}
