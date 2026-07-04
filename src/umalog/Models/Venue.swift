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
    /// プリセット（アプリ同梱）の競馬場かどうか。
    var isPreset: Bool = false
    /// 表示順。CloudKit 互換のため ordered relationship の代わりに使う。
    var sortIndex: Int = 0
    /// この競馬場を開催地とするレース。競馬場削除時は参照だけが nil になりレースは残る。
    @Relationship(deleteRule: .nullify)
    var races: [Race]? = nil

    /// 競馬場を生成する。
    /// - Parameters:
    ///   - name: 競馬場名。
    ///   - isPreset: プリセットかどうか。
    ///   - sortIndex: 表示順。
    init(name: String, isPreset: Bool = false, sortIndex: Int = 0) {
        self.name = name
        self.isPreset = isPreset
        self.sortIndex = sortIndex
    }
}
