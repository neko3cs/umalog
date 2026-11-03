//
//  RaceEntryModelTests.swift
//  umalog
//
//  Created by neko3cs on 2026/06/12.
//

import SwiftData
import Testing
@testable import umalog

@MainActor
struct 出走馬モデルTest {
    let container: ModelContainer

    init() throws {
        let schema = Schema([Race.self, Bet.self, RaceEntry.self, Venue.self, TicketType.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - デフォルト値

    @Test func `新規出走馬は馬番とソート順が 0 で文字列が空で予想印が無い`() {
        let entry = RaceEntry()
        container.mainContext.insert(entry)
        #expect(entry.horseNumber == 0)
        #expect(entry.horseName == "")
        #expect(entry.jockeyName == "")
        #expect(entry.trainerName == "")
        #expect(entry.predictionMark == nil)
        #expect(entry.sortIndex == 0)
    }

    // MARK: - mark getter

    @Test(arguments: [
        ("◎", PredictionMark.honmei), ("○", .taikou), ("▲", .tanana), ("△", .renmei),
        ("☆", .hoshi), ("注", .chu), ("押", .oshi), ("消", .keshi),
    ])
    func 保存された記号から予想印が読み取れる(stored: String, mark: PredictionMark) {
        let entry = RaceEntry(predictionMark: stored)
        container.mainContext.insert(entry)
        #expect(entry.mark == mark)
    }

    @Test(arguments: [nil, "invalid", ""] as [String?])
    func 保存された値が予想印の記号でなければ予想印は無い(stored: String?) {
        let entry = RaceEntry(predictionMark: stored)
        container.mainContext.insert(entry)
        #expect(entry.mark == nil)
    }

    // MARK: - mark setter

    @Test func 予想印を設定すると保存する記号が更新される() {
        let entry = RaceEntry(predictionMark: nil)
        container.mainContext.insert(entry)
        entry.mark = .honmei
        #expect(entry.predictionMark == "◎")
    }

    @Test func 予想印を外すと保存する記号が無くなる() {
        let entry = RaceEntry(predictionMark: "◎")
        container.mainContext.insert(entry)
        entry.mark = nil
        #expect(entry.predictionMark == nil)
    }

    @Test func 予想印を変更すると新しい記号が保存される() {
        let entry = RaceEntry(predictionMark: "◎")
        container.mainContext.insert(entry)
        entry.mark = .keshi
        #expect(entry.predictionMark == "消")
        #expect(entry.mark == .keshi)
    }

    @Test func `全予想印で設定した予想印と保存される記号が一致する`() {
        let entry = RaceEntry()
        container.mainContext.insert(entry)
        for mark in PredictionMark.allCases {
            entry.mark = mark
            #expect(entry.mark == mark)
            #expect(entry.predictionMark == mark.rawValue)
        }
    }
}
