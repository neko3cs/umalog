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

    @State private var exportURL: ExportURL?
    @State private var showingImportPicker = false
    @State private var showingImportConfirm = false
    @State private var pendingImportURL: URL?
    @State private var importError: String?
    @State private var showingImportError = false
    @State private var showingImportSuccess = false
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var showingExportSuccess = false
    @State private var exportError: String?
    @State private var showingExportError = false

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
                        HStack {
                            Label("ZIPバックアップ", systemImage: "archivebox")
                            Spacer()
                            if isExporting { ProgressView() }
                        }
                    }
                    .disabled(isExporting || isImporting)

                    Button {
                        showingImportPicker = true
                    } label: {
                        HStack {
                            Label("ZIPから復元", systemImage: "archivebox.fill")
                                .foregroundStyle(.orange)
                            Spacer()
                            if isImporting { ProgressView() }
                        }
                    }
                    .disabled(isExporting || isImporting)
                }

                Section("このアプリについて") {
                    LabeledContent(
                        "バージョン",
                        value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
                    )
                    Link(destination: URL(string: "https://github.com/neko3cs/umalog")!) {
                        Label("ソースコード（GitHub）", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    NavigationLink(destination: LicensesView()) {
                        Label("ライセンス", systemImage: "doc.text")
                    }
                }
            }
            .navigationTitle("設定")
            .sheet(item: $exportURL) { item in
                ExportDocumentPicker(fileURL: item.url) {
                    showingExportSuccess = true
                }
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
            .alert("バックアップ完了", isPresented: $showingExportSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("ZIPファイルを保存しました。")
            }
            .alert("バックアップエラー", isPresented: $showingExportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportError ?? "不明なエラーが発生しました")
            }
        }
    }

    private func exportZip() {
        isExporting = true
        Task { @MainActor in
            // SwiftUIにProgressView描画の機会を与える
            await Task.yield()
            do {
                let url = try ZipExporter.export(races: races)
                isExporting = false
                exportURL = ExportURL(url: url)
            } catch {
                isExporting = false
                exportError = error.localizedDescription
                showingExportError = true
            }
        }
    }

    private func performImport(from url: URL) {
        isImporting = true
        Task { @MainActor in
            await Task.yield()
            defer { isImporting = false }
            do {
                try ZipImporter.importZip(from: url, context: modelContext)
                showingImportSuccess = true
            } catch {
                importError = error.localizedDescription
                showingImportError = true
            }
        }
    }
}

// MARK: - Licenses

struct LicensesView: View {
    struct Package: Identifiable {
        let id = UUID()
        let name: String
        let version: String
        let licenseType: String
        let licenseText: String
    }

    let packages: [Package] = [
        Package(
            name: "swift-markdown-ui",
            version: "2.4.1",
            licenseType: "MIT",
            licenseText: """
            The MIT License (MIT)

            Copyright (c) 2020 Guillermo Gonzalez

            Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

            The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

            THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
            """
        ),
        Package(
            name: "ZIPFoundation",
            version: "0.9.20",
            licenseType: "MIT",
            licenseText: """
            MIT License

            Copyright (c) 2017-2026 Thomas Zoechling (https://www.peakstep.com)

            Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

            The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

            THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
            """
        ),
        Package(
            name: "NetworkImage",
            version: "6.0.1",
            licenseType: "MIT",
            licenseText: """
            MIT License

            Copyright (c) 2020 Guille Gonzalez

            Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

            The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

            THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
            """
        ),
        Package(
            name: "swift-cmark",
            version: "0.8.0",
            licenseType: "BSD-2-Clause",
            licenseText: """
            Copyright (c) 2014, John MacFarlane

            All rights reserved.

            Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

                * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

                * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

            THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
            """
        ),
    ]

    var body: some View {
        List(packages) { package in
            NavigationLink(destination: LicenseDetailView(package: package)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(package.name)
                    Text("\(package.version)  \(package.licenseType)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
        .navigationTitle("ライセンス")
    }
}

struct LicenseDetailView: View {
    let package: LicensesView.Package

    var body: some View {
        ScrollView {
            Text(package.licenseText)
                .font(.caption)
                .monospaced()
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(package.name)
        .navigationBarTitleDisplayMode(.inline)
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

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.zip])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPicked: (URL) -> Void
        init(onPicked: @escaping (URL) -> Void) {
            self.onPicked = onPicked
        }

        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            // セキュリティスコープが解放されると元URLを後で読めなくなるため、
            // 取得直後にアプリのtmpへコピーする
            let tmpURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("import_\(UUID().uuidString).zip")
            do {
                try? FileManager.default.removeItem(at: tmpURL)
                try FileManager.default.copyItem(at: url, to: tmpURL)
                onPicked(tmpURL)
            } catch {
                onPicked(url) // フォールバック（おそらく失敗するがエラーをユーザーに伝えるため）
            }
        }
    }
}

struct ExportDocumentPicker: UIViewControllerRepresentable {
    let fileURL: URL
    let onSaved: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSaved: onSaved)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onSaved: () -> Void
        init(onSaved: @escaping () -> Void) {
            self.onSaved = onSaved
        }

        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt _: [URL]) {
            onSaved()
        }
    }
}
