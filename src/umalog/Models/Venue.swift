//
//  Venue.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import Foundation
import SwiftData

/// 競馬場マスターを表す SwiftData モデル。
@Model
final class Venue {
    /// 競馬場名。
    var name: String = ""
    /// 区分（`RaceCategory` の rawValue）。この競馬場を選んだレースの区分になる。
    var category: String = "central"
    /// 表示順。CloudKit 互換のため ordered relationship の代わりに使う。
    var sortIndex: Int = 0
    /// この競馬場を開催地とするレース。競馬場削除時は参照だけが nil になりレースは残る。
    @Relationship(deleteRule: .nullify)
    var races: [Race]? = nil

    /// 競馬場を生成する。
    /// - Parameters:
    ///   - name: 競馬場名。
    ///   - category: 区分（`RaceCategory` の rawValue）。
    ///   - sortIndex: 表示順。
    init(name: String, category: String = "central", sortIndex: Int = 0) {
        self.name = name
        self.category = category
        self.sortIndex = sortIndex
    }

    /// 競馬場マスターにない競馬場を、既存の競馬場の後ろに追加する。既存の競馬場と並び順には触れない。
    /// 既存の競馬場の区分は `venuePresets` に揃える。
    /// - Parameter context: 追加先のモデルコンテキスト。
    /// - Returns: 1 件以上追加した場合は true。
    @discardableResult
    static func insertMissingPresets(into context: ModelContext) -> Bool {
        let existing = (try? context.fetch(FetchDescriptor<Venue>())) ?? []
        let existingByName = Dictionary(existing.map { ($0.name, $0) }) { first, _ in first }
        var nextSortIndex = (existing.map(\.sortIndex).max() ?? -1) + 1
        var inserted = false
        for preset in venuePresets {
            if let venue = existingByName[preset.name] {
                // 区分を持たなかった頃に投入した競馬場は、移行時の既定値（中央）になっている
                if venue.category != preset.category.rawValue {
                    venue.category = preset.category.rawValue
                }
            } else {
                context.insert(Venue(name: preset.name, category: preset.category.rawValue, sortIndex: nextSortIndex))
                nextSortIndex += 1
                inserted = true
            }
        }
        return inserted
    }
}
