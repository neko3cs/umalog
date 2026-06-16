//
//  ContentView.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.undoManager) private var undoManager
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            RaceListView()
                .tabItem {
                    Label("レース", systemImage: "list.bullet.clipboard")
                }
            BalanceSummaryView()
                .tabItem {
                    Label("収支", systemImage: "yensign.circle")
                }
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gear")
                }
        }
        .onAppear {
            modelContext.undoManager = undoManager
        }
        .onChange(of: undoManager) { _, newManager in
            modelContext.undoManager = newManager
        }
    }
}
