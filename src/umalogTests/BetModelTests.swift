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
}
