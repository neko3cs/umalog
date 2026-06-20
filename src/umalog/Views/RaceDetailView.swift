//
//  RaceDetailView.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import MarkdownUI
import SwiftData
import SwiftUI

struct RaceDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.undoManager) private var undoManager
    @Bindable var race: Race
    @State private var showingEditRace = false
    @State private var showingAddEntry = false
    @State private var showingAddBet = false
    @State private var editingEntry: RaceEntry?
    @State private var editingBet: Bet?
    // @Query で取得することで、SwiftData の変更通知が SwiftUI List に正しく伝わる。
    // race.entries / race.bets の直接参照では UICollectionView の diff 計算が崩れるため。
    @Query(sort: \RaceEntry.horseNumber) private var allEntries: [RaceEntry]
    @Query(sort: \Bet.sortIndex) private var allBets: [Bet]

    private var sortedEntries: [RaceEntry] {
        allEntries.filter { $0.race?.persistentModelID == race.persistentModelID }
    }

    private var sortedBets: [Bet] {
        allBets.filter { $0.race?.persistentModelID == race.persistentModelID }
    }

    var body: some View {
        List {
            Section("レース情報") {
                LabeledContent("日付") {
                    Text(race.date.japaneseShortDateString)
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
                    EntryRowView(entry: entry, position: race.finishPosition(forHorseNumber: entry.horseNumber))
                        .contentShape(Rectangle())
                        .onTapGesture { editingEntry = entry }
                }
                .onDelete { indexSet in
                    for i in indexSet {
                        let entry = sortedEntries[i]
                        let snap = EntrySnapshot(from: entry)
                        let raceId = race.persistentModelID
                        undoManager?.registerUndo(withTarget: modelContext) { [snap] ctx in
                            guard let raceRef = ctx.model(for: raceId) as? Race else { return }
                            ctx.insert(RaceEntry(
                                race: raceRef, horseNumber: snap.horseNumber, horseName: snap.horseName,
                                jockeyName: snap.jockeyName, trainerName: snap.trainerName,
                                predictionMark: snap.predictionMark, finishPosition: snap.finishPosition,
                                sortIndex: snap.sortIndex
                            ))
                        }
                        undoManager?.setActionName("出走馬を削除")
                        modelContext.delete(entry)
                    }
                }
                Button { showingAddEntry = true } label: {
                    Label("出走馬を追加", systemImage: "plus")
                }
                .accessibilityIdentifier("add-entry-button")
            } header: {
                Text("出走馬 \(sortedEntries.count)頭")
            }

            Section("着順") {
                FinishPositionPicker(label: "1着", selection: $race.firstPlaceHorseNumber, entries: sortedEntries)
                FinishPositionPicker(label: "2着", selection: $race.secondPlaceHorseNumber, entries: sortedEntries)
                FinishPositionPicker(label: "3着", selection: $race.thirdPlaceHorseNumber, entries: sortedEntries)
            }

            Section {
                ForEach(sortedBets) { bet in
                    BetRowView(bet: bet)
                        .contentShape(Rectangle())
                        .onTapGesture { editingBet = bet }
                }
                .onDelete { indexSet in
                    for i in indexSet {
                        let bet = sortedBets[i]
                        let snap = BetSnapshot(from: bet)
                        let raceId = race.persistentModelID
                        undoManager?.registerUndo(withTarget: modelContext) { [snap, raceId] ctx in
                            guard let races = try? ctx.fetch(FetchDescriptor<Race>()),
                                  let raceRef = races.first(where: { $0.persistentModelID == raceId })
                            else { return }
                            let allTicketTypes = (try? ctx.fetch(FetchDescriptor<TicketType>())) ?? []
                            let ticketType = snap.ticketTypeId.flatMap { id in
                                allTicketTypes.first(where: { $0.persistentModelID == id })
                            }
                            let restored = Bet(
                                race: raceRef, ticketType: ticketType,
                                ticketTypeName: snap.ticketTypeName, selection: snap.selection,
                                unitPrice: snap.unitPrice, purchaseAmount: snap.purchaseAmount,
                                payoutAmount: snap.payoutAmount, sortIndex: snap.sortIndex
                            )
                            ctx.insert(restored)
                            for selSnap in snap.selections {
                                let selTicketType = selSnap.ticketTypeId.flatMap { id in
                                    allTicketTypes.first(where: { $0.persistentModelID == id })
                                }
                                ctx.insert(BetSelection(
                                    bet: restored, ticketType: selTicketType,
                                    ticketTypeName: selSnap.ticketTypeName, selection: selSnap.selection,
                                    unitPrice: selSnap.unitPrice, combinationCount: selSnap.combinationCount,
                                    sortIndex: selSnap.sortIndex
                                ))
                            }
                        }
                        undoManager?.setActionName("馬券を削除")
                        (bet.selections ?? []).forEach { modelContext.delete($0) }
                        modelContext.delete(bet)
                    }
                }
                Button { showingAddBet = true } label: {
                    Label("馬券を追加", systemImage: "plus")
                }
                .accessibilityIdentifier("add-bet-button")
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

            Section("メモ（Markdown）") {
                NavigationLink {
                    MemoView(race: race)
                } label: {
                    if race.memo.isEmpty {
                        Text("タップして追加")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(race.memo)
                            .lineLimit(3)
                            .foregroundStyle(.primary)
                    }
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

// MARK: - Memo Views

private struct MemoView: View {
    @Bindable var race: Race
    @State private var showingEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if race.memo.isEmpty {
                    Text("メモなし")
                        .foregroundStyle(.secondary)
                        .italic()
                        .padding()
                } else {
                    Markdown(race.memo)
                        .padding()
                }
            }
        }
        .navigationTitle("メモ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("編集") { showingEditor = true }
        }
        .sheet(isPresented: $showingEditor) {
            MemoEditView(race: race)
        }
    }
}

private struct MemoEditView: View {
    @Bindable var race: Race
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            TextEditor(text: $draft)
                .font(.body.monospaced())
                .padding(.horizontal)
                .navigationTitle("メモを編集")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            race.memo = draft
                            dismiss()
                        }
                    }
                }
                .onAppear { draft = race.memo }
        }
    }
}

