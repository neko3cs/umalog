//
//  RaceEntry.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import Foundation
import SwiftData

/// レースの出走馬 1 頭を表す SwiftData モデル。
@Model
final class RaceEntry {
    /// 親レース。
    var race: Race?
    /// 馬番。0 は未入力。
    var horseNumber: Int = 0
    /// 馬名。
    var horseName: String = ""
    /// 騎手名。未入力の場合は空文字。
    var jockeyName: String = ""
    /// 調教師名。未入力の場合は空文字。
    var trainerName: String = ""
    /// 予想印（`PredictionMark.rawValue`）。未設定の場合は nil。
    var predictionMark: String?
    /// 着順。未確定の場合は nil。
    var finishPosition: Int?
    /// 表示順。CloudKit 互換のため ordered relationship の代わりに使う。
    var sortIndex: Int = 0

    /// 出走馬を生成する。
    /// - Parameters:
    ///   - race: 親レース。
    ///   - horseNumber: 馬番（0 は未入力）。
    ///   - horseName: 馬名。
    ///   - jockeyName: 騎手名。
    ///   - trainerName: 調教師名。
    ///   - predictionMark: 予想印の rawValue。
    ///   - finishPosition: 着順。
    ///   - sortIndex: 表示順。
    init(
        race: Race? = nil,
        horseNumber: Int = 0,
        horseName: String = "",
        jockeyName: String = "",
        trainerName: String = "",
        predictionMark: String? = nil,
        finishPosition: Int? = nil,
        sortIndex: Int = 0,
    ) {
        self.race = race
        self.horseNumber = horseNumber
        self.horseName = horseName
        self.jockeyName = jockeyName
        self.trainerName = trainerName
        self.predictionMark = predictionMark
        self.finishPosition = finishPosition
        self.sortIndex = sortIndex
    }

    /// 予想印を enum として読み書きするアクセサー。ストレージには rawValue（`predictionMark`）を保存する。
    var mark: PredictionMark? {
        get { predictionMark.flatMap { PredictionMark(rawValue: $0) } }
        set { predictionMark = newValue?.rawValue }
    }
}
