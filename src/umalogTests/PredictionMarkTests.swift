//
//  PredictionMarkTests.swift
//  umalog
//
//  Created by neko3cs on 2026/06/12.
//

import Foundation
import Testing
@testable import umalog

struct PredictionMarkTests {
    // MARK: - CaseIterable

    @Test func allCases_hasExactlyEightElements() {
        #expect(PredictionMark.allCases.count == 8)
    }

    // MARK: - rawValue

    @Test func rawValue_honmei_isCorrect() {
        #expect(PredictionMark.honmei.rawValue == "◎")
    }

    @Test func rawValue_taikou_isCorrect() {
        #expect(PredictionMark.taikou.rawValue == "○")
    }

    @Test func rawValue_tanana_isCorrect() {
        #expect(PredictionMark.tanana.rawValue == "▲")
    }

    @Test func rawValue_renmei_isCorrect() {
        #expect(PredictionMark.renmei.rawValue == "△")
    }

    @Test func rawValue_hoshi_isCorrect() {
        #expect(PredictionMark.hoshi.rawValue == "☆")
    }

    @Test func rawValue_chu_isCorrect() {
        #expect(PredictionMark.chu.rawValue == "注")
    }

    @Test func rawValue_oshi_isCorrect() {
        #expect(PredictionMark.oshi.rawValue == "押")
    }

    @Test func rawValue_keshi_isCorrect() {
        #expect(PredictionMark.keshi.rawValue == "消")
    }

    @Test func allRawValues_areUnique() {
        let rawValues = PredictionMark.allCases.map { $0.rawValue }
        #expect(Set(rawValues).count == PredictionMark.allCases.count)
    }

    // MARK: - init(rawValue:)

    @Test func initRawValue_withValidHonmei_returnsHonmei() {
        #expect(PredictionMark(rawValue: "◎") == .honmei)
    }

    @Test func initRawValue_withValidKeshi_returnsKeshi() {
        #expect(PredictionMark(rawValue: "消") == .keshi)
    }

    @Test func initRawValue_withInvalidString_returnsNil() {
        #expect(PredictionMark(rawValue: "x") == nil)
    }

    @Test func initRawValue_withEmptyString_returnsNil() {
        #expect(PredictionMark(rawValue: "") == nil)
    }

    @Test func initRawValue_allCasesRoundTrip() {
        for mark in PredictionMark.allCases {
            #expect(PredictionMark(rawValue: mark.rawValue) == mark)
        }
    }

    // MARK: - Codable

    @Test func codable_encodesAndDecodesAllCases() throws {
        for mark in PredictionMark.allCases {
            let encoded = try JSONEncoder().encode(mark)
            let decoded = try JSONDecoder().decode(PredictionMark.self, from: encoded)
            #expect(decoded == mark)
        }
    }
}
