//
//  TicketTypeTests.swift
//  umalogTests
//
//  Created by neko3cs on 2026/10/28.
//

import Foundation
import SwiftData
import Testing
@testable import umalog

/// 1 券種分の、買い方ごとの期待点数。
private struct CombinationCase: Sendable, CustomTestStringConvertible {
    /// 券種名。
    let name: String
    /// 通常 `1` の点数。
    let normal: Int
    /// BOX `1,2,3,4[BOX]` の点数。
    let box: Int
    /// フォーメーション `1,2/1,2,3` の点数。
    let formation: Int
    /// 流し `1>2,3,4[流し]` の点数。
    let nagashi: Int

    /// テスト結果に表示する券種名。
    var testDescription: String {
        name
    }
}

/// 全券種の期待点数。
/// 単勝・複勝・応援馬券は 1 頭の券種なので BOX・流しは成立しない（0 点）。応援馬券は単勝と複勝の 2 点。フォーメーションは入力画面で選べないため、
/// 計算上は各軸の積のままになる。
private let combinationCases: [CombinationCase] = [
    .init(name: "単勝", normal: 1, box: 0, formation: 6, nagashi: 0),
    .init(name: "複勝", normal: 1, box: 0, formation: 6, nagashi: 0),
    .init(name: "枠連", normal: 1, box: 6, formation: 3, nagashi: 3),
    .init(name: "馬連", normal: 1, box: 6, formation: 3, nagashi: 3),
    .init(name: "ワイド", normal: 1, box: 6, formation: 3, nagashi: 3),
    .init(name: "馬単", normal: 1, box: 12, formation: 4, nagashi: 3),
    .init(name: "三連複", normal: 1, box: 4, formation: 0, nagashi: 3),
    .init(name: "三連単", normal: 1, box: 24, formation: 0, nagashi: 6),
    .init(name: "枠単", normal: 1, box: 12, formation: 4, nagashi: 3),
    .init(name: "応援馬券", normal: 2, box: 0, formation: 6, nagashi: 0),
]

@MainActor
struct 券種Test {
    let container: ModelContainer

