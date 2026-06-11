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

    @State private var csvContent: String? = nil
    @State private var showingShareSheet = false

    var body: some View {
        NavigationStack {
            List {
                Section("管理") {
                    NavigationLink {
                        VenueManagementView()
                    } label: {
                        LabeledContent("競馬場", value: "\(venues.count)件")
                    }
                    NavigationLink {
                        TicketTypeManagementView()
                    } label: {
                        LabeledContent("券種", value: "\(ticketTypes.count)件")
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
            .sheet(isPresented: $showingShareSheet) {
                if let csv = csvContent {
                    ShareSheet(content: csv, filename: "umalog_export.csv")
                }
            }
        }
    }
}

private struct VenueManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Venue.sortIndex) private var venues: [Venue]

    @State private var showingAdd = false
    @State private var newName = ""

    var body: some View {
        List {
            ForEach(venues) { venue in
                Text(venue.name)
            }
            .onDelete { indexSet in
                for i in indexSet { modelContext.delete(venues[i]) }
            }
            Button {
                showingAdd = true
            } label: {
                Label("競馬場を追加", systemImage: "plus")
            }
        }
        .navigationTitle("競馬場")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .alert("競馬場を追加", isPresented: $showingAdd) {
            TextField("競馬場名", text: $newName)
            Button("追加") {
                guard !newName.isEmpty else { return }
                modelContext.insert(Venue(name: newName, isPreset: false, sortIndex: venues.count))
                newName = ""
            }
            Button("キャンセル", role: .cancel) { newName = "" }
        }
    }
}

private struct TicketTypeManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TicketType.sortIndex) private var ticketTypes: [TicketType]

    @State private var showingAdd = false
    @State private var newName = ""

    var body: some View {
        List {
            ForEach(ticketTypes) { tt in
                Text(tt.name)
            }
            .onDelete { indexSet in
                for i in indexSet { modelContext.delete(ticketTypes[i]) }
            }
            Button {
                showingAdd = true
            } label: {
                Label("券種を追加", systemImage: "plus")
            }
        }
        .navigationTitle("券種")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .alert("券種を追加", isPresented: $showingAdd) {
            TextField("券種名", text: $newName)
            Button("追加") {
                guard !newName.isEmpty else { return }
                modelContext.insert(TicketType(name: newName, sortIndex: ticketTypes.count))
                newName = ""
            }
            Button("キャンセル", role: .cancel) { newName = "" }
        }
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
