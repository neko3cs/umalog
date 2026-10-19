//
//  NagashiSelection.swift
//  umalog
//
//  Created by neko3cs on 2026/10/19.
//

import Foundation

/// 流し買いの買い目。軸馬・相手馬・軸の着順・マルチ指定を持ち、買い目文字列と相互変換する。
///
/// 買い目文字列の書式は `<軸>><相手>[<種別>]`。軸・相手はカンマ区切りの馬番、種別は次のいずれか。
/// - `流し`: 着順を問わない流し（馬連・ワイド・枠連・三連複）。例: `1>2,3,4[流し]`、`1,2>3,4[流し]`
/// - `<着順>着流し`: 軸の着順を指定した流し（馬単・三連単）。軸 2 頭は `・` 区切りで軸の並び順に対応する。
///   例: `1>2,3[1着流し]`、`1,2>3,4[1・3着流し]`（1 番が 1 着、2 番が 3 着）
/// - `流しマルチ`: 軸の着順を問わない流し（馬単・三連単）。例: `1>2,3[流しマルチ]`
struct NagashiSelection: Equatable {
    /// 軸馬の馬番。着順指定がある場合は `axisPositions` と同じ並びで対応する。
    var axes: [Int]
    /// 相手馬の馬番。
    var opponents: [Int]
    /// 軸の着順（1 始まり）。着順を問わない流し・マルチでは空。
    var axisPositions: [Int] = []
    /// マルチ指定かどうか。
    var isMulti: Bool = false

    /// 流しの買い目を生成する。
    /// - Parameters:
    ///   - axes: 軸馬の馬番。
    ///   - opponents: 相手馬の馬番。
    ///   - axisPositions: 軸の着順（1 始まり）。着順を問わない場合は空。
    ///   - isMulti: マルチ指定かどうか。
    init(axes: [Int], opponents: [Int], axisPositions: [Int] = [], isMulti: Bool = false) {
        self.axes = axes
        self.opponents = opponents
        self.axisPositions = axisPositions
        self.isMulti = isMulti
    }

    /// 買い目文字列をパースする。
    /// - Parameter selection: 買い目文字列（例: `"1>2,3[1着流し]"`）。
    /// - Returns: 流しの書式でない、または軸・相手が空の場合は nil。
    init?(selection: String) {
        guard selection.hasSuffix("]"), let open = selection.lastIndex(of: "[") else { return nil }
        let tag = selection[selection.index(after: open) ..< selection.index(before: selection.endIndex)]
        let parts = selection[..<open].split(separator: ">", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }

        var positions: [Int] = []
        var isMulti = false
        if tag == "流しマルチ" {
            isMulti = true
        } else if tag.hasSuffix("着流し") {
            let nums = tag.dropLast(3).split(separator: "・", omittingEmptySubsequences: false).map { Int($0) }
            guard !nums.isEmpty, nums.allSatisfy({ $0 != nil }) else { return nil }
            positions = nums.compactMap(\.self)
        } else if tag != "流し" {
            return nil
        }

        let axes = parts[0].split(separator: ",").compactMap { Int($0) }
        let opponents = parts[1].split(separator: ",").compactMap { Int($0) }
        guard !axes.isEmpty, !opponents.isEmpty, positions.isEmpty || positions.count == axes.count else { return nil }
        self.init(axes: axes, opponents: opponents, axisPositions: positions, isMulti: isMulti)
    }

    /// 買い目文字列表記（例: `"1>2,3[1着流し]"`）。
    var notation: String {
        let tag = if isMulti {
            "流しマルチ"
        } else if axisPositions.isEmpty {
            "流し"
        } else {
            axisPositions.map { "\($0)" }.joined(separator: "・") + "着流し"
        }
        let axesText = axes.map { "\($0)" }.joined(separator: ",")
        let opponentsText = opponents.map { "\($0)" }.joined(separator: ",")
        return "\(axesText)>\(opponentsText)[\(tag)]"
    }

