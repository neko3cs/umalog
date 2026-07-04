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
}
