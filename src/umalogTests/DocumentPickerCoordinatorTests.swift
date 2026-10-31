//
//  DocumentPickerCoordinatorTests.swift
//  umalog
//
//  Created by neko3cs on 2026/10/31.
//

import Foundation
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import umalog

/// ファイル選択画面のコーディネーターを、選択結果を直接渡して確かめる。
/// - Note: ファイル選択画面は別プロセスで UI テストから安定して操作できないため（#43）、選んだ後の処理はここで確かめる。
@MainActor
struct ドキュメントピッカーのコーディネーターTest {
    /// テスト用の ZIP に見立てたファイルを一時ディレクトリに作る。
    /// - Parameter contents: ファイルに書き込む内容。
    /// - Returns: 作成したファイルの URL。
    private func makeSourceFile(contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("source_\(UUID().uuidString).zip")
        try Data(contents.utf8).write(to: url)
        return url
    }

    @Test
    func 復元するファイルを選ぶとアプリの作業用フォルダへ写した場所が渡される() throws {
        let source = try makeSourceFile(contents: "backup")
        defer { try? FileManager.default.removeItem(at: source) }
        var picked: URL?
        let coordinator = ImportDocumentPicker.Coordinator { picked = $0 }

        coordinator.documentPicker(
            UIDocumentPickerViewController(forOpeningContentTypes: [.zip]),
            didPickDocumentsAt: [source],
        )

        let copied = try #require(picked)
        defer { try? FileManager.default.removeItem(at: copied) }
        #expect(copied != source)
        #expect(copied.deletingLastPathComponent().standardizedFileURL
            == FileManager.default.temporaryDirectory.standardizedFileURL)
        #expect(copied.lastPathComponent.hasPrefix("import_"))
        #expect(try String(contentsOf: copied, encoding: .utf8) == "backup")
    }

    @Test
    func 写せないファイルを選ぶと元の場所がそのまま渡される() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing_\(UUID().uuidString).zip")
        var picked: URL?
        let coordinator = ImportDocumentPicker.Coordinator { picked = $0 }

        coordinator.documentPicker(
            UIDocumentPickerViewController(forOpeningContentTypes: [.zip]),
            didPickDocumentsAt: [missing],
        )

        #expect(picked == missing)
    }

    @Test
    func 復元するファイルが選ばれていなければ何も渡されない() {
        var called = false
        let coordinator = ImportDocumentPicker.Coordinator { _ in called = true }

        coordinator.documentPicker(
            UIDocumentPickerViewController(forOpeningContentTypes: [.zip]),
            didPickDocumentsAt: [],
        )

        #expect(!called)
    }

    @Test
    func 保存先を選ぶと保存完了が知らされる() throws {
        let source = try makeSourceFile(contents: "backup")
        defer { try? FileManager.default.removeItem(at: source) }
        var saved = false
        let coordinator = ExportDocumentPicker.Coordinator { saved = true }

        coordinator.documentPicker(
            UIDocumentPickerViewController(forExporting: [source], asCopy: true),
            didPickDocumentsAt: [source],
        )

        #expect(saved)
    }
}
