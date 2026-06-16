//
//  BetFormView.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import SwiftData
import SwiftUI

// MARK: - Supporting Types

enum BetStyle: String, CaseIterable {
    case normal = "通常"
    case box = "ボックス"
    case formation = "フォーメーション"
}

struct BetSelectionDraft: Identifiable {
    var id: UUID = .init()
    var ticketType: TicketType?
    var ticketTypeName: String = ""
    var useCustom: Bool = false
    var selection: String = ""
    var unitPrice: Int = 100

    var displayTicketTypeName: String {
        useCustom ? ticketTypeName : (ticketType?.name ?? "")
    }

    var combinationCount: Int {
        max(1, Bet.combinationCount(selection: selection, ticketTypeName: displayTicketTypeName))
    }

    var purchaseAmount: Int {
        unitPrice * combinationCount
    }
}

// MARK: - BetFormView

struct BetFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let race: Race
    var bet: Bet?

    @State private var draftSelections: [BetSelectionDraft] = []
    @State private var payoutAmount: Int = 0
    @State private var showingSelectionForm = false
    @State private var editingDraftId: UUID?

    private var isEditing: Bool {
        bet != nil
    }

    private var totalPurchase: Int {
        draftSelections.reduce(0) { $0 + $1.purchaseAmount }
    }

    var body: some View {
        NavigationStack {
            Form {
                selectionsSection
                amountSection
            }
            .navigationTitle(isEditing ? "馬券を編集" : "馬券を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showingSelectionForm) {
                selectionFormSheet
            }
            .onAppear { loadIfEditing() }
        }
    }

    // MARK: - Sections

    private var selectionsSection: some View {
        Section("買い目") {
            ForEach(draftSelections) { draft in
                BetSelectionDraftRowView(draft: draft)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingDraftId = draft.id
                        showingSelectionForm = true
                    }
            }
            .onDelete { indexSet in draftSelections.remove(atOffsets: indexSet) }
            Button {
                editingDraftId = nil
                showingSelectionForm = true
            } label: {
                Label("買い目を追加", systemImage: "plus")
            }
        }
    }

    private var amountSection: some View {
        Section("金額") {
            LabeledContent("合計購入額", value: "¥\(totalPurchase.formatted())")
            HStack {
                Text("払戻額")
                Spacer()
                TextField("0", value: $payoutAmount, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                Text("円")
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("キャンセル") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(isEditing ? "更新" : "追加") {
                save()
                dismiss()
            }
            .disabled(draftSelections.isEmpty || totalPurchase <= 0)
        }
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("完了") {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
        }
    }

    // MARK: - Sheet

    @ViewBuilder
    private var selectionFormSheet: some View {
        let editDraft = editingDraftId.flatMap { id in draftSelections.first { $0.id == id } }
        SelectionFormView(race: race, existing: editDraft) { savedDraft in
            if let editId = editingDraftId,
               let idx = draftSelections.firstIndex(where: { $0.id == editId })
            {
                var updated = savedDraft
                updated.id = editId
                draftSelections[idx] = updated
            } else {
                draftSelections.append(savedDraft)
            }
            editingDraftId = nil
        }
    }

    // MARK: - Load / Save

    private func loadIfEditing() {
        guard let bet else { return }
        payoutAmount = bet.payoutAmount
        let sorted = (bet.selections ?? []).sorted { $0.sortIndex < $1.sortIndex }
        draftSelections = sorted.map { sel in
            BetSelectionDraft(
                ticketType: sel.ticketType,
                ticketTypeName: sel.ticketTypeName,
                useCustom: sel.ticketType == nil && !sel.ticketTypeName.isEmpty,
                selection: sel.selection,
                unitPrice: sel.unitPrice
            )
        }
    }

    private func save() {
        if let bet {
            for sel in bet.selections ?? [] {
                modelContext.delete(sel)
            }
            bet.payoutAmount = payoutAmount
            bet.purchaseAmount = totalPurchase
            for (idx, draft) in draftSelections.enumerated() {
                modelContext.insert(BetSelection(
                    bet: bet,
                    ticketType: draft.useCustom ? nil : draft.ticketType,
                    ticketTypeName: draft.displayTicketTypeName,
                    selection: draft.selection,
                    unitPrice: draft.unitPrice,
                    combinationCount: draft.combinationCount,
                    sortIndex: idx
                ))
            }
        } else {
            let sortIndex = (race.bets ?? []).count
            let newBet = Bet(
                race: race,
                purchaseAmount: totalPurchase,
                payoutAmount: payoutAmount,
                sortIndex: sortIndex
            )
            modelContext.insert(newBet)
            for (idx, draft) in draftSelections.enumerated() {
                modelContext.insert(BetSelection(
                    bet: newBet,
                    ticketType: draft.useCustom ? nil : draft.ticketType,
                    ticketTypeName: draft.displayTicketTypeName,
                    selection: draft.selection,
                    unitPrice: draft.unitPrice,
                    combinationCount: draft.combinationCount,
                    sortIndex: idx
                ))
            }
        }
    }
}

// MARK: - BetSelectionDraftRowView

struct BetSelectionDraftRowView: View {
    let draft: BetSelectionDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                if !draft.displayTicketTypeName.isEmpty {
                    Text(draft.displayTicketTypeName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Text(draft.selection.isEmpty ? "（買い目未入力）" : draft.selection)
                    .foregroundStyle(draft.selection.isEmpty ? .secondary : .primary)
                Spacer()
            }
            if draft.combinationCount > 1 {
                Text("¥\(draft.unitPrice.formatted()) × \(draft.combinationCount)点 = ¥\(draft.purchaseAmount.formatted())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("¥\(draft.purchaseAmount.formatted())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - SelectionFormView

struct SelectionFormView: View {
    @Environment(\.dismiss) private var dismiss

    let race: Race
    let existing: BetSelectionDraft?
    let onSave: (BetSelectionDraft) -> Void

    @Query(sort: \TicketType.sortIndex) private var ticketTypes: [TicketType]

    @State private var selectedTicketType: TicketType?
    @State private var customTicketTypeName: String = ""
    @State private var useCustom: Bool = false
    @State private var manualHorseCount: Int = 1
    @State private var betStyle: BetStyle = .normal
    @State private var horse1: Int = -1
    @State private var horse2: Int = -1
    @State private var horse3: Int = -1
    @State private var boxHorses: Set<Int> = []
    @State private var formLeg1: Set<Int> = []
    @State private var formLeg2: Set<Int> = []
    @State private var formLeg3: Set<Int> = []
    @State private var selectionText: String = ""
    @State private var unitPrice: Int = 100
    @State private var hasFinishedInitialLoad: Bool = false

    private var isEditing: Bool {
        existing != nil
    }

    private var sortedEntries: [RaceEntry] {
        (race.entries ?? []).sorted { $0.horseNumber < $1.horseNumber }
    }

    private var hasEntries: Bool {
        !sortedEntries.isEmpty
    }

    private var autoHorseCount: Int? {
        let name = useCustom ? customTicketTypeName : (selectedTicketType?.name ?? "")
        switch name {
        case "単勝", "複勝": return 1
        case "枠連", "馬連", "ワイド", "馬単": return 2
        case "三連複", "三連単": return 3
        default: return nil
        }
    }

    private var effectiveHorseCount: Int {
        autoHorseCount ?? manualHorseCount
    }

    private var effectiveBetStyle: BetStyle {
        effectiveHorseCount == 1 ? .normal : betStyle
    }

    private var builtSelection: String {
        switch effectiveBetStyle {
        case .normal:
            var nums: [Int] = []
            if horse1 >= 0 { nums.append(horse1) }
            if effectiveHorseCount >= 2, horse2 >= 0 { nums.append(horse2) }
            if effectiveHorseCount >= 3, horse3 >= 0 { nums.append(horse3) }
            return nums.map { "\($0)" }.joined(separator: "-")
        case .box:
            guard !boxHorses.isEmpty else { return "" }
            return boxHorses.sorted().map { "\($0)" }.joined(separator: ",") + "[BOX]"
        case .formation:
            let activeLeg3 = effectiveHorseCount >= 3 ? formLeg3 : nil
            let legs: [Set<Int>] = activeLeg3 != nil
                ? [formLeg1, formLeg2, formLeg3]
                : [formLeg1, formLeg2]
            guard legs.allSatisfy({ !$0.isEmpty }) else { return "" }
            return legs
                .map { $0.sorted().map { "\($0)" }.joined(separator: ",") }
                .joined(separator: "/")
        }
    }

    private var selection: String {
        hasEntries ? builtSelection : selectionText
    }

    private var currentTicketTypeName: String {
        useCustom ? customTicketTypeName : (selectedTicketType?.name ?? "")
    }

    private var currentCombinationCount: Int {
        max(1, Bet.combinationCount(selection: selection, ticketTypeName: currentTicketTypeName))
    }

    private var computedPurchase: Int {
        unitPrice * currentCombinationCount
    }

    var body: some View {
        NavigationStack {
            Form {
                ticketTypeSection
                selectionSection
                unitPriceSection
            }
            .navigationTitle(isEditing ? "買い目を編集" : "買い目を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .onAppear { setupInitialState() }
            .onChange(of: selectedTicketType) { _, _ in resetIfUserChange(resetStyle: true) }
            .onChange(of: useCustom) { _, _ in resetIfUserChange(resetStyle: true) }
            .onChange(of: betStyle) { _, _ in resetIfUserChange(resetStyle: false) }
            .onChange(of: manualHorseCount) { _, _ in resetIfUserChange(resetStyle: false) }
        }
    }

    // MARK: - Ticket Type Section

    private var ticketTypeSection: some View {
        Section("券種") {
            Toggle("カスタム券種", isOn: $useCustom)
            if useCustom {
                TextField("券種名", text: $customTicketTypeName)
            } else {
                Picker("券種", selection: $selectedTicketType) {
                    Text("未選択").tag(nil as TicketType?)
                    ForEach(ticketTypes) { ticketType in
                        Text(ticketType.name).tag(ticketType as TicketType?)
                    }
                }
            }
        }
    }

    // MARK: - Selection Section

    private var selectionSection: some View {
        Section("買い目") {
            if autoHorseCount == nil {
                Picker("頭数", selection: $manualHorseCount) {
                    Text("1頭").tag(1)
                    Text("2頭").tag(2)
                    Text("3頭").tag(3)
                }
                .pickerStyle(.segmented)
            }

            if hasEntries, effectiveHorseCount >= 2 {
                Picker("買い方", selection: $betStyle) {
                    ForEach(BetStyle.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
            }

            if hasEntries {
                selectionRows
            } else {
                TextField("買い目（例: 1-2-3）", text: $selectionText)
                Text("出走馬を先に登録すると馬番から選択できます")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if hasEntries, !builtSelection.isEmpty {
                LabeledContent("買い目", value: builtSelection)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Unit Price Section

    private var unitPriceSection: some View {
        Section("金額") {
            HStack {
                Text("1口あたり")
                Spacer()
                TextField("金額", value: $unitPrice, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                Text("円")
            }
            if currentCombinationCount > 1 {
                LabeledContent("この買い目の購入額") {
                    Text("¥\(unitPrice.formatted()) × \(currentCombinationCount)点 = ¥\(computedPurchase.formatted())")
                        .foregroundStyle(.secondary)
                }
            } else {
                LabeledContent("この買い目の購入額", value: "¥\(computedPurchase.formatted())")
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("キャンセル") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(isEditing ? "更新" : "追加") {
                save()
            }
            .disabled(selection.isEmpty || unitPrice <= 0)
        }
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("完了") {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
        }
    }

    // MARK: - Selection Rows

    @ViewBuilder
    private var selectionRows: some View {
        switch effectiveBetStyle {
        case .normal:
            horsePicker(label: "1頭目", selection: $horse1)
            if effectiveHorseCount >= 2 { horsePicker(label: "2頭目", selection: $horse2) }
            if effectiveHorseCount >= 3 { horsePicker(label: "3頭目", selection: $horse3) }

        case .box:
            ForEach(sortedEntries) { entry in
                Button {
                    toggleSet(&boxHorses, entry.horseNumber)
                } label: {
                    HStack {
                        Text("\(entry.horseNumber)番 \(entry.horseName)")
                            .foregroundStyle(.primary)
                        Spacer()
                        if boxHorses.contains(entry.horseNumber) {
                            Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }

        case .formation:
            HStack {
                Text("馬番 / 馬名")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                legLabel("軸1")
                legLabel("軸2")
                if effectiveHorseCount >= 3 { legLabel("軸3") }
            }
            ForEach(sortedEntries) { entry in
                HStack(spacing: 6) {
                    Text("\(entry.horseNumber)番")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 30)
                    Text(entry.horseName)
                        .lineLimit(1)
                    Spacer()
                    legToggle(isOn: formLeg1.contains(entry.horseNumber)) {
                        toggleSet(&formLeg1, entry.horseNumber)
                    }
                    legToggle(isOn: formLeg2.contains(entry.horseNumber)) {
                        toggleSet(&formLeg2, entry.horseNumber)
                    }
                    if effectiveHorseCount >= 3 {
                        legToggle(isOn: formLeg3.contains(entry.horseNumber)) {
                            toggleSet(&formLeg3, entry.horseNumber)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func horsePicker(label: String, selection: Binding<Int>) -> some View {
        Picker(label, selection: selection) {
            Text("未選択").tag(-1)
            ForEach(sortedEntries) { entry in
                Text("\(entry.horseNumber)番 \(entry.horseName)").tag(entry.horseNumber)
            }
        }
    }

    private func legLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .frame(width: 44)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
    }

    private func legToggle(isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: isOn ? "checkmark.square.fill" : "square")
                .font(.title3)
                .foregroundStyle(isOn ? Color.accentColor : Color.secondary.opacity(0.4))
                .frame(width: 44)
        }
        .buttonStyle(.plain)
    }

    private func toggleSet(_ set: inout Set<Int>, _ value: Int) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }

    private func resetIfUserChange(resetStyle: Bool) {
        guard hasFinishedInitialLoad else { return }
        horse1 = -1; horse2 = -1; horse3 = -1
        boxHorses = []; formLeg1 = []; formLeg2 = []; formLeg3 = []
        selectionText = ""
        if resetStyle { betStyle = .normal }
    }

    // MARK: - Load / Save

    private func setupInitialState() {
        guard !hasFinishedInitialLoad else { return }
        loadFromExisting()
        DispatchQueue.main.async { hasFinishedInitialLoad = true }
    }

    private func loadFromExisting() {
        guard let existing else { return }
        selectedTicketType = existing.ticketType
        customTicketTypeName = existing.ticketTypeName
        useCustom = existing.useCustom
        unitPrice = existing.unitPrice

        if hasEntries {
            let sel = existing.selection
            if sel.hasSuffix("[BOX]") {
                betStyle = .box
                boxHorses = Set(sel.dropLast(5).split(separator: ",").compactMap { Int($0) })
            } else if sel.contains("/") {
                betStyle = .formation
                let parts = sel.split(separator: "/")
                formLeg1 = Set(parts.first?.split(separator: ",").compactMap { Int($0) } ?? [])
                formLeg2 = Set(
                    parts.dropFirst().first?.split(separator: ",").compactMap { Int($0) } ?? []
                )
                formLeg3 = Set(
                    parts.dropFirst(2).first?.split(separator: ",").compactMap { Int($0) } ?? []
                )
                manualHorseCount = parts.count >= 3 ? 3 : 2
            } else {
                betStyle = .normal
                let nums = sel.split(separator: "-").compactMap { Int($0) }
                manualHorseCount = max(1, min(3, nums.isEmpty ? 1 : nums.count))
                horse1 = nums.isEmpty ? -1 : nums[0]
                horse2 = nums.count > 1 ? nums[1] : -1
                horse3 = nums.count > 2 ? nums[2] : -1
            }
        } else {
            selectionText = existing.selection
        }
    }

    private func save() {
        let draft = BetSelectionDraft(
            ticketType: useCustom ? nil : selectedTicketType,
            ticketTypeName: currentTicketTypeName,
            useCustom: useCustom,
            selection: selection,
            unitPrice: unitPrice
        )
        onSave(draft)
        dismiss()
    }
}
