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
struct BetModelTests {
    let container: ModelContainer

    init() throws {
        let schema = Schema([Race.self, Bet.self, RaceEntry.self, Venue.self, TicketType.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - balance

    @Test func balance_whenProfit_returnsPositiveValue() {
        let bet = Bet(purchaseAmount: 1000, payoutAmount: 2500)
        container.mainContext.insert(bet)
        #expect(bet.balance == 1500)
    }

    @Test func balance_whenLoss_returnsNegativeValue() {
        let bet = Bet(purchaseAmount: 1000, payoutAmount: 0)
        container.mainContext.insert(bet)
        #expect(bet.balance == -1000)
    }

    @Test func balance_whenBreakEven_returnsZero() {
        let bet = Bet(purchaseAmount: 800, payoutAmount: 800)
        container.mainContext.insert(bet)
        #expect(bet.balance == 0)
    }

    @Test func balance_equalsPayoutMinusPurchase() {
        let bet = Bet(purchaseAmount: 300, payoutAmount: 750)
        container.mainContext.insert(bet)
        #expect(bet.balance == bet.payoutAmount - bet.purchaseAmount)
    }

    // MARK: - displayTicketTypeName

    @Test func displayTicketTypeName_whenTicketTypeIsSet_returnsTicketTypeName() {
        let ctx = container.mainContext
        let tt = TicketType(name: "単勝"); ctx.insert(tt)
        let bet = Bet(ticketType: tt, ticketTypeName: "fallback"); ctx.insert(bet)
        #expect(bet.displayTicketTypeName == "単勝")
    }

    @Test func displayTicketTypeName_whenTicketTypeIsNil_returnsStoredName() {
        let bet = Bet(ticketType: nil, ticketTypeName: "カスタム券種")
        container.mainContext.insert(bet)
        #expect(bet.displayTicketTypeName == "カスタム券種")
    }

    @Test func displayTicketTypeName_whenBothNilAndEmpty_returnsEmpty() {
        let bet = Bet(ticketType: nil, ticketTypeName: "")
        container.mainContext.insert(bet)
        #expect(bet.displayTicketTypeName == "")
    }

    @Test func displayTicketTypeName_prefersTicketTypeOverStoredName() {
        let ctx = container.mainContext
        let tt = TicketType(name: "馬連"); ctx.insert(tt)
        let bet = Bet(ticketType: tt, ticketTypeName: "これは使われない"); ctx.insert(bet)
        #expect(bet.displayTicketTypeName == "馬連")
        #expect(bet.displayTicketTypeName != "これは使われない")
    }

    // MARK: - unitPrice / combinationCount

    @Test func defaultUnitPrice_is100() {
        let bet = Bet()
        container.mainContext.insert(bet)
        #expect(bet.unitPrice == 100)
    }

    // MARK: - combinationCount: empty / normal

    @Test func combinationCount_whenSelectionIsEmpty_returnsZero() {
        #expect(Bet.combinationCount(selection: "", ticketTypeName: "単勝") == 0)
    }

    @Test func combinationCount_whenSingleNumber_returnsOne() {
        #expect(Bet.combinationCount(selection: "5", ticketTypeName: "単勝") == 1)
    }

    @Test func combinationCount_whenTwoNumbersHyphen_returnsOne() {
        #expect(Bet.combinationCount(selection: "1-2", ticketTypeName: "馬連") == 1)
    }

    @Test func combinationCount_whenThreeNumbersHyphen_returnsOne() {
        #expect(Bet.combinationCount(selection: "1-2-3", ticketTypeName: "三連単") == 1)
    }

    // MARK: - combinationCount: box

    @Test func combinationCount_boxUmaren_3horses_returns3() {
        // 3C2 = 3
        #expect(Bet.combinationCount(selection: "1,2,3[BOX]", ticketTypeName: "馬連") == 3)
    }

    @Test func combinationCount_boxWide_4horses_returns6() {
        // 4C2 = 6
        #expect(Bet.combinationCount(selection: "1,2,3,4[BOX]", ticketTypeName: "ワイド") == 6)
    }

    @Test func combinationCount_boxUmatan_3horses_returns6() {
        // 3P2 = 6
        #expect(Bet.combinationCount(selection: "1,2,3[BOX]", ticketTypeName: "馬単") == 6)
    }

    @Test func combinationCount_boxSanrenpuku_4horses_returns4() {
        // 4C3 = 4
        #expect(Bet.combinationCount(selection: "1,2,3,4[BOX]", ticketTypeName: "三連複") == 4)
    }

    @Test func combinationCount_boxSanrentan_4horses_returns24() {
        // 4P3 = 24
        #expect(Bet.combinationCount(selection: "1,2,3,4[BOX]", ticketTypeName: "三連単") == 24)
    }

    @Test func combinationCount_boxWakuren_3horses_returns3() {
        #expect(Bet.combinationCount(selection: "1,2,3[BOX]", ticketTypeName: "枠連") == 3)
    }

    @Test func combinationCount_boxSanrenpuku_2horses_returnsZero() {
        // 三連複に2頭BOXは不成立
        #expect(Bet.combinationCount(selection: "1,2[BOX]", ticketTypeName: "三連複") == 0)
    }

    @Test func combinationCount_boxUnknownTicketType_returnsZero() {
        #expect(Bet.combinationCount(selection: "1,2,3[BOX]", ticketTypeName: "未知の券種") == 0)
    }

    // MARK: - combinationCount: formation

    @Test func combinationCount_formationUmaren_1axis_3second_returns3() {
        // 1×3 = 3、重複なし
        #expect(Bet.combinationCount(selection: "1/2,3,4", ticketTypeName: "馬連") == 3)
    }

    @Test func combinationCount_formationUmaren_excludesSelfPairs() {
        // (1,1),(1,2),(2,1),(2,2) → 順不同で {1,2} のみ
        #expect(Bet.combinationCount(selection: "1,2/1,2", ticketTypeName: "馬連") == 1)
    }

    @Test func combinationCount_formationUmatan_excludesSelfPairs_returnsOrderedCount() {
        // (1,2)(2,1) = 2 通り（順序あり）
        #expect(Bet.combinationCount(selection: "1,2/1,2", ticketTypeName: "馬単") == 2)
    }

    @Test func combinationCount_formationSanrentan_1axis_2x3_returns6() {
        // 1×2×3 = 6、軸とそれ以外がぶつからなければそのまま
        #expect(Bet.combinationCount(selection: "1/2,3/4,5,6", ticketTypeName: "三連単") == 6)
    }

    @Test func combinationCount_formationSanrenpuku_1axis_2x3_returns6() {
        // 順不同だが各馬がユニークなので 1×2×3 = 6
        #expect(Bet.combinationCount(selection: "1/2,3/4,5,6", ticketTypeName: "三連複") == 6)
    }

    @Test func combinationCount_formationSanrenpuku_overlap_dedupes() {
        // (1,2,3)(1,3,2)(2,1,3)... が重複扱いで集約される
        let count = Bet.combinationCount(selection: "1,2/1,2,3/1,2,3", ticketTypeName: "三連複")
        // 候補triplesから重複を除いた数
        // 1st leg=[1,2], 2nd leg=[1,2,3], 3rd leg=[1,2,3]
        // unordered & all distinct な集合: {1,2,3} のみ → 1
        #expect(count == 1)
    }

    @Test func combinationCount_formationTwoLeg_lessThanTwoLegs_returnsZero() {
        // 1軸しかない場合（不正フォーマット）
        // selection "1" は normal 扱いで 1 を返すが、"/1" のような不正は別経路。
        // ここではフォーメーション形式かつ leg=1 のケースを想定外として扱う
        #expect(Bet.combinationCount(selection: "1/2/3", ticketTypeName: "馬連") == 0)
    }

    // MARK: - combinationCount via instance property

    @Test func combinationCountProperty_reflectsSelectionAndTicketType() {
        let bet = Bet(ticketTypeName: "三連複", selection: "1,2,3,4[BOX]")
        container.mainContext.insert(bet)
        #expect(bet.combinationCount == 4)
    }
}
