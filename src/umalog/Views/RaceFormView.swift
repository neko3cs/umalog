//
//  RaceFormView.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import SwiftData
import SwiftUI

/// レースの追加・編集フォーム。`race` が nil なら新規追加、非 nil なら編集として動作する。
struct RaceFormView: View {
    /// SwiftData のモデルコンテキスト。
    @Environment(\.modelContext) private var modelContext
    /// シートを閉じるためのアクション。
    @Environment(\.dismiss) private var dismiss

    /// 編集対象のレース。新規追加の場合は nil。
    var race: Race?

    /// SwiftData から取得した全競馬場。
    @Query(sort: \Venue.sortIndex) private var venues: [Venue]

    /// 入力中の開催日。
    @State private var date: Date = .init()
    /// 入力中の競馬場。
    @State private var selectedVenue: Venue?
    /// 入力中のレース番号。
    @State private var raceNumber: Int = 1
    /// 入力中のレース名。
    @State private var raceName: String = ""
    /// 入力中の距離（メートル）。
    @State private var distance: Int = 1600
    /// 入力中のトラック種別（"turf" / "dirt"）。
    @State private var trackType: String = "turf"
    /// 入力中の馬場状態。
    @State private var trackCondition: String = "良"
    /// 入力中の区分（"central" / "local"）。
    @State private var category: String = "central"
    /// 入力中のグレード識別子。
    @State private var grade: String = ""

    /// 馬場状態の選択肢。
    private let trackConditions = ["良", "稍重", "重", "不良"]
    /// 編集モードかどうか。
    private var isEditing: Bool {
        race != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("レース情報") {
                    HStack {
                        Text("日付")
                        Spacer()
                        Text(date.japaneseShortDateString)
                            .foregroundStyle(.blue)
                            .overlay {
                                DatePicker("", selection: $date, displayedComponents: .date)
                                    .labelsHidden()
                                    .colorMultiply(.clear)
                            }
                    }
                    Picker("競馬場", selection: $selectedVenue) {
                        Text("未選択").tag(nil as Venue?)
                        ForEach(venues) { venue in
                            Text(venue.name).tag(venue as Venue?)
                        }
                    }
                    Stepper("R\(raceNumber)", value: $raceNumber, in: 1 ... 12)
                    TextField("レース名（任意）", text: $raceName)
                    Picker("グレード", selection: $grade) {
                        ForEach(RaceGrade.allCases, id: \.rawValue) { g in
                            Text(g.displayName).tag(g.rawValue)
                        }
                    }
                }

                Section("コース") {
                    Picker("トラック", selection: $trackType) {
                        Text("芝").tag("turf")
                        Text("ダート").tag("dirt")
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text("距離")
                        Spacer()
                        TextField("距離", value: $distance, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("m")
                    }

                    Picker("馬場状態", selection: $trackCondition) {
                        ForEach(trackConditions, id: \.self) { condition in
                            Text(condition).tag(condition)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("区分", selection: $category) {
                        Text("中央（JRA）").tag("central")
                        Text("地方（NAR）").tag("local")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(isEditing ? "レースを編集" : "レースを追加")
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
            .onAppear { loadIfEditing() }
        }
    }

    /// 編集モードの場合、編集対象レースの値を入力フィールドに読み込む。
    private func loadIfEditing() {
        guard let race else { return }
        date = race.date
        selectedVenue = race.venue
        raceNumber = race.raceNumber
        raceName = race.raceName
        distance = race.distance
        trackType = race.trackType
        trackCondition = race.trackCondition
        category = race.category
        grade = race.grade
    }

    /// 入力値を保存する。編集モードなら既存レースを更新し、新規モードならレースを挿入する。
    private func save() {
        if let race {
            race.date = date
            race.venue = selectedVenue
            race.raceNumber = raceNumber
            race.raceName = raceName
            race.distance = distance
            race.trackType = trackType
            race.trackCondition = trackCondition
            race.category = category
            race.grade = grade
        } else {
            let newRace = Race(
                date: date, venue: selectedVenue, raceNumber: raceNumber,
                raceName: raceName, distance: distance, trackType: trackType,
                trackCondition: trackCondition, category: category, grade: grade,
            )
            modelContext.insert(newRace)
        }
    }
}
