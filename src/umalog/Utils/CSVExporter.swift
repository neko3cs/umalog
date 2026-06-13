//
//  CSVExporter.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import Foundation

enum CSVExporter {
    static func export(races: [Race]) -> String {
        var lines: [String] = []
        let sorted = races.sorted { $0.date < $1.date }

        lines.append("=== RACES ===")
        lines.append("date,venue,race_number,race_name,distance,track_type,track_condition,category,total_purchase,total_payout,balance,memo")
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
                "\(race.totalPurchase)",
                "\(race.totalPayout)",
                "\(race.balance)",
                race.memo.replacingOccurrences(of: "\n", with: " "),
            ]
            lines.append(row.map { escape($0) }.joined(separator: ","))
        }

        lines.append("")
        lines.append("=== ENTRIES ===")
        lines.append("date,venue,race_number,horse_number,horse_name,jockey_name,trainer_name,prediction_mark,finish_position")
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
                    entry.finishPosition.map { "\($0)" } ?? "",
                ]
                lines.append(row.map { escape($0) }.joined(separator: ","))
            }
        }

        lines.append("")
        lines.append("=== BETS ===")
        lines.append("date,venue,race_number,ticket_type,selection,purchase_amount,payout_amount,balance")
        for race in sorted {
            for bet in (race.bets ?? []).sorted(by: { $0.sortIndex < $1.sortIndex }) {
                let row: [String] = [
                    formatDate(race.date),
                    race.venue?.name ?? "",
                    "\(race.raceNumber)",
                    bet.displayTicketTypeName,
                    bet.selection,
                    "\(bet.purchaseAmount)",
                    "\(bet.payoutAmount)",
                    "\(bet.balance)",
                ]
                lines.append(row.map { escape($0) }.joined(separator: ","))
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
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd"
        return f.string(from: date)
    }
}

// MARK: - ZIP Exporter

enum ZipExporter {
    static func export(races: [Race]) -> Data {
        let sorted = races.sorted { $0.date < $1.date }
        var files: [(name: String, data: Data)] = []

        // races.csv
        files.append(("races.csv", Data(racesCSV(sorted).utf8)))

        // entries.csv
        files.append(("entries.csv", Data(entriesCSV(sorted).utf8)))

        // bets.csv
        files.append(("bets.csv", Data(betsCSV(sorted).utf8)))

        // Markdown memo files per race
        for race in sorted {
            guard !race.memo.isEmpty else { continue }
            let baseName = race.raceName.isEmpty ? "R\(race.raceNumber)" : race.raceName
            let safeName = baseName
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: ":", with: "_")
                .replacingOccurrences(of: "\\", with: "_")
            let fileName = "\(CSVExporter.formatDate(race.date))_\(safeName).md"
            files.append((fileName, Data(race.memo.utf8)))
        }

        return ZipWriter.create(files: files)
    }

    private static func racesCSV(_ races: [Race]) -> String {
        var lines = ["date,venue,race_number,race_name,distance,track_type,track_condition,category,total_purchase,total_payout,balance"]
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
                "\(race.totalPurchase)",
                "\(race.totalPayout)",
                "\(race.balance)",
            ]
            lines.append(row.map { CSVExporter.escape($0) }.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    private static func entriesCSV(_ races: [Race]) -> String {
        var lines = ["date,venue,race_number,horse_number,horse_name,jockey_name,trainer_name,prediction_mark,finish_position"]
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
                    entry.finishPosition.map { "\($0)" } ?? "",
                ]
                lines.append(row.map { CSVExporter.escape($0) }.joined(separator: ","))
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func betsCSV(_ races: [Race]) -> String {
        var lines = ["date,venue,race_number,ticket_type,selection,purchase_amount,payout_amount,balance"]
        for race in races {
            for bet in (race.bets ?? []).sorted(by: { $0.sortIndex < $1.sortIndex }) {
                let row: [String] = [
                    CSVExporter.formatDate(race.date),
                    race.venue?.name ?? "",
                    "\(race.raceNumber)",
                    bet.displayTicketTypeName,
                    bet.selection,
                    "\(bet.purchaseAmount)",
                    "\(bet.payoutAmount)",
                    "\(bet.balance)",
                ]
                lines.append(row.map { CSVExporter.escape($0) }.joined(separator: ","))
            }
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - ZIP Writer (STORE method, no compression)

private enum ZipWriter {
    static func create(files: [(name: String, data: Data)]) -> Data {
        var archive = Data()
        var centralDir = Data()
        var offsets: [UInt32] = []

        for (name, data) in files {
            offsets.append(UInt32(archive.count))
            let nameData = Data(name.utf8)
            let crc = crc32(data)
            archive += localHeader(nameData: nameData, size: UInt32(data.count), crc: crc)
            archive += data
        }

        let centralOffset = UInt32(archive.count)
        for (i, (name, data)) in files.enumerated() {
            let nameData = Data(name.utf8)
            centralDir += centralHeader(nameData: nameData, size: UInt32(data.count), crc: crc32(data), offset: offsets[i])
        }

        archive += centralDir
        archive += endRecord(count: UInt16(files.count), centralSize: UInt32(centralDir.count), centralOffset: centralOffset)
        return archive
    }

    private static func localHeader(nameData: Data, size: UInt32, crc: UInt32) -> Data {
        var d = Data()
        d += sig(0x04034B50)
        d += le(UInt16(20)); d += le(UInt16(0)); d += le(UInt16(0))
        d += le(UInt16(0)); d += le(UInt16(0))
        d += le(crc); d += le(size); d += le(size)
        d += le(UInt16(nameData.count)); d += le(UInt16(0))
        d += nameData
        return d
    }

    private static func centralHeader(nameData: Data, size: UInt32, crc: UInt32, offset: UInt32) -> Data {
        var d = Data()
        d += sig(0x02014B50)
        d += le(UInt16(20)); d += le(UInt16(20)); d += le(UInt16(0)); d += le(UInt16(0))
        d += le(UInt16(0)); d += le(UInt16(0))
        d += le(crc); d += le(size); d += le(size)
        d += le(UInt16(nameData.count)); d += le(UInt16(0)); d += le(UInt16(0))
        d += le(UInt16(0)); d += le(UInt16(0)); d += le(UInt32(0))
        d += le(offset)
        d += nameData
        return d
    }

    private static func endRecord(count: UInt16, centralSize: UInt32, centralOffset: UInt32) -> Data {
        var d = Data()
        d += sig(0x06054B50)
        d += le(UInt16(0)); d += le(UInt16(0))
        d += le(count); d += le(count)
        d += le(centralSize); d += le(centralOffset)
        d += le(UInt16(0))
        return d
    }

    private static func crc32(_ data: Data) -> UInt32 {
        let table: [UInt32] = (0 ..< 256).map { i -> UInt32 in
            (0 ..< 8).reduce(UInt32(i)) { crc, _ in (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1 }
        }
        return ~data.reduce(~UInt32(0)) { crc, byte in
            table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
    }

    private static func le<T: FixedWidthInteger>(_ v: T) -> Data {
        withUnsafeBytes(of: v.littleEndian) { Data($0) }
    }

    private static func sig(_ v: UInt32) -> Data { le(v) }
}
