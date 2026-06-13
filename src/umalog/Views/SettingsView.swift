//
//  SettingsView.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Venue.sortIndex) private var venues: [Venue]
    @Query(sort: \TicketType.sortIndex) private var ticketTypes: [TicketType]
    @Query private var races: [Race]

    @State private var exportURL: ExportURL? = nil
    @State private var showingImportPicker = false
    @State private var showingImportConfirm = false
    @State private var pendingImportURL: URL? = nil
    @State private var importError: String? = nil
    @State private var showingImportError = false
    @State private var showingImportSuccess = false

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
                    Button {
                        showingImportPicker = true
                    } label: {
                        Label("ZIPから復元", systemImage: "archivebox.fill")
                            .foregroundStyle(.orange)
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
            .sheet(item: $exportURL) { item in
                ExportDocumentPicker(fileURL: item.url)
            }
            .sheet(isPresented: $showingImportPicker) {
                ImportDocumentPicker { url in
                    pendingImportURL = url
                    showingImportConfirm = true
                }
            }
            .alert("データを復元", isPresented: $showingImportConfirm) {
                Button("復元", role: .destructive) {
                    if let url = pendingImportURL { performImport(from: url) }
                }
                Button("キャンセル", role: .cancel) { pendingImportURL = nil }
            } message: {
                Text("現在のレースデータをすべて削除してZIPから復元します。競馬場・券種データは変更されません。この操作は元に戻せません。")
            }
            .alert("復元エラー", isPresented: $showingImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importError ?? "不明なエラーが発生しました")
            }
            .alert("復元完了", isPresented: $showingImportSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("ZIPファイルからデータを復元しました。")
            }
        }
    }

    private func exportZip() {
        guard let url = try? ZipExporter.export(races: races) else { return }
        exportURL = ExportURL(url: url)
    }

    private func performImport(from url: URL) {
        do {
            try ZipImporter.importZip(from: url, context: modelContext)
            showingImportSuccess = true
        } catch {
            importError = error.localizedDescription
            showingImportError = true
        }
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

private struct ExportURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct ImportDocumentPicker: UIViewControllerRepresentable {
    let onPicked: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.zip])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPicked: (URL) -> Void
        init(onPicked: @escaping (URL) -> Void) { self.onPicked = onPicked }

        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            onPicked(url)
        }
    }
}

struct ExportDocumentPicker: UIViewControllerRepresentable {
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
