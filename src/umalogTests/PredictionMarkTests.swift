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

    @Test func `本命のraw valueが本命記号の文字列になる`() {
        #expect(PredictionMark.honmei.rawValue == "◎")
    }

    @Test func `対抗のraw valueが対抗記号の文字列になる`() {
        #expect(PredictionMark.taikou.rawValue == "○")
    }

    @Test func `単穴のraw valueが単穴記号の文字列になる`() {
        #expect(PredictionMark.tanana.rawValue == "▲")
    }

    @Test func `連下のraw valueが連下記号の文字列になる`() {
        #expect(PredictionMark.renmei.rawValue == "△")
    }

    @Test func `星のraw valueが星記号の文字列になる`() {
        #expect(PredictionMark.hoshi.rawValue == "☆")
    }

    @Test func `注のraw valueは注である`() {
        #expect(PredictionMark.chu.rawValue == "注")
    }

    @Test func `押のraw valueは押である`() {
        #expect(PredictionMark.oshi.rawValue == "押")
    }

    @Test func `消のraw valueは消である`() {
        #expect(PredictionMark.keshi.rawValue == "消")
    }

    @Test func `全てのraw valueが 一 意である`() {
        let rawValues = PredictionMark.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == PredictionMark.allCases.count)
    }

    // MARK: - init(rawValue:)

    @Test func `本命記号のraw valueのときに本命が返る`() {
        #expect(PredictionMark(rawValue: "◎") == .honmei)
    }

    @Test func `raw valueが消のときに消が返る`() {
        #expect(PredictionMark(rawValue: "消") == .keshi)
    }

    @Test func `無効なraw valueのときにnilが返る`() {
        #expect(PredictionMark(rawValue: "x") == nil)
    }

    @Test func `空文字のraw valueのときにnilが返る`() {
        #expect(PredictionMark(rawValue: "") == nil)
    }

    @Test func `全ケースでraw valueのラウンドトリップが成立する`() {
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
