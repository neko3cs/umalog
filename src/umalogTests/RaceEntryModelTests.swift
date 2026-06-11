//
//  RaceEntryModelTests.swift
//  umalog
//
//  Created by neko3cs on 2026/06/12.
//

import Testing
import SwiftData
@testable import umalog

@Suite
struct RaceEntryModelTests {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Race.self, Bet.self, RaceEntry.self, Venue.self, TicketType.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - mark getter

    @Test @MainActor func mark_getter_whenNil_returnsNil() throws {
        let container = try makeContainer()
        let entry = RaceEntry(predictionMark: nil)
        container.mainContext.insert(entry)
        #expect(entry.mark == nil)
    }

    @Test @MainActor func mark_getter_whenHonmei_returnsHonmei() throws {
        let container = try makeContainer()
        let entry = RaceEntry(predictionMark: "◎")
        container.mainContext.insert(entry)
        #expect(entry.mark == .honmei)
    }

    @Test @MainActor func mark_getter_whenTaikou_returnsTaikou() throws {
        let container = try makeContainer()
        let entry = RaceEntry(predictionMark: "○")
        container.mainContext.insert(entry)
        #expect(entry.mark == .taikou)
    }

    @Test @MainActor func mark_getter_whenTanana_returnsTanana() throws {
        let container = try makeContainer()
        let entry = RaceEntry(predictionMark: "▲")
        container.mainContext.insert(entry)
        #expect(entry.mark == .tanana)
    }

    @Test @MainActor func mark_getter_whenRenmei_returnsRenmei() throws {
        let container = try makeContainer()
        let entry = RaceEntry(predictionMark: "△")
        container.mainContext.insert(entry)
        #expect(entry.mark == .renmei)
    }

    @Test @MainActor func mark_getter_whenHoshi_returnsHoshi() throws {
        let container = try makeContainer()
        let entry = RaceEntry(predictionMark: "☆")
        container.mainContext.insert(entry)
        #expect(entry.mark == .hoshi)
    }

    @Test @MainActor func mark_getter_whenChu_returnsChu() throws {
        let container = try makeContainer()
        let entry = RaceEntry(predictionMark: "注")
        container.mainContext.insert(entry)
        #expect(entry.mark == .chu)
    }

    @Test @MainActor func mark_getter_whenOshi_returnsOshi() throws {
        let container = try makeContainer()
        let entry = RaceEntry(predictionMark: "押")
        container.mainContext.insert(entry)
        #expect(entry.mark == .oshi)
    }

    @Test @MainActor func mark_getter_whenKeshi_returnsKeshi() throws {
        let container = try makeContainer()
        let entry = RaceEntry(predictionMark: "消")
        container.mainContext.insert(entry)
        #expect(entry.mark == .keshi)
    }

    @Test @MainActor func mark_getter_whenInvalidString_returnsNil() throws {
        let container = try makeContainer()
        let entry = RaceEntry(predictionMark: "invalid")
        container.mainContext.insert(entry)
        #expect(entry.mark == nil)
    }

    @Test @MainActor func mark_getter_whenEmptyString_returnsNil() throws {
        let container = try makeContainer()
        let entry = RaceEntry(predictionMark: "")
        container.mainContext.insert(entry)
        #expect(entry.mark == nil)
    }

    // MARK: - mark setter

    @Test @MainActor func mark_setter_whenSetToMark_updatesPredictionMark() throws {
        let container = try makeContainer()
        let entry = RaceEntry(predictionMark: nil)
        container.mainContext.insert(entry)
        entry.mark = .honmei
        #expect(entry.predictionMark == "◎")
    }

    @Test @MainActor func mark_setter_whenSetToNil_clearsPredictionMark() throws {
        let container = try makeContainer()
        let entry = RaceEntry(predictionMark: "◎")
        container.mainContext.insert(entry)
        entry.mark = nil
        #expect(entry.predictionMark == nil)
    }

    @Test @MainActor func mark_setter_whenChanged_updatesCorrectly() throws {
        let container = try makeContainer()
        let entry = RaceEntry(predictionMark: "◎")
        container.mainContext.insert(entry)
        entry.mark = .keshi
        #expect(entry.predictionMark == "消")
        #expect(entry.mark == .keshi)
    }

    @Test @MainActor func mark_setterAndGetter_areConsistentForAllCases() throws {
        let container = try makeContainer()
        let entry = RaceEntry()
        container.mainContext.insert(entry)
        for mark in PredictionMark.allCases {
            entry.mark = mark
            #expect(entry.mark == mark)
            #expect(entry.predictionMark == mark.rawValue)
        }
    }
}
