//
//  ShakeWindow.swift
//  umalog
//
//  Created by neko3cs on 2026/06/18.
//

import UIKit

extension Notification.Name {
    /// デバイスがシェイクされたときに `UIWindow` から送出される通知。
    static let deviceDidShake = Notification.Name("deviceDidShake")
}

/// UIWindow 全体に適用することで SwiftUI 管理のウィンドウでもシェイクを検出できる。
/// SwiftUI にはシェイク検出 API がないため、UIKit のモーションイベントを通知に変換する。
extension UIWindow {
    /// シェイクモーション終了時に `deviceDidShake` 通知を送出する。
    /// - Parameters:
    ///   - motion: 終了したモーションの種別。
    ///   - event: モーションイベント。
    override open func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}
