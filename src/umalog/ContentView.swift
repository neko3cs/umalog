//
//  ContentView.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import SwiftUI

/// ルートのタブビュー。シェイクによる取り消し（Undo）のハンドリングも担う。
struct ContentView: View {
    /// ウィンドウの UndoManager。削除操作の取り消しに使う。
    @Environment(\.undoManager) private var undoManager
    /// 取り消し確認アラートの表示状態。
    @State private var showUndoAlert = false
    /// アラートで「取り消す」が選択され、実行待ちであることを示すフラグ。
    @State private var pendingUndo = false

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
        .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
            if undoManager?.canUndo == true {
                showUndoAlert = true
            }
        }
        .alert("取り消し", isPresented: $showUndoAlert) {
            Button("取り消す", role: .destructive) {
                pendingUndo = true
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            let name = undoManager?.undoActionName ?? ""
            Text(name.isEmpty ? "最後の操作を取り消しますか？" : "\(name)を取り消しますか？")
        }
        // アラートのdismissアニメーション完了後にundoを実行する。
        // アニメーション中にListを更新するとUICollectionViewの差分計算が崩れるため。
        .onChange(of: showUndoAlert) { _, isShowing in
            guard !isShowing, pendingUndo else { return }
            pendingUndo = false
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                undoManager?.undo()
            }
        }
    }
}
