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

class ShakeWindow: UIWindow {
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
            return
        }
        super.motionEnded(motion, with: event)
    }
}
