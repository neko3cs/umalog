//
//  RaceFormView.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import SwiftData
import SwiftUI

struct RaceFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var race: Race? = nil

    @Query(sort: \Venue.sortIndex) private var venues: [Venue]

    @State private var date: Date = .init()
    @State private var selectedVenue: Venue? = nil
    @State private var raceNumber: Int = 1
    @State private var raceName: String = ""
    @State private var distance: Int = 1600
    @State private var trackType: String = "turf"
    @State private var trackCondition: String = "良"
    @State private var category: String = "central"

    private let trackConditions = ["良", "稍重", "重", "不良"]
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
                        Text(date.formatted(Date.FormatStyle().locale(Locale(identifier: "ja_JP")).year(.defaultDigits).month(.twoDigits).day(.twoDigits)))
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
                        ForEach(trackConditions, id: \.self) { c in
                            Text(c).tag(c)
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
                            to: nil, from: nil, for: nil
                        )
                    }
                }
            }
            .onAppear { loadIfEditing() }
        }
    }

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
    }

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
        } else {
            let newRace = Race(
                date: date, venue: selectedVenue, raceNumber: raceNumber,
                raceName: raceName, distance: distance, trackType: trackType,
                trackCondition: trackCondition, category: category
            )
            modelContext.insert(newRace)
        }
    }
}
