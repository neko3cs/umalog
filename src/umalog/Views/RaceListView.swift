//
//  RaceListView.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import SwiftData
import SwiftUI

struct RaceListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.undoManager) private var undoManager
    @Query(sort: \Race.date, order: .reverse) private var races: [Race]
    @State private var showingAddRace = false

    private var groupedRaces: [(Date, [Race])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: races) { race in
            calendar.startOfDay(for: race.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    var body: some View {
        NavigationStack {
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
            .navigationTitle("Umalog")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddRace = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddRace) {
                RaceFormView()
            }
            .overlay {
                if races.isEmpty {
                    ContentUnavailableView(
                        "レースがありません",
                        systemImage: "list.bullet.clipboard",
                        description: Text("右上の + ボタンからレースを追加してください"),
                    )
                }
            }
        }
    }

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

struct RaceRowView: View {
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
