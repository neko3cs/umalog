//
//  BetSelection.swift
//  umalog
//
//  Created by neko3cs on 2026/06/16.
//

import Foundation
import SwiftData

/// 馬券 1 枚に含まれる個々の買い目を表す SwiftData モデル。
@Model
final class BetSelection {
    /// 親の馬券。
    var bet: Bet?
    /// 券種。マスターから削除された場合に備えて `ticketTypeName` も併せて保存する。
    var ticketType: TicketType?
    /// 券種名。`ticketType` が nil のときの表示にも使う。
    var ticketTypeName: String = ""
    /// 買い目文字列（例: `"1-2-3"` / `"1,2,3[BOX]"` / `"1,2/3,4,5"`）。
    var selection: String = ""
    /// 1 口あたりの金額（円）。
    var unitPrice: Int = 100
    /// 組合せ点数。
    var combinationCount: Int = 1
    /// 表示順。CloudKit 互換のため ordered relationship の代わりに使う。
    var sortIndex: Int = 0

    /// 買い目を生成する。
    /// - Parameters:
    ///   - bet: 親の馬券。
    ///   - ticketType: 券種。
    ///   - ticketTypeName: 券種名。
    ///   - selection: 買い目文字列。
    ///   - unitPrice: 1 口あたりの金額。
    ///   - combinationCount: 組合せ点数。
    ///   - sortIndex: 表示順。
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

    /// 表示用の券種名。券種マスターがあればその名前、なければ保存済みの券種名を返す。
    var displayTicketTypeName: String {
        ticketType?.name ?? ticketTypeName
    }

    /// この買い目の購入額（単価 × 組合せ点数）。
    var purchaseAmount: Int {
        unitPrice * combinationCount
    }
}
