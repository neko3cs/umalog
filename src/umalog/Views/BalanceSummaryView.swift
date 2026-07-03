//
//  BalanceSummaryView.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import SwiftData
import SwiftUI

enum SummaryPeriod: String, CaseIterable {
    case daily = "日"
    case monthly = "月"
    case yearly = "年"
    case range = "期間"
}

// MARK: - Period Calculator

struct BalanceSummaryPeriodCalc {
    let calendar: Calendar

    init() {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "ja_JP")
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        calendar = cal
    }

    func interval(for period: SummaryPeriod, date: Date) -> DateInterval? {
        switch period {
        case .daily: calendar.dateInterval(of: .day, for: date)
        case .monthly: calendar.dateInterval(of: .month, for: date)
        case .yearly: calendar.dateInterval(of: .year, for: date)
        case .range: nil
        }
    }

    func rangeInterval(from: Date, to: Date) -> DateInterval? {
        guard from <= to else { return nil }
        let start = calendar.startOfDay(for: from)
        let end = calendar.startOfDay(for: to).addingTimeInterval(86400)
        return DateInterval(start: start, end: end)
    }

    func advance(_ date: Date, by steps: Int, unit period: SummaryPeriod) -> Date {
        let component: Calendar.Component
        switch period {
        case .daily: component = .day
        case .monthly: component = .month
        case .yearly: component = .year
        case .range: return date
        }
        return calendar.date(byAdding: component, value: steps, to: date) ?? date
    }

    func title(for period: SummaryPeriod, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        switch period {
        case .daily: formatter.dateFormat = "yyyy年M月d日"
        case .monthly: formatter.dateFormat = "yyyy年M月"
        case .yearly: formatter.dateFormat = "yyyy年"
        case .range: return ""
        }
        return formatter.string(from: date)
    }

    func rangeTitle(from: Date, to: Date) -> String {
        guard from <= to else { return "期間を正しく設定してください" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日"
        let fromStr = formatter.string(from: from)
        let toStr = formatter.string(from: to)
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: from),
            to: calendar.startOfDay(for: to),
        ).day.map { $0 + 1 } ?? 1
        return "\(fromStr) 〜 \(toStr) (\(days)日間)"
    }

    func year(from date: Date) -> Int {
        calendar.component(.year, from: date)
    }

    func month(from date: Date) -> Int {
        calendar.component(.month, from: date)
    }

    func setYear(_ year: Int, in date: Date) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day], from: date)
        comps.year = year
        return calendar.date(from: comps) ?? date
    }

    func setMonth(_ month: Int, in date: Date) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day], from: date)
        comps.month = month
        return calendar.date(from: comps) ?? date
    }
}

// MARK: - BalanceSummaryView

struct BalanceSummaryView: View {
    @Query private var races: [Race]

    @State private var period: SummaryPeriod = .monthly
    @State private var selectedDate: Date = .init()
    @State private var fromDate: Date = Calendar.current.date(
        byAdding: .month, value: -1, to: Date(),
    ) ?? Date()
    @State private var toDate: Date = .init()

    private let calc = BalanceSummaryPeriodCalc()

    private var isRangeValid: Bool {
        period != .range || fromDate <= toDate
    }

    private var filteredRaces: [Race] {
        if period == .range {
            guard let interval = calc.rangeInterval(from: fromDate, to: toDate) else { return [] }
            return races.filter { interval.contains($0.date) }
        }
        guard let interval = calc.interval(for: period, date: selectedDate) else { return [] }
        return races.filter { interval.contains($0.date) }
    }

    private var totalPurchase: Int {
        filteredRaces.reduce(0) { $0 + $1.totalPurchase }
    }

    private var totalPayout: Int {
        filteredRaces.reduce(0) { $0 + $1.totalPayout }
    }

    private var balance: Int {
        totalPayout - totalPurchase
    }

    private var returnRate: Double? {
        guard totalPurchase > 0 else { return nil }
        return Double(totalPayout) / Double(totalPurchase)
    }

