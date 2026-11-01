//
//  UndoSnapshotTests.swift
//  umalog
//
//  Created by neko3cs on 2026/10/31.
//

import Foundation
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

    @Test func 削除した出走馬を復元すると同じ内容で元のレースに戻る() throws {
        let context = container.mainContext
        let race = Race(raceName: "テストレース")
        context.insert(race)
        let entry = RaceEntry(
            race: race, horseNumber: 3, horseName: "テスト馬", jockeyName: "テスト騎手", trainerName: "テスト調教師",
            predictionMark: PredictionMark.honmei.rawValue, finishPosition: 1, sortIndex: 2,
        )
        context.insert(entry)
        try context.save()
        let snap = EntrySnapshot(from: entry)
        context.delete(entry)
        try context.save()

        snap.restore(into: context, race: race)

        let entries = try context.fetch(FetchDescriptor<RaceEntry>())
        let restored = try #require(entries.first)
        #expect(entries.count == 1)
        #expect(restored.race?.persistentModelID == race.persistentModelID)
        #expect(restored.horseNumber == 3)
        #expect(restored.horseName == "テスト馬")
        #expect(restored.jockeyName == "テスト騎手")
        #expect(restored.trainerName == "テスト調教師")
        #expect(restored.predictionMark == PredictionMark.honmei.rawValue)
        #expect(restored.finishPosition == 1)
        #expect(restored.sortIndex == 2)
    }

    @Test func 削除した馬券を復元すると買い目ごと元のレースに戻り券種マスターに結び直される() throws {
        let context = container.mainContext
        let race = Race(raceName: "テストレース")
        let umaren = TicketType(name: "馬連")
        let wide = TicketType(name: "ワイド")
        context.insert(race)
        context.insert(umaren)
        context.insert(wide)
        let bet = Bet(race: race, ticketType: umaren, ticketTypeName: "馬連", selection: "1-2",
                      unitPrice: 100, purchaseAmount: 400, payoutAmount: 1200, sortIndex: 4)
        context.insert(bet)
        context.insert(BetSelection(bet: bet, ticketType: umaren, ticketTypeName: "馬連",
                                    selection: "1,2,3[BOX]", unitPrice: 100, combinationCount: 3, sortIndex: 0))
        context.insert(BetSelection(bet: bet, ticketType: wide, ticketTypeName: "ワイド",
                                    selection: "1-2", unitPrice: 100, combinationCount: 1, sortIndex: 1))
        try context.save()
        let snap = BetSnapshot(from: bet)
        (bet.selections ?? []).forEach { context.delete($0) }
        context.delete(bet)
        try context.save()

        snap.restore(into: context, race: race, ticketTypes: [umaren, wide])

        let bets = try context.fetch(FetchDescriptor<Bet>())
        let restored = try #require(bets.first)
        #expect(bets.count == 1)
        #expect(restored.race?.persistentModelID == race.persistentModelID)
        #expect(restored.ticketType?.persistentModelID == umaren.persistentModelID)
        #expect(restored.ticketTypeName == "馬連")
        #expect(restored.selection == "1-2")
        #expect(restored.unitPrice == 100)
        #expect(restored.purchaseAmount == 400)
        #expect(restored.payoutAmount == 1200)
        #expect(restored.sortIndex == 4)
        let selections = (restored.selections ?? []).sorted { $0.sortIndex < $1.sortIndex }
        #expect(selections.count == 2)
        #expect(selections.map(\.ticketType?.persistentModelID) == [umaren.persistentModelID, wide.persistentModelID])
        #expect(selections.map(\.ticketTypeName) == ["馬連", "ワイド"])
        #expect(selections.map(\.selection) == ["1,2,3[BOX]", "1-2"])
        #expect(selections.map(\.unitPrice) == [100, 100])
        #expect(selections.map(\.combinationCount) == [3, 1])
        #expect(selections.map(\.sortIndex) == [0, 1])
    }

    @Test func 券種マスターに無い券種の馬券を復元すると券種なしで券種名は残る() throws {
        let context = container.mainContext
        let race = Race(raceName: "テストレース")
        let ticketType = TicketType(name: "馬連")
        context.insert(race)
        context.insert(ticketType)
        let bet = Bet(race: race, ticketType: ticketType, ticketTypeName: "馬連", selection: "1-2", purchaseAmount: 100)
        context.insert(bet)
        context.insert(BetSelection(bet: bet, ticketType: ticketType, ticketTypeName: "馬連", selection: "1-2"))
        try context.save()
        let snap = BetSnapshot(from: bet)
        (bet.selections ?? []).forEach { context.delete($0) }
        context.delete(bet)
        try context.save()

        snap.restore(into: context, race: race, ticketTypes: [])

        let restored = try #require(try context.fetch(FetchDescriptor<Bet>()).first)
        let sel = try #require(restored.selections?.first)
        #expect(restored.ticketType == nil)
        #expect(restored.ticketTypeName == "馬連")
        #expect(sel.ticketType == nil)
        #expect(sel.ticketTypeName == "馬連")
    }

    @Test func 削除したレースを復元すると出走馬と馬券ごと戻りマスターに結び直されて保存される() throws {
        let context = container.mainContext
        let venue = Venue(name: "東京")
        let ticketType = TicketType(name: "単勝")
        context.insert(venue)
        context.insert(ticketType)
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        let race = Race(
            date: date, venue: venue, raceNumber: 11, raceName: "テストステークス", distance: 2400,
            trackType: "dirt", trackCondition: "重", category: "local", grade: "G1", memo: "メモ",
            firstPlaceHorseNumber: 5, secondPlaceHorseNumber: 2, thirdPlaceHorseNumber: 8, sortIndex: 3,
        )
        context.insert(race)
        context.insert(RaceEntry(race: race, horseNumber: 5, horseName: "テスト馬"))
        let bet = Bet(race: race, ticketType: ticketType, ticketTypeName: "単勝", selection: "5",
                      purchaseAmount: 100, payoutAmount: 350)
        context.insert(bet)
        context.insert(BetSelection(bet: bet, ticketType: ticketType, ticketTypeName: "単勝", selection: "5"))
        try context.save()
        let snap = RaceSnapshot(from: race)
        context.delete(race)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<Race>()).isEmpty)

        snap.restore(into: context)

        #expect(!context.hasChanges)
        let races = try context.fetch(FetchDescriptor<Race>())
        let restored = try #require(races.first)
        #expect(races.count == 1)
        #expect(restored.date == date)
        #expect(restored.venue?.persistentModelID == venue.persistentModelID)
        #expect(restored.raceNumber == 11)
        #expect(restored.raceName == "テストステークス")
        #expect(restored.distance == 2400)
        #expect(restored.trackType == "dirt")
        #expect(restored.trackCondition == "重")
        #expect(restored.category == "local")
        #expect(restored.grade == "G1")
        #expect(restored.memo == "メモ")
        #expect(restored.firstPlaceHorseNumber == 5)
        #expect(restored.secondPlaceHorseNumber == 2)
        #expect(restored.thirdPlaceHorseNumber == 8)
        #expect(restored.sortIndex == 3)
        #expect(restored.entries?.map(\.horseName) == ["テスト馬"])
        let restoredBet = try #require(restored.bets?.first)
        #expect(restored.bets?.count == 1)
        #expect(restoredBet.ticketType?.persistentModelID == ticketType.persistentModelID)
        #expect(restoredBet.payoutAmount == 350)
        #expect(restoredBet.selections?.first?.ticketType?.persistentModelID == ticketType.persistentModelID)
    }

    @Test func 競馬場が削除されたあとにレースを復元すると競馬場なしで戻る() throws {
        let context = container.mainContext
        let venue = Venue(name: "東京")
        context.insert(venue)
        let race = Race(venue: venue, raceName: "テストレース")
        context.insert(race)
        try context.save()
        let snap = RaceSnapshot(from: race)
        context.delete(race)
        context.delete(venue)
        try context.save()

        snap.restore(into: context)

        let restored = try #require(try context.fetch(FetchDescriptor<Race>()).first)
        #expect(restored.venue == nil)
        #expect(restored.raceName == "テストレース")
    }
}
