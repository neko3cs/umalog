//
//  RaceEntry.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import Foundation
import SwiftData

@Model
final class RaceEntry {
    var race: Race?
    var horseNumber: Int = 0
    var horseName: String = ""
    var jockeyName: String = ""
    var trainerName: String = ""
    var predictionMark: String? // PredictionMark.rawValue
    var finishPosition: Int?
    var sortIndex: Int = 0

    init(
        race: Race? = nil,
        horseNumber: Int = 0,
        horseName: String = "",
        jockeyName: String = "",
        trainerName: String = "",
        predictionMark: String? = nil,
        finishPosition: Int? = nil,
        sortIndex: Int = 0
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

    var mark: PredictionMark? {
        get { predictionMark.flatMap { PredictionMark(rawValue: $0) } }
        set { predictionMark = newValue?.rawValue }
    }
}
