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

    private static func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd"
        return f.string(from: date)
    }

    private static func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else {
            return value
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
