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
    @Relationship(deleteRule: .cascade, inverse: \BetSelection.bet)
    var selections: [BetSelection]?
    // Legacy fields kept for data migration and backward-compat CSV import
    var ticketType: TicketType?
    var ticketTypeName: String = ""
    var selection: String = ""
    var unitPrice: Int = 100
    var purchaseAmount: Int = 0
    var payoutAmount: Int = 0 // 0 = 未確定
    var sortIndex: Int = 0

    init(
        race: Race? = nil,
        ticketType: TicketType? = nil,
        ticketTypeName: String = "",
        selection: String = "",
        unitPrice: Int = 100,
        purchaseAmount: Int = 0,
        payoutAmount: Int = 0,
        sortIndex: Int = 0
    ) {
        self.race = race
        self.ticketType = ticketType
        self.ticketTypeName = ticketTypeName
        self.selection = selection
        self.unitPrice = unitPrice
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

    /// 保存されている購入額から逆算した組合せ数（表示用）
    var combinationCount: Int {
        Bet.combinationCount(selection: selection, ticketTypeName: displayTicketTypeName)
    }

    // MARK: - Combination Count

    /// 買い目文字列と券種名から組合せ点数を計算する。
    /// - normal: 常に 1
    /// - box: 券種ごとに n から組合せ数を算出
    /// - formation: 各軸の積（重複馬を除外、券種が unordered なら順序差を解消）
    static func combinationCount(selection: String, ticketTypeName: String) -> Int {
        if selection.isEmpty { return 0 }

        // Box (e.g. "1,2,3[BOX]")
        if let range = selection.range(of: "[BOX]") {
            let head = selection[selection.startIndex ..< range.lowerBound]
            let horses = head.split(separator: ",").compactMap { Int($0) }
            return boxCount(n: horses.count, ticketTypeName: ticketTypeName)
        }

        // Formation (e.g. "1,2/3,4,5")
        if selection.contains("/") {
            let legs: [[Int]] = selection.split(separator: "/").map {
                $0.split(separator: ",").compactMap { Int($0) }
            }
            return formationCount(legs: legs, ticketTypeName: ticketTypeName)
        }

        // Normal: 単発の買い目は 1 点
        return 1
    }

    private static func boxCount(n: Int, ticketTypeName: String) -> Int {
        guard n >= 2 else { return 0 }
        switch ticketTypeName {
        case "枠連", "馬連", "ワイド":
            return n * (n - 1) / 2
        case "馬単":
            return n * (n - 1)
        case "三連複":
            return n >= 3 ? n * (n - 1) * (n - 2) / 6 : 0
        case "三連単":
            return n >= 3 ? n * (n - 1) * (n - 2) : 0
        default:
            return 0
        }
    }

    private static func formationCount(legs: [[Int]], ticketTypeName: String) -> Int {
        guard legs.count >= 2 else { return 0 }
        switch ticketTypeName {
        case "枠連", "馬連", "ワイド":
            return formationTwoLegUnordered(legs: legs)
        case "馬単":
            return formationTwoLegOrdered(legs: legs)
        case "三連複":
            return formationThreeLegUnordered(legs: legs)
        case "三連単":
            return formationThreeLegOrdered(legs: legs)
        default:
            return legs.map(\.count).reduce(1, *)
        }
    }

    private static func formationTwoLegUnordered(legs: [[Int]]) -> Int {
        guard legs.count == 2 else { return 0 }
        var pairs = Set<Set<Int>>()
        for first in legs[0] {
            for second in legs[1] {
                if first != second { pairs.insert(Set([first, second])) }
            }
        }
        return pairs.count
    }

    private static func formationTwoLegOrdered(legs: [[Int]]) -> Int {
        guard legs.count == 2 else { return 0 }
        var count = 0
        for first in legs[0] {
            for second in legs[1] {
                if first != second { count += 1 }
            }
        }
        return count
    }

    private static func formationThreeLegUnordered(legs: [[Int]]) -> Int {
        guard legs.count == 3 else { return 0 }
        var triples = Set<Set<Int>>()
        for first in legs[0] {
            for second in legs[1] {
                for third in legs[2] {
                    if first != second && second != third && first != third {
                        triples.insert(Set([first, second, third]))
                    }
                }
            }
        }
        return triples.count
    }

    private static func formationThreeLegOrdered(legs: [[Int]]) -> Int {
        guard legs.count == 3 else { return 0 }
        var count = 0
        for first in legs[0] {
            for second in legs[1] {
                for third in legs[2] {
                    if first != second && second != third && first != third { count += 1 }
                }
            }
        }
        return count
    }
}
