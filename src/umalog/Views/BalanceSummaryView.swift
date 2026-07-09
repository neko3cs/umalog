//
//  BalanceSummaryView.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import SwiftData
import SwiftUI

/// 収支集計の単位。rawValue はセグメントピッカーの表示名。
enum SummaryPeriod: String, CaseIterable {
    /// 日次集計
    case daily = "日"
    /// 月次集計
    case monthly = "月"
    /// 年次集計
    case yearly = "年"
    /// 任意の日付範囲での集計
    case range = "期間"
}

// MARK: - Period Calculator

/// 収支集計の期間計算ロジック。日本時間（ja_JP / Asia/Tokyo）の暦で計算する。
struct BalanceSummaryPeriodCalc {
    /// 期間計算に使うカレンダー（グレゴリオ暦・日本時間）。
    let calendar: Calendar

    /// 日本時間のカレンダーを構築する。
    init() {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "ja_JP")
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        calendar = cal
    }

    /// 指定日を含む集計期間を返す。
    /// - Parameters:
    ///   - period: 集計単位。
    ///   - date: 基準日。
    /// - Returns: 集計期間。期間モード（`.range`）の場合は nil。
    func interval(for period: SummaryPeriod, date: Date) -> DateInterval? {
        switch period {
        case .daily: calendar.dateInterval(of: .day, for: date)
        case .monthly: calendar.dateInterval(of: .month, for: date)
        case .yearly: calendar.dateInterval(of: .year, for: date)
        case .range: nil
        }
    }

    /// 開始日から終了日まで（両端の日を含む）の集計期間を返す。
    /// - Parameters:
    ///   - from: 開始日。
    ///   - to: 終了日。
    /// - Returns: 集計期間。開始日が終了日より後の場合は nil。
    func rangeInterval(from: Date, to: Date) -> DateInterval? {
        guard from <= to else { return nil }
        let start = calendar.startOfDay(for: from)
        let end = calendar.startOfDay(for: to).addingTimeInterval(86400)
        return DateInterval(start: start, end: end)
    }

    /// 基準日を集計単位で指定ステップ分進めた日付を返す。
    /// - Parameters:
    ///   - date: 基準日。
    ///   - steps: 進めるステップ数。負数で戻す。
    ///   - period: 集計単位。期間モードの場合は日付を変更しない。
    /// - Returns: 移動後の日付。
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

    /// 集計期間のタイトル文字列（例: `2026年6月`）を返す。
    /// - Parameters:
    ///   - period: 集計単位。
    ///   - date: 基準日。
    /// - Returns: タイトル文字列。期間モードの場合は空文字。
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

    /// 期間モードのタイトル文字列（例: `2026年6月1日 〜 2026年6月14日 (14日間)`）を返す。
    /// - Parameters:
    ///   - from: 開始日。
    ///   - to: 終了日。
    /// - Returns: タイトル文字列。開始日が終了日より後の場合はエラーメッセージ。
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

    /// 日付から年を取り出す。
    /// - Parameter date: 対象の日付。
    /// - Returns: 年。
    func year(from date: Date) -> Int {
        calendar.component(.year, from: date)
    }

    /// 日付から月を取り出す。
    /// - Parameter date: 対象の日付。
    /// - Returns: 月（1〜12）。
    func month(from date: Date) -> Int {
        calendar.component(.month, from: date)
    }

    /// 日付の年だけを変更した日付を返す。変更後の年月に存在しない日は月末日に丸める。
    /// - Parameters:
    ///   - year: 設定する年。
    ///   - date: 基準の日付。
    /// - Returns: 変更後の日付。
    func setYear(_ year: Int, in date: Date) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day], from: date)
        comps.year = year
        return dateClampedToMonthEnd(comps) ?? date
    }

    /// 日付の月だけを変更した日付を返す。変更後の年月に存在しない日は月末日に丸める。
    /// - Parameters:
    ///   - month: 設定する月（1〜12）。
    ///   - date: 基準の日付。
    /// - Returns: 変更後の日付。
    func setMonth(_ month: Int, in date: Date) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day], from: date)
        comps.month = month
        return dateClampedToMonthEnd(comps) ?? date
    }

    /// 日が変更後の年月に存在しない場合（例: 1月31日 → 2月）に月末日へ丸めて Date を生成する。
    /// 丸めないと Calendar が翌月へ繰り上げるため、ピッカーで選んだ月と表示月がズレてしまう。
    /// - Parameter components: year・month・day を含む変更後の日付コンポーネント。
    /// - Returns: 丸め後の日付。生成に失敗した場合は nil。
    private func dateClampedToMonthEnd(_ components: DateComponents) -> Date? {
        var comps = components
        let day = comps.day ?? 1
        comps.day = 1
        guard let firstOfMonth = calendar.date(from: comps),
              let dayRange = calendar.range(of: .day, in: .month, for: firstOfMonth)
        else { return nil }
        comps.day = min(day, dayRange.upperBound - 1)
        return calendar.date(from: comps)
    }
}

