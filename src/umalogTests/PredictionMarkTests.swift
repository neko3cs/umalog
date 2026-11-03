//
//  PredictionMarkTests.swift
//  umalog
//
//  Created by neko3cs on 2026/06/12.
//

import Foundation
import Testing
@testable import umalog

struct 予想印Test {
    // MARK: - CaseIterable

    @Test func `予想印は全部で 8 種類ある`() {
        #expect(PredictionMark.allCases.count == 8)
    }

    @Test func 全ケースの順序が仕様書通りになる() {
        let expected: [PredictionMark] = [.honmei, .taikou, .tanana, .renmei, .hoshi, .chu, .oshi, .keshi]
        #expect(PredictionMark.allCases == expected)
    }

    // MARK: - rawValue

    @Test(arguments: [
        (PredictionMark.honmei, "◎"), (.taikou, "○"), (.tanana, "▲"), (.renmei, "△"),
        (.hoshi, "☆"), (.chu, "注"), (.oshi, "押"), (.keshi, "消"),
    ])
    func 予想印ごとに保存する記号が決まっている(mark: PredictionMark, symbol: String) {
        #expect(mark.rawValue == symbol)
        #expect(PredictionMark(rawValue: symbol) == mark)
    }

    @Test func 保存する記号が予想印どうしで重複しない() {
        let rawValues = PredictionMark.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == PredictionMark.allCases.count)
    }

    // MARK: - init(rawValue:)

    @Test(arguments: ["x", ""])
    func 予想印の記号でない文字列からは予想印が作られない(rawValue: String) {
        #expect(PredictionMark(rawValue: rawValue) == nil)
    }

    @Test func 全予想印で記号から元の予想印に戻せる() {
        for mark in PredictionMark.allCases {
            #expect(PredictionMark(rawValue: mark.rawValue) == mark)
        }
    }

    // MARK: - Codable

    @Test func 全ケースでエンコードとデコードが正しく行われる() throws {
        for mark in PredictionMark.allCases {
            let encoded = try JSONEncoder().encode(mark)
            let decoded = try JSONDecoder().decode(PredictionMark.self, from: encoded)
            #expect(decoded == mark)
        }
    }
}
