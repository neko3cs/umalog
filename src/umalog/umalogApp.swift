//
//  umalogApp.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import SwiftData
import SwiftUI

/// アプリのエントリーポイント。`AppDelegate` が生成した `ModelContainer` をルートビューに注入する。
@main
struct umalogApp: App {
    /// シーン設定とデータ初期化を担う AppDelegate。
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(AppDelegate.shared.modelContainer)
        }
    }
}
