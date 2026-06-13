//
//  SettingsView.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Venue.sortIndex) private var venues: [Venue]
    @Query(sort: \TicketType.sortIndex) private var ticketTypes: [TicketType]
    @Query private var races: [Race]

    @State private var showingDocumentPicker = false
    @State private var zipFileURL: URL? = nil

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
                        exportZip()
                    } label: {
                        Label("ZIPバックアップ", systemImage: "archivebox")
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
            .sheet(isPresented: $showingDocumentPicker) {
                if let url = zipFileURL {
                    DocumentPicker(fileURL: url)
                }
            }
        }
    }

    private func exportZip() {
        let data = ZipExporter.export(races: races)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateStr = formatter.string(from: Date())
        let filename = "umalog_backup_\(dateStr).zip"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url)
        zipFileURL = url
        showingDocumentPicker = true
    }
}

private struct VenueManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Venue.sortIndex) private var venues: [Venue]

    @State private var showingAdd = false
    @State private var newName = ""
    @State private var showingReset = false

    var body: some View {
        List {
            ForEach(venues) { venue in
                Text(venue.name)
            }
            .onDelete { indexSet in
                for i in indexSet {
                    modelContext.delete(venues[i])
                }
            }
            Button {
                showingAdd = true
            } label: {
                Label("競馬場を追加", systemImage: "plus")
            }

            Section {
                Button(role: .destructive) {
                    showingReset = true
                } label: {
                    Label("初期状態にリセット", systemImage: "arrow.counterclockwise")
                }
            } footer: {
                Text("追加・削除した競馬場をすべて破棄し、インストール時の状態に戻します。レースデータには影響しません。")
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
        .alert("競馬場をリセット", isPresented: $showingReset) {
            Button("リセット", role: .destructive) { resetVenues() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("競馬場をインストール時の状態に戻します。この操作は元に戻せません。")
        }
    }

    private func resetVenues() {
        venues.forEach { modelContext.delete($0) }
        for preset in venuePresets {
            modelContext.insert(Venue(name: preset.name, isPreset: true, sortIndex: preset.sortIndex))
        }
    }
}

private struct TicketTypeManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TicketType.sortIndex) private var ticketTypes: [TicketType]

    @State private var showingAdd = false
    @State private var newName = ""
    @State private var showingReset = false

    var body: some View {
        List {
            ForEach(ticketTypes) { tt in
                Text(tt.name)
            }
            .onDelete { indexSet in
                for i in indexSet {
                    modelContext.delete(ticketTypes[i])
                }
            }
            Button {
                showingAdd = true
            } label: {
                Label("券種を追加", systemImage: "plus")
            }

            Section {
                Button(role: .destructive) {
                    showingReset = true
                } label: {
                    Label("初期状態にリセット", systemImage: "arrow.counterclockwise")
                }
            } footer: {
                Text("追加・削除した券種をすべて破棄し、インストール時の状態に戻します。馬券データには影響しません。")
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
        .alert("券種をリセット", isPresented: $showingReset) {
            Button("リセット", role: .destructive) { resetTicketTypes() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("券種をインストール時の状態に戻します。この操作は元に戻せません。")
        }
    }

    private func resetTicketTypes() {
        ticketTypes.forEach { modelContext.delete($0) }
        for (name, index) in defaultTicketTypeNames {
            modelContext.insert(TicketType(name: name, sortIndex: index))
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let fileURL: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {}
}
