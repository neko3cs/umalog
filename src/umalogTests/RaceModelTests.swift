//
//  RaceModelTests.swift
//  umalog
//
//  Created by neko3cs on 2026/06/12.
//

import Foundation
import SwiftData
import Testing
@testable import umalog

@MainActor
struct RaceModelTests {
    let container: ModelContainer

    init() throws {
        let schema = Schema([Race.self, Bet.self, BetSelection.self, RaceEntry.self, Venue.self, TicketType.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - totalPurchase

    @Test func totalPurchase_whenBetsIsNil_returnsZero() {
        let race = Race(); container.mainContext.insert(race)
        race.bets = nil
        #expect(race.totalPurchase == 0)
    }

    @Test func totalPurchase_whenBetsIsEmpty_returnsZero() {
        let race = Race(); container.mainContext.insert(race)
        race.bets = []
        #expect(race.totalPurchase == 0)
    }

    @Test func totalPurchase_withSingleBet_returnsPurchaseAmount() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 1000); ctx.insert(bet)
        race.bets = [bet]
        #expect(race.totalPurchase == 1000)
    }

    @Test func totalPurchase_withMultipleBets_returnsSum() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet1 = Bet(race: race, purchaseAmount: 1000); ctx.insert(bet1)
        let bet2 = Bet(race: race, purchaseAmount: 500); ctx.insert(bet2)
        let bet3 = Bet(race: race, purchaseAmount: 200); ctx.insert(bet3)
        race.bets = [bet1, bet2, bet3]
        #expect(race.totalPurchase == 1700)
    }

    // MARK: - totalPayout

    @Test func totalPayout_whenBetsIsNil_returnsZero() {
        let race = Race(); container.mainContext.insert(race)
        race.bets = nil
        #expect(race.totalPayout == 0)
    }

