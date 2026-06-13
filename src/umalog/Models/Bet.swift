//
//  Bet.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import Foundation
import SwiftData

@Model
final class Bet {
    var race: Race?
    var ticketType: TicketType?
    var ticketTypeName: String = "" // 券種削除時の表示用デノーマライズ
    var selection: String = ""
    var purchaseAmount: Int = 0
    var payoutAmount: Int = 0 // 0 = 未確定
    var sortIndex: Int = 0

    init(
        race: Race? = nil,
        ticketType: TicketType? = nil,
        ticketTypeName: String = "",
        selection: String = "",
        purchaseAmount: Int = 0,
        payoutAmount: Int = 0,
        sortIndex: Int = 0
    ) {
        self.race = race
        self.ticketType = ticketType
        self.ticketTypeName = ticketTypeName
        self.selection = selection
        self.purchaseAmount = purchaseAmount
        self.payoutAmount = payoutAmount
        self.sortIndex = sortIndex
    }

    var balance: Int {
        payoutAmount - purchaseAmount
    }

    var displayTicketTypeName: String {
        ticketType?.name ?? ticketTypeName
    }
}
