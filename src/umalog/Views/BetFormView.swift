//
//  BetFormView.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import SwiftData
import SwiftUI

enum BetStyle: String, CaseIterable {
    case normal = "通常"
    case box = "ボックス"
    case formation = "フォーメーション"
}

struct BetFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let race: Race
    var bet: Bet? = nil

    @Query(sort: \TicketType.sortIndex) private var ticketTypes: [TicketType]

    @State private var selectedTicketType: TicketType? = nil
    @State private var customTicketTypeName: String = ""
    @State private var useCustom: Bool = false
    @State private var manualHorseCount: Int = 1
    @State private var betStyle: BetStyle = .normal
    // 通常
    @State private var horse1: Int = -1
    @State private var horse2: Int = -1
    @State private var horse3: Int = -1
    /// ボックス
    @State private var boxHorses: Set<Int> = []
    // フォーメーション
    @State private var formLeg1: Set<Int> = []
    @State private var formLeg2: Set<Int> = []
    @State private var formLeg3: Set<Int> = []
    // テキスト入力フォールバック
    @State private var selectionText: String = ""
    @State private var purchaseAmount: Int = 100
    @State private var payoutAmount: Int = 0

    private var isEditing: Bool {
        bet != nil
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

    var body: some View {
        NavigationStack {
            Form {
                Section("券種") {
                    Toggle("カスタム券種", isOn: $useCustom)
                    if useCustom {
                        TextField("券種名", text: $customTicketTypeName)
                    } else {
                        Picker("券種", selection: $selectedTicketType) {
                            Text("未選択").tag(nil as TicketType?)
                            ForEach(ticketTypes) { tt in
                                Text(tt.name).tag(tt as TicketType?)
                            }
                        }
                    }
                }

                Section("買い目") {
                    if autoHorseCount == nil {
                        Picker("頭数", selection: $manualHorseCount) {
                            Text("1頭").tag(1)
                            Text("2頭").tag(2)
                            Text("3頭").tag(3)
                        }
                        .pickerStyle(.segmented)
                    }

                    if hasEntries && effectiveHorseCount >= 2 {
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

                    if hasEntries && !builtSelection.isEmpty {
                        LabeledContent("買い目", value: builtSelection)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("金額") {
                    HStack {
                        Text("購入額")
                        Spacer()
                        TextField("金額", value: $purchaseAmount, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("円")
                    }
                    HStack {
                        Text("払戻額")
                        Spacer()
                        TextField("0 = 未確定", value: $payoutAmount, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("円")
                    }
                    if payoutAmount == 0 {
                        Text("払戻額 0 円は「未確定」として扱われます")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(isEditing ? "馬券を編集" : "馬券を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "更新" : "追加") {
                        save()
                        dismiss()
                    }
                    .disabled(selection.isEmpty || purchaseAmount <= 0)
                }
            }
            .onAppear { loadIfEditing() }
            .onChange(of: selectedTicketType) { _, _ in resetSelection(resetStyle: true) }
            .onChange(of: useCustom) { _, _ in resetSelection(resetStyle: true) }
            .onChange(of: betStyle) { _, _ in resetSelection(resetStyle: false) }
            .onChange(of: manualHorseCount) { _, _ in resetSelection(resetStyle: false) }
        }
    }

    private func resetSelection(resetStyle: Bool) {
        horse1 = -1; horse2 = -1; horse3 = -1
        boxHorses = []; formLeg1 = []; formLeg2 = []; formLeg3 = []
        selectionText = ""
        if resetStyle { betStyle = .normal }
    }

    // MARK: - Selection rows

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
            // 1行に馬の情報 + 各軸のトグルボタンを並べる
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

    // MARK: - Load / Save

    private func loadIfEditing() {
        guard let bet else { return }
        selectedTicketType = bet.ticketType
        customTicketTypeName = bet.ticketTypeName
        useCustom = bet.ticketType == nil && !bet.ticketTypeName.isEmpty
        purchaseAmount = bet.purchaseAmount
        payoutAmount = bet.payoutAmount

        if hasEntries {
            let sel = bet.selection
            if sel.hasSuffix("[BOX]") {
                betStyle = .box
                boxHorses = Set(sel.dropLast(5).split(separator: ",").compactMap { Int($0) })
            } else if sel.contains("/") {
                betStyle = .formation
                let parts = sel.split(separator: "/")
                formLeg1 = Set(parts.first?.split(separator: ",").compactMap { Int($0) } ?? [])
                formLeg2 = Set(parts.dropFirst().first?.split(separator: ",").compactMap { Int($0) } ?? [])
                formLeg3 = Set(parts.dropFirst(2).first?.split(separator: ",").compactMap { Int($0) } ?? [])
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
            selectionText = bet.selection
        }
    }

    private func save() {
        let ttName = useCustom ? customTicketTypeName : (selectedTicketType?.name ?? "")
        let tt = useCustom ? nil : selectedTicketType
        if let bet {
            bet.ticketType = tt
            bet.ticketTypeName = ttName
            bet.selection = selection
            bet.purchaseAmount = purchaseAmount
            bet.payoutAmount = payoutAmount
        } else {
            let sortIndex = (race.bets ?? []).count
            modelContext.insert(Bet(
                race: race, ticketType: tt, ticketTypeName: ttName,
                selection: selection, purchaseAmount: purchaseAmount,
                payoutAmount: payoutAmount, sortIndex: sortIndex
            ))
        }
    }
}
