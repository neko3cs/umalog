//
//  Race.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import Foundation
import SwiftData

@Model
final class Race {
    var date: Date = Date()
    var venue: Venue?
    var raceNumber: Int = 1
    var raceName: String = ""
    var distance: Int = 1600
    var trackType: String = "turf" // "turf" | "dirt"
    var trackCondition: String = "良" // 良・稍重・重・不良
    var category: String = "central" // "central" | "local"
    var memo: String = ""
    var sortIndex: Int = 0
    // 着順（馬番を保持。0 = 未入力）
    var firstPlaceHorseNumber: Int = 0
    var secondPlaceHorseNumber: Int = 0
    var thirdPlaceHorseNumber: Int = 0
    var entries: [RaceEntry]?
    var bets: [Bet]?

    init(
        date: Date = Date(),
        venue: Venue? = nil,
        raceNumber: Int = 1,
        raceName: String = "",
        distance: Int = 1600,
        trackType: String = "turf",
        trackCondition: String = "良",
        category: String = "central",
        memo: String = "",
        firstPlaceHorseNumber: Int = 0,
        secondPlaceHorseNumber: Int = 0,
        thirdPlaceHorseNumber: Int = 0,
        sortIndex: Int = 0
    ) {
        self.date = date
        self.venue = venue
        self.raceNumber = raceNumber
        self.raceName = raceName
        self.distance = distance
        self.trackType = trackType
        self.trackCondition = trackCondition
        self.category = category
        self.memo = memo
        self.firstPlaceHorseNumber = firstPlaceHorseNumber
        self.secondPlaceHorseNumber = secondPlaceHorseNumber
        self.thirdPlaceHorseNumber = thirdPlaceHorseNumber
        self.sortIndex = sortIndex
    }

    /// 指定馬番の着順を返す（1〜3 着の中で当該馬番にマッチするものを返す。未入力時 nil）
    func finishPosition(forHorseNumber number: Int) -> Int? {
        if firstPlaceHorseNumber == number { return 1 }
        if secondPlaceHorseNumber == number { return 2 }
        if thirdPlaceHorseNumber == number { return 3 }
        return nil
    }

    var totalPurchase: Int {
        (bets ?? []).reduce(0) { $0 + $1.purchaseAmount }
    }

    var totalPayout: Int {
        (bets ?? []).reduce(0) { $0 + $1.payoutAmount }
    }

    var balance: Int {
        totalPayout - totalPurchase
    }

    var returnRate: Double? {
        guard totalPurchase > 0 else { return nil }
        return Double(totalPayout) / Double(totalPurchase)
    }
}
