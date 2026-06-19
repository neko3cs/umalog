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

    @Test func 日次の集計期間に同日正午が含まれる() throws {
        let date = makeDate(2026, 6, 15)
        let interval = try #require(calc.interval(for: .daily, date: date))
        #expect(interval.contains(makeDate(2026, 6, 15)))
    }

    @Test func 日次の集計期間に翌日が含まれない() throws {
        let date = makeDate(2026, 6, 15)
        let interval = try #require(calc.interval(for: .daily, date: date))
        #expect(!interval.contains(makeDate(2026, 6, 16)))
    }

    @Test func 日次の集計期間に前日が含まれない() throws {
        let date = makeDate(2026, 6, 15)
        let interval = try #require(calc.interval(for: .daily, date: date))
        #expect(!interval.contains(makeDate(2026, 6, 14)))
    }

    @Test func 月次の集計期間に月初と月末が含まれる() throws {
        let date = makeDate(2026, 6, 15)
        let interval = try #require(calc.interval(for: .monthly, date: date))
        #expect(interval.contains(makeDate(2026, 6, 1)))
        #expect(interval.contains(makeDate(2026, 6, 30)))
    }

    @Test func 月次の集計期間に翌月が含まれない() throws {
        let date = makeDate(2026, 6, 15)
        let interval = try #require(calc.interval(for: .monthly, date: date))
        #expect(!interval.contains(makeDate(2026, 7, 1)))
    }

    @Test func 月次の集計期間に前月が含まれない() throws {
        let date = makeDate(2026, 6, 15)
        let interval = try #require(calc.interval(for: .monthly, date: date))
        #expect(!interval.contains(makeDate(2026, 5, 31)))
    }

    @Test func 年次の集計期間に1月1日と12月31日が含まれる() throws {
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

    @Test func 日次で1進めると翌日になる() {
        let date = makeDate(2026, 6, 15)
        let next = calc.advance(date, by: 1, unit: .daily)
        let diff = calc.calendar.dateComponents([.day], from: date, to: next)
        #expect(diff.day == 1)
    }

    @Test func 日次でマイナス1進めると前日になる() {
        let date = makeDate(2026, 6, 15)
        let prev = calc.advance(date, by: -1, unit: .daily)
        let diff = calc.calendar.dateComponents([.day], from: prev, to: date)
        #expect(diff.day == 1)
    }

    @Test func 月次で1進めると翌月になる() {
        let date = makeDate(2026, 6, 15)
        let next = calc.advance(date, by: 1, unit: .monthly)
        #expect(calc.month(from: next) == 7)
        #expect(calc.year(from: next) == 2026)
    }

    @Test func 月次で12月から1進めると翌年1月になる() {
        let date = makeDate(2026, 12, 15)
        let next = calc.advance(date, by: 1, unit: .monthly)
        #expect(calc.month(from: next) == 1)
        #expect(calc.year(from: next) == 2027)
    }

    @Test func 月次で1月からマイナス1進めると前年12月になる() {
        let date = makeDate(2026, 1, 15)
        let prev = calc.advance(date, by: -1, unit: .monthly)
        #expect(calc.month(from: prev) == 12)
        #expect(calc.year(from: prev) == 2025)
    }

    @Test func 年次で1進めると翌年になる() {
        let date = makeDate(2026, 6, 15)
        let next = calc.advance(date, by: 1, unit: .yearly)
        #expect(calc.year(from: next) == 2027)
    }

    // MARK: - title

    @Test func 日次のタイトルが年月日形式で表示される() {
        let date = makeDate(2026, 6, 15)
        #expect(calc.title(for: .daily, date: date) == "2026年6月15日")
    }

    @Test func 月次のタイトルが年月形式で表示される() {
        let date = makeDate(2026, 6, 15)
        #expect(calc.title(for: .monthly, date: date) == "2026年6月")
    }

    @Test func 年次のタイトルが年形式で表示される() {
        let date = makeDate(2026, 6, 15)
        #expect(calc.title(for: .yearly, date: date) == "2026年")
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

    @Test func 期間指定の集計区間に終了日翌日が含まれない() throws {
        let from = makeDate(2026, 3, 1)
        let to = makeDate(2026, 6, 30)
        let interval = try #require(calc.rangeInterval(from: from, to: to))
        #expect(!interval.contains(makeDate(2026, 7, 1)))
    }

    @Test func 期間指定の集計区間に開始日前日が含まれない() throws {
        let from = makeDate(2026, 3, 1)
        let to = makeDate(2026, 6, 30)
        let interval = try #require(calc.rangeInterval(from: from, to: to))
        #expect(!interval.contains(makeDate(2026, 2, 28)))
    }

    @Test func 開始日が終了日より後の場合はnilを返す() {
        let from = makeDate(2026, 7, 1)
        let to = makeDate(2026, 6, 30)
        #expect(calc.rangeInterval(from: from, to: to) == nil)
    }

    @Test func 同一日の期間指定でその日が含まれ翌日が含まれない() throws {
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

    @Test func 単日の期間タイトルに1日間が含まれる() {
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
