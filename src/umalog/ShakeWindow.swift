//
//  ShakeWindow.swift
//  umalog
//
//  Created by neko3cs on 2026/06/18.
//

import UIKit

extension Notification.Name {
    static let deviceDidShake = Notification.Name("deviceDidShake")
}

/// UIWindow 全体に適用することで SwiftUI 管理のウィンドウでもシェイクを検出できる
extension UIWindow {
    override open func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}
