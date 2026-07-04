//
//  BetFormView.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import SwiftData
import SwiftUI

// MARK: - Supporting Types

/// 買い方の種類。rawValue はセグメントピッカーの表示名。
enum BetStyle: String, CaseIterable {
    /// 通常（馬番を個別に指定）
    case normal = "通常"
    /// ボックス買い
    case box = "ボックス"
    /// フォーメーション買い
    case formation = "フォーメーション"
}

/// 買い目フォームの編集用ドラフト。保存確定まで SwiftData モデルに触れないための値型。
struct BetSelectionDraft: Identifiable {
    /// ドラフトの識別子。編集時の差し替え先特定に使う。
    var id: UUID = .init()
    /// 選択した券種。カスタム券種の場合は nil。
    var ticketType: TicketType?
    /// カスタム券種名。
    var ticketTypeName: String = ""
    /// カスタム券種を使うかどうか。
    var useCustom: Bool = false
    /// 買い目文字列。
    var selection: String = ""
    /// 1 口あたりの金額（円）。
    var unitPrice: Int = 100

    /// 表示用の券種名。カスタムならカスタム券種名、そうでなければ選択した券種の名前。
    var displayTicketTypeName: String {
        useCustom ? ticketTypeName : (ticketType?.name ?? "")
    }

    /// 買い目と券種から算出した組合せ点数（最低 1）。
    var combinationCount: Int {
        max(1, Bet.combinationCount(selection: selection, ticketTypeName: displayTicketTypeName))
    }

    /// この買い目の購入額（単価 × 組合せ点数）。
    var purchaseAmount: Int {
        unitPrice * combinationCount
    }
}

// MARK: - BetFormView

/// 馬券の追加・編集フォーム。複数の買い目ドラフトと払戻額をまとめて 1 枚の馬券として保存する。
/// `bet` が nil なら新規追加、非 nil なら編集として動作する。
struct BetFormView: View {
    /// SwiftData のモデルコンテキスト。
    @Environment(\.modelContext) private var modelContext
    /// シートを閉じるためのアクション。
    @Environment(\.dismiss) private var dismiss

    /// 馬券を追加する対象のレース。
    let race: Race
    /// 編集対象の馬券。新規追加の場合は nil。
    var bet: Bet?

    /// 編集中の買い目ドラフト一覧。
    @State private var draftSelections: [BetSelectionDraft] = []
    /// 入力中の払戻額（円）。0 は未精算。
    @State private var payoutAmount: Int = 0
    /// 買い目入力シートの表示状態。
    @State private var showingSelectionForm = false
    /// 編集中のドラフト ID。nil の場合は新規追加として買い目シートを開く。
    @State private var editingDraftId: UUID?

    /// 編集モードかどうか。
    private var isEditing: Bool {
        bet != nil
    }

    /// 全買い目ドラフトの購入額合計。
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

    /// 買い目ドラフトの一覧と追加ボタンのセクション。
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

    /// 合計購入額の表示と払戻額入力のセクション。
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

    /// キャンセル・保存・キーボード閉じるボタンのツールバー。
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
                    to: nil, from: nil, for: nil,
                )
            }
        }
    }

    // MARK: - Sheet

    /// 買い目入力シート。編集中のドラフトがあればその内容を初期値として渡す。
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

    /// 編集モードの場合、編集対象馬券の払戻額と買い目をドラフトに読み込む。
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
                unitPrice: sel.unitPrice,
            )
        }
    }

    /// ドラフトの内容を保存する。編集モードなら既存馬券を更新し、新規モードなら馬券と買い目を挿入する。
    private func save() {
        if let bet {
            bet.payoutAmount = payoutAmount
            bet.purchaseAmount = totalPurchase
            let existing = (bet.selections ?? []).sorted { $0.sortIndex < $1.sortIndex }
            let draftCount = draftSelections.count
            let existingCount = existing.count
            // 既存レコードをインプレース更新する。短時間の insert/delete の連続は SwiftUI List の差分計算を崩すため
            for idx in 0 ..< min(draftCount, existingCount) {
                let sel = existing[idx]
                let draft = draftSelections[idx]
                sel.ticketType = draft.useCustom ? nil : draft.ticketType
                sel.ticketTypeName = draft.displayTicketTypeName
                sel.selection = draft.selection
                sel.unitPrice = draft.unitPrice
                sel.combinationCount = draft.combinationCount
                sel.sortIndex = idx
            }
            // ドラフトが増えた分は新規挿入する
            if draftCount > existingCount {
                for idx in existingCount ..< draftCount {
                    let draft = draftSelections[idx]
                    modelContext.insert(BetSelection(
                        bet: bet,
                        ticketType: draft.useCustom ? nil : draft.ticketType,
                        ticketTypeName: draft.displayTicketTypeName,
                        selection: draft.selection,
                        unitPrice: draft.unitPrice,
                        combinationCount: draft.combinationCount,
                        sortIndex: idx,
                    ))
                }
            }
            // ドラフトが減った分は余剰レコードを削除する
            if existingCount > draftCount {
                for idx in draftCount ..< existingCount {
                    modelContext.delete(existing[idx])
                }
            }
        } else {
            let sortIndex = (race.bets ?? []).count
            let newBet = Bet(
                race: race,
                purchaseAmount: totalPurchase,
                payoutAmount: payoutAmount,
                sortIndex: sortIndex,
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
                    sortIndex: idx,
                ))
            }
        }
    }
}

