//
//  RaceListView.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import SwiftData
import SwiftUI

/// レース一覧のホーム画面。日付ごとのセクション表示・フィルター・ソート・削除（Undo 対応）を提供する。
struct RaceListView: View {
    /// SwiftData のモデルコンテキスト。
    @Environment(\.modelContext) private var modelContext
    /// ウィンドウの UndoManager。レース削除の取り消しに使う。
    @Environment(\.undoManager) private var undoManager
    /// SwiftData から取得した全レース。
    @Query private var races: [Race]
    /// SwiftData から取得した全競馬場。
    @Query(sort: \Venue.sortIndex) private var venues: [Venue]
    /// レース追加シートの表示状態。
    @State private var showingAddRace = false
    /// レース取り込みシートの表示状態。
    @State private var showingImportRace = false
    /// フィルターシートの表示状態。
    @State private var showingFilter = false
    /// 現在のフィルター条件。
    @State private var filter = RaceFilter()
    /// ソート方向。true なら日付昇順、false なら降順。
    @State private var sortAscending = false

    /// フィルターとソートを適用したレース配列。
    private var filteredRaces: [Race] {
        let base = filter.isActive ? filter.apply(to: races) : races
        return base.sorted { sortAscending ? $0.date < $1.date : $0.date > $1.date }
    }

    /// フィルター適用後のレースを日付（その日の 0 時）でグループ化し、ソート方向に従って並べた配列。
    private var groupedRaces: [(Date, [Race])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredRaces) { race in
            calendar.startOfDay(for: race.date)
        }
        return grouped.sorted { sortAscending ? $0.key < $1.key : $0.key > $1.key }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if filter.isActive {
                    FilterChipsView(filter: $filter, venues: venues)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                List {
                    ForEach(groupedRaces, id: \.0) { date, dayRaces in
                        Section {
                            ForEach(dayRaces.sorted { $0.raceNumber < $1.raceNumber }) { race in
                                NavigationLink(destination: RaceDetailView(race: race)) {
                                    RaceRowView(race: race)
                                }
                            }
                            .onDelete { indexSet in
                                let sorted = dayRaces.sorted { $0.raceNumber < $1.raceNumber }
                                for index in indexSet {
                                    deleteRace(sorted[index])
                                }
                            }
                        } header: {
                            Text(date.japaneseShortDateString)
                        }
                    }
                }
                .overlay {
                    if races.isEmpty {
                        ContentUnavailableView(
                            "レースがありません",
                            systemImage: "list.bullet.clipboard",
                            description: Text("右上の + ボタンから、手入力するか AI の予想を取り込んでレースを追加してください"),
                        )
                    } else if filteredRaces.isEmpty {
                        ContentUnavailableView(
                            "条件に一致するレースがありません",
                            systemImage: "line.3.horizontal.decrease.circle",
                            description: Text("フィルター条件を変更してください"),
                        )
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: filter.isActive)
            .navigationTitle("Umalog")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        sortAscending.toggle()
                    } label: {
                        Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                    }
                    .accessibilityIdentifier("sort-toggle-button")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingFilter = true
                    } label: {
                        Image(
                            systemName: filter.isActive
                                ? "line.3.horizontal.decrease.circle.fill"
                                : "line.3.horizontal.decrease.circle",
                        )
                    }
                    .accessibilityIdentifier("filter-button")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingAddRace = true
                        } label: {
                            Label("手入力で追加", systemImage: "square.and.pencil")
                        }
                        .accessibilityIdentifier("add-race-manual-button")
                        Button {
                            showingImportRace = true
                        } label: {
                            Label("JSONで取り込み", systemImage: "doc.on.clipboard")
                        }
                        .accessibilityIdentifier("import-race-button")
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("add-race-button")
                }
            }
            .sheet(isPresented: $showingAddRace) {
                RaceFormView()
            }
            .sheet(isPresented: $showingImportRace) {
                RaceJSONImportView()
            }
            .sheet(isPresented: $showingFilter) {
                RaceFilterView(filter: $filter)
            }
        }
    }

    /// レースを子データごと削除する。削除前にスナップショットを取り、シェイクで復元できるよう Undo を登録する。
    /// - Parameter race: 削除対象のレース。
    private func deleteRace(_ race: Race) {
        let snapshot = RaceSnapshot(from: race)
        undoManager?.registerUndo(withTarget: modelContext) { [snapshot] ctx in
            snapshot.restore(into: ctx)
        }
        undoManager?.setActionName("レースを削除")

        (race.entries ?? []).forEach { modelContext.delete($0) }
        for bet in race.bets ?? [] {
            (bet.selections ?? []).forEach { modelContext.delete($0) }
            modelContext.delete(bet)
        }
        modelContext.delete(race)
    }
}

/// レース一覧の 1 行。レース番号・競馬場・コース情報・収支サマリーを表示する。
struct RaceRowView: View {
    /// 表示対象のレース。
    let race: Race

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("R\(race.raceNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let venue = race.venue {
                    Text(venue.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(race.trackType == "turf" ? "芝" : "ダ")
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(race.trackType == "turf" ? Color.green.opacity(0.2) : Color.brown.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Text("\(race.distance)m")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(race.trackCondition)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                Text(race.raceName.isEmpty ? "\(race.raceNumber)R" : race.raceName)
                if !race.grade.isEmpty, let gradeEnum = RaceGrade(rawValue: race.grade) {
                    Text(gradeEnum.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(gradeEnum.badgeColor.opacity(0.2))
                        .foregroundStyle(gradeEnum.badgeColor)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            HStack(spacing: 12) {
                Text("購入 ¥\(race.totalPurchase.formatted())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("払戻 ¥\(race.totalPayout.formatted())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if race.totalPurchase > 0 {
                    Text(race.balance >= 0 ? "+¥\(race.balance.formatted())" : "−¥\((-race.balance).formatted())")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(race.balance >= 0 ? .green : .red)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Grade Badge Color

private extension RaceGrade {
    /// リスト行バッジの背景・前景色。
    var badgeColor: Color {
        switch self {
        case .unspecified: .clear
        case .g1: .purple
        case .g2: .blue
        case .g3: .green
        case .listed: .orange
        case .openSpecial, .general: .secondary
        }
    }
}
