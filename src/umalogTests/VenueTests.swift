//
//  VenueTests.swift
//  umalogTests
//
//  Created by neko3cs on 2026/10/28.
//

import Foundation
import SwiftData
import Testing
@testable import umalog

@MainActor
struct 競馬場Test {
    let container: ModelContainer

    init() throws {
        container = try Self.makeContainer()
    }

    /// インメモリの SwiftData コンテナを生成する。
    /// - Returns: 全モデルを登録したコンテナ。
    private static func makeContainer() throws -> ModelContainer {
        let schema = Schema([Race.self, Bet.self, BetSelection.self, RaceEntry.self, Venue.self, TicketType.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// 競馬場マスターを表示順に取得する。
    /// - Parameter context: 取得元のモデルコンテキスト。
    /// - Returns: 表示順に並べた競馬場。
    private func fetchVenues(in context: ModelContext) throws -> [Venue] {
        try context.fetch(FetchDescriptor<Venue>(sortBy: [SortDescriptor(\.sortIndex)]))
    }

    // MARK: - 競馬場の一覧

    @Test func `中央 10 場と地方 15 場と海外 24 場を扱う`() {
        #expect(venuePresets.count(where: { $0.category == .central }) == 10)
        #expect(venuePresets.count(where: { $0.category == .local }) == 15)
        #expect(venuePresets.count(where: { $0.category == .overseas }) == 24)
    }

    @Test func 競馬場名に重複がない() {
        #expect(Set(venuePresets.map(\.name)).count == venuePresets.count)
    }

    @Test(arguments: [
        ("東京", RaceCategory.central), ("帯広", .local), ("大井", .local),
        ("パリロンシャン", .overseas), ("シャティン", .overseas), ("メイダン", .overseas),
    ])
    func 競馬場ごとに区分が決まっている(name: String, category: RaceCategory) {
        #expect(venuePresets.first { $0.name == name }?.category == category)
    }

    // MARK: - プリセットの投入

    @Test func `競馬場マスターが空なら全競馬場が 一 覧の順に区分付きで追加される`() throws {
        let ctx = container.mainContext
        let inserted = Venue.insertMissingPresets(into: ctx)
        #expect(inserted)
        let venues = try fetchVenues(in: ctx)
        #expect(venues.map(\.name) == venuePresets.map(\.name))
        #expect(venues.map(\.category) == venuePresets.map(\.category.rawValue))
        #expect(venues.map(\.sortIndex) == Array(0 ..< venuePresets.count))
    }

    @Test func 既存ユーザーには足りない競馬場だけが既存の並び順の後ろに追加される() throws {
        let ctx = container.mainContext
        // 旧バージョンのプリセット 24 場（中央 10 場 + 地方 14 場）。区分を持たなかったため既定値の中央になっている
        let oldNames = venuePresets.prefix(24).map(\.name)
        for (index, name) in oldNames.enumerated() {
            ctx.insert(Venue(name: name, sortIndex: index))
        }
        let inserted = Venue.insertMissingPresets(into: ctx)
        #expect(inserted)
        let venues = try fetchVenues(in: ctx)
        #expect(venues.map(\.name) == venuePresets.map(\.name))
        #expect(venues.map(\.sortIndex) == Array(0 ..< venuePresets.count))
        #expect(venues[24].name == "帯広")
    }

    @Test func 既存の競馬場の並び順とレースとの紐づきは変わらず区分だけが揃う() throws {
        let ctx = container.mainContext
        let oi = Venue(name: "大井", sortIndex: 0); ctx.insert(oi)
        let tokyo = Venue(name: "東京", sortIndex: 1); ctx.insert(tokyo)
        let race = Race(venue: oi, raceName: "東京大賞典", category: "local"); ctx.insert(race)
        try ctx.save()
        let oiID = oi.persistentModelID

        Venue.insertMissingPresets(into: ctx)

        let venues = try fetchVenues(in: ctx)
        #expect(venues.prefix(2).map(\.name) == ["大井", "東京"])
        #expect(venues.count(where: { $0.name == "大井" }) == 1)
        #expect(oi.category == "local")
        #expect(tokyo.category == "central")
        #expect(race.venue?.persistentModelID == oiID)
        #expect(venues.dropFirst(2).map(\.sortIndex) == Array(2 ..< venuePresets.count))
    }

    @Test func 全競馬場がそろっていれば何も追加しない() throws {
        let ctx = container.mainContext
        Venue.insertMissingPresets(into: ctx)
        let inserted = Venue.insertMissingPresets(into: ctx)
        #expect(inserted == false)
        #expect(try fetchVenues(in: ctx).count == venuePresets.count)
    }

    // MARK: - 区分

    @Test func 区分が未知のレースは地方として扱われる() {
        let race = Race(category: "unknown")
        container.mainContext.insert(race)
        #expect(race.categoryValue == .local)
    }

    @Test func 海外のレースは区分が海外と表示される() {
        let race = Race(category: "overseas")
        container.mainContext.insert(race)
        #expect(race.categoryValue.displayName == "海外")
    }

    // MARK: - ZIP バックアップ / 復元

    @Test func 海外競馬場のレースはzip復元後も同名の競馬場に紐づき区分が海外のまま復元される() throws {
        let exportCtx = container.mainContext
        Venue.insertMissingPresets(into: exportCtx)
        let longchamp = try #require(try fetchVenues(in: exportCtx).first { $0.name == "パリロンシャン" })
        let race = Race(
            date: Date(timeIntervalSince1970: 1_791_000_000),
            venue: longchamp,
            raceNumber: 4,
            raceName: "凱旋門賞",
            category: longchamp.category,
        )
        exportCtx.insert(race)

        let url = try ZipExporter.export(races: [race])
        defer { try? FileManager.default.removeItem(at: url) }

        let importContainer = try Self.makeContainer()
        let importCtx = importContainer.mainContext
        Venue.insertMissingPresets(into: importCtx)
        try ZipImporter.importZip(from: url, context: importCtx)

        let restored = try #require(try importCtx.fetch(FetchDescriptor<Race>()).first)
        #expect(restored.raceName == "凱旋門賞")
        #expect(restored.category == "overseas")
        let restoredVenue = try #require(restored.venue)
        #expect(restoredVenue.name == "パリロンシャン")
        #expect(restoredVenue.modelContext === importCtx)
    }
}
