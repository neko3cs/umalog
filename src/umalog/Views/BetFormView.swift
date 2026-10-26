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
    /// 流し買い
    case nagashi = "流し"
}

/// 流し買いで軸を置く着順の指定。着順を区別する券種（馬単・三連単）でのみ使う。
struct NagashiPlacement: Hashable {
    /// 軸の着順（1 始まり）。マルチの場合は空。
    var positions: [Int]
    /// マルチ指定かどうか。
    var isMulti: Bool = false

    /// 軸を 1 着から順に置く既定の指定。
    /// - Parameter axisCount: 軸の頭数。
    /// - Returns: 既定の着順指定。
    static func leading(axisCount: Int) -> NagashiPlacement {
        NagashiPlacement(positions: Array(1 ... max(1, axisCount)))
    }

    /// 頭数・軸の頭数に対して選べる全ての指定（着順の組合せ + マルチ）。
    /// - Parameters:
    ///   - horseCount: 1 点あたりの頭数。
    ///   - axisCount: 軸の頭数。
    /// - Returns: 選択肢の一覧。
    static func options(horseCount: Int, axisCount: Int) -> [NagashiPlacement] {
        let positions: [[Int]] = axisCount >= 2
            ? (1 ... horseCount).flatMap { first in
                (1 ... horseCount).filter { $0 > first }.map { [first, $0] }
            }
            : (1 ... horseCount).map { [$0] }
        return positions.map { NagashiPlacement(positions: $0) } + [NagashiPlacement(positions: [], isMulti: true)]
    }

    /// セグメントピッカーの表示名（例: 「1着」「1・3着」「マルチ」）。
    var label: String {
        isMulti ? "マルチ" : positions.map { "\($0)" }.joined(separator: "・") + "着"
    }
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

/// 買い目入力シートの対象。`.sheet(item:)` に渡し、表示時点の編集対象を確実にシートへ渡すために使う。
/// - Note: `.sheet(isPresented:)` と別の `@State` で編集対象を持つと、初回表示時に古い値が読まれることがある（Issue #46）。
enum SelectionFormTarget: Identifiable {
    /// 買い目を新規追加する。
    case new
    /// 指定 ID のドラフトを編集する。
    case edit(UUID)

    /// シートの識別子。編集対象が変われば別のシートとして扱われる。
    var id: String {
        switch self {
        case .new: "new"
        case let .edit(draftId): draftId.uuidString
        }
    }

    /// 編集対象のドラフト ID。新規追加の場合は nil。
    var editingDraftId: UUID? {
        if case let .edit(draftId) = self {
            draftId
        } else {
            nil
        }
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
    /// 表示中の買い目入力シートの対象。nil ならシートは閉じている。
    @State private var selectionFormTarget: SelectionFormTarget?

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
            .sheet(item: $selectionFormTarget) { target in
                selectionFormSheet(for: target)
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
                    .onTapGesture { selectionFormTarget = .edit(draft.id) }
            }
            .onDelete { indexSet in draftSelections.remove(atOffsets: indexSet) }
            Button {
                selectionFormTarget = .new
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

    /// 買い目入力シートを生成する。編集対象のドラフトがあればその内容を初期値として渡す。
    /// - Parameter target: シートの対象（新規追加または編集するドラフト）。
    /// - Returns: 買い目入力シートのビュー。
    private func selectionFormSheet(for target: SelectionFormTarget) -> some View {
        let editId = target.editingDraftId
        let editDraft = editId.flatMap { id in draftSelections.first { $0.id == id } }
        return SelectionFormView(race: race, existing: editDraft) { savedDraft in
            if let editId, let idx = draftSelections.firstIndex(where: { $0.id == editId }) {
                var updated = savedDraft
                updated.id = editId
                draftSelections[idx] = updated
            } else {
                draftSelections.append(savedDraft)
            }
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
        // 一時 ID のまま一覧に出すと、自動保存で恒久 ID に変わった時点で行が作り直されるため、すぐに確定させる（Issue #55）
        try? modelContext.save()
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
