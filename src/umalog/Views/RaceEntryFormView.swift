//
//  RaceEntryFormView.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import SwiftUI
import SwiftData

struct RaceEntryFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let race: Race
    var entry: RaceEntry? = nil

    @Query private var allEntries: [RaceEntry]

    @State private var horseNumber: Int = 1
    @State private var horseName: String = ""
    @State private var jockeyName: String = ""
    @State private var trainerName: String = ""
    @State private var selectedMark: PredictionMark? = nil
    @State private var finishPositionText: String = ""

    private var isEditing: Bool { entry != nil }

    private var horseNameSuggestions: [String] {
        guard !horseName.isEmpty else { return [] }
        let names = Set(allEntries.map { $0.horseName }.filter { !$0.isEmpty })
        return names.filter { $0.localizedStandardContains(horseName) && $0 != horseName }.sorted()
    }

    private var jockeyNameSuggestions: [String] {
        guard !jockeyName.isEmpty else { return [] }
        let names = Set(allEntries.map { $0.jockeyName }.filter { !$0.isEmpty })
        return names.filter { $0.localizedStandardContains(jockeyName) && $0 != jockeyName }.sorted()
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
                                            : Color.secondary.opacity(0.1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("着順（結果確定後に入力）") {
                    HStack {
                        Text("着順")
                        Spacer()
                        TextField("未入力", text: $finishPositionText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        if !finishPositionText.isEmpty { Text("着") }
                    }
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
            }
            .onAppear { loadIfEditing() }
        }
    }

    private func loadIfEditing() {
        if let entry {
            horseNumber = entry.horseNumber
            horseName = entry.horseName
            jockeyName = entry.jockeyName
            trainerName = entry.trainerName
            selectedMark = entry.mark
            finishPositionText = entry.finishPosition.map { "\($0)" } ?? ""
        } else {
            let maxNum = (race.entries ?? []).map { $0.horseNumber }.max() ?? 0
            horseNumber = maxNum + 1
        }
    }

    private func save() {
        let pos = Int(finishPositionText)
        if let entry {
            entry.horseNumber = horseNumber
            entry.horseName = horseName
            entry.jockeyName = jockeyName
            entry.trainerName = trainerName
            entry.mark = selectedMark
            entry.finishPosition = pos
        } else {
            let sortIndex = (race.entries ?? []).count
            modelContext.insert(RaceEntry(
                race: race, horseNumber: horseNumber, horseName: horseName,
                jockeyName: jockeyName, trainerName: trainerName,
                predictionMark: selectedMark?.rawValue, finishPosition: pos,
                sortIndex: sortIndex
            ))
        }
    }
}
