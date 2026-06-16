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
                        description: Text("右上の + ボタンからレースを追加してください")
                    )
                }
            }
        }
    }

    private func deleteRace(_ race: Race) {
        (race.entries ?? []).forEach { modelContext.delete($0) }
        (race.bets ?? []).forEach { modelContext.delete($0) }
        modelContext.delete(race)
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
            Text(race.raceName.isEmpty ? "\(race.raceNumber)R" : race.raceName)
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
