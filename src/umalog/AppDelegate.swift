//
//  AppDelegate.swift
//  umalog
//
//  Created by neko3cs on 2026/06/18.
//

import SwiftData
import UIKit

/// SwiftData コンテナの生成・初期データ投入・シーン設定を担う AppDelegate。
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// 共有インスタンス。`umalogApp` からコンテナ参照に使う。
    private(set) static var shared: AppDelegate!

    /// アプリ全体で共有する SwiftData コンテナ。テスト実行時はインメモリストアに切り替える。
    let modelContainer: ModelContainer = {
        let schema = Schema([
            Venue.self,
            TicketType.self,
            Race.self,
            RaceEntry.self,
            Bet.self,
            BetSelection.self,
        ])
        let isUITesting = CommandLine.arguments.contains("--UITesting")
        let isUnitTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            && !CommandLine.arguments.contains("--UITesting")
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isUITesting || isUnitTesting)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    /// 生成と同時に共有インスタンスを登録する。
    override init() {
        super.init()
        AppDelegate.shared = self
    }

    /// シーン接続時に `SceneDelegate` を割り当てる。
    /// - Parameter connectingSceneSession: 接続されるシーンセッション。
    /// - Returns: `SceneDelegate` を指定したシーン設定。
    func application(
        _: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options _: UIScene.ConnectionOptions,
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }

    /// 競馬場・券種マスターが空なら初期プリセットを投入し、旧データモデルの移行を行う。
    @MainActor
    func seedInitialDataIfNeeded() async {
        let context = modelContainer.mainContext
        let venueCount = (try? context.fetchCount(FetchDescriptor<Venue>())) ?? 0
        if venueCount == 0 {
            for preset in venuePresets {
                context.insert(Venue(name: preset.name, isPreset: true, sortIndex: preset.sortIndex))
            }
            for (name, index) in defaultTicketTypeNames {
                context.insert(TicketType(name: name, sortIndex: index))
            }
        }
        await migrateToSelectionModelIfNeeded()
    }

    /// 買い目（`BetSelection`）を持たない旧形式の馬券に、レガシーフィールドから買い目を生成して移行する。
    @MainActor
    private func migrateToSelectionModelIfNeeded() async {
        let context = modelContainer.mainContext
        let bets = (try? context.fetch(FetchDescriptor<Bet>())) ?? []
        var needsSave = false
        for bet in bets {
            guard (bet.selections ?? []).isEmpty, !bet.selection.isEmpty else { continue }
            let count = max(1, Bet.combinationCount(
                selection: bet.selection,
                ticketTypeName: bet.displayTicketTypeName,
            ))
            context.insert(BetSelection(
                bet: bet,
                ticketType: bet.ticketType,
                ticketTypeName: bet.ticketTypeName,
                selection: bet.selection,
                unitPrice: bet.unitPrice,
                combinationCount: count,
                sortIndex: 0,
            ))
            needsSave = true
        }
        if needsSave {
            try? context.save()
        }
    }
}
