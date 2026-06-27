//
//  Venue.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import Foundation
import SwiftData

@Model
final class Venue {
    var name: String = ""
    var isPreset: Bool = false
    var sortIndex: Int = 0
    @Relationship(deleteRule: .nullify)
    var races: [Race]? = nil

    init(name: String, isPreset: Bool = false, sortIndex: Int = 0) {
        self.name = name
        self.isPreset = isPreset
        self.sortIndex = sortIndex
    }
}
