//
//  BetModelTests.swift
//  umalog
//
//  Created by neko3cs on 2026/06/12.
//

import Testing
import SwiftData
@testable import umalog

@Suite
struct BetModelTests {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Race.self, Bet.self, RaceEntry.self, Venue.self, TicketType.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - balance

    @Test @MainActor func balance_whenProfit_returnsPositiveValue() throws {
        let container = try makeContainer()
        let bet = Bet(purchaseAmount: 1000, payoutAmount: 2500)
        container.mainContext.insert(bet)
        #expect(bet.balance == 1500)
    }

    @Test @MainActor func balance_whenLoss_returnsNegativeValue() throws {
        let container = try makeContainer()
        let bet = Bet(purchaseAmount: 1000, payoutAmount: 0)
        container.mainContext.insert(bet)
        #expect(bet.balance == -1000)
    }

    @Test @MainActor func balance_whenBreakEven_returnsZero() throws {
        let container = try makeContainer()
        let bet = Bet(purchaseAmount: 800, payoutAmount: 800)
        container.mainContext.insert(bet)
        #expect(bet.balance == 0)
    }

    @Test @MainActor func balance_equalsPayoutMinusPurchase() throws {
        let container = try makeContainer()
        let bet = Bet(purchaseAmount: 300, payoutAmount: 750)
        container.mainContext.insert(bet)
        #expect(bet.balance == bet.payoutAmount - bet.purchaseAmount)
    }

    // MARK: - displayTicketTypeName

    @Test @MainActor func displayTicketTypeName_whenTicketTypeIsSet_returnsTicketTypeName() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let tt = TicketType(name: "単勝"); ctx.insert(tt)
        let bet = Bet(ticketType: tt, ticketTypeName: "fallback"); ctx.insert(bet)
        #expect(bet.displayTicketTypeName == "単勝")
    }

    @Test @MainActor func displayTicketTypeName_whenTicketTypeIsNil_returnsStoredName() throws {
        let container = try makeContainer()
        let bet = Bet(ticketType: nil, ticketTypeName: "カスタム券種")
        container.mainContext.insert(bet)
        #expect(bet.displayTicketTypeName == "カスタム券種")
    }

    @Test @MainActor func displayTicketTypeName_whenBothNilAndEmpty_returnsEmpty() throws {
        let container = try makeContainer()
        let bet = Bet(ticketType: nil, ticketTypeName: "")
        container.mainContext.insert(bet)
        #expect(bet.displayTicketTypeName == "")
    }

    @Test @MainActor func displayTicketTypeName_prefersTicketTypeOverStoredName() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let tt = TicketType(name: "馬連"); ctx.insert(tt)
        let bet = Bet(ticketType: tt, ticketTypeName: "これは使われない"); ctx.insert(bet)
        #expect(bet.displayTicketTypeName == "馬連")
        #expect(bet.displayTicketTypeName != "これは使われない")
    }
}
