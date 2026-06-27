//
//  BetSelection.swift
//  umalog
//
//  Created by neko3cs on 2026/06/16.
//

import Foundation
import SwiftData

@Model
final class BetSelection {
    var bet: Bet?
    var ticketType: TicketType?
    var ticketTypeName: String = ""
    var selection: String = ""
    var unitPrice: Int = 100
    var combinationCount: Int = 1
    var sortIndex: Int = 0

    init(
        bet: Bet? = nil,
        ticketType: TicketType? = nil,
        ticketTypeName: String = "",
        selection: String = "",
        unitPrice: Int = 100,
        combinationCount: Int = 1,
        sortIndex: Int = 0,
    ) {
        self.bet = bet
        self.ticketType = ticketType
        self.ticketTypeName = ticketTypeName
        self.selection = selection
        self.unitPrice = unitPrice
        self.combinationCount = combinationCount
        self.sortIndex = sortIndex
    }

    var displayTicketTypeName: String {
        ticketType?.name ?? ticketTypeName
    }

    var purchaseAmount: Int {
        unitPrice * combinationCount
    }
}
