//
//  RaceModelTests.swift
//  umalog
//
//  Created by neko3cs on 2026/06/12.
//

import Testing
import SwiftData
@testable import umalog

@Suite
struct RaceModelTests {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Race.self, Bet.self, RaceEntry.self, Venue.self, TicketType.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - totalPurchase

    @Test @MainActor func totalPurchase_whenBetsIsNil_returnsZero() throws {
        let container = try makeContainer()
        let race = Race(); container.mainContext.insert(race)
        race.bets = nil
        #expect(race.totalPurchase == 0)
    }

    @Test @MainActor func totalPurchase_whenBetsIsEmpty_returnsZero() throws {
        let container = try makeContainer()
        let race = Race(); container.mainContext.insert(race)
        race.bets = []
        #expect(race.totalPurchase == 0)
    }

    @Test @MainActor func totalPurchase_withSingleBet_returnsPurchaseAmount() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 1000); ctx.insert(bet)
        race.bets = [bet]
        #expect(race.totalPurchase == 1000)
    }

    @Test @MainActor func totalPurchase_withMultipleBets_returnsSum() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet1 = Bet(race: race, purchaseAmount: 1000); ctx.insert(bet1)
        let bet2 = Bet(race: race, purchaseAmount: 500);  ctx.insert(bet2)
        let bet3 = Bet(race: race, purchaseAmount: 200);  ctx.insert(bet3)
        race.bets = [bet1, bet2, bet3]
        #expect(race.totalPurchase == 1700)
    }

    // MARK: - totalPayout

    @Test @MainActor func totalPayout_whenBetsIsNil_returnsZero() throws {
        let container = try makeContainer()
        let race = Race(); container.mainContext.insert(race)
        race.bets = nil
        #expect(race.totalPayout == 0)
    }

    @Test @MainActor func totalPayout_whenAllBetsUnsettled_returnsZero() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet1 = Bet(race: race, purchaseAmount: 1000, payoutAmount: 0); ctx.insert(bet1)
        let bet2 = Bet(race: race, purchaseAmount: 500,  payoutAmount: 0); ctx.insert(bet2)
        race.bets = [bet1, bet2]
        #expect(race.totalPayout == 0)
    }

    @Test @MainActor func totalPayout_withPartiallySettledBets_returnsSumOfPayouts() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet1 = Bet(race: race, purchaseAmount: 1000, payoutAmount: 2500); ctx.insert(bet1)
        let bet2 = Bet(race: race, purchaseAmount: 500,  payoutAmount: 0);    ctx.insert(bet2)
        race.bets = [bet1, bet2]
        #expect(race.totalPayout == 2500)
    }

    @Test @MainActor func totalPayout_withAllSettledBets_returnsSum() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet1 = Bet(race: race, purchaseAmount: 1000, payoutAmount: 2000); ctx.insert(bet1)
        let bet2 = Bet(race: race, purchaseAmount: 500,  payoutAmount: 800);  ctx.insert(bet2)
        race.bets = [bet1, bet2]
        #expect(race.totalPayout == 2800)
    }

    // MARK: - balance

    @Test @MainActor func balance_withNoBets_returnsZero() throws {
        let container = try makeContainer()
        let race = Race(); container.mainContext.insert(race)
        race.bets = []
        #expect(race.balance == 0)
    }

    @Test @MainActor func balance_whenProfit_returnsPositiveValue() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 1000, payoutAmount: 3000); ctx.insert(bet)
        race.bets = [bet]
        #expect(race.balance == 2000)
    }

    @Test @MainActor func balance_whenLoss_returnsNegativeValue() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 1000, payoutAmount: 0); ctx.insert(bet)
        race.bets = [bet]
        #expect(race.balance == -1000)
    }

    @Test @MainActor func balance_whenBreakEven_returnsZero() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 1000, payoutAmount: 1000); ctx.insert(bet)
        race.bets = [bet]
        #expect(race.balance == 0)
    }

    @Test @MainActor func balance_equalsPayoutMinusPurchase() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet1 = Bet(race: race, purchaseAmount: 500, payoutAmount: 1200); ctx.insert(bet1)
        let bet2 = Bet(race: race, purchaseAmount: 300, payoutAmount: 0);    ctx.insert(bet2)
        race.bets = [bet1, bet2]
        #expect(race.balance == race.totalPayout - race.totalPurchase)
    }

    // MARK: - returnRate

    @Test @MainActor func returnRate_whenBetsIsNil_returnsNil() throws {
        let container = try makeContainer()
        let race = Race(); container.mainContext.insert(race)
        race.bets = nil
        #expect(race.returnRate == nil)
    }

    @Test @MainActor func returnRate_whenBetsIsEmpty_returnsNil() throws {
        let container = try makeContainer()
        let race = Race(); container.mainContext.insert(race)
        race.bets = []
        #expect(race.returnRate == nil)
    }

    @Test @MainActor func returnRate_whenTotalPurchaseIsZero_returnsNil() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 0, payoutAmount: 0); ctx.insert(bet)
        race.bets = [bet]
        #expect(race.returnRate == nil)
    }

    @Test @MainActor func returnRate_whenBreakEven_returnsOne() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 1000, payoutAmount: 1000); ctx.insert(bet)
        race.bets = [bet]
        #expect(race.returnRate == 1.0)
    }

    @Test @MainActor func returnRate_whenProfit_returnsGreaterThanOne() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 1000, payoutAmount: 2000); ctx.insert(bet)
        race.bets = [bet]
        let rate = try #require(race.returnRate)
        #expect(rate > 1.0)
        #expect(rate == 2.0)
    }

    @Test @MainActor func returnRate_whenLoss_returnsLessThanOne() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 1000, payoutAmount: 400); ctx.insert(bet)
        race.bets = [bet]
        let rate = try #require(race.returnRate)
        #expect(rate < 1.0)
        #expect(rate == 0.4)
    }

    @Test @MainActor func returnRate_calculatesPayoutDividedByPurchase() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet1 = Bet(race: race, purchaseAmount: 500, payoutAmount: 1500); ctx.insert(bet1)
        let bet2 = Bet(race: race, purchaseAmount: 500, payoutAmount: 0);    ctx.insert(bet2)
        race.bets = [bet1, bet2]
        let rate = try #require(race.returnRate)
        #expect(rate == 1.5)
    }
}
