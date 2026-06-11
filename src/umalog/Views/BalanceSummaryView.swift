//
//  BalanceSummaryView.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import SwiftUI
import SwiftData

enum SummaryPeriod: String, CaseIterable {
    case daily = "日"
    case monthly = "月"
    case yearly = "年"
}

struct BalanceSummaryView: View {
    @Query private var races: [Race]

    @State private var period: SummaryPeriod = .monthly
    @State private var selectedDate: Date = Date()

    private let calendar = Calendar.current

    private var filteredRaces: [Race] {
        races.filter { race in
            switch period {
            case .daily:
                return calendar.isDate(race.date, inSameDayAs: selectedDate)
            case .monthly:
                return calendar.isDate(race.date, equalTo: selectedDate, toGranularity: .month)
            case .yearly:
                return calendar.isDate(race.date, equalTo: selectedDate, toGranularity: .year)
            }
        }
    }

    private var totalPurchase: Int { filteredRaces.reduce(0) { $0 + $1.totalPurchase } }
    private var totalPayout: Int { filteredRaces.reduce(0) { $0 + $1.totalPayout } }
    private var balance: Int { totalPayout - totalPurchase }
    private var returnRate: Double? {
        guard totalPurchase > 0 else { return nil }
        return Double(totalPayout) / Double(totalPurchase)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("期間", selection: $period) {
                        ForEach(SummaryPeriod.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)

                    DatePicker("対象", selection: $selectedDate, displayedComponents: .date)
                }

                Section("集計") {
                    summaryRow("購入合計", "¥\(totalPurchase.formatted())")
                    summaryRow("払戻合計", "¥\(totalPayout.formatted())")
                    summaryRow(
                        "収支",
                        "\(balance >= 0 ? "+" : "−")¥\(abs(balance).formatted())",
                        color: totalPurchase == 0 ? .primary : balance >= 0 ? .green : .red
                    )
                    if let rate = returnRate {
                        summaryRow("回収率", String(format: "%.1f%%", rate * 100))
                    }
                    summaryRow("レース数", "\(filteredRaces.count) R")
                }

                if !filteredRaces.isEmpty {
                    Section("内訳") {
                        ForEach(filteredRaces.sorted { $0.date > $1.date }) { race in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(race.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if let venue = race.venue {
                                            Text(venue.name)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Text("R\(race.raceNumber)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(race.raceName.isEmpty ? "R\(race.raceNumber)" : race.raceName)
                                        .font(.body)
                                }
                                Spacer()
                                if race.totalPurchase > 0 {
                                    Text("\(race.balance >= 0 ? "+" : "−")¥\(abs(race.balance).formatted())")
                                        .font(.callout)
                                        .fontWeight(.medium)
                                        .foregroundStyle(race.balance >= 0 ? .green : .red)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("収支")
        }
    }

    private func summaryRow(_ label: String, _ value: String, color: Color = .primary) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(color)
                .fontWeight(.medium)
        }
    }
}
