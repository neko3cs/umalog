//
//  SceneDelegate.swift
//  umalog
//
//  Created by neko3cs on 2026/06/18.
//

import UIKit

/// ウィンドウ管理は SwiftUI の WindowGroup に委譲し、
/// ここではシードデータ初期化とシーン状態保存の無効化のみ担う。
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    /// シーンがアクティブになったタイミングで初期データ投入とデータ移行を実行する。
    func sceneDidBecomeActive(_: UIScene) {
        Task { @MainActor in
            await AppDelegate.shared.seedInitialDataIfNeeded()
        }
    }

    /// シーン状態の保存を無効化する。
    /// - Returns: 常に nil（状態復元しない）。
    func stateRestorationActivity(for _: UIScene) -> NSUserActivity? {
        nil
    }
}
