//
//  umalogApp.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import SwiftUI

@main
struct umalogApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // ウィンドウ管理は SceneDelegate（ShakeWindow）に委譲するため、ここは空
        WindowGroup { EmptyView() }
    }
}
