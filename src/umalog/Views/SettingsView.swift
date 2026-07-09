//
//  SettingsView.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

// swiftlint:disable line_length
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// 設定画面。マスター管理・ZIP バックアップ / 復元・データ初期化・アプリ情報を提供する。
struct SettingsView: View {
    /// SwiftData のモデルコンテキスト。
    @Environment(\.modelContext) private var modelContext
    /// SwiftData から取得した全競馬場。
    @Query(sort: \Venue.sortIndex) private var venues: [Venue]
    /// SwiftData から取得した全券種。
    @Query(sort: \TicketType.sortIndex) private var ticketTypes: [TicketType]
    /// SwiftData から取得した全レース。バックアップ対象。
    @Query private var races: [Race]

    /// エクスポート済み ZIP の URL。非 nil のとき保存先選択シートを表示する。
    @State private var exportURL: ExportURL?
    /// 復元用 ZIP 選択シートの表示状態。
    @State private var showingImportPicker = false
    /// 復元確認アラートの表示状態。
    @State private var showingImportConfirm = false
    /// 復元確認中の ZIP の URL。
    @State private var pendingImportURL: URL?
    /// 復元エラーのメッセージ。
    @State private var importError: String?
    /// 復元エラーアラートの表示状態。
    @State private var showingImportError = false
    /// 復元完了アラートの表示状態。
    @State private var showingImportSuccess = false
    /// エクスポート処理中かどうか。
    @State private var isExporting = false
    /// 復元処理中かどうか。
    @State private var isImporting = false
    /// バックアップ完了アラートの表示状態。
    @State private var showingExportSuccess = false
    /// バックアップエラーのメッセージ。
    @State private var exportError: String?
    /// バックアップエラーアラートの表示状態。
    @State private var showingExportError = false
    /// データ初期化確認アラートの表示状態。
    @State private var showingDataReset = false
    /// データ初期化完了アラートの表示状態。
    @State private var showingDataResetSuccess = false

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
                            if isExporting {
                                ProgressView()
                            }
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
                            if isImporting {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isExporting || isImporting)

