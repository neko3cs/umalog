//
//  BetModelTests.swift
//  umalog
//
//  Created by neko3cs on 2026/06/12.
//

import SwiftData
import Testing
@testable import umalog

@MainActor
struct 馬券モデルTest {
    let container: ModelContainer

    init() throws {
        let schema = Schema([Race.self, Bet.self, BetSelection.self, RaceEntry.self, Venue.self, TicketType.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - balance

    @Test(arguments: [(1000, 2500, 1500), (1000, 0, -1000), (800, 800, 0)])
    func 馬券の収支が払戻額から購入額を引いた値になる(purchase: Int, payout: Int, balance: Int) {
        let bet = Bet(purchaseAmount: purchase, payoutAmount: payout)
        container.mainContext.insert(bet)
        #expect(bet.balance == balance)
    }

    // MARK: - displayTicketTypeName

    @Test func 券種が設定されている場合は保存された券種名より券種の名前が表示される() {
        let ctx = container.mainContext
        let ticketType = TicketType(name: "馬連"); ctx.insert(ticketType)
        let bet = Bet(ticketType: ticketType, ticketTypeName: "これは使われない"); ctx.insert(bet)
        #expect(bet.displayTicketTypeName == "馬連")
    }

    @Test func 券種がnilの場合に保存された券種名が表示される() {
        let bet = Bet(ticketType: nil, ticketTypeName: "カスタム券種")
        container.mainContext.insert(bet)
        #expect(bet.displayTicketTypeName == "カスタム券種")
    }

    // MARK: - unitPrice / combinationCount

    @Test func `デフォルトの単価が 100 円である`() {
        let bet = Bet()
        container.mainContext.insert(bet)
        #expect(bet.unitPrice == 100)
    }

    // MARK: - combinationCount

    @Test(arguments: [
        // 通常: 空は 0 点、馬番を並べただけの買い目は頭数によらず 1 点
        ("", "単勝", 0),
        ("5", "単勝", 1),
        ("1-2", "馬連", 1),
        ("1-2-3", "三連単", 1),
        // BOX: 順不同は nCk、順序ありは nPk。頭数が足りない・券種が未知なら 0 点
        ("1,2,3[BOX]", "馬連", 3),
        ("1,2,3,4[BOX]", "ワイド", 6),
        ("1,2,3[BOX]", "馬単", 6),
        ("1,2,3,4[BOX]", "三連複", 4),
        ("1,2,3,4[BOX]", "三連単", 24),
        ("1,2,3[BOX]", "枠連", 3),
        ("1,2[BOX]", "三連複", 0),
        ("1,2,3[BOX]", "未知の券種", 0),
        // フォーメーション: 各軸の積から同じ馬を含む組を除き、順不同の券種では並び違いを 1 点にまとめる
        ("1/2,3,4", "馬連", 3),
        ("1,2/1,2", "馬連", 1), // (1,2)(2,1) → {1,2}
        ("1,2/1,2", "馬単", 2), // (1,2)(2,1)
        ("1/2,3/4,5,6", "三連単", 6),
        ("1/2,3/4,5,6", "三連複", 6),
        ("1,2/1,2,3/1,2,3", "三連複", 1), // 全頭が異なる組は {1,2,3} だけ
        ("1/2/3", "馬連", 0), // 軸の数が券種の頭数と合わない
    ])
    func 買い目と券種から組合せ点数が決まる(selection: String, ticketTypeName: String, expected: Int) {
        #expect(Bet.combinationCount(selection: selection, ticketTypeName: ticketTypeName) == expected)
    }

    // MARK: - combinationCount（インスタンスプロパティ）

    @Test func インスタンスの組合せ数が買い目と券種を反映する() {
        let bet = Bet(ticketTypeName: "三連複", selection: "1,2,3,4[BOX]")
        container.mainContext.insert(bet)
        #expect(bet.combinationCount == 4)
    }

    // MARK: - BetSelection

    @Test func `買い目のデフォルト単価が 100 円である`() {
        let sel = BetSelection()
        container.mainContext.insert(sel)
        #expect(sel.unitPrice == 100)
    }

    @Test func `買い目のデフォルト購入額が 100 円である`() {
        let sel = BetSelection()
        container.mainContext.insert(sel)
        #expect(sel.purchaseAmount == 100)
    }

    @Test(arguments: [(100, 6, 600), (200, 1, 200), (100, 0, 0)])
    func 買い目の購入額が単価と組合せ数の積になる(unitPrice: Int, combinationCount: Int, expected: Int) {
        let sel = BetSelection(unitPrice: unitPrice, combinationCount: combinationCount)
        container.mainContext.insert(sel)
        #expect(sel.purchaseAmount == expected)
    }

    @Test func 買い目の表示券種名は券種が設定されている場合に優先される() {
        let ctx = container.mainContext
        let ticketType = TicketType(name: "単勝"); ctx.insert(ticketType)
        let sel = BetSelection(ticketType: ticketType, ticketTypeName: "fallback"); ctx.insert(sel)
        #expect(sel.displayTicketTypeName == "単勝")
    }

    @Test func 買い目の表示券種名は券種がnilの場合に保存名にフォールバックする() {
        let sel = BetSelection(ticketType: nil, ticketTypeName: "カスタム")
        container.mainContext.insert(sel)
        #expect(sel.displayTicketTypeName == "カスタム")
    }

    // MARK: - TicketType

    @Test func 券種のデフォルトソート順がゼロである() {
        let ticketType = TicketType(name: "単勝")
        container.mainContext.insert(ticketType)
        #expect(ticketType.sortIndex == 0)
    }

    // MARK: - Venue

    @Test func 競馬場のデフォルト値が正しく設定される() {
        let venue = Venue(name: "東京")
        container.mainContext.insert(venue)
        #expect(venue.name == "東京")
        #expect(venue.category == "central")
        #expect(venue.sortIndex == 0)
    }

    @Test func 競馬場の区分とソート順が設定できる() {
        let venue = Venue(name: "大井", category: "local", sortIndex: 10)
        container.mainContext.insert(venue)
        #expect(venue.name == "大井")
        #expect(venue.category == "local")
        #expect(venue.sortIndex == 10)
    }

    // MARK: - Property-Based Tests

    @Test func 任意の購入額と払戻額で収支が常に払戻マイナス購入に等しい() {
        for _ in 0 ..< 1000 {
            let purchase = Int.random(in: 0 ... 100_000)
            let payout = Int.random(in: 0 ... 500_000)
            let bet = Bet(purchaseAmount: purchase, payoutAmount: payout)
            container.mainContext.insert(bet)
            #expect(bet.balance == payout - purchase)
        }
    }

    @Test func `任意の頭数で馬連boxの組合せ数がn選 2 の公式に従う`() {
        for horseCount in 2 ... 18 {
            let horses = (1 ... horseCount).map { "\($0)" }.joined(separator: ",")
            let count = Bet.combinationCount(selection: "\(horses)[BOX]", ticketTypeName: "馬連")
            let expected = horseCount * (horseCount - 1) / 2
            #expect(count == expected, "馬連BOX \(horseCount)頭: expected \(expected), got \(count)")
        }
    }

    @Test func `任意の頭数で三連複boxの組合せ数がn選 3 の公式に従う`() {
        for horseCount in 3 ... 18 {
            let horses = (1 ... horseCount).map { "\($0)" }.joined(separator: ",")
            let count = Bet.combinationCount(selection: "\(horses)[BOX]", ticketTypeName: "三連複")
            let expected = horseCount * (horseCount - 1) * (horseCount - 2) / 6
            #expect(count == expected, "三連複BOX \(horseCount)頭: expected \(expected), got \(count)")
        }
    }

    @Test func 馬連フォーメーションの組合せ数が脚の順序に依存しない() {
        for _ in 0 ..< 200 {
            let leg1Size = Int.random(in: 1 ... 5)
            let leg2Size = Int.random(in: 1 ... 5)
            let leg1 = Array(1 ... leg1Size)
            let leg2 = Array(6 ... (5 + leg2Size))
            let leg1Str = leg1.map { "\($0)" }.joined(separator: ",")
            let leg2Str = leg2.map { "\($0)" }.joined(separator: ",")
            let sel1 = "\(leg1Str)/\(leg2Str)"
            let sel2 = "\(leg2Str)/\(leg1Str)"
            let count1 = Bet.combinationCount(selection: sel1, ticketTypeName: "馬連")
            let count2 = Bet.combinationCount(selection: sel2, ticketTypeName: "馬連")
            #expect(count1 == count2, "馬連フォーメーションの対称性: \(sel1) vs \(sel2)")
        }
    }

    @Test func 馬連フォーメーションで馬番を追加すると組合せ数が減らない() {
        for baseSize in 1 ... 4 {
            let base = Array(1 ... baseSize)
            let extended = Array(1 ... (baseSize + 1))
            let pivot = Array(10 ... 13).map { "\($0)" }.joined(separator: ",")
            let sel1 = "\(base.map { "\($0)" }.joined(separator: ","))/\(pivot)"
            let sel2 = "\(extended.map { "\($0)" }.joined(separator: ","))/\(pivot)"
            let count1 = Bet.combinationCount(selection: sel1, ticketTypeName: "馬連")
            let count2 = Bet.combinationCount(selection: sel2, ticketTypeName: "馬連")
            #expect(count2 >= count1, "馬番を追加したフォーメーションは組合せ数が減らない: \(sel1) vs \(sel2)")
        }
    }
}
