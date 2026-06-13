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
struct RaceEntryModelTests {
    let container: ModelContainer

    init() throws {
        let schema = Schema([Race.self, Bet.self, RaceEntry.self, Venue.self, TicketType.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - mark getter

    @Test func mark_getter_whenNil_returnsNil() {
        let entry = RaceEntry(predictionMark: nil)
        container.mainContext.insert(entry)
        #expect(entry.mark == nil)
    }

    @Test func mark_getter_whenHonmei_returnsHonmei() {
        let entry = RaceEntry(predictionMark: "◎")
        container.mainContext.insert(entry)
        #expect(entry.mark == .honmei)
    }

    @Test func mark_getter_whenTaikou_returnsTaikou() {
        let entry = RaceEntry(predictionMark: "○")
        container.mainContext.insert(entry)
        #expect(entry.mark == .taikou)
    }

    @Test func mark_getter_whenTanana_returnsTanana() {
        let entry = RaceEntry(predictionMark: "▲")
        container.mainContext.insert(entry)
        #expect(entry.mark == .tanana)
    }

    @Test func mark_getter_whenRenmei_returnsRenmei() {
        let entry = RaceEntry(predictionMark: "△")
        container.mainContext.insert(entry)
        #expect(entry.mark == .renmei)
    }

    @Test func mark_getter_whenHoshi_returnsHoshi() {
        let entry = RaceEntry(predictionMark: "☆")
        container.mainContext.insert(entry)
        #expect(entry.mark == .hoshi)
    }

    @Test func mark_getter_whenChu_returnsChu() {
        let entry = RaceEntry(predictionMark: "注")
        container.mainContext.insert(entry)
        #expect(entry.mark == .chu)
    }

    @Test func mark_getter_whenOshi_returnsOshi() {
        let entry = RaceEntry(predictionMark: "押")
        container.mainContext.insert(entry)
        #expect(entry.mark == .oshi)
    }

    @Test func mark_getter_whenKeshi_returnsKeshi() {
        let entry = RaceEntry(predictionMark: "消")
        container.mainContext.insert(entry)
        #expect(entry.mark == .keshi)
    }

    @Test func mark_getter_whenInvalidString_returnsNil() {
        let entry = RaceEntry(predictionMark: "invalid")
        container.mainContext.insert(entry)
        #expect(entry.mark == nil)
    }

    @Test func mark_getter_whenEmptyString_returnsNil() {
        let entry = RaceEntry(predictionMark: "")
        container.mainContext.insert(entry)
        #expect(entry.mark == nil)
    }

    // MARK: - mark setter

    @Test func mark_setter_whenSetToMark_updatesPredictionMark() {
        let entry = RaceEntry(predictionMark: nil)
        container.mainContext.insert(entry)
        entry.mark = .honmei
        #expect(entry.predictionMark == "◎")
    }

    @Test func mark_setter_whenSetToNil_clearsPredictionMark() {
        let entry = RaceEntry(predictionMark: "◎")
        container.mainContext.insert(entry)
        entry.mark = nil
        #expect(entry.predictionMark == nil)
    }

    @Test func mark_setter_whenChanged_updatesCorrectly() {
        let entry = RaceEntry(predictionMark: "◎")
        container.mainContext.insert(entry)
        entry.mark = .keshi
        #expect(entry.predictionMark == "消")
        #expect(entry.mark == .keshi)
    }

    @Test func mark_setterAndGetter_areConsistentForAllCases() {
        let entry = RaceEntry()
        container.mainContext.insert(entry)
        for mark in PredictionMark.allCases {
            entry.mark = mark
            #expect(entry.mark == mark)
            #expect(entry.predictionMark == mark.rawValue)
        }
    }
}
