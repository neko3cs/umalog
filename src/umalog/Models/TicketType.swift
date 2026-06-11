//
//  TicketType.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import Foundation
import SwiftData

@Model
final class TicketType {
    var name: String = ""
    var sortIndex: Int = 0

    init(name: String, sortIndex: Int = 0) {
        self.name = name
        self.sortIndex = sortIndex
    }
}