// MARK: - BalanceSummaryView

/// 収支サマリー画面。日・月・年・期間の単位で購入合計・払戻合計・収支・回収率を集計表示する。
struct BalanceSummaryView: View {
    /// SwiftData から取得した全レース。
    @Query private var races: [Race]

    /// 選択中の集計単位。
    @State private var period: SummaryPeriod = .monthly
    /// 日・月・年モードの基準日。
    @State private var selectedDate: Date = .init()
    /// 期間モードの開始日。初期値は 1 か月前。
    @State private var fromDate: Date = Calendar.current.date(
        byAdding: .month, value: -1, to: Date(),
    ) ?? Date()
    /// 期間モードの終了日。
    @State private var toDate: Date = .init()

    /// 期間計算ロジック。
    private let calc = BalanceSummaryPeriodCalc()

    /// 期間モードの開始日・終了日が正しい順序かどうか。
    private var isRangeValid: Bool {
        period != .range || fromDate <= toDate
    }

    /// 現在の集計期間に開催日が含まれるレース。
    private var filteredRaces: [Race] {
        if period == .range {
            guard let interval = calc.rangeInterval(from: fromDate, to: toDate) else { return [] }
            return races.filter { interval.contains($0.date) }
        }
        guard let interval = calc.interval(for: period, date: selectedDate) else { return [] }
        return races.filter { interval.contains($0.date) }
    }

    /// 集計期間内の購入額合計。
    private var totalPurchase: Int {
        filteredRaces.reduce(0) { $0 + $1.totalPurchase }
    }

    /// 集計期間内の払戻額合計。
    private var totalPayout: Int {
        filteredRaces.reduce(0) { $0 + $1.totalPayout }
    }

    /// 集計期間内の収支（払戻合計 − 購入合計）。
    private var balance: Int {
        totalPayout - totalPurchase
    }

    /// 集計期間内の回収率。購入がない場合は nil。
    private var returnRate: Double? {
        guard totalPurchase > 0 else { return nil }
        return Double(totalPayout) / Double(totalPurchase)
    }

    var body: some View {
        NavigationStack {
            List {
                periodControlSection
                summarySection
                if !filteredRaces.isEmpty {
                    breakdownSection
                }
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

    /// 集計単位ピッカー・前後移動・日付選択をまとめたセクション。
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

    /// 期間タイトルと前後移動ボタンの行。期間モードでは移動ボタンを無効化する。
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

    /// 集計単位に応じた日付選択 UI（日: DatePicker / 月: 年月ピッカー / 年: 年ピッカー / 期間: 範囲指定）。
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

    /// 期間モードの開始日・終了日ピッカーと順序エラーの表示。
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

    /// 購入合計・払戻合計・収支・回収率・レース数の集計セクション。
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

    /// 集計期間内のレースを日付降順で並べた内訳セクション。
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

    /// 集計セクションのラベルと値の行を生成する。
    /// - Parameters:
    ///   - label: 行ラベル。
    ///   - value: 表示する値。
    ///   - color: 値の文字色。
    /// - Returns: 集計行のビュー。
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
