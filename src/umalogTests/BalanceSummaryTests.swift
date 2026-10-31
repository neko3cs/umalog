//
//  BalanceSummaryTests.swift
//  umalog
//
//  Created by neko3cs on 2026/06/17.
//

import Foundation
import Testing
@testable import umalog

struct 収支集計期間計算Test {
    private let calc = BalanceSummaryPeriodCalc()

    private func makeDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        var comps = DateComponents()
        comps.timeZone = TimeZone(identifier: "Asia/Tokyo")
        comps.year = year; comps.month = month; comps.day = day; comps.hour = hour
        return Calendar(identifier: .gregorian).date(from: comps) ?? Date()
    }

    // MARK: - interval

    @Test func 期間モードのintervalは常にnilを返す() {
        let interval = calc.interval(for: .range, date: makeDate(2026, 6, 15))
        #expect(interval == nil)
    }

    @Test(arguments: [(15, true), (14, false), (16, false)])
    func 日次の集計期間には基準日だけが含まれ前日と翌日は含まれない(day: Int, isContained: Bool) throws {
        let interval = try #require(calc.interval(for: .daily, date: makeDate(2026, 6, 15)))
        #expect(interval.contains(makeDate(2026, 6, day)) == isContained)
    }

    @Test func 月次の集計期間に月初と月末が含まれる() throws {
        let date = makeDate(2026, 6, 15)
        let interval = try #require(calc.interval(for: .monthly, date: date))
        #expect(interval.contains(makeDate(2026, 6, 1)))
        #expect(interval.contains(makeDate(2026, 6, 30)))
    }

    @Test func `年次の集計期間に 1 月 1 日と 12 月 31 日が含まれる`() throws {
        let date = makeDate(2026, 6, 15)
        let interval = try #require(calc.interval(for: .yearly, date: date))
        #expect(interval.contains(makeDate(2026, 1, 1)))
        #expect(interval.contains(makeDate(2026, 12, 31)))
    }

    @Test func 年次の集計期間に翌年が含まれない() throws {
        let date = makeDate(2026, 6, 15)
        let interval = try #require(calc.interval(for: .yearly, date: date))
        #expect(!interval.contains(makeDate(2027, 1, 1)))
    }

    // MARK: - advance

    @Test func 期間モードのadvanceは日付を変更しない() {
        let date = makeDate(2026, 6, 15)
        let result = calc.advance(date, by: 1, unit: .range)
        #expect(result == date)
    }

    @Test func `日次で 1 進めると翌日になる`() {
        let date = makeDate(2026, 6, 15)
        let next = calc.advance(date, by: 1, unit: .daily)
        let diff = calc.calendar.dateComponents([.day], from: date, to: next)
        #expect(diff.day == 1)
    }

    @Test func `日次でマイナス 1 進めると前日になる`() {
        let date = makeDate(2026, 6, 15)
        let prev = calc.advance(date, by: -1, unit: .daily)
        let diff = calc.calendar.dateComponents([.day], from: prev, to: date)
        #expect(diff.day == 1)
    }

    @Test(arguments: [
        (6, 1, 2026, 7), // 翌月
        (12, 1, 2027, 1), // 12 月から翌年 1 月
        (1, -1, 2025, 12), // 1 月から前年 12 月
    ])
    func 月次で進めると年をまたいでも前後の月になる(month: Int, steps: Int, expectedYear: Int, expectedMonth: Int) {
        let result = calc.advance(makeDate(2026, month, 15), by: steps, unit: .monthly)
        #expect(calc.year(from: result) == expectedYear)
        #expect(calc.month(from: result) == expectedMonth)
    }

    @Test func `年次で 1 進めると翌年になる`() {
        let date = makeDate(2026, 6, 15)
        let next = calc.advance(date, by: 1, unit: .yearly)
        #expect(calc.year(from: next) == 2027)
    }

    // MARK: - title

    @Test(arguments: [
        (SummaryPeriod.daily, "2026年6月15日"), (.monthly, "2026年6月"), (.yearly, "2026年"), (.range, ""),
    ])
    func 集計単位ごとのタイトルは単位に合った年月日の形式になり期間モードは空文字になる(period: SummaryPeriod, expected: String) {
        #expect(calc.title(for: period, date: makeDate(2026, 6, 15)) == expected)
    }

    // MARK: - setYear / setMonth

    @Test func 年を設定すると月を保持したまま年が変更される() {
        let date = makeDate(2026, 6, 15)
        let updated = calc.setYear(2030, in: date)
        #expect(calc.year(from: updated) == 2030)
        #expect(calc.month(from: updated) == 6)
    }

    @Test func 月を設定すると年を保持したまま月が変更される() {
        let date = makeDate(2026, 6, 15)
        let updated = calc.setMonth(12, in: date)
        #expect(calc.month(from: updated) == 12)
        #expect(calc.year(from: updated) == 2026)
    }

    @Test func `1 月 31 日から 2 月を設定すると 2 月末日に丸められる`() {
        // 丸めないと 2/31 が 3/3 に繰り上がり、選択した月と表示月がズレる
        let date = makeDate(2026, 1, 31)
        let updated = calc.setMonth(2, in: date)
        #expect(calc.month(from: updated) == 2)
        #expect(calc.year(from: updated) == 2026)
        #expect(calc.calendar.component(.day, from: updated) == 28)
    }

    @Test func `31 日ある月へ月を設定すると日が保持される`() {
        let date = makeDate(2026, 1, 31)
        let updated = calc.setMonth(3, in: date)
        #expect(calc.month(from: updated) == 3)
        #expect(calc.calendar.component(.day, from: updated) == 31)
    }

    @Test func `うるう年 2 月 29 日から平年を設定すると 2 月 28 日に丸められる`() {
        let date = makeDate(2024, 2, 29)
        let updated = calc.setYear(2025, in: date)
        #expect(calc.year(from: updated) == 2025)
        #expect(calc.month(from: updated) == 2)
        #expect(calc.calendar.component(.day, from: updated) == 28)
    }

    // MARK: - rangeInterval

    @Test func 期間指定の集計区間に開始日が含まれる() throws {
        let from = makeDate(2026, 3, 1)
        let to = makeDate(2026, 6, 30)
        let interval = try #require(calc.rangeInterval(from: from, to: to))
        #expect(interval.contains(makeDate(2026, 3, 1)))
    }

    @Test func 期間指定の集計区間に終了日が含まれる() throws {
        let from = makeDate(2026, 3, 1)
        let to = makeDate(2026, 6, 30)
        let interval = try #require(calc.rangeInterval(from: from, to: to))
        #expect(interval.contains(makeDate(2026, 6, 30)))
    }

    @Test func 開始日が終了日より後の場合はnilを返す() {
        let from = makeDate(2026, 7, 1)
        let to = makeDate(2026, 6, 30)
        #expect(calc.rangeInterval(from: from, to: to) == nil)
    }

    @Test func `同一日の期間指定でその日が含まれ翌日が含まれない`() throws {
        let date = makeDate(2026, 6, 15)
        let interval = try #require(calc.rangeInterval(from: date, to: date))
        #expect(interval.contains(makeDate(2026, 6, 15)))
        #expect(!interval.contains(makeDate(2026, 6, 16)))
    }

    // MARK: - rangeTitle

    @Test func 期間タイトルに開始日と終了日が含まれる() {
        let from = makeDate(2026, 3, 1)
        let to = makeDate(2026, 6, 14)
        let title = calc.rangeTitle(from: from, to: to)
        #expect(title.contains("2026年3月1日"))
        #expect(title.contains("2026年6月14日"))
    }

    @Test func 期間タイトルに日数が含まれる() {
        let from = makeDate(2026, 6, 1)
        let to = makeDate(2026, 6, 14)
        let title = calc.rangeTitle(from: from, to: to)
        #expect(title.contains("14日間"))
    }

    @Test func `単日の期間タイトルに 1 日間が含まれる`() {
        let date = makeDate(2026, 6, 15)
        let title = calc.rangeTitle(from: date, to: date)
        #expect(title.contains("1日間"))
    }

    @Test func 開始日が終了日より後の期間タイトルにはチルダが含まれない() {
        let from = makeDate(2026, 7, 1)
        let to = makeDate(2026, 6, 30)
        let title = calc.rangeTitle(from: from, to: to)
        #expect(!title.contains("〜"))
    }
}
