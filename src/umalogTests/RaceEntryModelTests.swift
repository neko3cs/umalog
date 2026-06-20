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

    @Test func 新規出走馬の馬番デフォルトが0である() {
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

    @Test func 新規出走馬のソート順デフォルトが0である() {
        let entry = RaceEntry()
        container.mainContext.insert(entry)
        #expect(entry.sortIndex == 0)
    }

    // MARK: - mark getter

    @Test func predictionMarkがnilのときmarkがnilを返す() {
        let entry = RaceEntry(predictionMark: nil)
        container.mainContext.insert(entry)
        #expect(entry.mark == nil)
    }

    @Test func predictionMarkが本命記号のときmarkが本命を返す() {
        let entry = RaceEntry(predictionMark: "◎")
        container.mainContext.insert(entry)
        #expect(entry.mark == .honmei)
    }

    @Test func predictionMarkが対抗記号のときmarkが対抗を返す() {
        let entry = RaceEntry(predictionMark: "○")
        container.mainContext.insert(entry)
        #expect(entry.mark == .taikou)
    }

    @Test func predictionMarkが単穴記号のときmarkが単穴を返す() {
        let entry = RaceEntry(predictionMark: "▲")
        container.mainContext.insert(entry)
        #expect(entry.mark == .tanana)
    }

    @Test func predictionMarkが連下記号のときmarkが連下を返す() {
        let entry = RaceEntry(predictionMark: "△")
        container.mainContext.insert(entry)
        #expect(entry.mark == .renmei)
    }

    @Test func predictionMarkが星記号のときmarkが星を返す() {
        let entry = RaceEntry(predictionMark: "☆")
        container.mainContext.insert(entry)
        #expect(entry.mark == .hoshi)
    }

    @Test func predictionMarkが注のときmarkが注を返す() {
        let entry = RaceEntry(predictionMark: "注")
        container.mainContext.insert(entry)
        #expect(entry.mark == .chu)
    }

    @Test func predictionMarkが押のときmarkが押を返す() {
        let entry = RaceEntry(predictionMark: "押")
        container.mainContext.insert(entry)
        #expect(entry.mark == .oshi)
    }

    @Test func predictionMarkが消のときmarkが消を返す() {
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

    @Test func markを設定するとpredictionMarkが更新される() {
        let entry = RaceEntry(predictionMark: nil)
        container.mainContext.insert(entry)
        entry.mark = .honmei
        #expect(entry.predictionMark == "◎")
    }

    @Test func markにnilを設定するとpredictionMarkがnilになる() {
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

    @Test func 全ケースでgetterとsetterが一致する() {
        let entry = RaceEntry()
        container.mainContext.insert(entry)
        for mark in PredictionMark.allCases {
            entry.mark = mark
            #expect(entry.mark == mark)
            #expect(entry.predictionMark == mark.rawValue)
        }
    }
}
