//
//  SelectionFormView.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import SwiftData
import SwiftUI

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

    /// 選択中の券種。アプリが扱う券種のいずれか、または未選択（nil）。
    @State private var selectedTicketType: TicketType?
    /// 編集対象が旧カスタム券種（アプリが扱わない券種）の場合の元の券種。券種を選び直さなければそのまま保存する。
    @State private var legacyTicketType: TicketType?
    /// 編集対象が旧カスタム券種の場合の元の券種名。
    @State private var legacyTicketTypeName: String = ""
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
    /// 流し買いの軸の頭数（三連複・三連単のみ 1 / 2 を選べる）。
    @State private var nagashiAxisCount: Int = 1
    /// 流し買いの 1 頭目の軸の馬番。-1 は未選択。
    @State private var nagashiAxis1: Int = -1
    /// 流し買いの 2 頭目の軸の馬番。-1 は未選択。
    @State private var nagashiAxis2: Int = -1
    /// 流し買いの相手の馬番集合。
    @State private var nagashiOpponents: Set<Int> = []
    /// 流し買いの軸の着順指定（馬単・三連単のみ）。
    @State private var nagashiPlacement: NagashiPlacement = .leading(axisCount: 1)
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

    /// 選択できる券種（アプリが扱う券種）。旧バージョンの設定画面で追加された任意名の券種は含めない。
    private var selectableTicketTypes: [TicketType] {
        ticketTypes.filter(\.isPreset)
    }

    /// 券種から一意に決まる頭数。決められない券種（未選択・旧カスタム券種）の場合は nil。
    private var autoHorseCount: Int? {
        switch currentTicketTypeName {
        case "単勝", "複勝": 1
        default: NagashiSelection.horseCount(ticketTypeName: currentTicketTypeName)
        }
    }

    /// 実際に使う頭数。券種から決まればそれを、決まらなければ手動指定を使う。
    private var effectiveHorseCount: Int {
        autoHorseCount ?? manualHorseCount
    }

    /// 選べる買い方。流しは組合せ点数を数えられる既知の券種でのみ選べる。
    private var availableBetStyles: [BetStyle] {
        NagashiSelection.horseCount(ticketTypeName: currentTicketTypeName) == nil
            ? BetStyle.allCases.filter { $0 != .nagashi }
            : BetStyle.allCases
    }

    /// 実際に使う買い方。1 頭の買い目に BOX / フォーメーション / 流しは成立しないため通常に固定する。
    private var effectiveBetStyle: BetStyle {
        guard effectiveHorseCount >= 2, availableBetStyles.contains(betStyle) else { return .normal }
        return betStyle
    }

    /// 流し買いで実際に使う軸の頭数。2 頭の券種では常に 1 頭。
    private var effectiveNagashiAxisCount: Int {
        effectiveHorseCount >= 3 ? nagashiAxisCount : 1
    }

    /// 現在の券種が着順を区別するかどうか（馬単・三連単）。
    private var isOrderedTicketType: Bool {
        NagashiSelection.isOrdered(ticketTypeName: currentTicketTypeName)
    }

    /// 馬番選択 UI の状態から組み立てた買い目文字列。未選択・不足がある場合は空文字。
    private var builtSelection: String {
        switch effectiveBetStyle {
        case .normal:
            var nums: [Int] = []
            if horse1 >= 0 {
                nums.append(horse1)
            }
            if effectiveHorseCount >= 2, horse2 >= 0 {
                nums.append(horse2)
            }
            if effectiveHorseCount >= 3, horse3 >= 0 {
                nums.append(horse3)
            }
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
        case .nagashi:
            let axes = effectiveNagashiAxisCount >= 2 ? [nagashiAxis1, nagashiAxis2] : [nagashiAxis1]
            guard axes.allSatisfy({ $0 >= 0 }), !nagashiOpponents.isEmpty else { return "" }
            return NagashiSelection(
                axes: axes,
                opponents: nagashiOpponents.sorted(),
                axisPositions: isOrderedTicketType ? nagashiPlacement.positions : [],
                isMulti: isOrderedTicketType && nagashiPlacement.isMulti,
            ).notation
        }
    }

    /// 保存する買い目文字列。出走馬があれば選択 UI から、なければテキスト入力から得る。
    private var selection: String {
        hasEntries ? builtSelection : selectionText
    }

    /// 現在の券種名。券種を選んでいればその名前、未選択なら旧カスタム券種名（なければ空文字）。
    private var currentTicketTypeName: String {
        selectedTicketType?.name ?? legacyTicketTypeName
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
            .onChange(of: betStyle) { _, _ in resetIfUserChange(resetStyle: false) }
            .onChange(of: manualHorseCount) { _, _ in resetIfUserChange(resetStyle: false) }
            .onChange(of: nagashiAxisCount) { _, _ in resetIfUserChange(resetStyle: false) }
        }
    }

    // MARK: - Ticket Type Section

    /// 券種選択のセクション。旧カスタム券種の買い目を編集中は、未選択の位置にその券種名を表示する。
    private var ticketTypeSection: some View {
        Section("券種") {
            Picker("券種", selection: $selectedTicketType) {
                Text(legacyTicketTypeName.isEmpty ? "未選択" : legacyTicketTypeName).tag(nil as TicketType?)
                ForEach(selectableTicketTypes) { ticketType in
                    Text(ticketType.name).tag(ticketType as TicketType?)
                }
            }
            .accessibilityIdentifier("ticket-type-picker")
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
                    ForEach(availableBetStyles, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
            }

            if hasEntries, effectiveBetStyle == .nagashi {
                nagashiOptionPickers
            }

            if hasEntries {
                selectionRows
            } else {
                TextField("買い目（例: 1-2-3）", text: $selectionText)
                Text("出走馬を先に登録すると馬番から選択できます")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("流しは「軸>相手[流し]」で入力できます（例: 1>2,3[流し]、1>2,3[1着流し]、1>2,3[流しマルチ]）")
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
            if effectiveHorseCount >= 2 {
                horsePicker(label: "2頭目", selection: $horse2)
            }
            if effectiveHorseCount >= 3 {
                horsePicker(label: "3頭目", selection: $horse3)
            }

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
                if effectiveHorseCount >= 3 {
                    legLabel("軸3")
                }
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

        case .nagashi:
            nagashiRows
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
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
    }

    /// ユーザー操作による券種・買い方の変更時に馬番選択をリセットする。初期値読み込み中は何もしない。
    /// - Parameter resetStyle: 買い方も通常に戻すかどうか。
    private func resetIfUserChange(resetStyle: Bool) {
        guard hasFinishedInitialLoad else { return }
        horse1 = -1; horse2 = -1; horse3 = -1
        boxHorses = []; formLeg1 = []; formLeg2 = []; formLeg3 = []
        nagashiAxis1 = -1; nagashiAxis2 = -1; nagashiOpponents = []
        selectionText = ""
        if resetStyle {
            betStyle = .normal
            nagashiAxisCount = 1
        }
        nagashiPlacement = .leading(axisCount: resetStyle ? 1 : nagashiAxisCount)
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
        if existing.ticketType?.isPreset == true {
            selectedTicketType = existing.ticketType
        } else {
            legacyTicketType = existing.ticketType
            legacyTicketTypeName = existing.displayTicketTypeName
        }
        unitPrice = existing.unitPrice

        if hasEntries {
            let sel = existing.selection
            if let nagashi = NagashiSelection(selection: sel) {
                betStyle = .nagashi
                nagashiAxisCount = min(2, nagashi.axes.count)
                nagashiAxis1 = nagashi.axes[0]
                nagashiAxis2 = nagashi.axes.count > 1 ? nagashi.axes[1] : -1
                nagashiOpponents = Set(nagashi.opponents)
                nagashiPlacement = nagashi.isMulti
                    ? NagashiPlacement(positions: [], isMulti: true)
                    : nagashi.axisPositions.isEmpty
                    ? .leading(axisCount: nagashiAxisCount)
                    : NagashiPlacement(positions: nagashi.axisPositions)
            } else if sel.hasSuffix("[BOX]") {
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
            ticketType: selectedTicketType ?? legacyTicketType,
            ticketTypeName: currentTicketTypeName,
            selection: selection,
            unitPrice: unitPrice,
        )
        onSave(draft)
        dismiss()
    }
}

// MARK: - Nagashi

extension SelectionFormView {
    /// 流し買いの軸の頭数と着順指定のピッカー。
    @ViewBuilder
    private var nagashiOptionPickers: some View {
        if effectiveHorseCount >= 3 {
            Picker("軸の頭数", selection: $nagashiAxisCount) {
                Text("軸1頭").tag(1)
                Text("軸2頭").tag(2)
            }
            .pickerStyle(.segmented)
        }
        if isOrderedTicketType {
            Picker("軸の着順", selection: $nagashiPlacement) {
                ForEach(
                    NagashiPlacement.options(horseCount: effectiveHorseCount, axisCount: effectiveNagashiAxisCount),
                    id: \.self,
                ) {
                    Text($0.label).tag($0)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    /// 流し買いの軸・相手の列ラベル。着順指定がある場合は軸の列に着順を表示する。
    private var nagashiColumnLabels: [String] {
        let positioned = isOrderedTicketType && !nagashiPlacement.isMulti
        let axisLabels = (0 ..< effectiveNagashiAxisCount).map { idx in
            if positioned, idx < nagashiPlacement.positions.count {
                return "\(nagashiPlacement.positions[idx])着"
            }
            return effectiveNagashiAxisCount >= 2 ? "軸\(idx + 1)" : "軸"
        }
        return axisLabels + ["相手"]
    }

    /// 流し買いの馬番選択行（軸は列ごとに 1 頭、相手は複数選択）。
    @ViewBuilder
    private var nagashiRows: some View {
        HStack {
            Text("馬番 / 馬名")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            ForEach(nagashiColumnLabels, id: \.self) { legLabel($0) }
        }
        ForEach(sortedEntries) { entry in
            let number = entry.horseNumber
            HStack(spacing: 6) {
                Text("\(number)番")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 30)
                Text(entry.horseName)
                    .lineLimit(1)
                Spacer()
                legToggle(isOn: nagashiAxis1 == number) { selectNagashiAxis(1, number) }
                    .accessibilityIdentifier("nagashi-axis1-\(number)")
                if effectiveNagashiAxisCount >= 2 {
                    legToggle(isOn: nagashiAxis2 == number) { selectNagashiAxis(2, number) }
                        .accessibilityIdentifier("nagashi-axis2-\(number)")
                }
                legToggle(isOn: nagashiOpponents.contains(number)) { toggleNagashiOpponent(number) }
                    .accessibilityIdentifier("nagashi-opponent-\(number)")
            }
        }
    }

    /// 流し買いの軸を選ぶ。選択済みの馬をもう一度選ぶと解除し、他の軸・相手と重複しないよう外す。
    /// - Parameters:
    ///   - axisIndex: 対象の軸（1 または 2）。
    ///   - number: 選択した馬番。
    private func selectNagashiAxis(_ axisIndex: Int, _ number: Int) {
        let current = axisIndex == 1 ? nagashiAxis1 : nagashiAxis2
        if nagashiAxis1 == number {
            nagashiAxis1 = -1
        }
        if nagashiAxis2 == number {
            nagashiAxis2 = -1
        }
        guard current != number else { return }
        nagashiOpponents.remove(number)
        if axisIndex == 1 {
            nagashiAxis1 = number
        } else {
            nagashiAxis2 = number
        }
    }

    /// 流し買いの相手をトグルする。軸に選ばれている馬を相手にした場合は軸から外す。
    /// - Parameter number: トグルする馬番。
    private func toggleNagashiOpponent(_ number: Int) {
        if nagashiAxis1 == number {
            nagashiAxis1 = -1
        }
        if nagashiAxis2 == number {
            nagashiAxis2 = -1
        }
        toggleSet(&nagashiOpponents, number)
    }
}
