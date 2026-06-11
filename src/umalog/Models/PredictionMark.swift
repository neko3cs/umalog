//
//  PredictionMark.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import Foundation

enum PredictionMark: String, CaseIterable, Codable {
    case honmei = "◎"
    case taikou = "○"
    case tanana = "▲"
    case renmei = "△"
    case hoshi = "☆"
    case chu = "注"
    case oshi = "押"
    case keshi = "消"
}
