//
//  Date+Display.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import Foundation

extension Date {
    /// 日本語ロケールの短縮日付文字列（例: `2026/06/13`）。リストや詳細画面の日付表示に使う。
    var japaneseShortDateString: String {
        formatted(
            Date.FormatStyle()
                .locale(Locale(identifier: "ja_JP"))
                .year(.defaultDigits)
                .month(.twoDigits)
                .day(.twoDigits),
        )
    }
}
