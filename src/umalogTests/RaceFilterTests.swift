//
//  RaceFilterTests.swift
//  umalog
//
//  Created by neko3cs on 2026/06/30.
//

import Foundation
import SwiftData
import Testing
@testable import umalog

@MainActor
struct RaceFilterTest {
    let container: ModelContainer

    init() throws {
        let schema = Schema([Race.self, Bet.self, BetSelection.self, RaceEntry.self, Venue.self, TicketType.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - isActive

    @Test func デフォルトのフィルターはアクティブでない() {
        #expect(RaceFilter().isActive == false)
    }

    @Test func 区分が設定されているときアクティブになる() {
        var f = RaceFilter()
        f.category = "central"
        #expect(f.isActive == true)
    }

    @Test func グレードが選択されているときアクティブになる() {
        var f = RaceFilter()
        f.grades = [.g1]
        #expect(f.isActive == true)
    }

    @Test func 開始日が設定されているときアクティブになる() {
        var f = RaceFilter()
        f.dateFrom = Date()
        #expect(f.isActive == true)
    }

    @Test func 終了日が設定されているときアクティブになる() {
        var f = RaceFilter()
        f.dateTo = Date()
        #expect(f.isActive == true)
    }

    @Test func 競馬場が選択されているときアクティブになる() {
        let ctx = container.mainContext
        let venue = Venue(name: "東京"); ctx.insert(venue)
        var f = RaceFilter()
        f.venueIDs = [venue.persistentModelID]
        #expect(f.isActive == true)
    }

    // MARK: - apply(to:) フィルターなし

    @Test func フィルターなしの場合すべてのレースが返される() {
        let ctx = container.mainContext
        let r1 = Race(); ctx.insert(r1)
        let r2 = Race(); ctx.insert(r2)
        let result = RaceFilter().apply(to: [r1, r2])
        #expect(result.count == 2)
    }

    @Test func 空配列にフィルターを適用すると空配列が返される() {
        let result = RaceFilter().apply(to: [])
        #expect(result.isEmpty)
    }

    // MARK: - apply(to:) 区分フィルター

    @Test func 区分中央フィルターで中央レースのみ返される() {
        let ctx = container.mainContext
        let central = Race(category: "central"); ctx.insert(central)
        let local = Race(category: "local"); ctx.insert(local)
        var f = RaceFilter()
        f.category = "central"
        let result = f.apply(to: [central, local])
        #expect(result.count == 1)
        #expect(result.first === central)
    }

    @Test func 区分地方フィルターで地方レースのみ返される() {
        let ctx = container.mainContext
        let central = Race(category: "central"); ctx.insert(central)
        let local = Race(category: "local"); ctx.insert(local)
        var f = RaceFilter()
        f.category = "local"
        let result = f.apply(to: [central, local])
        #expect(result.count == 1)
        #expect(result.first === local)
    }

    // MARK: - apply(to:) グレードフィルター

    @Test func `グレードg 1 フィルターでg 1 レースのみ返される`() {
        let ctx = container.mainContext
        let g1 = Race(grade: "G1"); ctx.insert(g1)
        let g2 = Race(grade: "G2"); ctx.insert(g2)
        let noGrade = Race(grade: ""); ctx.insert(noGrade)
        var f = RaceFilter()
        f.grades = [.g1]
        let result = f.apply(to: [g1, g2, noGrade])
        #expect(result.count == 1)
        #expect(result.first === g1)
    }

    @Test func 複数グレードフィルターで該当グレードのレースが返される() {
        let ctx = container.mainContext
        let g1 = Race(grade: "G1"); ctx.insert(g1)
        let g2 = Race(grade: "G2"); ctx.insert(g2)
        let g3 = Race(grade: "G3"); ctx.insert(g3)
        var f = RaceFilter()
        f.grades = [.g1, .g2]
        let result = f.apply(to: [g1, g2, g3])
        #expect(result.count == 2)
        #expect(!result.contains(where: { $0 === g3 }))
    }

    @Test func グレード未選択フィルターでグレード未設定レースのみ返される() {
        let ctx = container.mainContext
        let g1 = Race(grade: "G1"); ctx.insert(g1)
        let noGrade = Race(grade: ""); ctx.insert(noGrade)
        var f = RaceFilter()
        f.grades = [.unspecified]
        let result = f.apply(to: [g1, noGrade])
        #expect(result.count == 1)
        #expect(result.first === noGrade)
    }

    @Test func 不正なgrade値を持つレースはunspecifiedとして扱われる() {
        let ctx = container.mainContext
        let invalid = Race(grade: "INVALID_GRADE"); ctx.insert(invalid)
        var f = RaceFilter()
        f.grades = [.unspecified]
        let result = f.apply(to: [invalid])
        #expect(result.count == 1)
    }

    // MARK: - apply(to:) 日付範囲フィルター

    @Test func 開始日フィルターで開始日以降のレースが返される() throws {
        let ctx = container.mainContext
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = try #require(cal.date(byAdding: .day, value: -1, to: today))
        let rYesterday = Race(date: yesterday); ctx.insert(rYesterday)
        let rToday = Race(date: today); ctx.insert(rToday)
        var f = RaceFilter()
        f.dateFrom = today
        let result = f.apply(to: [rYesterday, rToday])
        #expect(result.count == 1)
        #expect(result.first === rToday)
    }

    @Test func 終了日フィルターで終了日以前のレースが返される() throws {
        let ctx = container.mainContext
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = try #require(cal.date(byAdding: .day, value: -1, to: today))
        let tomorrow = try #require(cal.date(byAdding: .day, value: 1, to: today))
        let rYesterday = Race(date: yesterday); ctx.insert(rYesterday)
        let rToday = Race(date: today); ctx.insert(rToday)
        let rTomorrow = Race(date: tomorrow); ctx.insert(rTomorrow)
        var f = RaceFilter()
        f.dateTo = today
        let result = f.apply(to: [rYesterday, rToday, rTomorrow])
        #expect(result.count == 2)
        #expect(!result.contains(where: { $0 === rTomorrow }))
    }

    @Test func 開始日と終了日フィルターで範囲内のレースのみ返される() throws {
        let ctx = container.mainContext
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let minus2 = try #require(cal.date(byAdding: .day, value: -2, to: today))
        let minus1 = try #require(cal.date(byAdding: .day, value: -1, to: today))
        let plus1 = try #require(cal.date(byAdding: .day, value: 1, to: today))
        let rMinus2 = Race(date: minus2); ctx.insert(rMinus2)
        let rMinus1 = Race(date: minus1); ctx.insert(rMinus1)
        let rToday = Race(date: today); ctx.insert(rToday)
        let rPlus1 = Race(date: plus1); ctx.insert(rPlus1)
        var f = RaceFilter()
        f.dateFrom = minus1
        f.dateTo = today
        let result = f.apply(to: [rMinus2, rMinus1, rToday, rPlus1])
        #expect(result.count == 2)
        #expect(!result.contains(where: { $0 === rMinus2 || $0 === rPlus1 }))
    }

    @Test func 開始日と同日のレースは範囲内に含まれる() {
        let ctx = container.mainContext
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let rToday = Race(date: today); ctx.insert(rToday)
        var f = RaceFilter()
        f.dateFrom = today
        let result = f.apply(to: [rToday])
        #expect(result.count == 1)
    }

    @Test func 終了日と同日のレースは範囲内に含まれる() {
        let ctx = container.mainContext
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let rToday = Race(date: today); ctx.insert(rToday)
        var f = RaceFilter()
        f.dateTo = today
        let result = f.apply(to: [rToday])
        #expect(result.count == 1)
    }

    // MARK: - apply(to:) 競馬場フィルター

    @Test func 競馬場フィルターで選択した競馬場のレースのみ返される() {
        let ctx = container.mainContext
        let tokyo = Venue(name: "東京"); ctx.insert(tokyo)
        let hanshin = Venue(name: "阪神"); ctx.insert(hanshin)
        let r1 = Race(); r1.venue = tokyo; ctx.insert(r1)
        let r2 = Race(); r2.venue = hanshin; ctx.insert(r2)
        let r3 = Race(); ctx.insert(r3)
        var f = RaceFilter()
        f.venueIDs = [tokyo.persistentModelID]
        let result = f.apply(to: [r1, r2, r3])
        #expect(result.count == 1)
        #expect(result.first === r1)
    }

    @Test func 競馬場フィルターで競馬場未設定レースは除外される() {
        let ctx = container.mainContext
        let tokyo = Venue(name: "東京"); ctx.insert(tokyo)
        let r1 = Race(); r1.venue = tokyo; ctx.insert(r1)
        let r2 = Race(); ctx.insert(r2)
        var f = RaceFilter()
        f.venueIDs = [tokyo.persistentModelID]
        let result = f.apply(to: [r1, r2])
        #expect(result.count == 1)
        #expect(result.first === r1)
    }

    @Test func 複数競馬場フィルターで複数の競馬場のレースが返される() {
        let ctx = container.mainContext
        let tokyo = Venue(name: "東京"); ctx.insert(tokyo)
        let hanshin = Venue(name: "阪神"); ctx.insert(hanshin)
        let nakayama = Venue(name: "中山"); ctx.insert(nakayama)
        let r1 = Race(); r1.venue = tokyo; ctx.insert(r1)
        let r2 = Race(); r2.venue = hanshin; ctx.insert(r2)
        let r3 = Race(); r3.venue = nakayama; ctx.insert(r3)
        var f = RaceFilter()
        f.venueIDs = [tokyo.persistentModelID, hanshin.persistentModelID]
        let result = f.apply(to: [r1, r2, r3])
        #expect(result.count == 2)
        #expect(!result.contains(where: { $0 === r3 }))
    }

    // MARK: - apply(to:) 複合フィルター

    @Test func 複合フィルターで全条件を満たすレースのみ返される() {
        let ctx = container.mainContext
        let tokyo = Venue(name: "東京"); ctx.insert(tokyo)
        let r1 = Race(category: "central", grade: "G1"); r1.venue = tokyo; ctx.insert(r1)
        let r2 = Race(category: "central", grade: "G2"); r2.venue = tokyo; ctx.insert(r2)
        let r3 = Race(category: "local", grade: "G1"); ctx.insert(r3)
        var f = RaceFilter()
        f.venueIDs = [tokyo.persistentModelID]
        f.category = "central"
        f.grades = [.g1]
        let result = f.apply(to: [r1, r2, r3])
        #expect(result.count == 1)
        #expect(result.first === r1)
    }

    @Test func 条件に合致するレースがない場合に空配列が返される() {
        let ctx = container.mainContext
        let r1 = Race(category: "central"); ctx.insert(r1)
        var f = RaceFilter()
        f.category = "local"
        let result = f.apply(to: [r1])
        #expect(result.isEmpty)
    }

    // MARK: - Property-Based Tests

    @Test func フィルター結果は常に入力配列のサブセットになる() throws {
        let ctx = container.mainContext
        let categories = ["central", "local"]
        let gradeRaws = ["G1", "G2", "G3", "Listed", "OpenSpecial", "General", ""]
        for _ in 0 ..< 200 {
            let race = try Race(
                category: #require(categories.randomElement()),
                grade: #require(gradeRaws.randomElement()),
            )
            ctx.insert(race)
            let races = [race]
            var f = RaceFilter()
            f.category = categories.randomElement()
            if Bool.random() {
                f.grades = try [#require(RaceGrade.allCases.randomElement())]
            }
            let result = f.apply(to: races)
            #expect(result.allSatisfy { r in races.contains(where: { $0 === r }) })
        }
    }

    @Test func フィルターなしのときは常に入力と同じ件数が返される() {
        let ctx = container.mainContext
        for _ in 0 ..< 100 {
            let count = Int.random(in: 0 ... 5)
            var races: [Race] = []
            for _ in 0 ..< count {
                let r = Race(); ctx.insert(r); races.append(r)
            }
            let result = RaceFilter().apply(to: races)
            #expect(result.count == races.count)
        }
    }

    @Test func クリア後のフィルターはアクティブでない() {
        for _ in 0 ..< 50 {
            var f = RaceFilter()
            f.category = "central"
            f.grades = [.g1, .g2]
            f.dateFrom = Date()
            f.dateTo = Date()
            f = RaceFilter()
            #expect(f.isActive == false)
        }
    }
}