// MARK: - Row Views

struct EntryRowView: View {
    let entry: RaceEntry
    var position: Int?

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
                    Text(entry.jockeyName).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let mark = entry.mark {
                Text(mark.rawValue)
                    .font(.title3).fontWeight(.bold).foregroundStyle(Color.accentColor)
                    .accessibilityIdentifier("entry-mark-display")
            }
            if let pos = position {
                Text("\(pos)着")
                    .font(.caption.bold())
                    .foregroundStyle(pos == 1 ? Color.orange : .secondary)
            }
        }
    }
}

struct BetRowView: View {
    let bet: Bet

    private var sortedSelections: [BetSelection] {
        (bet.selections ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if sortedSelections.isEmpty {
                legacySelectionRow
            } else {
                ForEach(sortedSelections) { sel in
                    selectionRow(sel)
                }
            }
            summaryRow
        }
        .padding(.vertical, 2)
    }

    private func selectionRow(_ sel: BetSelection) -> some View {
        HStack(spacing: 6) {
            if !sel.displayTicketTypeName.isEmpty {
                Text(sel.displayTicketTypeName)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            Text(sel.selection)
            Spacer()
            if sel.combinationCount > 1 {
                Text("¥\(sel.unitPrice.formatted()) × \(sel.combinationCount)点")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("¥\(sel.unitPrice.formatted())")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var legacySelectionRow: some View {
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
    }

    private var summaryRow: some View {
        HStack(spacing: 8) {
            if sortedSelections.count > 1 {
                Text("計 ¥\(bet.purchaseAmount.formatted())").font(.caption)
            } else {
                Text("¥\(bet.purchaseAmount.formatted())").font(.caption)
            }
            Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
            Text("¥\(bet.payoutAmount.formatted())")
                .font(.caption)
                .foregroundStyle(bet.payoutAmount > 0 ? .green : .red)
            Spacer()
        }
    }
}

// MARK: - Snapshots for Undo

struct EntrySnapshot {
    let horseNumber: Int
    let horseName: String
    let jockeyName: String
    let trainerName: String
    let predictionMark: String?
    let finishPosition: Int?
    let sortIndex: Int

    init(from entry: RaceEntry) {
        horseNumber = entry.horseNumber
        horseName = entry.horseName
        jockeyName = entry.jockeyName
        trainerName = entry.trainerName
        predictionMark = entry.predictionMark
        finishPosition = entry.finishPosition
        sortIndex = entry.sortIndex
    }
}

struct BetSnapshot {
    let ticketTypeId: PersistentIdentifier?
    let ticketTypeName: String
    let selection: String
    let unitPrice: Int
    let purchaseAmount: Int
    let payoutAmount: Int
    let sortIndex: Int
    let selections: [SelectionSnapshot]

    struct SelectionSnapshot {
        let ticketTypeId: PersistentIdentifier?
        let ticketTypeName: String
        let selection: String
        let unitPrice: Int
        let combinationCount: Int
        let sortIndex: Int
    }

    init(from bet: Bet) {
        ticketTypeId = bet.ticketType?.persistentModelID
        ticketTypeName = bet.ticketTypeName
        selection = bet.selection
        unitPrice = bet.unitPrice
        purchaseAmount = bet.purchaseAmount
        payoutAmount = bet.payoutAmount
        sortIndex = bet.sortIndex
        selections = (bet.selections ?? []).map { sel in
            SelectionSnapshot(
                ticketTypeId: sel.ticketType?.persistentModelID, ticketTypeName: sel.ticketTypeName,
                selection: sel.selection, unitPrice: sel.unitPrice,
                combinationCount: sel.combinationCount, sortIndex: sel.sortIndex
            )
        }
    }
}

// MARK: - Finish Position Picker

struct FinishPositionPicker: View {
    let label: String
    @Binding var selection: Int
    let entries: [RaceEntry]

    var body: some View {
        Picker(label, selection: $selection) {
            Text("未入力").tag(0)
            ForEach(entries) { entry in
                Text("\(entry.horseNumber)番 \(entry.horseName)").tag(entry.horseNumber)
            }
        }
    }
}