                    Button(role: .destructive) {
                        showingDataReset = true
                    } label: {
                        Label("データを初期化", systemImage: "trash")
                    }
                    .accessibilityIdentifier("reset-all-data-button")
                    .disabled(isExporting || isImporting)
                }

                Section("このアプリについて") {
                    LabeledContent(
                        "バージョン",
                        value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—",
                    )
                    Link(destination: URL(string: "https://github.com/neko3cs/umalog")!) {
                        Label("ソースコード（GitHub）", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    NavigationLink(destination: LicensesView()) {
                        Label("ライセンス", systemImage: "doc.text")
                    }
                    .accessibilityIdentifier("licenses-link")
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
                    if let url = pendingImportURL {
                        performImport(from: url)
                    }
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
            .alert("データを初期化", isPresented: $showingDataReset) {
                Button("初期化", role: .destructive) { resetAllData() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("レース・馬券データをすべて削除します。競馬場・券種データは変更されません。この操作は元に戻せません。")
            }
            .alert("初期化完了", isPresented: $showingDataResetSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("レース・馬券データをすべて削除しました。")
            }
        }
    }

    /// レースデータをすべて削除する（子の出走馬・馬券はカスケード削除）。競馬場・券種マスターは保持する。
    private func resetAllData() {
        let races = (try? modelContext.fetch(FetchDescriptor<Race>())) ?? []
        races.forEach { modelContext.delete($0) }
        try? modelContext.save()
        showingDataResetSuccess = true
    }

    /// ZIP バックアップを生成し、保存先選択シートを表示する。
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

    /// ZIP バックアップからデータを復元し、結果に応じたアラートを表示する。
    /// - Parameter url: 復元する ZIP ファイルの URL。
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

/// 使用しているオープンソースパッケージのライセンス一覧画面。
struct LicensesView: View {
    /// 表示するパッケージのライセンス情報。
    struct Package: Identifiable {
        /// リスト表示用の識別子。
        let id = UUID()
        /// パッケージ名。
        let name: String
        /// バージョン。
        let version: String
        /// ライセンス種別（例: MIT）。
        let licenseType: String
        /// ライセンス全文。
        let licenseText: String
    }

    /// 表示対象のパッケージ一覧。依存を追加・更新したらここも更新する。
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
            """,
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
            """,
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
            """,
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
            """,
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

/// ライセンス全文の表示画面。
struct LicenseDetailView: View {
    /// 表示対象のパッケージ。
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

/// 競馬場マスターの追加・削除・リセットを行う管理画面。
private struct VenueManagementView: View {
    /// SwiftData のモデルコンテキスト。
    @Environment(\.modelContext) private var modelContext
    /// SwiftData から取得した全競馬場。
    @Query(sort: \Venue.sortIndex) private var venues: [Venue]

    /// 追加ダイアログの表示状態。
    @State private var showingAdd = false
    /// 追加ダイアログで入力中の競馬場名。
    @State private var newName = ""
    /// リセット確認アラートの表示状態。
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

    /// 競馬場マスターをすべて削除し、プリセットを再投入する。レースの競馬場参照は nil になる。
    private func resetVenues() {
        venues.forEach { modelContext.delete($0) }
        for preset in venuePresets {
            modelContext.insert(Venue(name: preset.name, isPreset: true, sortIndex: preset.sortIndex))
        }
    }
}

/// 券種マスターの追加・削除・リセットを行う管理画面。
private struct TicketTypeManagementView: View {
    /// SwiftData のモデルコンテキスト。
    @Environment(\.modelContext) private var modelContext
    /// SwiftData から取得した全券種。
    @Query(sort: \TicketType.sortIndex) private var ticketTypes: [TicketType]

    /// 追加ダイアログの表示状態。
    @State private var showingAdd = false
    /// 追加ダイアログで入力中の券種名。
    @State private var newName = ""
    /// リセット確認アラートの表示状態。
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

    /// 券種マスターをすべて削除し、プリセットを再投入する。馬券の券種参照は nil になるが券種名は保持される。
    private func resetTicketTypes() {
        ticketTypes.forEach { modelContext.delete($0) }
        for (name, index) in defaultTicketTypeNames {
            modelContext.insert(TicketType(name: name, sortIndex: index))
        }
    }
}

/// `sheet(item:)` で使うためのエクスポート URL の Identifiable ラッパー。
private struct ExportURL: Identifiable {
    /// シート表示用の識別子。
    let id = UUID()
    /// エクスポートした ZIP の URL。
    let url: URL
}

/// 復元用 ZIP を選択するドキュメントピッカーの SwiftUI ラッパー。
struct ImportDocumentPicker: UIViewControllerRepresentable {
    /// ファイル選択時に呼ばれるハンドラ。アプリから読める一時コピーの URL を受け取る。
    let onPicked: (URL) -> Void

    /// デリゲートを仲介するコーディネーターを生成する。
    /// - Returns: コーディネーター。
    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked)
    }

    /// ZIP のみ選択可能なドキュメントピッカーを生成する。
    /// - Parameter context: Representable のコンテキスト。
    /// - Returns: 設定済みのピッカー。
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.zip])
        picker.delegate = context.coordinator
        return picker
    }

    /// 更新処理は不要。
    func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {}

    /// `UIDocumentPickerDelegate` を実装するコーディネーター。
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        /// ファイル選択時に呼ばれるハンドラ。
        let onPicked: (URL) -> Void

        /// コーディネーターを生成する。
        /// - Parameter onPicked: ファイル選択時のハンドラ。
        init(onPicked: @escaping (URL) -> Void) {
            self.onPicked = onPicked
        }

        /// 選択されたファイルをアプリの一時ディレクトリへコピーしてハンドラに渡す。
        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

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

/// バックアップ ZIP の保存先を選択するドキュメントピッカーの SwiftUI ラッパー。
struct ExportDocumentPicker: UIViewControllerRepresentable {
    /// 保存する ZIP ファイルの URL。
    let fileURL: URL
    /// 保存完了時に呼ばれるハンドラ。
    let onSaved: () -> Void

    /// デリゲートを仲介するコーディネーターを生成する。
    /// - Returns: コーディネーター。
    func makeCoordinator() -> Coordinator {
        Coordinator(onSaved: onSaved)
    }

    /// ファイルのコピーを書き出すドキュメントピッカーを生成する。
    /// - Parameter context: Representable のコンテキスト。
    /// - Returns: 設定済みのピッカー。
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    /// 更新処理は不要。
    func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {}

    /// `UIDocumentPickerDelegate` を実装するコーディネーター。
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        /// 保存完了時に呼ばれるハンドラ。
        let onSaved: () -> Void

        /// コーディネーターを生成する。
        /// - Parameter onSaved: 保存完了時のハンドラ。
        init(onSaved: @escaping () -> Void) {
            self.onSaved = onSaved
        }

        /// 保存完了をハンドラに通知する。
        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt _: [URL]) {
            onSaved()
        }
    }
}

// swiftlint:enable line_length
