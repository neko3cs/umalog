//
//  UndoSnapshotTests.swift
//  umalog
//
//  Created by neko3cs on 2026/10/31.
//

import SwiftData
import Testing
@testable import umalog

@MainActor
struct 削除取り消し用スナップショットTest {
    let container: ModelContainer

    init() throws {
        let schema = Schema([Race.self, Bet.self, BetSelection.self, RaceEntry.self, Venue.self, TicketType.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    @Test func 出走馬のスナップショットが全項目を写し取る() {
        let entry = RaceEntry(
            horseNumber: 3, horseName: "テスト馬", jockeyName: "テスト騎手", trainerName: "テスト調教師",
            predictionMark: PredictionMark.honmei.rawValue, finishPosition: 1, sortIndex: 2,
        )
        container.mainContext.insert(entry)

        let snap = EntrySnapshot(from: entry)

        #expect(snap.horseNumber == 3)
        #expect(snap.horseName == "テスト馬")
        #expect(snap.jockeyName == "テスト騎手")
        #expect(snap.trainerName == "テスト調教師")
        #expect(snap.predictionMark == PredictionMark.honmei.rawValue)
        #expect(snap.finishPosition == 1)
        #expect(snap.sortIndex == 2)
    }

    @Test func 馬券のスナップショットが買い目と券種の永続識別子も写し取る() throws {
        let context = container.mainContext
        let ticketType = TicketType(name: "馬連")
        context.insert(ticketType)
        let bet = Bet(ticketType: ticketType, ticketTypeName: "馬連", selection: "1-2",
                      unitPrice: 100, purchaseAmount: 300, payoutAmount: 1200, sortIndex: 4)
        context.insert(bet)
        context.insert(BetSelection(bet: bet, ticketType: ticketType, ticketTypeName: "馬連",
                                    selection: "1,2,3[BOX]", unitPrice: 100, combinationCount: 3, sortIndex: 0))
        try context.save()

        let snap = BetSnapshot(from: bet)

        #expect(snap.ticketTypeId == ticketType.persistentModelID)
        #expect(snap.ticketTypeName == "馬連")
        #expect(snap.selection == "1-2")
        #expect(snap.unitPrice == 100)
        #expect(snap.purchaseAmount == 300)
        #expect(snap.payoutAmount == 1200)
        #expect(snap.sortIndex == 4)
        let sel = try #require(snap.selections.first)
        #expect(snap.selections.count == 1)
        #expect(sel.ticketTypeId == ticketType.persistentModelID)
        #expect(sel.ticketTypeName == "馬連")
        #expect(sel.selection == "1,2,3[BOX]")
        #expect(sel.unitPrice == 100)
        #expect(sel.combinationCount == 3)
        #expect(sel.sortIndex == 0)
    }

    @Test func 券種のない旧形式の馬券のスナップショットは券種の識別子がnilで買い目が空になる() {
        let bet = Bet(ticketTypeName: "旧券種", selection: "1-2", purchaseAmount: 100)
        container.mainContext.insert(bet)

        let snap = BetSnapshot(from: bet)

        #expect(snap.ticketTypeId == nil)
        #expect(snap.ticketTypeName == "旧券種")
        #expect(snap.selections.isEmpty)
    }
}
