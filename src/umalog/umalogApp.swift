//
//  umalogApp.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import SwiftData
import SwiftUI

@main
struct umalogApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(AppDelegate.shared.modelContainer)
        }
    }
}
