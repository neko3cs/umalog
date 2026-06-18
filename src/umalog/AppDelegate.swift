//
//  AppDelegate.swift
//  umalog
//
//  Created by neko3cs on 2026/06/18.
//

import SwiftData
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    private(set) static var shared: AppDelegate!

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

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func application(
        _: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options _: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }

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

    @MainActor
    private func migrateToSelectionModelIfNeeded() async {
        let context = modelContainer.mainContext
        let bets = (try? context.fetch(FetchDescriptor<Bet>())) ?? []
        var needsSave = false
        for bet in bets {
            guard (bet.selections ?? []).isEmpty, !bet.selection.isEmpty else { continue }
            let count = max(1, Bet.combinationCount(
                selection: bet.selection,
                ticketTypeName: bet.displayTicketTypeName
            ))
            context.insert(BetSelection(
                bet: bet,
                ticketType: bet.ticketType,
                ticketTypeName: bet.ticketTypeName,
                selection: bet.selection,
                unitPrice: bet.unitPrice,
                combinationCount: count,
                sortIndex: 0
            ))
            needsSave = true
        }
        if needsSave { try? context.save() }
    }
}