// MARK: - BetSelectionDraftRowView

/// 馬券フォーム内の買い目ドラフト 1 件分の行。券種・買い目・購入額内訳を表示する。
struct BetSelectionDraftRowView: View {
    /// 表示対象のドラフト。
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

/// 買い目 1 件の入力シート。出走馬が登録済みなら馬番選択 UI、未登録ならテキスト入力を提供する。
struct SelectionFormView: View {
    /// シートを閉じるためのアクション。
    @Environment(\.dismiss) private var dismiss

    /// 買い目の対象レース。出走馬の有無で入力 UI を切り替える。
    let race: Race
    /// 編集対象のドラフト。新規追加の場合は nil。
    let existing: BetSelectionDraft?
    /// 保存確定時に呼ばれるハンドラ。
    let onSave: (BetSelectionDraft) -> Void

    /// SwiftData から取得した全券種。
    @Query(sort: \TicketType.sortIndex) private var ticketTypes: [TicketType]

    /// 選択中の券種。
    @State private var selectedTicketType: TicketType?
    /// 入力中のカスタム券種名。
    @State private var customTicketTypeName: String = ""
    /// カスタム券種を使うかどうか。
    @State private var useCustom: Bool = false
    /// 券種から頭数を自動決定できない場合に使う手動指定の頭数。
    @State private var manualHorseCount: Int = 1
    /// 選択中の買い方。
    @State private var betStyle: BetStyle = .normal
    /// 通常買いの 1 頭目の馬番。-1 は未選択。
    @State private var horse1: Int = -1
    /// 通常買いの 2 頭目の馬番。-1 は未選択。
    @State private var horse2: Int = -1
    /// 通常買いの 3 頭目の馬番。-1 は未選択。
    @State private var horse3: Int = -1
    /// ボックス買いで選択中の馬番集合。
    @State private var boxHorses: Set<Int> = []
    /// フォーメーション買いの軸 1 の馬番集合。
    @State private var formLeg1: Set<Int> = []
    /// フォーメーション買いの軸 2 の馬番集合。
    @State private var formLeg2: Set<Int> = []
    /// フォーメーション買いの軸 3 の馬番集合。
    @State private var formLeg3: Set<Int> = []
    /// 出走馬未登録時にテキスト入力される買い目文字列。
    @State private var selectionText: String = ""
    /// 入力中の 1 口あたりの金額（円）。
    @State private var unitPrice: Int = 100
    /// 初期値の読み込みが完了したかどうか。読み込み中に onChange のリセットが走らないようにするためのフラグ。
    @State private var hasFinishedInitialLoad: Bool = false

    /// 編集モードかどうか。
    private var isEditing: Bool {
        existing != nil
    }

    /// 対象レースの出走馬を馬番昇順で返す。
    private var sortedEntries: [RaceEntry] {
        (race.entries ?? []).sorted { $0.horseNumber < $1.horseNumber }
    }

    /// 出走馬が登録されているかどうか。
    private var hasEntries: Bool {
        !sortedEntries.isEmpty
    }

    /// 券種から一意に決まる頭数。決められない券種（カスタム等）の場合は nil。
    private var autoHorseCount: Int? {
        let name = useCustom ? customTicketTypeName : (selectedTicketType?.name ?? "")
        switch name {
        case "単勝", "複勝": return 1
        case "枠連", "馬連", "ワイド", "馬単": return 2
        case "三連複", "三連単": return 3
        default: return nil
        }
    }

    /// 実際に使う頭数。券種から決まればそれを、決まらなければ手動指定を使う。
    private var effectiveHorseCount: Int {
        autoHorseCount ?? manualHorseCount
    }

    /// 実際に使う買い方。1 頭の買い目に BOX / フォーメーションは成立しないため通常に固定する。
    private var effectiveBetStyle: BetStyle {
        effectiveHorseCount == 1 ? .normal : betStyle
    }

    /// 馬番選択 UI の状態から組み立てた買い目文字列。未選択・不足がある場合は空文字。
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

