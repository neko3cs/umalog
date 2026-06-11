//
//  Item.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
