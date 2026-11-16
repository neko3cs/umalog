//
//  DataResetTests.swift
//  umalog
//
//  Created by neko3cs on 2026/11/17.
//

import Foundation
import SwiftData
import Testing
@testable import umalog

/// データの初期化で、記録がすべて消え、初期化より前の操作を取り消せなくなることを確かめる。
@MainActor
struct データ初期化Test {
    let container: ModelContainer

    init() throws {
        let schema = Schema([Race.self, Bet.self, BetSelection.self, RaceEntry.self, Venue.self, TicketType.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    /// 競馬場・券種と、出走馬・馬券・買い目を持つレースを 1 件ずつ保存する。
    private func insertRaceWithChildren() throws {
        let context = container.mainContext
        let venue = Venue(name: "東京")
        let ticketType = TicketType(name: "単勝")
        let race = Race(venue: venue, raceName: "初期化するレース")
        let bet = Bet(race: race, purchaseAmount: 100)
        context.insert(venue)
        context.insert(ticketType)
        context.insert(race)
        context.insert(RaceEntry(race: race, horseNumber: 1, horseName: "初期化する馬"))
        context.insert(bet)
        context.insert(BetSelection(bet: bet, ticketType: ticketType, ticketTypeName: "単勝", selection: "1"))
        try context.save()
    }

    @Test func `初期化するとレースと出走馬と馬券と買い目が消え競馬場と券種は残る`() throws {
        let context = container.mainContext
        try insertRaceWithChildren()

        try DataReset.deleteAllRaces(in: context, undoManager: nil)

        #expect(try context.fetchCount(FetchDescriptor<Race>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<RaceEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Bet>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<BetSelection>()) == 0)
        #expect(try context.fetch(FetchDescriptor<Venue>()).map(\.name) == ["東京"])
        #expect(try context.fetch(FetchDescriptor<TicketType>()).map(\.name) == ["単勝"])
    }

    @Test func `レースを削除してから初期化すると削除したレースは取り消しで戻らない`() throws {
        let context = container.mainContext
        try insertRaceWithChildren()
        let race = try #require(try context.fetch(FetchDescriptor<Race>()).first)
        let snapshot = RaceSnapshot(from: race)
        let undoManager = UndoManager()
        context.delete(race)
        undoManager.registerUndo(withTarget: context) { [snapshot] context in
            snapshot.restore(into: context)
        }
        try #require(undoManager.canUndo)

        try DataReset.deleteAllRaces(in: context, undoManager: undoManager)
        undoManager.undo()

        #expect(!undoManager.canUndo)
        #expect(try context.fetchCount(FetchDescriptor<Race>()) == 0)
    }

    @Test func `初期化のあとで行った削除は取り消せる`() throws {
        let context = container.mainContext
        let undoManager = UndoManager()
        try DataReset.deleteAllRaces(in: context, undoManager: undoManager)
        let race = Race(raceName: "初期化のあとのレース")
        context.insert(race)
        try context.save()
        let snapshot = RaceSnapshot(from: race)

        context.delete(race)
        undoManager.registerUndo(withTarget: context) { [snapshot] context in
            snapshot.restore(into: context)
        }
        undoManager.undo()

        #expect(try context.fetch(FetchDescriptor<Race>()).map(\.raceName) == ["初期化のあとのレース"])
    }
}
