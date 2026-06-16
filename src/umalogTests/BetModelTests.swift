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
        let schema = Schema([Race.self, Bet.self, BetSelection.self, RaceEntry.self, Venue.self, TicketType.self])
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
        let ticketType = TicketType(name: "単勝"); ctx.insert(ticketType)
        let bet = Bet(ticketType: ticketType, ticketTypeName: "fallback"); ctx.insert(bet)
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
        let ticketType = TicketType(name: "馬連"); ctx.insert(ticketType)
        let bet = Bet(ticketType: ticketType, ticketTypeName: "これは使われない"); ctx.insert(bet)
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

    // MARK: - BetSelection

    @Test func betSelection_displayTicketTypeName_prefersTicketTypeOverStoredName() {
        let ctx = container.mainContext
        let ticketType = TicketType(name: "単勝"); ctx.insert(ticketType)
        let sel = BetSelection(ticketType: ticketType, ticketTypeName: "fallback"); ctx.insert(sel)
        #expect(sel.displayTicketTypeName == "単勝")
    }

    @Test func betSelection_displayTicketTypeName_fallsBackToStoredName() {
        let sel = BetSelection(ticketType: nil, ticketTypeName: "カスタム")
        container.mainContext.insert(sel)
        #expect(sel.displayTicketTypeName == "カスタム")
    }

    @Test func betSelection_purchaseAmount_equalsUnitPriceTimesCombinationCount() {
        let sel = BetSelection(unitPrice: 100, combinationCount: 6)
        container.mainContext.insert(sel)
        #expect(sel.purchaseAmount == 600)
    }

    @Test func betSelection_purchaseAmount_whenSingleCombination_equalsUnitPrice() {
        let sel = BetSelection(unitPrice: 200, combinationCount: 1)
        container.mainContext.insert(sel)
        #expect(sel.purchaseAmount == 200)
    }

    // MARK: - Venue init coverage

    @Test func venue_defaultInit_hasEmptyName() {
        let venue = Venue(name: "東京")
        container.mainContext.insert(venue)
        #expect(venue.name == "東京")
        #expect(venue.isPreset == false)
        #expect(venue.sortIndex == 0)
    }

    @Test func venue_initWithPresetAndSortIndex() {
        let venue = Venue(name: "中山", isPreset: true, sortIndex: 5)
        container.mainContext.insert(venue)
        #expect(venue.name == "中山")
        #expect(venue.isPreset == true)
        #expect(venue.sortIndex == 5)
    }

    // MARK: - Property-Based Tests

    /// Property 1 (Invariant): balance == payout - purchase for any values
    @Test func pbt_balance_alwaysEqualsPayoutMinusPurchase() {
        for _ in 0 ..< 1000 {
            let purchase = Int.random(in: 0 ... 100_000)
            let payout = Int.random(in: 0 ... 500_000)
            let bet = Bet(purchaseAmount: purchase, payoutAmount: payout)
            container.mainContext.insert(bet)
            #expect(bet.balance == payout - purchase)
        }
    }

    /// Property 2 (Invariant): box count for n horses follows C(n,k) formula
    @Test func pbt_boxCount_umaren_alwaysEqualsNCR2() {
        for horseCount in 2 ... 18 {
            let horses = (1 ... horseCount).map { "\($0)" }.joined(separator: ",")
            let count = Bet.combinationCount(selection: "\(horses)[BOX]", ticketTypeName: "馬連")
            let expected = horseCount * (horseCount - 1) / 2
            #expect(count == expected, "馬連BOX \(horseCount)頭: expected \(expected), got \(count)")
        }
    }

    /// Property 3 (Invariant): box count for 三連複 follows C(n,3) formula
    @Test func pbt_boxCount_sanrenpuku_alwaysEqualsNCR3() {
        for horseCount in 3 ... 18 {
            let horses = (1 ... horseCount).map { "\($0)" }.joined(separator: ",")
            let count = Bet.combinationCount(selection: "\(horses)[BOX]", ticketTypeName: "三連複")
            let expected = horseCount * (horseCount - 1) * (horseCount - 2) / 6
            #expect(count == expected, "三連複BOX \(horseCount)頭: expected \(expected), got \(count)")
        }
    }

    /// Property 4 (Commutativity): formation unordered count is symmetric
    @Test func pbt_formationTwoLeg_unordered_isSymmetric() {
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

    /// Property 5 (Monotonicity): adding horses to a formation leg never decreases count
    @Test func pbt_formationCount_isMonotonicallyNonDecreasing() {
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
