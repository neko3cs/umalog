//
//  PredictionMark.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import Foundation

/// 予想印を表す enum。rawValue は表示・ストレージ共通の印文字。
/// - Note: 8 種類は仕様として固定。追加・削除してはならない。
enum PredictionMark: String, CaseIterable, Codable {
    /// 本命
    case honmei = "◎"
    /// 対抗
    case taikou = "○"
    /// 単穴
    case tanana = "▲"
    /// 連下
    case renmei = "△"
    /// 星
    case hoshi = "☆"
    /// 注意
    case chu = "注"
    /// 押さえ
    case oshi = "押"
    /// 消し
    case keshi = "消"
}
