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

    @Test func 払戻が購入より多い場合に収支がプラスになる() {
        let bet = Bet(purchaseAmount: 1000, payoutAmount: 2500)
        container.mainContext.insert(bet)
        #expect(bet.balance == 1500)
    }

    @Test func 払戻がゼロの場合に収支がマイナスになる() {
        let bet = Bet(purchaseAmount: 1000, payoutAmount: 0)
        container.mainContext.insert(bet)
        #expect(bet.balance == -1000)
    }

    @Test func 払戻と購入が同額の場合に収支がゼロになる() {
        let bet = Bet(purchaseAmount: 800, payoutAmount: 800)
        container.mainContext.insert(bet)
        #expect(bet.balance == 0)
    }

    // MARK: - displayTicketTypeName

    @Test func 券種が設定されている場合に券種名が表示される() {
        let ctx = container.mainContext
        let ticketType = TicketType(name: "単勝"); ctx.insert(ticketType)
        let bet = Bet(ticketType: ticketType, ticketTypeName: "fallback"); ctx.insert(bet)
        #expect(bet.displayTicketTypeName == "単勝")
    }

    @Test func 券種がnilの場合に保存された券種名が表示される() {
        let bet = Bet(ticketType: nil, ticketTypeName: "カスタム券種")
        container.mainContext.insert(bet)
        #expect(bet.displayTicketTypeName == "カスタム券種")
    }

    @Test func 券種が設定されている場合は保存された券種名より優先される() {
        let ctx = container.mainContext
        let ticketType = TicketType(name: "馬連"); ctx.insert(ticketType)
        let bet = Bet(ticketType: ticketType, ticketTypeName: "これは使われない"); ctx.insert(bet)
        #expect(bet.displayTicketTypeName == "馬連")
        #expect(bet.displayTicketTypeName != "これは使われない")
    }

    // MARK: - unitPrice / combinationCount

    @Test func デフォルトの単価が100円である() {
        let bet = Bet()
        container.mainContext.insert(bet)
        #expect(bet.unitPrice == 100)
    }

    // MARK: - combinationCount: 通常

    @Test func 買い目が空の場合に組合せ数がゼロになる() {
        #expect(Bet.combinationCount(selection: "", ticketTypeName: "単勝") == 0)
    }

    @Test func 単一馬番の場合に組合せ数が1になる() {
        #expect(Bet.combinationCount(selection: "5", ticketTypeName: "単勝") == 1)
    }

    @Test func ハイフン区切り2頭の場合に組合せ数が1になる() {
        #expect(Bet.combinationCount(selection: "1-2", ticketTypeName: "馬連") == 1)
    }

    @Test func ハイフン区切り3頭の場合に組合せ数が1になる() {
        #expect(Bet.combinationCount(selection: "1-2-3", ticketTypeName: "三連単") == 1)
    }

    // MARK: - combinationCount: BOX

    @Test func 馬連BOX3頭の組合せ数が3になる() {
        // 3C2 = 3
        #expect(Bet.combinationCount(selection: "1,2,3[BOX]", ticketTypeName: "馬連") == 3)
    }

    @Test func ワイドBOX4頭の組合せ数が6になる() {
        // 4C2 = 6
        #expect(Bet.combinationCount(selection: "1,2,3,4[BOX]", ticketTypeName: "ワイド") == 6)
    }

    @Test func 馬単BOX3頭の組合せ数が6になる() {
        // 3P2 = 6
        #expect(Bet.combinationCount(selection: "1,2,3[BOX]", ticketTypeName: "馬単") == 6)
    }

    @Test func 三連複BOX4頭の組合せ数が4になる() {
        // 4C3 = 4
        #expect(Bet.combinationCount(selection: "1,2,3,4[BOX]", ticketTypeName: "三連複") == 4)
    }

    @Test func 三連単BOX4頭の組合せ数が24になる() {
        // 4P3 = 24
        #expect(Bet.combinationCount(selection: "1,2,3,4[BOX]", ticketTypeName: "三連単") == 24)
    }

    @Test func 枠連BOX3頭の組合せ数が3になる() {
        #expect(Bet.combinationCount(selection: "1,2,3[BOX]", ticketTypeName: "枠連") == 3)
    }

    @Test func 三連複BOX2頭の組合せ数がゼロになる() {
        // 三連複に2頭BOXは不成立
        #expect(Bet.combinationCount(selection: "1,2[BOX]", ticketTypeName: "三連複") == 0)
    }

    @Test func 未知の券種のBOX組合せ数がゼロになる() {
        #expect(Bet.combinationCount(selection: "1,2,3[BOX]", ticketTypeName: "未知の券種") == 0)
    }

    // MARK: - combinationCount: フォーメーション

    @Test func 馬連フォーメーション1軸3頭の組合せ数が3になる() {
        // 1×3 = 3、重複なし
        #expect(Bet.combinationCount(selection: "1/2,3,4", ticketTypeName: "馬連") == 3)
    }

    @Test func 馬連フォーメーションで同一馬番ペアが除外される() {
        // (1,1),(1,2),(2,1),(2,2) → 順不同で {1,2} のみ
        #expect(Bet.combinationCount(selection: "1,2/1,2", ticketTypeName: "馬連") == 1)
    }

    @Test func 馬単フォーメーションで同一馬番ペアが除外され順序考慮の数になる() {
        // (1,2)(2,1) = 2 通り（順序あり）
        #expect(Bet.combinationCount(selection: "1,2/1,2", ticketTypeName: "馬単") == 2)
    }

    @Test func 三連単フォーメーション1軸2x3の組合せ数が6になる() {
        // 1×2×3 = 6、軸とそれ以外がぶつからなければそのまま
        #expect(Bet.combinationCount(selection: "1/2,3/4,5,6", ticketTypeName: "三連単") == 6)
    }

    @Test func 三連複フォーメーション1軸2x3の組合せ数が6になる() {
        // 順不同だが各馬がユニークなので 1×2×3 = 6
        #expect(Bet.combinationCount(selection: "1/2,3/4,5,6", ticketTypeName: "三連複") == 6)
    }

    @Test func 三連複フォーメーションで重複が除外される() {
        // (1,2,3)(1,3,2)(2,1,3)... が重複扱いで集約される
        let count = Bet.combinationCount(selection: "1,2/1,2,3/1,2,3", ticketTypeName: "三連複")
        // 1st leg=[1,2], 2nd leg=[1,2,3], 3rd leg=[1,2,3]
        // unordered & all distinct な集合: {1,2,3} のみ → 1
        #expect(count == 1)
    }

    @Test func 馬連フォーメーションで脚が不足している場合にゼロになる() {
        #expect(Bet.combinationCount(selection: "1/2/3", ticketTypeName: "馬連") == 0)
    }

    // MARK: - combinationCount（インスタンスプロパティ）

    @Test func インスタンスの組合せ数が買い目と券種を反映する() {
        let bet = Bet(ticketTypeName: "三連複", selection: "1,2,3,4[BOX]")
        container.mainContext.insert(bet)
        #expect(bet.combinationCount == 4)
    }

    // MARK: - BetSelection

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

    @Test func 買い目の購入額が単価と組合せ数の積になる() {
        let sel = BetSelection(unitPrice: 100, combinationCount: 6)
        container.mainContext.insert(sel)
        #expect(sel.purchaseAmount == 600)
    }

    @Test func 買い目の購入額が組合せ数1の場合に単価に等しい() {
        let sel = BetSelection(unitPrice: 200, combinationCount: 1)
        container.mainContext.insert(sel)
        #expect(sel.purchaseAmount == 200)
    }

    // MARK: - Venue

    @Test func 競馬場のデフォルト値が正しく設定される() {
        let venue = Venue(name: "東京")
        container.mainContext.insert(venue)
        #expect(venue.name == "東京")
        #expect(venue.isPreset == false)
        #expect(venue.sortIndex == 0)
    }

    @Test func 競馬場のプリセットとソート順が設定できる() {
        let venue = Venue(name: "中山", isPreset: true, sortIndex: 5)
        container.mainContext.insert(venue)
        #expect(venue.name == "中山")
        #expect(venue.isPreset == true)
        #expect(venue.sortIndex == 5)
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

    @Test func 任意の頭数で馬連BOXの組合せ数がn選2の公式に従う() {
        for horseCount in 2 ... 18 {
            let horses = (1 ... horseCount).map { "\($0)" }.joined(separator: ",")
            let count = Bet.combinationCount(selection: "\(horses)[BOX]", ticketTypeName: "馬連")
            let expected = horseCount * (horseCount - 1) / 2
            #expect(count == expected, "馬連BOX \(horseCount)頭: expected \(expected), got \(count)")
        }
    }

    @Test func 任意の頭数で三連複BOXの組合せ数がn選3の公式に従う() {
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