    var body: some View {
        NavigationStack {
            List {
                periodControlSection
                summarySection
                if !filteredRaces.isEmpty { breakdownSection }
            }
            .navigationTitle("収支")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("今日") {
                        goToToday()
                    }
                    .accessibilityIdentifier("today-button")
                }
            }
        }
    }

    /// 日/月/年モードでは選択日を、期間モードでは開始日・終了日を今日にリセットする
    private func goToToday() {
        let today = Date()
        selectedDate = today
        fromDate = today
        toDate = today
    }

    // MARK: - Period Control Section

    private var periodControlSection: some View {
        Section {
            Picker("集計単位", selection: $period) {
                ForEach(SummaryPeriod.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
            .pickerStyle(.segmented)

            navigationRow
            periodPickerRow
        }
    }

    private var navigationRow: some View {
        HStack {
            Button {
                selectedDate = calc.advance(selectedDate, by: -1, unit: period)
            } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 32)
            }
            .buttonStyle(.borderless)
            .disabled(period == .range)
            .accessibilityIdentifier("period-prev-button")
            Spacer()
            Group {
                if period == .range {
                    Text(calc.rangeTitle(from: fromDate, to: toDate))
                        .multilineTextAlignment(.center)
                } else {
                    Text(calc.title(for: period, date: selectedDate))
                }
            }
            .font(.headline)
            .accessibilityIdentifier("period-title")
            Spacer()
            Button {
                selectedDate = calc.advance(selectedDate, by: 1, unit: period)
            } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 32)
            }
            .buttonStyle(.borderless)
            .disabled(period == .range)
            .accessibilityIdentifier("period-next-button")
        }
    }

    @ViewBuilder
    private var periodPickerRow: some View {
        switch period {
        case .daily:
            DatePicker("日付", selection: $selectedDate, displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "ja_JP"))
        case .monthly:
            HStack {
                Picker("年", selection: Binding(
                    get: { calc.year(from: selectedDate) },
                    set: { selectedDate = calc.setYear($0, in: selectedDate) },
                )) {
                    ForEach(2000 ... 2050, id: \.self) { year in
                        Text(verbatim: "\(year)年").tag(year)
                    }
                }
                .frame(maxWidth: .infinity)
                Picker("月", selection: Binding(
                    get: { calc.month(from: selectedDate) },
                    set: { selectedDate = calc.setMonth($0, in: selectedDate) },
                )) {
                    ForEach(1 ... 12, id: \.self) { month in
                        Text(verbatim: "\(month)月").tag(month)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        case .yearly:
            Picker("年", selection: Binding(
                get: { calc.year(from: selectedDate) },
                set: { selectedDate = calc.setYear($0, in: selectedDate) },
            )) {
                ForEach(2000 ... 2050, id: \.self) { year in
                    Text(verbatim: "\(year)年").tag(year)
                }
            }
            .frame(maxWidth: .infinity)
        case .range:
            rangePickers
        }
    }

    private var rangePickers: some View {
        VStack(spacing: 0) {
            DatePicker("開始日", selection: $fromDate, displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "ja_JP"))
            DatePicker("終了日", selection: $toDate, displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "ja_JP"))
            if fromDate > toDate {
                Text("開始日は終了日より前に設定してください")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        Section("集計") {
            summaryRow("購入合計", "¥\(totalPurchase.formatted())")
            summaryRow("払戻合計", "¥\(totalPayout.formatted())")
            summaryRow(
                "収支",
                "\(balance >= 0 ? "+" : "−")¥\(abs(balance).formatted())",
                color: totalPurchase == 0 ? .primary : balance >= 0 ? .green : .red,
            )
            if let rate = returnRate {
                summaryRow("回収率", String(format: "%.1f%%", rate * 100))
            }
            summaryRow("レース数", "\(filteredRaces.count) R")
        }
    }

    // MARK: - Breakdown Section

    private var breakdownSection: some View {
        Section("内訳") {
            ForEach(filteredRaces.sorted { $0.date > $1.date }) { race in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(race.date.japaneseShortDateString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let venue = race.venue {
                                Text(venue.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("R\(race.raceNumber)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(race.raceName.isEmpty ? "R\(race.raceNumber)" : race.raceName)
                            .font(.body)
                    }
                    Spacer()
                    if race.totalPurchase > 0 {
                        Text("\(race.balance >= 0 ? "+" : "−")¥\(abs(race.balance).formatted())")
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundStyle(race.balance >= 0 ? .green : .red)
                    }
                }
            }
        }
    }

    private func summaryRow(_ label: String, _ value: String, color: Color = .primary) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(color)
                .fontWeight(.medium)
        }
    }
}