    /// 保存する買い目文字列。出走馬があれば選択 UI から、なければテキスト入力から得る。
    private var selection: String {
        hasEntries ? builtSelection : selectionText
    }

    /// 現在の券種名。カスタムならカスタム券種名、そうでなければ選択した券種の名前。
    private var currentTicketTypeName: String {
        useCustom ? customTicketTypeName : (selectedTicketType?.name ?? "")
    }

    /// 現在の入力から算出した組合せ点数（最低 1）。
    private var currentCombinationCount: Int {
        max(1, Bet.combinationCount(selection: selection, ticketTypeName: currentTicketTypeName))
    }

    /// 現在の入力から算出した購入額（単価 × 組合せ点数）。
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

    /// 券種選択（マスターから選択またはカスタム入力）のセクション。
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

    /// 頭数・買い方・馬番（またはテキスト）を入力する買い目セクション。
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

    /// 単価入力と購入額プレビューのセクション。
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

    /// キャンセル・保存・キーボード閉じるボタンのツールバー。
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
                    to: nil, from: nil, for: nil,
                )
            }
        }
    }

    // MARK: - Selection Rows

    /// 買い方に応じた馬番選択 UI（通常: ピッカー / ボックス: チェック行 / フォーメーション: 軸別チェック）。
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

    /// 通常買い用の馬番ピッカー行を生成する。
    /// - Parameters:
    ///   - label: 行ラベル（例: 「1頭目」）。
    ///   - selection: 選択された馬番のバインディング（-1 は未選択）。
    /// - Returns: 馬番ピッカーのビュー。
    private func horsePicker(label: String, selection: Binding<Int>) -> some View {
        Picker(label, selection: selection) {
            Text("未選択").tag(-1)
            ForEach(sortedEntries) { entry in
                Text("\(entry.horseNumber)番 \(entry.horseName)").tag(entry.horseNumber)
            }
        }
    }

    /// フォーメーションのヘッダーに表示する軸ラベルを生成する。
    /// - Parameter text: ラベル文字列（例: 「軸1」）。
    /// - Returns: 軸ラベルのビュー。
    private func legLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .frame(width: 44)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
    }

    /// フォーメーションの軸選択チェックボタンを生成する。
    /// `Form` 内の `Toggle` はタップを取りこぼすことがあるため `Button` + チェックマークで実装する。
    /// - Parameters:
    ///   - isOn: 選択状態。
    ///   - action: タップ時のアクション。
    /// - Returns: チェックボタンのビュー。
    private func legToggle(isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: isOn ? "checkmark.square.fill" : "square")
                .font(.title3)
                .foregroundStyle(isOn ? Color.accentColor : Color.secondary.opacity(0.4))
                .frame(width: 44)
        }
        .buttonStyle(.plain)
    }

    /// 集合内の値の有無をトグルする。
    /// - Parameters:
    ///   - set: 対象の集合。
    ///   - value: トグルする値。
    private func toggleSet(_ set: inout Set<Int>, _ value: Int) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }

    /// ユーザー操作による券種・買い方の変更時に馬番選択をリセットする。初期値読み込み中は何もしない。
    /// - Parameter resetStyle: 買い方も通常に戻すかどうか。
    private func resetIfUserChange(resetStyle: Bool) {
        guard hasFinishedInitialLoad else { return }
        horse1 = -1; horse2 = -1; horse3 = -1
        boxHorses = []; formLeg1 = []; formLeg2 = []; formLeg3 = []
        selectionText = ""
        if resetStyle { betStyle = .normal }
    }

    // MARK: - Load / Save

    /// 初期値を読み込み、次のランループで読み込み完了フラグを立てる。
    /// フラグ設定を遅延させるのは、読み込みが発火させる onChange でリセットが走るのを防ぐため。
    private func setupInitialState() {
        guard !hasFinishedInitialLoad else { return }
        loadFromExisting()
        DispatchQueue.main.async { hasFinishedInitialLoad = true }
    }

    /// 編集対象ドラフトの買い目文字列をパースし、買い方・馬番選択の各状態に展開する。
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
                    parts.dropFirst().first?.split(separator: ",").compactMap { Int($0) } ?? [],
                )
                formLeg3 = Set(
                    parts.dropFirst(2).first?.split(separator: ",").compactMap { Int($0) } ?? [],
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

    /// 入力値からドラフトを組み立てて保存ハンドラに渡し、シートを閉じる。
    private func save() {
        let draft = BetSelectionDraft(
            ticketType: useCustom ? nil : selectedTicketType,
            ticketTypeName: currentTicketTypeName,
            useCustom: useCustom,
            selection: selection,
            unitPrice: unitPrice,
        )
        onSave(draft)
        dismiss()
    }
}
