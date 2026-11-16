//
//  DataReset.swift
//  umalog
//
//  Created by neko3cs on 2026/11/17.
//

import Foundation
import SwiftData

/// データの初期化。レースの記録をすべて消す。
enum DataReset {
    /// レースをすべて削除して保存する（出走馬・馬券・買い目はカスケード削除）。競馬場・券種マスターは残す。
    /// - Parameters:
    ///   - context: 削除対象の ModelContext。
    ///   - undoManager: 成功したら履歴を消す UndoManager。
    /// - Throws: レースの取得か保存のエラー。失敗したときは履歴を消さない。
    static func deleteAllRaces(in context: ModelContext, undoManager: UndoManager?) throws {
        try context.fetch(FetchDescriptor<Race>()).forEach { context.delete($0) }
        try context.save()
        // 初期化より前の削除を取り消すと、空にしたデータに古い記録が戻る
        undoManager?.removeAllActions()
    }
}
