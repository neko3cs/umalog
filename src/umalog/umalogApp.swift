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
    private var isUnitTesting: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            && !CommandLine.arguments.contains("--UITesting")
    }

    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Venue.self,
            TicketType.self,
            Race.self,
            RaceEntry.self,
            Bet.self,
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

    var body: some Scene {
        WindowGroup {
            if isUnitTesting {
                EmptyView()
            } else {
                ContentView()
                    .task { await seedInitialDataIfNeeded() }
            }
        }
        .modelContainer(sharedModelContainer)
    }

    @MainActor
    private func seedInitialDataIfNeeded() async {
        let context = sharedModelContainer.mainContext
        let venueCount = (try? context.fetchCount(FetchDescriptor<Venue>())) ?? 0
        guard venueCount == 0 else { return }

        for preset in venuePresets {
            context.insert(Venue(name: preset.name, isPreset: true, sortIndex: preset.sortIndex))
        }
        for (name, index) in defaultTicketTypeNames {
            context.insert(TicketType(name: name, sortIndex: index))
        }
    }
}
