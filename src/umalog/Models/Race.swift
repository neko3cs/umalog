//
//  Race.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import Foundation
import SwiftData

/// 1 開催レースを表す SwiftData モデル。出走馬（`RaceEntry`）と馬券（`Bet`）を子に持つ。
@Model
final class Race {
    /// 開催日。
    var date: Date = Date()
    /// 開催競馬場。未選択の場合は nil。
    var venue: Venue?
    /// レース番号（1〜12）。
    var raceNumber: Int = 1
    /// レース名。未入力の場合は空文字。
    var raceName: String = ""
    /// 距離（メートル）。
    var distance: Int = 1600
    /// トラック種別。"turf"（芝）または "dirt"（ダート）。
    var trackType: String = "turf"
    /// 馬場状態（良・稍重・重・不良）。
    var trackCondition: String = "良"
    /// 区分。"central"（中央）または "local"（地方）。
    var category: String = "central"
    /// レースのグレード識別子。空文字はグレード未選択を示す。
    var grade: String = ""
    /// Markdown 形式のメモ。
    var memo: String = ""
    /// 表示順。CloudKit 互換のため ordered relationship の代わりに使う。
    var sortIndex: Int = 0
    /// 1 着の馬番。0 は未入力。
    var firstPlaceHorseNumber: Int = 0
    /// 2 着の馬番。0 は未入力。
    var secondPlaceHorseNumber: Int = 0
    /// 3 着の馬番。0 は未入力。
    var thirdPlaceHorseNumber: Int = 0
    /// 出走馬の一覧。レース削除時にカスケード削除される。
    @Relationship(deleteRule: .cascade, inverse: \RaceEntry.race)
    var entries: [RaceEntry]?
    /// 馬券の一覧。レース削除時にカスケード削除される。
    @Relationship(deleteRule: .cascade, inverse: \Bet.race)
    var bets: [Bet]?

    /// レースを生成する。
    /// - Parameters:
    ///   - date: 開催日。
    ///   - venue: 開催競馬場。
    ///   - raceNumber: レース番号。
    ///   - raceName: レース名。
    ///   - distance: 距離（メートル）。
    ///   - trackType: トラック種別（"turf" / "dirt"）。
    ///   - trackCondition: 馬場状態。
    ///   - category: 区分（"central" / "local"）。
    ///   - grade: グレード識別子。
    ///   - memo: Markdown 形式のメモ。
    ///   - firstPlaceHorseNumber: 1 着の馬番（0 は未入力）。
    ///   - secondPlaceHorseNumber: 2 着の馬番（0 は未入力）。
    ///   - thirdPlaceHorseNumber: 3 着の馬番（0 は未入力）。
    ///   - sortIndex: 表示順。
    init(
        date: Date = Date(),
        venue: Venue? = nil,
        raceNumber: Int = 1,
        raceName: String = "",
        distance: Int = 1600,
        trackType: String = "turf",
        trackCondition: String = "良",
        category: String = "central",
        grade: String = "",
        memo: String = "",
        firstPlaceHorseNumber: Int = 0,
        secondPlaceHorseNumber: Int = 0,
        thirdPlaceHorseNumber: Int = 0,
        sortIndex: Int = 0,
    ) {
        self.date = date
        self.venue = venue
        self.raceNumber = raceNumber
        self.raceName = raceName
        self.distance = distance
        self.trackType = trackType
        self.trackCondition = trackCondition
        self.category = category
        self.grade = grade
        self.memo = memo
        self.firstPlaceHorseNumber = firstPlaceHorseNumber
        self.secondPlaceHorseNumber = secondPlaceHorseNumber
        self.thirdPlaceHorseNumber = thirdPlaceHorseNumber
        self.sortIndex = sortIndex
    }

    /// 指定馬番の着順（1〜3 着）を返す。
    /// - Note: 馬番 0 は「未入力」を意味するため、着順欄が未入力（= 0）でも誤って一致しないよう常に nil を返す。
    /// - Parameter number: 判定対象の馬番。
    /// - Returns: 1〜3 着に該当すればその着順、それ以外は nil。
    func finishPosition(forHorseNumber number: Int) -> Int? {
        guard number > 0 else { return nil }
        if firstPlaceHorseNumber == number {
            return 1
        }
        if secondPlaceHorseNumber == number {
            return 2
        }
        if thirdPlaceHorseNumber == number {
            return 3
        }
        return nil
    }

    /// 全馬券の購入額合計。
    var totalPurchase: Int {
        (bets ?? []).reduce(0) { $0 + $1.purchaseAmount }
    }

    /// 全馬券の払戻額合計。未精算の馬券は 0 円として扱う。
    var totalPayout: Int {
        (bets ?? []).reduce(0) { $0 + $1.payoutAmount }
    }

    /// このレースの収支（払戻合計 − 購入合計）。
    var balance: Int {
        totalPayout - totalPurchase
    }

    /// 回収率（払戻合計 ÷ 購入合計）。購入がない場合は nil。
    var returnRate: Double? {
        guard totalPurchase > 0 else { return nil }
        return Double(totalPayout) / Double(totalPurchase)
    }
}

/// レースのグレードを表す。rawValue はストレージ・CSV に使う文字列識別子。
enum RaceGrade: String, CaseIterable {
    /// グレード未選択（空文字）。
    case unspecified = ""
    /// G1
    case g1 = "G1"
    /// G2
    case g2 = "G2"
    /// G3
    case g3 = "G3"
    /// リステッド競走
    case listed = "Listed"
    /// オープン特別競走
    case openSpecial = "OpenSpecial"
    /// 一般競走
    case general = "General"

    /// ピッカー・ラベルで使う表示名。
    var displayName: String {
        switch self {
        case .unspecified: "未選択"
        case .g1: "G1"
        case .g2: "G2"
        case .g3: "G3"
        case .listed: "リステッド"
        case .openSpecial: "オープン特別"
        case .general: "一般"
        }
    }
}