    @Test func totalPayout_whenAllBetsUnsettled_returnsZero() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet1 = Bet(race: race, purchaseAmount: 1000, payoutAmount: 0); ctx.insert(bet1)
        let bet2 = Bet(race: race, purchaseAmount: 500, payoutAmount: 0); ctx.insert(bet2)
        race.bets = [bet1, bet2]
        #expect(race.totalPayout == 0)
    }

    @Test func totalPayout_withPartiallySettledBets_returnsSumOfPayouts() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet1 = Bet(race: race, purchaseAmount: 1000, payoutAmount: 2500); ctx.insert(bet1)
        let bet2 = Bet(race: race, purchaseAmount: 500, payoutAmount: 0); ctx.insert(bet2)
        race.bets = [bet1, bet2]
        #expect(race.totalPayout == 2500)
    }

    @Test func totalPayout_withAllSettledBets_returnsSum() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet1 = Bet(race: race, purchaseAmount: 1000, payoutAmount: 2000); ctx.insert(bet1)
        let bet2 = Bet(race: race, purchaseAmount: 500, payoutAmount: 800); ctx.insert(bet2)
        race.bets = [bet1, bet2]
        #expect(race.totalPayout == 2800)
    }

    // MARK: - balance

    @Test func balance_withNoBets_returnsZero() {
        let race = Race(); container.mainContext.insert(race)
        race.bets = []
        #expect(race.balance == 0)
    }

    @Test func balance_whenProfit_returnsPositiveValue() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 1000, payoutAmount: 3000); ctx.insert(bet)
        race.bets = [bet]
        #expect(race.balance == 2000)
    }

    @Test func balance_whenLoss_returnsNegativeValue() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 1000, payoutAmount: 0); ctx.insert(bet)
        race.bets = [bet]
        #expect(race.balance == -1000)
    }

    @Test func balance_whenBreakEven_returnsZero() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 1000, payoutAmount: 1000); ctx.insert(bet)
        race.bets = [bet]
        #expect(race.balance == 0)
    }

    @Test func balance_equalsPayoutMinusPurchase() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet1 = Bet(race: race, purchaseAmount: 500, payoutAmount: 1200); ctx.insert(bet1)
        let bet2 = Bet(race: race, purchaseAmount: 300, payoutAmount: 0); ctx.insert(bet2)
        race.bets = [bet1, bet2]
        #expect(race.balance == race.totalPayout - race.totalPurchase)
    }

    // MARK: - returnRate

    @Test func returnRate_whenBetsIsNil_returnsNil() {
        let race = Race(); container.mainContext.insert(race)
        race.bets = nil
        #expect(race.returnRate == nil)
    }

    @Test func returnRate_whenBetsIsEmpty_returnsNil() {
        let race = Race(); container.mainContext.insert(race)
        race.bets = []
        #expect(race.returnRate == nil)
    }

    @Test func returnRate_whenTotalPurchaseIsZero_returnsNil() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 0, payoutAmount: 0); ctx.insert(bet)
        race.bets = [bet]
        #expect(race.returnRate == nil)
    }

    @Test func returnRate_whenBreakEven_returnsOne() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 1000, payoutAmount: 1000); ctx.insert(bet)
        race.bets = [bet]
        #expect(race.returnRate == 1.0)
    }

    @Test func returnRate_whenProfit_returnsGreaterThanOne() throws {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 1000, payoutAmount: 2000); ctx.insert(bet)
        race.bets = [bet]
        let rate = try #require(race.returnRate)
        #expect(rate > 1.0)
        #expect(rate == 2.0)
    }

    @Test func returnRate_whenLoss_returnsLessThanOne() throws {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 1000, payoutAmount: 400); ctx.insert(bet)
        race.bets = [bet]
        let rate = try #require(race.returnRate)
        #expect(rate < 1.0)
        #expect(rate == 0.4)
    }

    @Test func returnRate_calculatesPayoutDividedByPurchase() throws {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet1 = Bet(race: race, purchaseAmount: 500, payoutAmount: 1500); ctx.insert(bet1)
        let bet2 = Bet(race: race, purchaseAmount: 500, payoutAmount: 0); ctx.insert(bet2)
        race.bets = [bet1, bet2]
        let rate = try #require(race.returnRate)
        #expect(rate == 1.5)
    }

    // MARK: - finishPosition

    @Test func finishPosition_whenHorseIsFirst_returnsOne() {
        let race = Race(firstPlaceHorseNumber: 5, secondPlaceHorseNumber: 3, thirdPlaceHorseNumber: 8)
        container.mainContext.insert(race)
        #expect(race.finishPosition(forHorseNumber: 5) == 1)
    }

    @Test func finishPosition_whenHorseIsSecond_returnsTwo() {
        let race = Race(firstPlaceHorseNumber: 5, secondPlaceHorseNumber: 3, thirdPlaceHorseNumber: 8)
        container.mainContext.insert(race)
        #expect(race.finishPosition(forHorseNumber: 3) == 2)
    }

    @Test func finishPosition_whenHorseIsThird_returnsThree() {
        let race = Race(firstPlaceHorseNumber: 5, secondPlaceHorseNumber: 3, thirdPlaceHorseNumber: 8)
        container.mainContext.insert(race)
        #expect(race.finishPosition(forHorseNumber: 8) == 3)
    }

    @Test func finishPosition_whenHorseIsNotPlaced_returnsNil() {
        let race = Race(firstPlaceHorseNumber: 5, secondPlaceHorseNumber: 3, thirdPlaceHorseNumber: 8)
        container.mainContext.insert(race)
        #expect(race.finishPosition(forHorseNumber: 1) == nil)
    }

    // MARK: - Property-Based Tests

    /// Property 1 (Invariant): totalBalance == sum(payout - purchase) for any bets
    @Test func pbt_totalBalance_equalsPayoutMinusPurchaseSummedOverAllBets() {
        let ctx = container.mainContext
        for _ in 0 ..< 500 {
            let race = Race(); ctx.insert(race)
            let betCount = Int.random(in: 1 ... 10)
            var bets: [Bet] = []
            var expected = 0
            for _ in 0 ..< betCount {
                let purchase = Int.random(in: 100 ... 10000)
                let payout = Int.random(in: 0 ... 50000)
                let bet = Bet(race: race, purchaseAmount: purchase, payoutAmount: payout)
                ctx.insert(bet)
                bets.append(bet)
                expected += payout - purchase
            }
            race.bets = bets
            #expect(race.balance == expected)
        }
    }

    /// Property 2 (Structural induction): balance == totalPayout - totalPurchase
    @Test func pbt_balance_equalsPayoutMinusPurchaseForRace() {
        let ctx = container.mainContext
        for _ in 0 ..< 500 {
            let race = Race(); ctx.insert(race)
            let betCount = Int.random(in: 1 ... 8)
            var bets: [Bet] = []
            for _ in 0 ..< betCount {
                let purchase = Int.random(in: 100 ... 5000)
                let payout = Int.random(in: 0 ... 20000)
                let bet = Bet(race: race, purchaseAmount: purchase, payoutAmount: payout)
                ctx.insert(bet)
                bets.append(bet)
            }
            race.bets = bets
            #expect(race.balance == race.totalPayout - race.totalPurchase)
        }
    }

    /// Property 3 (Oracle): returnRate when payout == purchase is exactly 1.0
    @Test func pbt_returnRate_whenPayoutEqualsPurchase_isExactlyOne() {
        let ctx = container.mainContext
        for _ in 0 ..< 200 {
            let amount = Int.random(in: 100 ... 100_000)
            let race = Race(); ctx.insert(race)
            let bet = Bet(race: race, purchaseAmount: amount, payoutAmount: amount)
            ctx.insert(bet)
            race.bets = [bet]
            #expect(race.returnRate == 1.0)
        }
    }

    // MARK: - Undo Manager

    @Test func undoManager_canBeAssignedToModelContext() {
        let ctx = container.mainContext
        let undoManager = UndoManager()
        ctx.undoManager = undoManager
        #expect(ctx.undoManager === undoManager)
    }

    @Test func undoManager_canRegisterAndCallUndoAction() {
        let undoManager = UndoManager()
        var value = 0
        undoManager.registerUndo(withTarget: undoManager as AnyObject) { _ in value = 1 }
        undoManager.undo()
        #expect(value == 1)
    }

    @Test func undoManager_canUndoAndRedoPropertyChange() throws {
        let ctx = container.mainContext
        let undoManager = UndoManager()
        ctx.undoManager = undoManager

        let race = Race(raceNumber: 1, raceName: "before")
        ctx.insert(race)

        undoManager.beginUndoGrouping()
        race.raceName = "after"
        undoManager.endUndoGrouping()

        #expect(race.raceName == "after")
        undoManager.undo()
        #expect(race.raceName == "before")
        undoManager.redo()
        #expect(race.raceName == "after")
    }
}
