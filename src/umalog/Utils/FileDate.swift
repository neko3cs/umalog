//
//  FileDate.swift
//  umalog
//
//  Created by neko3cs on 2026/11/08.
//

import Foundation

/// CSV・ZIP バックアップ・メモファイル名・取り込む JSON に書く日付のフォーマッター。
/// - Note: 端末の暦法に従うと、和暦では元号の年（2026 年 → `0008`）が書かれ、暦法の違う端末で取り込むと日付が狂う（#68）。
///   そのためグレゴリオ暦・`en_US_POSIX`・端末のタイムゾーンで読み書きする。行ごとに作ると重いので、書式ごとに 1 つを使い回す。
enum FileDate {
    /// CSV の date 列に使う `yyyy/MM/dd`。
    static let slashed = make("yyyy/MM/dd")
    /// メモファイル名に使う `yyyyMMdd`。
    static let compact = make("yyyyMMdd")
    /// 取り込む JSON の日付に使う `yyyy-MM-dd`。
    static let hyphenated = make("yyyy-MM-dd")

    /// 書式を設定したフォーマッターを作る。
    /// - Parameter format: `dateFormat` に設定する書式。
    /// - Returns: 暦法・ロケール・タイムゾーンを固定したフォーマッター。
    private static func make(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // 起動中に端末のタイムゾーンが変わっても追従する
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = format
        formatter.isLenient = false
        return formatter
    }
}
