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

    @Test func `新規出走馬の馬番デフォルトが 0 である`() {
        let entry = RaceEntry()
        container.mainContext.insert(entry)
        #expect(entry.horseNumber == 0)
    }

    @Test func 新規出走馬の馬名デフォルトが空文字である() {
        let entry = RaceEntry()
        container.mainContext.insert(entry)
        #expect(entry.horseName == "")
    }

    @Test func 新規出走馬の騎手名デフォルトが空文字である() {
        let entry = RaceEntry()
        container.mainContext.insert(entry)
        #expect(entry.jockeyName == "")
    }

    @Test func 新規出走馬の調教師名デフォルトが空文字である() {
        let entry = RaceEntry()
        container.mainContext.insert(entry)
        #expect(entry.trainerName == "")
    }

    @Test func 新規出走馬の予想印デフォルトがnilである() {
        let entry = RaceEntry()
        container.mainContext.insert(entry)
        #expect(entry.predictionMark == nil)
    }

    @Test func `新規出走馬のソート順デフォルトが 0 である`() {
        let entry = RaceEntry()
        container.mainContext.insert(entry)
        #expect(entry.sortIndex == 0)
    }

    // MARK: - mark getter

    @Test func `prediction markがnilのときmarkがnilを返す`() {
        let entry = RaceEntry(predictionMark: nil)
        container.mainContext.insert(entry)
        #expect(entry.mark == nil)
    }

    @Test func `prediction markが本命記号のときmarkが本命を返す`() {
        let entry = RaceEntry(predictionMark: "◎")
        container.mainContext.insert(entry)
        #expect(entry.mark == .honmei)
    }

    @Test func `prediction markが対抗記号のときmarkが対抗を返す`() {
        let entry = RaceEntry(predictionMark: "○")
        container.mainContext.insert(entry)
        #expect(entry.mark == .taikou)
    }

    @Test func `prediction markが単穴記号のときmarkが単穴を返す`() {
        let entry = RaceEntry(predictionMark: "▲")
        container.mainContext.insert(entry)
        #expect(entry.mark == .tanana)
    }

    @Test func `prediction markが連下記号のときmarkが連下を返す`() {
        let entry = RaceEntry(predictionMark: "△")
        container.mainContext.insert(entry)
        #expect(entry.mark == .renmei)
    }

    @Test func `prediction markが星記号のときmarkが星を返す`() {
        let entry = RaceEntry(predictionMark: "☆")
        container.mainContext.insert(entry)
        #expect(entry.mark == .hoshi)
    }

    @Test func `prediction markが注のときmarkが注を返す`() {
        let entry = RaceEntry(predictionMark: "注")
        container.mainContext.insert(entry)
        #expect(entry.mark == .chu)
    }

    @Test func `prediction markが押のときmarkが押を返す`() {
        let entry = RaceEntry(predictionMark: "押")
        container.mainContext.insert(entry)
        #expect(entry.mark == .oshi)
    }

    @Test func `prediction markが消のときmarkが消を返す`() {
        let entry = RaceEntry(predictionMark: "消")
        container.mainContext.insert(entry)
        #expect(entry.mark == .keshi)
    }

    @Test func 無効な文字列のときmarkがnilを返す() {
        let entry = RaceEntry(predictionMark: "invalid")
        container.mainContext.insert(entry)
        #expect(entry.mark == nil)
    }

    @Test func 空文字のときmarkがnilを返す() {
        let entry = RaceEntry(predictionMark: "")
        container.mainContext.insert(entry)
        #expect(entry.mark == nil)
    }

    // MARK: - mark setter

    @Test func `markを設定するとprediction markが更新される`() {
        let entry = RaceEntry(predictionMark: nil)
        container.mainContext.insert(entry)
        entry.mark = .honmei
        #expect(entry.predictionMark == "◎")
    }

    @Test func `markにnilを設定するとprediction markがnilになる`() {
        let entry = RaceEntry(predictionMark: "◎")
        container.mainContext.insert(entry)
        entry.mark = nil
        #expect(entry.predictionMark == nil)
    }

    @Test func markを変更すると正しく更新される() {
        let entry = RaceEntry(predictionMark: "◎")
        container.mainContext.insert(entry)
        entry.mark = .keshi
        #expect(entry.predictionMark == "消")
        #expect(entry.mark == .keshi)
    }

    @Test func `全ケースでgetterとsetterが 一 致する`() {
        let entry = RaceEntry()
        container.mainContext.insert(entry)
        for mark in PredictionMark.allCases {
            entry.mark = mark
            #expect(entry.mark == mark)
            #expect(entry.predictionMark == mark.rawValue)
        }
    }
}
