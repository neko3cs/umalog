//
//  RaceFilterView.swift
//  umalog
//
//  Created by neko3cs on 2026/06/30.
//

import SwiftData
import SwiftUI

// MARK: - RaceFilter

/// レース一覧フィルター条件を保持する値型。
struct RaceFilter: Equatable {
    /// 選択した競馬場の永続ID。空なら全競馬場を対象とする。
    var venueIDs: Set<PersistentIdentifier> = []
    /// 区分フィルター。nil なら全区分。"central" または "local"。
    var category: String?
    /// 選択グレード。空なら全グレードを対象とする。
    var grades: Set<RaceGrade> = []
    /// 絞り込み開始日。nil なら下限なし。
    var dateFrom: Date?
    /// 絞り込み終了日。nil なら上限なし。
    var dateTo: Date?

    /// いずれかの条件が設定されているか。
    var isActive: Bool {
        !venueIDs.isEmpty || category != nil || !grades.isEmpty || dateFrom != nil || dateTo != nil
    }

    /// レース配列にフィルターを適用した結果を返す。
    /// - Parameter races: フィルター適用前のレース配列。
    /// - Returns: 全条件を満たすレースのみからなる配列。
    func apply(to races: [Race]) -> [Race] {
        races.filter { matchesVenue($0) && matchesCategory($0) && matchesGrade($0) && matchesDateRange($0) }
    }

    /// 競馬場条件に合致するか。venueIDs が空なら常に true。
    /// - Parameter race: 評価対象のレース。
    private func matchesVenue(_ race: Race) -> Bool {
        guard !venueIDs.isEmpty else { return true }
        guard let venue = race.venue else { return false }
        return venueIDs.contains(venue.persistentModelID)
    }

    /// 区分条件に合致するか。category が nil なら常に true。
    /// - Parameter race: 評価対象のレース。
    private func matchesCategory(_ race: Race) -> Bool {
        guard let category else { return true }
        return race.category == category
    }

    /// グレード条件に合致するか。grades が空なら常に true。
    /// - Parameter race: 評価対象のレース。
    private func matchesGrade(_ race: Race) -> Bool {
        guard !grades.isEmpty else { return true }
        return grades.contains(RaceGrade(rawValue: race.grade) ?? .unspecified)
    }

    /// 日付範囲条件に合致するか。dateFrom/dateTo が nil の端は制限なし。
    /// - Parameter race: 評価対象のレース。
    private func matchesDateRange(_ race: Race) -> Bool {
        let cal = Calendar.current
        if let from = dateFrom, race.date < cal.startOfDay(for: from) { return false }
        if let to = dateTo {
            guard let nextDay = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: to)) else { return true }
            if race.date >= nextDay { return false }
        }
        return true
    }
}

// MARK: - RaceFilterView