    init() throws {
        let schema = Schema([Race.self, Bet.self, BetSelection.self, RaceEntry.self, Venue.self, TicketType.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    /// 券種マスターを表示順に取得する。
    /// - Returns: 表示順に並べた券種名と表示順の組。
    private func fetchTicketTypes() throws -> [(name: String, sortIndex: Int)] {
        let descriptor = FetchDescriptor<TicketType>(sortBy: [SortDescriptor(\.sortIndex)])
        return try container.mainContext.fetch(descriptor).map { ($0.name, $0.sortIndex) }
    }

    // MARK: - 初期値

    @Test func 券種のデフォルトソート順がゼロである() {
        let ticketType = TicketType(name: "単勝")
        container.mainContext.insert(ticketType)
        #expect(ticketType.sortIndex == 0)
    }

    // MARK: - プリセットの投入

    @Test func 券種マスターが空なら全券種がプリセットの順に追加される() throws {
        let inserted = TicketType.insertMissingPresets(into: container.mainContext)
        #expect(inserted)
        let ticketTypes = try fetchTicketTypes()
        #expect(ticketTypes.map(\.name) == defaultTicketTypeNames.map(\.name))
        #expect(ticketTypes.map(\.sortIndex) == defaultTicketTypeNames.map(\.sortIndex))
    }

    @Test func 既存ユーザーには足りない券種だけが既存の並び順の後ろに追加される() throws {
        let ctx = container.mainContext
        // 旧バージョンのプリセット 8 券種を、ユーザーが並び替えた状態
        let oldNames = ["三連単", "単勝", "複勝", "枠連", "馬連", "ワイド", "馬単", "三連複"]
        for (index, name) in oldNames.enumerated() {
            ctx.insert(TicketType(name: name, sortIndex: index))
        }
        let inserted = TicketType.insertMissingPresets(into: ctx)
        #expect(inserted)
        let ticketTypes = try fetchTicketTypes()
        #expect(ticketTypes.map(\.name) == oldNames + ["枠単", "応援馬券"])
        #expect(ticketTypes.suffix(2).map(\.sortIndex) == [8, 9])
    }

    @Test func 削除済みの券種は既存の表示順の最大値の後ろに追加される() throws {
        let ctx = container.mainContext
        ctx.insert(TicketType(name: "馬連", sortIndex: 3))
        ctx.insert(TicketType(name: "独自の券種", sortIndex: 10))
        TicketType.insertMissingPresets(into: ctx)
        let ticketTypes = try fetchTicketTypes()
        #expect(ticketTypes.count == defaultTicketTypeNames.count + 1)
        #expect(ticketTypes.prefix(2).map(\.name) == ["馬連", "独自の券種"])
        #expect(ticketTypes.dropFirst(2).map(\.sortIndex) == Array(11 ... 19))
        #expect(ticketTypes.count(where: { $0.name == "馬連" }) == 1)
    }

    @Test func 全券種がそろっていれば何も追加しない() throws {
        let ctx = container.mainContext
        TicketType.insertMissingPresets(into: ctx)
        let inserted = TicketType.insertMissingPresets(into: ctx)
        #expect(inserted == false)
        #expect(try fetchTicketTypes().count == defaultTicketTypeNames.count)
    }

    // MARK: - isPreset

    @Test(arguments: defaultTicketTypeNames.map(\.name))
    func アプリが扱う券種はプリセットとみなされる(name: String) {
        let ticketType = TicketType(name: name)
        container.mainContext.insert(ticketType)
        #expect(ticketType.isPreset)
    }

    @Test func 旧設定画面で追加された任意名の券種はプリセットとみなされない() {
        let ticketType = TicketType(name: "WIN5")
        container.mainContext.insert(ticketType)
        #expect(ticketType.isPreset == false)
    }

    // MARK: - 組合せ点数: 全券種

    @Test func 組合せ点数の期待値がすべての券種を網羅している() {
        #expect(combinationCases.map(\.name) == defaultTicketTypeNames.map(\.name))
    }

    @Test(arguments: combinationCases)
    fileprivate func 全券種で組合せ点数が券種の数え方に従う(expected: CombinationCase) {
        let name = expected.name
        #expect(Bet.combinationCount(selection: "1", ticketTypeName: name) == expected.normal)
        #expect(Bet.combinationCount(selection: "1,2,3,4[BOX]", ticketTypeName: name) == expected.box)
        // 2 軸: (1,2)(1,3)(2,1)(2,3) → 順不同なら {1,2}{1,3}{2,3} の 3 点、順序ありなら 4 点
        #expect(Bet.combinationCount(selection: "1,2/1,2,3", ticketTypeName: name) == expected.formation)
        // 軸 1 頭・相手 3 頭: 2 頭の券種は 3 点、三連複は 3C2 = 3 点、三連単（1 着流し）は 3P2 = 6 点
        #expect(Bet.combinationCount(selection: "1>2,3,4[流し]", ticketTypeName: name) == expected.nagashi)
    }

    // MARK: - 枠単

    @Test func `枠単box 3 頭の組合せ数が 6 になる`() {
        // 3P2 = 6
        #expect(Bet.combinationCount(selection: "1,2,3[BOX]", ticketTypeName: "枠単") == 6)
    }

    @Test func 枠単フォーメーションは順序を区別し同じ番号の組だけ除外する() {
        // (1,2)(2,1) = 2 通り
        #expect(Bet.combinationCount(selection: "1,2/1,2", ticketTypeName: "枠単") == 2)
    }

    @Test func 枠単は着順を区別する流しの券種として扱われる() {
        #expect(NagashiSelection.horseCount(ticketTypeName: "枠単") == 2)
        #expect(NagashiSelection.isOrdered(ticketTypeName: "枠単"))
        #expect(Bet.combinationCount(selection: "1>2,3,4[2着流し]", ticketTypeName: "枠単") == 3)
        #expect(Bet.combinationCount(selection: "1>2,3,4[流しマルチ]", ticketTypeName: "枠単") == 6)
    }

    @Test func 枠単の買い目ドラフトは単価と点数から購入額を計算する() {
        let ctx = container.mainContext
        let wakutan = TicketType(name: "枠単", sortIndex: 8); ctx.insert(wakutan)
        let draft = BetSelectionDraft(ticketType: wakutan, selection: "1,2,3[BOX]", unitPrice: 200)
        #expect(draft.combinationCount == 6)
        #expect(draft.purchaseAmount == 1200)
    }

    // MARK: - 応援馬券

    @Test func `応援馬券は単勝と複勝の 2 点として購入額を計算する`() {
        let ctx = container.mainContext
        let ouen = TicketType(name: "応援馬券", sortIndex: 9); ctx.insert(ouen)
        let draft = BetSelectionDraft(ticketType: ouen, selection: "5", unitPrice: 100)
        #expect(draft.combinationCount == 2)
        #expect(draft.purchaseAmount == 200)
    }

    @Test func 応援馬券は流しに対応しない券種として扱われる() {
        #expect(NagashiSelection.horseCount(ticketTypeName: "応援馬券") == nil)
        #expect(NagashiSelection.isOrdered(ticketTypeName: "応援馬券") == false)
    }

    // MARK: - 旧カスタム券種の互換

    @Test func 旧カスタム券種の買い目ドラフトは保存済みの券種名で表示される() {
        let draft = BetSelectionDraft(ticketType: nil, ticketTypeName: "WIN5", selection: "1-2-3-4-5", unitPrice: 100)
        #expect(draft.displayTicketTypeName == "WIN5")
        #expect(draft.purchaseAmount == 100)
    }
}
