//
//  SceneDelegate.swift
//  umalog
//
//  Created by neko3cs on 2026/06/18.
//

import UIKit

/// ウィンドウ管理は SwiftUI の WindowGroup に委譲し、
/// ここではシードデータ初期化とシーン状態保存の無効化のみ担う
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func sceneDidBecomeActive(_: UIScene) {
        Task { @MainActor in
            await AppDelegate.shared.seedInitialDataIfNeeded()
        }
    }

    func stateRestorationActivity(for _: UIScene) -> NSUserActivity? {
        return nil
    }
}
