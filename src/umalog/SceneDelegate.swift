//
//  SceneDelegate.swift
//  umalog
//
//  Created by neko3cs on 2026/06/18.
//

import SwiftData
import SwiftUI
import UIKit

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo _: UISceneSession,
        options _: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = ShakeWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(
            rootView: ContentView().modelContainer(AppDelegate.shared.modelContainer)
        )
        window.makeKeyAndVisible()
        self.window = window
    }

    func sceneDidBecomeActive(_: UIScene) {
        Task { @MainActor in
            await AppDelegate.shared.seedInitialDataIfNeeded()
        }
    }
}
