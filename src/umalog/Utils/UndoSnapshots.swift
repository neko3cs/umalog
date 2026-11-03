//
//  UndoSnapshots.swift
//  umalog
//
//  Created by neko3cs on 2026/10/31.
//

import Foundation
import SwiftData

/// 出走馬削除の Undo 復元用スナップショット。各プロパティは `RaceEntry` の同名フィールドの写し。
struct EntrySnapshot {
    let horseNumber: Int
    let horseName: String
    let jockeyName: String
    let trainerName: String
    let predictionMark: String?
    let finishPosition: Int?
    let sortIndex: Int

    /// 出走馬からスナップショットを取る。
    /// - Parameter entry: スナップショット対象の出走馬。
    init(from entry: RaceEntry) {
        horseNumber = entry.horseNumber
        horseName = entry.horseName
        jockeyName = entry.jockeyName
        trainerName = entry.trainerName
        predictionMark = entry.predictionMark
        finishPosition = entry.finishPosition
        sortIndex = entry.sortIndex
    }

    /// スナップショットから出走馬を作り直して挿入する。保存はしない。
    /// - Parameters:
    ///   - context: 復元先の ModelContext。
    ///   - race: 復元した出走馬の親レース。
    func restore(into context: ModelContext, race: Race) {
        context.insert(RaceEntry(
            race: race, horseNumber: horseNumber, horseName: horseName,
            jockeyName: jockeyName, trainerName: trainerName,
            predictionMark: predictionMark, finishPosition: finishPosition,
            sortIndex: sortIndex,
        ))
    }
}

/// 馬券削除の Undo 復元用スナップショット。各プロパティは `Bet` の同名フィールドの写しで、
/// 買い目もネストしたスナップショットとして保持する。券種は永続 ID で保持し復元時に再関連付けする。
struct BetSnapshot {
    let ticketTypeId: PersistentIdentifier?
    let ticketTypeName: String
    let selection: String
    let unitPrice: Int
    let purchaseAmount: Int
    let payoutAmount: Int
    let sortIndex: Int
    let selections: [SelectionSnapshot]

    /// 買い目のスナップショット。各プロパティは `BetSelection` の同名フィールドの写し。
    struct SelectionSnapshot {
        let ticketTypeId: PersistentIdentifier?
        let ticketTypeName: String
        let selection: String
        let unitPrice: Int
        let combinationCount: Int
        let sortIndex: Int
    }

    /// 馬券からスナップショットを取る。
    /// - Parameter bet: スナップショット対象の馬券。
    init(from bet: Bet) {
        ticketTypeId = bet.ticketType?.persistentModelID
        ticketTypeName = bet.ticketTypeName
        selection = bet.selection
        unitPrice = bet.unitPrice
        purchaseAmount = bet.purchaseAmount
        payoutAmount = bet.payoutAmount
        sortIndex = bet.sortIndex
        selections = (bet.selections ?? []).map { sel in
            SelectionSnapshot(
                ticketTypeId: sel.ticketType?.persistentModelID, ticketTypeName: sel.ticketTypeName,
                selection: sel.selection, unitPrice: sel.unitPrice,
                combinationCount: sel.combinationCount, sortIndex: sel.sortIndex,
            )
        }
    }

    /// スナップショットから馬券と買い目を作り直して挿入する。保存はしない。
    /// - Parameters:
    ///   - context: 復元先の ModelContext。
    ///   - race: 復元した馬券の親レース。
    ///   - ticketTypes: 券種マスター。永続 ID が一致する券種に再関連付けし、見つからなければ券種なしで復元する。
    func restore(into context: ModelContext, race: Race, ticketTypes: [TicketType]) {
        let ticketType = { (id: PersistentIdentifier?) in
            id.flatMap { id in ticketTypes.first { $0.persistentModelID == id } }
        }
        let bet = Bet(
            race: race, ticketType: ticketType(ticketTypeId),
            ticketTypeName: ticketTypeName, selection: selection,
            unitPrice: unitPrice, purchaseAmount: purchaseAmount,
            payoutAmount: payoutAmount, sortIndex: sortIndex,
        )
        context.insert(bet)
        for sel in selections {
            context.insert(BetSelection(
                bet: bet, ticketType: ticketType(sel.ticketTypeId),
                ticketTypeName: sel.ticketTypeName, selection: sel.selection,
                unitPrice: sel.unitPrice, combinationCount: sel.combinationCount,
                sortIndex: sel.sortIndex,
            ))
        }
    }
}

/// レース削除の Undo 復元用スナップショット。各プロパティは `Race` の同名フィールドの写しで、
/// 子の出走馬・馬券もネストしたスナップショットとして保持する。
struct RaceSnapshot {
    let date: Date
    let venueId: PersistentIdentifier?
    let raceNumber: Int
    let raceName: String
    let distance: Int
    let trackType: String
    let trackCondition: String
    let category: String
    let grade: String
    let memo: String
    let sortIndex: Int
    let firstPlaceHorseNumber: Int
    let secondPlaceHorseNumber: Int
    let thirdPlaceHorseNumber: Int
    let entries: [EntrySnapshot]
    let bets: [BetSnapshot]

    /// レースからスナップショットを取る。
    /// - Parameter race: スナップショット対象のレース。
    init(from race: Race) {
        date = race.date
        venueId = race.venue?.persistentModelID
        raceNumber = race.raceNumber
        raceName = race.raceName
        distance = race.distance
        trackType = race.trackType
        trackCondition = race.trackCondition
        category = race.category
        grade = race.grade
        memo = race.memo
        sortIndex = race.sortIndex
        firstPlaceHorseNumber = race.firstPlaceHorseNumber
        secondPlaceHorseNumber = race.secondPlaceHorseNumber
        thirdPlaceHorseNumber = race.thirdPlaceHorseNumber
        entries = (race.entries ?? []).map { EntrySnapshot(from: $0) }
        bets = (race.bets ?? []).map { BetSnapshot(from: $0) }
    }

    /// スナップショットからレースと子データを再作成して挿入し、保存する。競馬場・券種は永続 ID で既存マスターと再関連付けする。
    /// - Parameter context: 復元先の ModelContext。
    func restore(into context: ModelContext) {
        let allVenues = (try? context.fetch(FetchDescriptor<Venue>())) ?? []
        let allTicketTypes = (try? context.fetch(FetchDescriptor<TicketType>())) ?? []
        let venue = venueId.flatMap { id in allVenues.first(where: { $0.persistentModelID == id }) }
        let race = Race(
            date: date, venue: venue, raceNumber: raceNumber, raceName: raceName,
            distance: distance, trackType: trackType, trackCondition: trackCondition,
            category: category, grade: grade, memo: memo,
            firstPlaceHorseNumber: firstPlaceHorseNumber,
            secondPlaceHorseNumber: secondPlaceHorseNumber,
            thirdPlaceHorseNumber: thirdPlaceHorseNumber,
            sortIndex: sortIndex,
        )
        context.insert(race)
        entries.forEach { $0.restore(into: context, race: race) }
        bets.forEach { $0.restore(into: context, race: race, ticketTypes: allTicketTypes) }
        // 取り消しで復元したレースは新しいレコードになる。自動保存を待つと、レース一覧に出たあとで
        // 一時 ID が恒久 ID に変わり、行が作り直されるため、表示前にここで保存する（Issue #55）
        try? context.save()
    }
}
