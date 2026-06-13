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
    var unitPrice: Int = 100 // 1口あたりの購入額
    var purchaseAmount: Int = 0 // 合計購入額 (= unitPrice × 組合せ数)
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
            // 2 軸・順不同
            guard legs.count == 2 else { return 0 }
            var pairs = Set<Set<Int>>()
            for a in legs[0] {
                for b in legs[1] where a != b {
                    pairs.insert(Set([a, b]))
                }
            }
            return pairs.count
        case "馬単":
            // 2 軸・順序あり
            guard legs.count == 2 else { return 0 }
            var count = 0
            for a in legs[0] {
                for b in legs[1] where a != b {
                    count += 1
                }
            }
            return count
        case "三連複":
            // 3 軸・順不同
            guard legs.count == 3 else { return 0 }
            var triples = Set<Set<Int>>()
            for a in legs[0] {
                for b in legs[1] {
                    for c in legs[2] where a != b && b != c && a != c {
                        triples.insert(Set([a, b, c]))
                    }
                }
            }
            return triples.count
        case "三連単":
            // 3 軸・順序あり
            guard legs.count == 3 else { return 0 }
            var count = 0
            for a in legs[0] {
                for b in legs[1] {
                    for c in legs[2] where a != b && b != c && a != c {
                        count += 1
                    }
                }
            }
            return count
        default:
            return legs.map(\.count).reduce(1, *)
        }
    }
}
