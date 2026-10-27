//
//  TicketType.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import Foundation
import SwiftData

/// 券種マスター（単勝・馬連など）を表す SwiftData モデル。
@Model
final class TicketType {
    /// 券種名。
    var name: String = ""
    /// 表示順。CloudKit 互換のため ordered relationship の代わりに使う。
    var sortIndex: Int = 0

    /// 券種を生成する。
    /// - Parameters:
    ///   - name: 券種名。
    ///   - sortIndex: 表示順。
    init(name: String, sortIndex: Int = 0) {
        self.name = name
        self.sortIndex = sortIndex
    }

    /// アプリが扱う券種（`defaultTicketTypeNames`）かどうか。
    var isPreset: Bool {
        defaultTicketTypeNames.contains { $0.name == name }
    }

    /// 券種マスターにない券種を、既存の券種の後ろに追加する。既存の券種と並び順には触れない。
    /// - Parameter context: 追加先のモデルコンテキスト。
    /// - Returns: 1 件以上追加した場合は true。
    @discardableResult
    static func insertMissingPresets(into context: ModelContext) -> Bool {
        let existing = (try? context.fetch(FetchDescriptor<TicketType>())) ?? []
        let existingNames = Set(existing.map(\.name))
        var nextSortIndex = (existing.map(\.sortIndex).max() ?? -1) + 1
        var inserted = false
        for (name, _) in defaultTicketTypeNames where !existingNames.contains(name) {
            context.insert(TicketType(name: name, sortIndex: nextSortIndex))
            nextSortIndex += 1
            inserted = true
        }
        return inserted
    }
}
