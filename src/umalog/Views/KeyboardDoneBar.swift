//
//  KeyboardDoneBar.swift
//  umalog
//
//  Created by neko3cs on 2026/11/01.
//

import SwiftUI
import UIKit

/// テキスト入力中だけ、画面下端（キーボードのすぐ上）に「完了」ボタンを出す。
///
/// 数字キーボードには改行キーが無く、ほかに閉じる手段が無いために使う。
/// - Note: `ToolbarItemGroup(placement: .keyboard)` は iOS 27 で表示されず、
///   `Invalid frame dimension` の実行時警告も出すため使わない（#70）。
///   表示の切り替えはキーボードの表示通知ではなく入力の開始・終了で行う。
///   ハードウェアキーボード接続中はソフトウェアキーボードが出ず、表示通知も来ないため。
///   フォームの入力欄は 1 行の `TextField`（`UITextField`）だけなので、その通知だけを見る。
struct KeyboardDoneBar: ViewModifier {
    /// テキスト入力中かどうか。
    @State private var isEditing = false

    /// - Parameter content: 「完了」ボタンを重ねるフォーム。
    /// - Returns: テキスト入力中は下端に「完了」ボタンを足したビュー。
    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                if isEditing {
                    HStack {
                        Spacer()
                        Button("完了") {
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.resignFirstResponder),
                                to: nil, from: nil, for: nil,
                            )
                        }
                        .accessibilityIdentifier("keyboard-done")
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.bar)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { _ in
                isEditing = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidEndEditingNotification)) { _ in
                isEditing = false
            }
    }
}

extension View {
    /// テキスト入力中だけ、キーボードのすぐ上に「完了」ボタンを出す。
    /// - Returns: ``KeyboardDoneBar`` を適用したビュー。
    func keyboardDoneBar() -> some View {
        modifier(KeyboardDoneBar())
    }
}
