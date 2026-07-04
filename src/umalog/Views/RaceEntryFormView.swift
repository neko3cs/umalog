//
//  RaceEntryFormView.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import SwiftData
import SwiftUI

/// 出走馬の追加・編集フォーム。`entry` が nil なら新規追加、非 nil なら編集として動作する。
/// 馬名・騎手名・調教師名には過去の入力とプリセットからのオートコンプリート候補を表示する。
struct RaceEntryFormView: View {
    /// SwiftData のモデルコンテキスト。
    @Environment(\.modelContext) private var modelContext
    /// シートを閉じるためのアクション。
    @Environment(\.dismiss) private var dismiss

    /// 出走馬を追加する対象のレース。
    let race: Race
    /// 編集対象の出走馬。新規追加の場合は nil。
    var entry: RaceEntry?

    /// 全レースの出走馬。オートコンプリート候補の収集に使う。
    @Query private var allEntries: [RaceEntry]

    /// 入力中の馬番。
    @State private var horseNumber: Int = 1
    /// 入力中の馬名。
    @State private var horseName: String = ""
    /// 入力中の騎手名。
    @State private var jockeyName: String = ""
    /// 入力中の調教師名。
    @State private var trainerName: String = ""
    /// 選択中の予想印。未選択の場合は nil。
    @State private var selectedMark: PredictionMark?

    /// 編集モードかどうか。
    private var isEditing: Bool {
        entry != nil
    }

    /// 過去に入力した馬名からの部分一致候補。
    private var horseNameSuggestions: [String] {
        guard !horseName.isEmpty else { return [] }
        let names = Set(allEntries.map(\.horseName).filter { !$0.isEmpty })
        return names.filter { $0.localizedStandardContains(horseName) && $0 != horseName }.sorted()
    }

    /// 過去の入力と JRA プリセットを合わせた騎手名の部分一致候補。
    private var jockeyNameSuggestions: [String] {
        guard !jockeyName.isEmpty else { return [] }
        let pastNames = Set(allEntries.map(\.jockeyName).filter { !$0.isEmpty })
        let combined = pastNames.union(jockeyPresets)
        return combined
            .filter { $0.localizedStandardContains(jockeyName) && $0 != jockeyName }
            .sorted()
    }

    /// 過去の入力と JRA プリセットを合わせた調教師名の部分一致候補。
    private var trainerNameSuggestions: [String] {
        guard !trainerName.isEmpty else { return [] }
        let pastNames = Set(allEntries.map(\.trainerName).filter { !$0.isEmpty })
        let combined = pastNames.union(trainerPresets)
        return combined
            .filter { $0.localizedStandardContains(trainerName) && $0 != trainerName }
            .sorted()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("出走馬情報") {
                    HStack {
                        Text("馬番")
                        Spacer()
                        TextField("馬番", value: $horseNumber, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }

                    TextField("馬名", text: $horseName)
                        .autocorrectionDisabled()

                    if !horseNameSuggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(horseNameSuggestions, id: \.self) { name in
                                    Button(name) { horseName = name }
                                        .buttonStyle(.bordered)
                                        .font(.caption)
                                        .tint(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    TextField("騎手名", text: $jockeyName)
                        .autocorrectionDisabled()

                    if !jockeyNameSuggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(jockeyNameSuggestions, id: \.self) { name in
                                    Button(name) { jockeyName = name }
                                        .buttonStyle(.bordered)
                                        .font(.caption)
                                        .tint(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    TextField("調教師名（任意）", text: $trainerName)
                        .autocorrectionDisabled()

                    if !trainerNameSuggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(trainerNameSuggestions, id: \.self) { name in
                                    Button(name) { trainerName = name }
                                        .buttonStyle(.bordered)
                                        .font(.caption)
                                        .tint(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section("予想印") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                        ForEach(PredictionMark.allCases, id: \.self) { mark in
                            Button {
                                selectedMark = selectedMark == mark ? nil : mark
                            } label: {
                                Text(mark.rawValue)
                                    .font(.title2)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        selectedMark == mark
                                            ? Color.accentColor.opacity(0.25)
                                            : Color.secondary.opacity(0.1),
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("mark-button-\(mark.rawValue)")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(isEditing ? "出走馬を編集" : "出走馬を追加")
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
                    .disabled(horseName.isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { dismissKeyboard() }
                }
            }
            .onAppear { loadIfEditing() }
        }
    }

    /// 表示中のキーボードを閉じる。
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil,
        )
    }

    /// 編集モードなら編集対象の値を、新規モードなら既存出走馬の最大馬番 + 1 を入力フィールドに設定する。
    private func loadIfEditing() {
        if let entry {
            horseNumber = entry.horseNumber
            horseName = entry.horseName
            jockeyName = entry.jockeyName
            trainerName = entry.trainerName
            selectedMark = entry.mark
        } else {
            let maxNum = (race.entries ?? []).map(\.horseNumber).max() ?? 0
            horseNumber = maxNum + 1
        }
    }

    /// 入力値を保存する。編集モードなら既存出走馬を更新し、新規モードなら出走馬を挿入する。
    private func save() {
        if let entry {
            entry.horseNumber = horseNumber
            entry.horseName = horseName
            entry.jockeyName = jockeyName
            entry.trainerName = trainerName
            entry.mark = selectedMark
        } else {
            let sortIndex = (race.entries ?? []).count
            modelContext.insert(RaceEntry(
                race: race, horseNumber: horseNumber, horseName: horseName,
                jockeyName: jockeyName, trainerName: trainerName,
                predictionMark: selectedMark?.rawValue,
                sortIndex: sortIndex,
            ))
        }
    }
}