    // MARK: - Ticket Type Rules

    /// 流しに対応する券種の 1 点あたりの頭数。
    /// - Parameter ticketTypeName: 券種名。
    /// - Returns: 頭数。流しに対応しない券種の場合は nil。
    static func horseCount(ticketTypeName: String) -> Int? {
        switch ticketTypeName {
        case "枠連", "馬連", "ワイド", "馬単": 2
        case "三連複", "三連単": 3
        default: nil
        }
    }

    /// 着順を区別する券種かどうか（馬単・三連単）。
    /// - Parameter ticketTypeName: 券種名。
    /// - Returns: 着順を区別する券種なら true。
    static func isOrdered(ticketTypeName: String) -> Bool {
        ticketTypeName == "馬単" || ticketTypeName == "三連単"
    }

    // MARK: - Combination Count

    /// 組合せ点数を計算する。軸と重複する相手馬・同一馬を含む組は数えない。
    ///
    /// 着順を区別する券種で着順指定がない場合は、軸を 1 着から順に置いたものとして数える。
    /// 着順を区別しない券種では着順指定・マルチ指定を無視する。
    /// - Parameter ticketTypeName: 券種名。
    /// - Returns: 組合せ点数。流しに対応しない券種・軸の頭数や着順が不正な場合は 0。
    func combinationCount(ticketTypeName: String) -> Int {
        guard let size = Self.horseCount(ticketTypeName: ticketTypeName),
              axes.count < size,
              Set(axes).count == axes.count
        else { return 0 }
        let ordered = Self.isOrdered(ticketTypeName: ticketTypeName)
        guard let placements = axisPlacements(size: size, ordered: ordered) else { return 0 }

        let axisSet = Set(axes)
        let others = Array(Set(opponents).subtracting(axisSet))
        var tickets = Set<[Int]>()
        for placement in placements {
            var legs = Array(repeating: others, count: size)
            for (axis, position) in zip(axes, placement) {
                legs[position] = [axis]
            }
            for combo in Self.distinctCombinations(legs: legs) {
                tickets.insert(ordered ? combo : combo.sorted())
            }
        }
        return tickets.count
    }

    /// 軸を置く着順（0 始まり）の候補一覧。マルチなら全ての並べ方、それ以外は 1 通り。
    /// - Parameters:
    ///   - size: 1 点あたりの頭数。
    ///   - ordered: 着順を区別する券種かどうか。
    /// - Returns: 候補一覧。着順指定が不正な場合は nil。
    private func axisPlacements(size: Int, ordered: Bool) -> [[Int]]? {
        let leading = Array(0 ..< axes.count)
        guard ordered else { return [leading] }
        if isMulti {
            return Self.permutations(of: Array(0 ..< size), length: axes.count)
        }
        guard !axisPositions.isEmpty else { return [leading] }
        let placement = axisPositions.map { $0 - 1 }
        guard placement.allSatisfy({ (0 ..< size).contains($0) }),
              Set(placement).count == placement.count
        else { return nil }
        return [placement]
    }

    /// 要素から指定個数を選んで並べた全ての順列を返す。
    /// - Parameters:
    ///   - values: 元の要素。
    ///   - length: 選ぶ個数。
    /// - Returns: 順列の一覧。
    private static func permutations(of values: [Int], length: Int) -> [[Int]] {
        guard length > 0 else { return [[]] }
        return values.flatMap { value in
            permutations(of: values.filter { $0 != value }, length: length - 1).map { [value] + $0 }
        }
    }

    /// 各着順の候補から 1 頭ずつ選んだ、同一馬を含まない組を全て返す。
    /// - Parameter legs: 着順ごとの候補馬番。
    /// - Returns: 着順順に並んだ組の一覧。
    private static func distinctCombinations(legs: [[Int]]) -> [[Int]] {
        legs.reduce([[]]) { partial, leg in
            partial.flatMap { combo in
                leg.filter { !combo.contains($0) }.map { combo + [$0] }
            }
        }
    }
}
