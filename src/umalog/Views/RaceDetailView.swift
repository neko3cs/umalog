//
//  RaceDetailView.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import SwiftUI
import SwiftData

struct RaceDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var race: Race
    @State private var showingEditRace = false
    @State private var showingAddEntry = false
    @State private var showingAddBet = false
    @State private var editingEntry: RaceEntry? = nil
    @State private var editingBet: Bet? = nil

    private var sortedEntries: [RaceEntry] {
        (race.entries ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    private var sortedBets: [Bet] {
        (race.bets ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    var body: some View {
        List {
            Section("レース情報") {
                LabeledContent("日付") {
                    Text(race.date.formatted(Date.FormatStyle(date: .long, time: .omitted).locale(Locale(identifier: "ja_JP"))))
                }
                if let venue = race.venue {
                    LabeledContent("競馬場", value: venue.name)
                }
                LabeledContent("レース番号", value: "R\(race.raceNumber)")
                if !race.raceName.isEmpty {
                    LabeledContent("レース名", value: race.raceName)
                }
                LabeledContent("コース") {
                    Text("\(race.trackType == "turf" ? "芝" : "ダート") \(race.distance)m \(race.trackCondition)")
                }
                LabeledContent("区分", value: race.category == "central" ? "中央（JRA）" : "地方（NAR）")
            }

            Section {
                ForEach(sortedEntries) { entry in
                    EntryRowView(entry: entry)
                        .contentShape(Rectangle())
                        .onTapGesture { editingEntry = entry }
                }
                .onDelete { indexSet in
                    for i in indexSet { modelContext.delete(sortedEntries[i]) }
                }
                Button { showingAddEntry = true } label: {
                    Label("出走馬を追加", systemImage: "plus")
                }
            } header: {
                Text("出走馬 \(sortedEntries.count)頭")
            }

            Section {
                ForEach(sortedBets) { bet in
                    BetRowView(bet: bet)
                        .contentShape(Rectangle())
                        .onTapGesture { editingBet = bet }
                }
                .onDelete { indexSet in
                    for i in indexSet { modelContext.delete(sortedBets[i]) }
                }
                Button { showingAddBet = true } label: {
                    Label("馬券を追加", systemImage: "plus")
                }
            } header: {
                Text("馬券 \(sortedBets.count)枚")
            } footer: {
                if race.totalPurchase > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack {
                            Spacer()
                            Text("購入 ¥\(race.totalPurchase.formatted())　払戻 ¥\(race.totalPayout.formatted())")
                        }
                        HStack {
                            Spacer()
                            Text("収支 \(race.balance >= 0 ? "+" : "−")¥\(abs(race.balance).formatted())")
                                .foregroundStyle(race.balance >= 0 ? .green : .red)
                            if let rate = race.returnRate {
                                Text("回収率 \(Int(rate * 100))%")
                            }
                        }
                    }
                    .font(.caption)
                }
            }

            if !race.memo.isEmpty {
                Section("メモ") {
                    Text(race.memo)
                        .font(.body)
                }
            }
        }
        .navigationTitle(race.raceName.isEmpty ? "R\(race.raceNumber)" : race.raceName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("編集") { showingEditRace = true }
            }
        }
        .sheet(isPresented: $showingEditRace) { RaceFormView(race: race) }
        .sheet(isPresented: $showingAddEntry) { RaceEntryFormView(race: race) }
        .sheet(isPresented: $showingAddBet) { BetFormView(race: race) }
        .sheet(item: $editingEntry) { entry in RaceEntryFormView(race: race, entry: entry) }
        .sheet(item: $editingBet) { bet in BetFormView(race: race, bet: bet) }
    }
}

struct EntryRowView: View {
    let entry: RaceEntry

    var body: some View {
        HStack(spacing: 10) {
            Text("\(entry.horseNumber)")
                .frame(width: 28, alignment: .center)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.horseName.isEmpty ? "（馬名未入力）" : entry.horseName)
                if !entry.jockeyName.isEmpty {
                    Text(entry.jockeyName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let mark = entry.mark {
                Text(mark.rawValue)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.accentColor)
            }
            if let pos = entry.finishPosition {
                Text("\(pos)着")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct BetRowView: View {
    let bet: Bet

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if !bet.displayTicketTypeName.isEmpty {
                    Text(bet.displayTicketTypeName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Text(bet.selection)
                Spacer()
            }
            HStack(spacing: 8) {
                Text("¥\(bet.purchaseAmount.formatted())")
                    .font(.caption)
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if bet.payoutAmount > 0 {
                    Text("¥\(bet.payoutAmount.formatted())")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Text("未確定")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(.vertical, 2)
    }
}
