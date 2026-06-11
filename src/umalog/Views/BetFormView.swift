//
//  BetFormView.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import SwiftUI
import SwiftData

struct BetFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let race: Race
    var bet: Bet? = nil

    @Query(sort: \TicketType.sortIndex) private var ticketTypes: [TicketType]

    @State private var selectedTicketType: TicketType? = nil
    @State private var customTicketTypeName: String = ""
    @State private var useCustom: Bool = false
    @State private var selection: String = ""
    @State private var purchaseAmount: Int = 100
    @State private var payoutAmount: Int = 0

    private var isEditing: Bool { bet != nil }

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
                    TextField("例: 1-2-3", text: $selection)
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
        }
    }

    private func loadIfEditing() {
        guard let bet else { return }
        selectedTicketType = bet.ticketType
        customTicketTypeName = bet.ticketTypeName
        useCustom = bet.ticketType == nil && !bet.ticketTypeName.isEmpty
        selection = bet.selection
        purchaseAmount = bet.purchaseAmount
        payoutAmount = bet.payoutAmount
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
