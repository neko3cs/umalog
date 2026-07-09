//
//  Bet.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import Foundation
import SwiftData

/// 1 枚の馬券を表す SwiftData モデル。買い目（`BetSelection`）を子に持つ。
@Model
final class Bet {
    /// 親レース。
    var race: Race?
    /// 買い目の一覧。馬券削除時にカスケード削除される。
    @Relationship(deleteRule: .cascade, inverse: \BetSelection.bet)
    var selections: [BetSelection]?
    /// 券種。旧データモデルの互換用フィールド（現行モデルでは `BetSelection` 側が持つ）。
    var ticketType: TicketType?
    /// 券種名。旧データモデルおよびレガシー CSV インポートの互換用フィールド。
    var ticketTypeName: String = ""
    /// 買い目文字列。旧データモデルの互換用フィールド。
    var selection: String = ""
    /// 1 口あたりの金額（円）。旧データモデルの互換用フィールド。
    var unitPrice: Int = 100
    /// 購入額合計（円）。
    var purchaseAmount: Int = 0
    /// 払戻額（円）。0 は未精算を示す。
    var payoutAmount: Int = 0
    /// 表示順。CloudKit 互換のため ordered relationship の代わりに使う。
    var sortIndex: Int = 0

    /// 馬券を生成する。
    /// - Parameters:
    ///   - race: 親レース。
    ///   - ticketType: 券種（互換用）。
    ///   - ticketTypeName: 券種名（互換用）。
    ///   - selection: 買い目文字列（互換用）。
    ///   - unitPrice: 1 口あたりの金額（互換用）。
    ///   - purchaseAmount: 購入額合計。
    ///   - payoutAmount: 払戻額（0 は未精算）。
    ///   - sortIndex: 表示順。
    init(
        race: Race? = nil,
        ticketType: TicketType? = nil,
        ticketTypeName: String = "",
        selection: String = "",
        unitPrice: Int = 100,
        purchaseAmount: Int = 0,
        payoutAmount: Int = 0,
        sortIndex: Int = 0,
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

    /// この馬券の収支（払戻額 − 購入額）。
    var balance: Int {
        payoutAmount - purchaseAmount
    }

    /// 表示用の券種名。券種マスターがあればその名前、なければ保存済みの券種名を返す。
    var displayTicketTypeName: String {
        ticketType?.name ?? ticketTypeName
    }

    /// 保存されている買い目と券種から算出した組合せ数（表示用）。
    var combinationCount: Int {
        Bet.combinationCount(selection: selection, ticketTypeName: displayTicketTypeName)
    }

    // MARK: - Combination Count

    /// 買い目文字列と券種名から組合せ点数を計算する。
    /// - normal: 常に 1
    /// - box: 券種ごとに n から組合せ数を算出
    /// - formation: 各軸の積（重複馬を除外、券種が unordered なら順序差を解消）
    /// - Parameters:
    ///   - selection: 買い目文字列（例: `"1-2-3"` / `"1,2,3[BOX]"` / `"1,2/3,4,5"`）。
    ///   - ticketTypeName: 券種名（例: `"馬連"`）。
    /// - Returns: 組合せ点数。買い目が空・不成立の場合は 0。
    static func combinationCount(selection: String, ticketTypeName: String) -> Int {
        if selection.isEmpty {
            return 0
        }

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

    /// BOX 買いの組合せ点数を券種ごとの公式で計算する。
    /// - Parameters:
    ///   - n: 選択した頭数。
    ///   - ticketTypeName: 券種名。
    /// - Returns: 組合せ点数。BOX に対応しない券種・頭数不足の場合は 0。
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

    /// フォーメーション買いの組合せ点数を券種の順序有無に応じて計算する。
    /// - Parameters:
    ///   - legs: 各軸の馬番リスト。
    ///   - ticketTypeName: 券種名。
    /// - Returns: 組合せ点数。軸が不足している場合は 0。
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

    /// 2 軸・順不同（馬連系）のフォーメーション点数。同一馬ペアを除外し、順序違いの重複を集約する。
    /// - Parameter legs: 各軸の馬番リスト。
    /// - Returns: 組合せ点数。軸数が 2 でない場合は 0。
    private static func formationTwoLegUnordered(legs: [[Int]]) -> Int {
        guard legs.count == 2 else { return 0 }
        var pairs = Set<Set<Int>>()
        for first in legs[0] {
            for second in legs[1] where first != second {
                pairs.insert(Set([first, second]))
            }
        }
        return pairs.count
    }

    /// 2 軸・順序あり（馬単）のフォーメーション点数。同一馬ペアのみ除外する。
    /// - Parameter legs: 各軸の馬番リスト。
    /// - Returns: 組合せ点数。軸数が 2 でない場合は 0。
    private static func formationTwoLegOrdered(legs: [[Int]]) -> Int {
        guard legs.count == 2 else { return 0 }
        var count = 0
        for first in legs[0] {
            for second in legs[1] where first != second {
                count += 1
            }
        }
        return count
    }

    /// 3 軸・順不同（三連複）のフォーメーション点数。同一馬を含む組を除外し、順序違いの重複を集約する。
    /// - Parameter legs: 各軸の馬番リスト。
    /// - Returns: 組合せ点数。軸数が 3 でない場合は 0。
    private static func formationThreeLegUnordered(legs: [[Int]]) -> Int {
        guard legs.count == 3 else { return 0 }
        var triples = Set<Set<Int>>()
        for first in legs[0] {
            for second in legs[1] {
                for third in legs[2] {
                    if first != second, second != third, first != third {
                        triples.insert(Set([first, second, third]))
                    }
                }
            }
        }
        return triples.count
    }

    /// 3 軸・順序あり（三連単）のフォーメーション点数。同一馬を含む組のみ除外する。
    /// - Parameter legs: 各軸の馬番リスト。
    /// - Returns: 組合せ点数。軸数が 3 でない場合は 0。
    private static func formationThreeLegOrdered(legs: [[Int]]) -> Int {
        guard legs.count == 3 else { return 0 }
        var count = 0
        for first in legs[0] {
            for second in legs[1] {
                for third in legs[2] {
                    if first != second, second != third, first != third {
                        count += 1
                    }
                }
            }
        }
        return count
    }
}
