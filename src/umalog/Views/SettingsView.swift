//
//  SettingsView.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Venue.sortIndex) private var venues: [Venue]
    @Query(sort: \TicketType.sortIndex) private var ticketTypes: [TicketType]
    @Query private var races: [Race]

    @State private var showingAddVenue = false
    @State private var newVenueName = ""
    @State private var showingAddTicketType = false
    @State private var newTicketTypeName = ""
    @State private var csvContent: String? = nil
    @State private var showingShareSheet = false

    var body: some View {
        NavigationStack {
            List {
                Section("競馬場") {
                    ForEach(venues) { venue in
                        Text(venue.name)
                    }
                    .onDelete(perform: deleteVenues)
                    Button {
                        showingAddVenue = true
                    } label: {
                        Label("競馬場を追加", systemImage: "plus")
                    }
                }

                Section("券種") {
                    ForEach(ticketTypes) { tt in
                        Text(tt.name)
                    }
                    .onDelete(perform: deleteTicketTypes)
                    Button {
                        showingAddTicketType = true
                    } label: {
                        Label("券種を追加", systemImage: "plus")
                    }
                }

                Section("データ") {
                    Button {
                        csvContent = CSVExporter.export(races: races)
                        showingShareSheet = true
                    } label: {
                        Label("CSVエクスポート", systemImage: "square.and.arrow.up")
                    }
                }

                Section {
                    HStack {
                        Text("iCloud同期")
                        Spacer()
                        Text("準備中")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("iCloud同期")
                } footer: {
                    Text("Apple Developer Account契約後に実装予定です")
                }

                Section("このアプリについて") {
                    LabeledContent(
                        "バージョン",
                        value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
                    )
                    Link(destination: URL(string: "https://github.com/neko3cs/umalog")!) {
                        Label("ソースコード（GitHub）", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }
            }
            .navigationTitle("設定")
            .alert("競馬場を追加", isPresented: $showingAddVenue) {
                TextField("競馬場名", text: $newVenueName)
                Button("追加") {
                    guard !newVenueName.isEmpty else { return }
                    modelContext.insert(Venue(name: newVenueName, isPreset: false, sortIndex: venues.count))
                    newVenueName = ""
                }
                Button("キャンセル", role: .cancel) { newVenueName = "" }
            }
            .alert("券種を追加", isPresented: $showingAddTicketType) {
                TextField("券種名", text: $newTicketTypeName)
                Button("追加") {
                    guard !newTicketTypeName.isEmpty else { return }
                    modelContext.insert(TicketType(name: newTicketTypeName, sortIndex: ticketTypes.count))
                    newTicketTypeName = ""
                }
                Button("キャンセル", role: .cancel) { newTicketTypeName = "" }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let csv = csvContent {
                    ShareSheet(content: csv, filename: "umalog_export.csv")
                }
            }
        }
    }

    private func deleteVenues(offsets: IndexSet) {
        for i in offsets { modelContext.delete(venues[i]) }
    }

    private func deleteTicketTypes(offsets: IndexSet) {
        for i in offsets { modelContext.delete(ticketTypes[i]) }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let content: String
    let filename: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? content.write(to: tempURL, atomically: true, encoding: .utf8)
        return UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