/// フィルター設定シート。
struct RaceFilterView: View {
    /// 適用するフィルター条件。
    @Binding var filter: RaceFilter
    /// SwiftData から取得した全競馬場。
    @Query(sort: \Venue.sortIndex) private var venues: [Venue]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if !venues.isEmpty {
                    Section("競馬場") {
                        ForEach(venues) { venue in
                            venueToggle(for: venue)
                        }
                    }
                }
                Section("区分") {
                    categoryPicker
                }
                Section("グレード") {
                    ForEach(RaceGrade.allCases.filter { $0 != .unspecified }, id: \.self) { grade in
                        gradeToggle(for: grade)
                    }
                }
                Section("日付範囲") {
                    dateRangeRows
                }
            }
            .navigationTitle("フィルター")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("クリア") { filter = RaceFilter() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }

    /// 指定競馬場の選択行。タップで選択トグルする。
    /// - Parameter venue: 対象の競馬場。
    private func venueToggle(for venue: Venue) -> some View {
        let isSelected = filter.venueIDs.contains(venue.persistentModelID)
        return Button {
            if isSelected {
                filter.venueIDs.remove(venue.persistentModelID)
            } else {
                filter.venueIDs.insert(venue.persistentModelID)
            }
        } label: {
            HStack {
                Text(venue.name)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
    }

    /// 区分（中央/地方）選択ピッカー。
    private var categoryPicker: some View {
        Picker("区分", selection: $filter.category) {
            Text("すべて").tag(String?.none)
            Text("中央").tag(String?.some("central"))
            Text("地方").tag(String?.some("local"))
        }
        .pickerStyle(.segmented)
    }

    /// 指定グレードの選択行。タップで選択トグルする。
    /// - Parameter grade: 対象のグレード。
    private func gradeToggle(for grade: RaceGrade) -> some View {
        let isSelected = filter.grades.contains(grade)
        return Button {
            if isSelected {
                filter.grades.remove(grade)
            } else {
                filter.grades.insert(grade)
            }
        } label: {
            HStack {
                Text(grade.displayName)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
    }

    /// 開始日・終了日を設定する行群。
    @ViewBuilder
    private var dateRangeRows: some View {
        dateBoundaryRow(
            label: "開始日を指定",
            isSet: filter.dateFrom != nil,
            onToggle: { on in filter.dateFrom = on ? Calendar.current.startOfDay(for: Date()) : nil },
        )
        if let dateFrom = filter.dateFrom {
            DatePicker(
                "開始日",
                selection: Binding(get: { dateFrom }, set: { filter.dateFrom = $0 }),
                displayedComponents: .date,
            )
        }
        dateBoundaryRow(
            label: "終了日を指定",
            isSet: filter.dateTo != nil,
            onToggle: { on in filter.dateTo = on ? Calendar.current.startOfDay(for: Date()) : nil },
        )
        if let dateTo = filter.dateTo {
            DatePicker(
                "終了日",
                selection: Binding(get: { dateTo }, set: { filter.dateTo = $0 }),
                displayedComponents: .date,
            )
        }
    }

    /// 日付範囲の開始日・終了日指定有無を切り替える行。
    /// - Parameters:
    ///   - label: 行に表示するラベル。
    ///   - isSet: 現在指定済みかどうか。
    ///   - onToggle: 指定有無が切り替わったときに呼ばれるハンドラ。
    private func dateBoundaryRow(label: String, isSet: Bool, onToggle: @escaping (Bool) -> Void) -> some View {
        Button {
            onToggle(!isSet)
        } label: {
            HStack {
                Text(label)
                    .foregroundStyle(.primary)
                Spacer()
                if isSet {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
    }
}

// MARK: - FilterChipsView

/// アクティブなフィルター条件をチップ形式で横スクロール表示するビュー。
struct FilterChipsView: View {
    /// 編集対象のフィルター条件。
    @Binding var filter: RaceFilter
    /// 競馬場名のルックアップに使う全競馬場。
    let venues: [Venue]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(filter.venueIDs), id: \.self) { id in
                    if let venue = venues.first(where: { $0.persistentModelID == id }) {
                        FilterChip(label: venue.name) { filter.venueIDs.remove(id) }
                    }
                }
                if let cat = filter.category {
                    FilterChip(label: cat == "central" ? "中央" : "地方") { filter.category = nil }
                }
                ForEach(RaceGrade.allCases.filter { filter.grades.contains($0) }, id: \.self) { grade in
                    FilterChip(label: grade.displayName) { filter.grades.remove(grade) }
                }
                if let from = filter.dateFrom {
                    FilterChip(label: "\(from.japaneseShortDateString)〜") { filter.dateFrom = nil }
                }
                if let to = filter.dateTo {
                    FilterChip(label: "〜\(to.japaneseShortDateString)") { filter.dateTo = nil }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - FilterChip

/// 個別フィルター条件を表すチップ。タップで解除できる。
struct FilterChip: View {
    /// チップに表示するラベルテキスト。
    let label: String
    /// タップ時（フィルター解除）に実行するアクション。
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.caption)
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.15))
            .foregroundStyle(Color.accentColor)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
