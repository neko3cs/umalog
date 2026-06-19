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

    @Test func 予想印は全部で8種類ある() {
        #expect(PredictionMark.allCases.count == 8)
    }

    // MARK: - rawValue

    @Test func 本命のrawValueが本命記号の文字列になる() {
        #expect(PredictionMark.honmei.rawValue == "◎")
    }

    @Test func 対抗のrawValueが対抗記号の文字列になる() {
        #expect(PredictionMark.taikou.rawValue == "○")
    }

    @Test func 単穴のrawValueが単穴記号の文字列になる() {
        #expect(PredictionMark.tanana.rawValue == "▲")
    }

    @Test func 連下のrawValueが連下記号の文字列になる() {
        #expect(PredictionMark.renmei.rawValue == "△")
    }

    @Test func 星のrawValueが星記号の文字列になる() {
        #expect(PredictionMark.hoshi.rawValue == "☆")
    }

    @Test func 注のrawValueは注である() {
        #expect(PredictionMark.chu.rawValue == "注")
    }

    @Test func 押のrawValueは押である() {
        #expect(PredictionMark.oshi.rawValue == "押")
    }

    @Test func 消のrawValueは消である() {
        #expect(PredictionMark.keshi.rawValue == "消")
    }

    @Test func 全てのrawValueが一意である() {
        let rawValues = PredictionMark.allCases.map { $0.rawValue }
        #expect(Set(rawValues).count == PredictionMark.allCases.count)
    }

    // MARK: - init(rawValue:)

    @Test func 本命記号のrawValueのときに本命が返る() {
        #expect(PredictionMark(rawValue: "◎") == .honmei)
    }

    @Test func rawValueが消のときに消が返る() {
        #expect(PredictionMark(rawValue: "消") == .keshi)
    }

    @Test func 無効なrawValueのときにnilが返る() {
        #expect(PredictionMark(rawValue: "x") == nil)
    }

    @Test func 空文字のrawValueのときにnilが返る() {
        #expect(PredictionMark(rawValue: "") == nil)
    }

    @Test func 全ケースでrawValueのラウンドトリップが成立する() {
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
