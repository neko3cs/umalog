//
//  BalanceSummaryTests.swift
//  umalog
//
//  Created by neko3cs on 2026/06/17.
//

import Foundation
import Testing
@testable import umalog

struct BalanceSummaryTests {
    private let calc = BalanceSummaryPeriodCalc()

    private func makeDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        var comps = DateComponents()
        comps.timeZone = TimeZone(identifier: "Asia/Tokyo")
        comps.year = year; comps.month = month; comps.day = day; comps.hour = hour
        return Calendar(identifier: .gregorian).date(from: comps) ?? Date()
    }

    // MARK: - interval

    @Test func interval_daily_containsSameDayNoon() throws {
        let date = makeDate(2026, 6, 15)
        let interval = try #require(calc.interval(for: .daily, date: date))
        #expect(interval.contains(makeDate(2026, 6, 15)))
    }

    @Test func interval_daily_doesNotContainNextDay() throws {
        let date = makeDate(2026, 6, 15)
        let interval = try #require(calc.interval(for: .daily, date: date))
        #expect(!interval.contains(makeDate(2026, 6, 16)))
    }

    @Test func interval_daily_doesNotContainPreviousDay() throws {
        let date = makeDate(2026, 6, 15)
        let interval = try #require(calc.interval(for: .daily, date: date))
        #expect(!interval.contains(makeDate(2026, 6, 14)))
    }

    @Test func interval_monthly_containsFirstAndLastDay() throws {
        let date = makeDate(2026, 6, 15)
        let interval = try #require(calc.interval(for: .monthly, date: date))
        #expect(interval.contains(makeDate(2026, 6, 1)))
        #expect(interval.contains(makeDate(2026, 6, 30)))
    }

    @Test func interval_monthly_doesNotContainNextMonth() throws {
        let date = makeDate(2026, 6, 15)
        let interval = try #require(calc.interval(for: .monthly, date: date))
        #expect(!interval.contains(makeDate(2026, 7, 1)))
    }

    @Test func interval_monthly_doesNotContainPreviousMonth() throws {
        let date = makeDate(2026, 6, 15)
        let interval = try #require(calc.interval(for: .monthly, date: date))
        #expect(!interval.contains(makeDate(2026, 5, 31)))
    }

    @Test func interval_yearly_containsJan1AndDec31() throws {
        let date = makeDate(2026, 6, 15)
        let interval = try #require(calc.interval(for: .yearly, date: date))
        #expect(interval.contains(makeDate(2026, 1, 1)))
        #expect(interval.contains(makeDate(2026, 12, 31)))
    }

    @Test func interval_yearly_doesNotContainNextYear() throws {
        let date = makeDate(2026, 6, 15)
        let interval = try #require(calc.interval(for: .yearly, date: date))
        #expect(!interval.contains(makeDate(2027, 1, 1)))
    }

    // MARK: - advance

    @Test func advance_daily_forwardByOne_incrementsDay() {
        let date = makeDate(2026, 6, 15)
        let next = calc.advance(date, by: 1, unit: .daily)
        let diff = calc.calendar.dateComponents([.day], from: date, to: next)
        #expect(diff.day == 1)
    }

    @Test func advance_daily_backwardByOne_decrementsDay() {
        let date = makeDate(2026, 6, 15)
        let prev = calc.advance(date, by: -1, unit: .daily)
        let diff = calc.calendar.dateComponents([.day], from: prev, to: date)
        #expect(diff.day == 1)
    }

    @Test func advance_monthly_forwardByOne_incrementsMonth() {
        let date = makeDate(2026, 6, 15)
        let next = calc.advance(date, by: 1, unit: .monthly)
        #expect(calc.month(from: next) == 7)
        #expect(calc.year(from: next) == 2026)
    }

    @Test func advance_monthly_wrapsToNextYear() {
        let date = makeDate(2026, 12, 15)
        let next = calc.advance(date, by: 1, unit: .monthly)
        #expect(calc.month(from: next) == 1)
        #expect(calc.year(from: next) == 2027)
    }

    @Test func advance_monthly_wrapsToPreviousYear() {
        let date = makeDate(2026, 1, 15)
        let prev = calc.advance(date, by: -1, unit: .monthly)
        #expect(calc.month(from: prev) == 12)
        #expect(calc.year(from: prev) == 2025)
    }

    @Test func advance_yearly_forwardByOne_incrementsYear() {
        let date = makeDate(2026, 6, 15)
        let next = calc.advance(date, by: 1, unit: .yearly)
        #expect(calc.year(from: next) == 2027)
    }

    // MARK: - title

    @Test func title_daily_formatsWithDayUnit() {
        let date = makeDate(2026, 6, 15)
        #expect(calc.title(for: .daily, date: date) == "2026年6月15日")
    }

    @Test func title_monthly_formatsWithMonthUnit() {
        let date = makeDate(2026, 6, 15)
        #expect(calc.title(for: .monthly, date: date) == "2026年6月")
    }

    @Test func title_yearly_formatsWithYearUnit() {
        let date = makeDate(2026, 6, 15)
        #expect(calc.title(for: .yearly, date: date) == "2026年")
    }

    // MARK: - setYear / setMonth

    @Test func setYear_updatesYearPreservingMonth() {
        let date = makeDate(2026, 6, 15)
        let updated = calc.setYear(2030, in: date)
        #expect(calc.year(from: updated) == 2030)
        #expect(calc.month(from: updated) == 6)
    }

    @Test func setMonth_updatesMonthPreservingYear() {
        let date = makeDate(2026, 6, 15)
        let updated = calc.setMonth(12, in: date)
        #expect(calc.month(from: updated) == 12)
        #expect(calc.year(from: updated) == 2026)
    }

    // MARK: - rangeInterval

    @Test func rangeInterval_containsFromDate() throws {
        let from = makeDate(2026, 3, 1)
        let to = makeDate(2026, 6, 30)
        let interval = try #require(calc.rangeInterval(from: from, to: to))
        #expect(interval.contains(makeDate(2026, 3, 1)))
    }

    @Test func rangeInterval_containsToDate() throws {
        let from = makeDate(2026, 3, 1)
        let to = makeDate(2026, 6, 30)
        let interval = try #require(calc.rangeInterval(from: from, to: to))
        #expect(interval.contains(makeDate(2026, 6, 30)))
    }

    @Test func rangeInterval_doesNotContainDayAfterTo() throws {
        let from = makeDate(2026, 3, 1)
        let to = makeDate(2026, 6, 30)
        let interval = try #require(calc.rangeInterval(from: from, to: to))
        #expect(!interval.contains(makeDate(2026, 7, 1)))
    }

    @Test func rangeInterval_doesNotContainDayBeforeFrom() throws {
        let from = makeDate(2026, 3, 1)
        let to = makeDate(2026, 6, 30)
        let interval = try #require(calc.rangeInterval(from: from, to: to))
        #expect(!interval.contains(makeDate(2026, 2, 28)))
    }

    @Test func rangeInterval_returnsNilWhenFromAfterTo() {
        let from = makeDate(2026, 7, 1)
        let to = makeDate(2026, 6, 30)
        #expect(calc.rangeInterval(from: from, to: to) == nil)
    }

    @Test func rangeInterval_singleDay_containsThatDay() throws {
        let date = makeDate(2026, 6, 15)
        let interval = try #require(calc.rangeInterval(from: date, to: date))
        #expect(interval.contains(makeDate(2026, 6, 15)))
        #expect(!interval.contains(makeDate(2026, 6, 16)))
    }

    // MARK: - rangeTitle

    @Test func rangeTitle_formatsFromAndTo() {
        let from = makeDate(2026, 3, 1)
        let to = makeDate(2026, 6, 14)
        let title = calc.rangeTitle(from: from, to: to)
        #expect(title.contains("2026年3月1日"))
        #expect(title.contains("2026年6月14日"))
    }

    @Test func rangeTitle_includesDayCount() {
        let from = makeDate(2026, 6, 1)
        let to = makeDate(2026, 6, 14)
        let title = calc.rangeTitle(from: from, to: to)
        #expect(title.contains("14日間"))
    }

    @Test func rangeTitle_singleDay_shows1DayCount() {
        let date = makeDate(2026, 6, 15)
        let title = calc.rangeTitle(from: date, to: date)
        #expect(title.contains("1日間"))
    }

    @Test func rangeTitle_whenFromAfterTo_returnsErrorMessage() {
        let from = makeDate(2026, 7, 1)
        let to = makeDate(2026, 6, 30)
        let title = calc.rangeTitle(from: from, to: to)
        #expect(!title.contains("〜"))
    }
}
