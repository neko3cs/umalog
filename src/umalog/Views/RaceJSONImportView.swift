//
//  RaceJSONImportView.swift
//  umalog
//
//  Created by neko3cs on 2026/10/28.
//

import SwiftData
import SwiftUI

/// JSON 文字列からレース・出走馬を取り込む画面。貼り付け → 差分プレビュー → 保存の順に進み、保存するまでデータは変えない。
/// `targetRace` が nil ならレース一覧からの取り込み、非 nil ならレース詳細からそのレースを更新する取り込みとして動作する。
struct RaceJSONImportView: View {
    /// SwiftData のモデルコンテキスト。
    @Environment(\.modelContext) private var modelContext
    /// シートを閉じるためのアクション。
    @Environment(\.dismiss) private var dismiss

    /// 更新するレース。レース一覧から開いた場合は nil。
    var targetRace: Race?

    /// 貼り付けられたテキスト。
    @State private var text = ""
    /// 検証を通過したときの取り込み計画。非 nil のときプレビューを表示する。
    @State private var plan: RaceImportPlan?
    /// 取り込みを中止したときのエラー。
    @State private var importError: RaceImportError?
    /// 直前にコピーした内容の説明。コピーしたことを知らせるために表示する。
    @State private var copiedMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if let plan {
                    previewSections(plan)
                } else {
                    inputSections
                }
            }
            .navigationTitle(targetRace == nil ? "レースを取り込み" : "取り込みで更新")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                        .accessibilityIdentifier("import-cancel-button")
                }
                ToolbarItem(placement: .confirmationAction) {
                    if let plan {
                        Button("保存") { save(plan) }
                            .disabled(!plan.hasChanges)
                            .accessibilityIdentifier("import-save-button")
                    } else {
                        Button("確認") { check() }
                            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("import-check-button")
                    }
                }
            }
        }
    }

    /// 入力画面の使い方の説明。
    private var footerText: String {
        let usage = "プロンプトを AI に渡して予想を JSON で出力してもらい、その出力を下に貼り付けます。"
        if targetRace == nil {
            return usage + "同じレース（日付・競馬場・レース番号）を貼り直すと差分だけを更新し、JSON に無い馬番の出走馬は削除します。"
        }
        return usage + "このレースと日付・競馬場・レース番号が同じ JSON だけを取り込み、差分だけを更新します。JSON に無い馬番の出走馬は削除します。"
    }

    /// テキストを貼り付ける入力画面のセクション。
    @ViewBuilder
    private var inputSections: some View {
        Section {
            Button {
                copy(RaceJSONImporter.promptForAI, message: "プロンプトをコピーしました")
            } label: {
                Label("AI 向けプロンプトをコピー", systemImage: "doc.on.doc")
            }
            .accessibilityIdentifier("copy-import-prompt-button")
        } footer: {
            Text(footerText)
        }

        Section("JSON") {
            TextEditor(text: $text)
                .font(.system(.footnote, design: .monospaced))
                .frame(minHeight: 200)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("import-json-editor")
            PasteButton(payloadType: String.self) { strings in
                Task { @MainActor in
                    text = strings.first ?? ""
                    importError = nil
                }
            }
        }

        if let importError {
            Section("取り込めませんでした（何も保存していません）") {
                Text(importError.errorDescription ?? "")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("import-error-text")
                Button {
                    copy(importError.reportForAI, message: "エラー内容をコピーしました")
                } label: {
                    Label("エラー内容をコピー（AI に渡す）", systemImage: "doc.on.doc")
                }
                .accessibilityIdentifier("copy-import-error-button")
            }
        }

        if let copiedMessage {
            Text(copiedMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    /// 保存前の差分プレビューのセクション。
    /// - Parameter plan: 表示する取り込み計画。
    /// - Returns: レースと出走馬の変更内容。
    @ViewBuilder
    private func previewSections(_ plan: RaceImportPlan) -> some View {
        Section("レース") {
            LabeledContent(
                "\(plan.data.date.japaneseShortDateString) \(plan.data.venueName) R\(plan.data.raceNumber)",
                value: plan.raceKind.displayName,
            )
            .accessibilityIdentifier("import-race-status")
            ForEach(plan.raceChanges, id: \.label) { change in
                changeRow(change)
            }
        }

        Section("出走馬") {
            ForEach(plan.entries) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("\(entry.horseNumber) \(entry.horseName)")
                        Spacer()
                        Text(entry.kind.displayName)
                            .foregroundStyle(entry.kind == .delete ? .red : .secondary)
                    }
                    ForEach(entry.changes, id: \.label) { change in
                        Text("\(change.label): \(change.oldValue) → \(change.newValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("import-entry-\(entry.horseNumber)")
            }
        }

        Section {
            if !plan.hasChanges {
                Text("変更はありません")
                    .foregroundStyle(.secondary)
            }
            Button("入力に戻る") { self.plan = nil }
                .accessibilityIdentifier("import-back-button")
        }
    }

    /// 1 フィールドの変更前後を表示する行。
    /// - Parameter change: 表示する変更。
    /// - Returns: 「変更前 → 変更後」の行。
    private func changeRow(_ change: RaceImportFieldChange) -> some View {
        LabeledContent(change.label, value: "\(change.oldValue) → \(change.newValue)")
            .font(.footnote)
    }

    /// テキストを検証して取り込み計画を作る。エラーなら原因を表示する。
    private func check() {
        copiedMessage = nil
        do {
            let data = try RaceJSONImporter.parse(text)
            plan = try RaceJSONImporter.makePlan(for: data, in: modelContext, target: targetRace)
            importError = nil
        } catch let error as RaceImportError {
            importError = error
        } catch {
            importError = RaceImportError(issues: [.init(path: "(JSON)", message: error.localizedDescription)])
        }
    }

    /// 取り込み計画を保存して画面を閉じる。失敗したら入力画面に戻して原因を表示する。
    /// - Parameter plan: 保存する取り込み計画。
    private func save(_ plan: RaceImportPlan) {
        do {
            try RaceJSONImporter.apply(plan, in: modelContext)
            dismiss()
        } catch {
            modelContext.rollback()
            self.plan = nil
            importError = RaceImportError(issues: [.init(path: "(保存)", message: error.localizedDescription)])
        }
    }

    /// テキストをクリップボードにコピーし、コピーしたことを表示する。
    /// - Parameters:
    ///   - string: コピーするテキスト。
    ///   - message: 表示する説明。
    private func copy(_ string: String, message: String) {
        UIPasteboard.general.string = string
        copiedMessage = message
    }
}
