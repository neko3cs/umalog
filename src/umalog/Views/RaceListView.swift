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
                            description: Text("右上の + ボタンからレースを追加してください"),
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
                    Button {
                        showingAddRace = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("add-race-button")
                }
            }
            .sheet(isPresented: $showingAddRace) {
                RaceFormView()
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

// MARK: - Snapshot for Undo

/// レース削除の Undo 復元用スナップショット。各プロパティは `Race` の同名フィールドの写しで、
/// 子の出走馬・馬券もネストしたスナップショットとして保持する。
private struct RaceSnapshot {
    let date: Date
    let venueId: PersistentIdentifier?
    let raceNumber: Int
    let raceName: String
    let distance: Int
    let trackType: String
    let trackCondition: String
    let category: String
    let grade: String
    let memo: String
    let sortIndex: Int
    let firstPlaceHorseNumber: Int
    let secondPlaceHorseNumber: Int
    let thirdPlaceHorseNumber: Int
    let entries: [EntrySnapshot]
    let bets: [BetSnapshot]

    /// レースからスナップショットを取る。
    /// - Parameter race: スナップショット対象のレース。
    init(from race: Race) {
        date = race.date
        venueId = race.venue?.persistentModelID
        raceNumber = race.raceNumber
        raceName = race.raceName
        distance = race.distance
        trackType = race.trackType
        trackCondition = race.trackCondition
        category = race.category
        grade = race.grade
        memo = race.memo
        sortIndex = race.sortIndex
        firstPlaceHorseNumber = race.firstPlaceHorseNumber
        secondPlaceHorseNumber = race.secondPlaceHorseNumber
        thirdPlaceHorseNumber = race.thirdPlaceHorseNumber
        entries = (race.entries ?? []).map { EntrySnapshot(from: $0) }
        bets = (race.bets ?? []).map { BetSnapshot(from: $0) }
    }

    /// スナップショットからレースと子データを再作成して挿入する。競馬場・券種は永続 ID で既存マスターと再関連付けする。
    /// - Parameter context: 復元先の ModelContext。
    func restore(into context: ModelContext) {
        let allVenues = (try? context.fetch(FetchDescriptor<Venue>())) ?? []
        let allTicketTypes = (try? context.fetch(FetchDescriptor<TicketType>())) ?? []
        let venue = venueId.flatMap { id in allVenues.first(where: { $0.persistentModelID == id }) }
        let race = Race(
            date: date, venue: venue, raceNumber: raceNumber, raceName: raceName,
            distance: distance, trackType: trackType, trackCondition: trackCondition,
            category: category, grade: grade, memo: memo,
            firstPlaceHorseNumber: firstPlaceHorseNumber,
            secondPlaceHorseNumber: secondPlaceHorseNumber,
            thirdPlaceHorseNumber: thirdPlaceHorseNumber,
            sortIndex: sortIndex,
        )
        context.insert(race)
        for snap in entries {
            context.insert(RaceEntry(
                race: race, horseNumber: snap.horseNumber, horseName: snap.horseName,
                jockeyName: snap.jockeyName, trainerName: snap.trainerName,
                predictionMark: snap.predictionMark, finishPosition: snap.finishPosition,
                sortIndex: snap.sortIndex,
            ))
        }
        for betSnap in bets {
            let ticketType = betSnap.ticketTypeId.flatMap { id in
                allTicketTypes.first(where: { $0.persistentModelID == id })
            }
            let bet = Bet(
                race: race, ticketType: ticketType,
                ticketTypeName: betSnap.ticketTypeName, selection: betSnap.selection,
                unitPrice: betSnap.unitPrice, purchaseAmount: betSnap.purchaseAmount,
                payoutAmount: betSnap.payoutAmount, sortIndex: betSnap.sortIndex,
            )
            context.insert(bet)
            for selSnap in betSnap.selections {
                let selTicketType = selSnap.ticketTypeId.flatMap { id in
                    allTicketTypes.first(where: { $0.persistentModelID == id })
                }
                context.insert(BetSelection(
                    bet: bet, ticketType: selTicketType,
                    ticketTypeName: selSnap.ticketTypeName, selection: selSnap.selection,
                    unitPrice: selSnap.unitPrice, combinationCount: selSnap.combinationCount,
                    sortIndex: selSnap.sortIndex,
                ))
            }
        }
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
