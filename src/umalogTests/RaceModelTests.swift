//
//  RaceModelTests.swift
//  umalog
//
//  Created by neko3cs on 2026/06/12.
//

import Foundation
import SwiftData
import Testing
@testable import umalog

@MainActor
struct レースモデルTest {
    let container: ModelContainer

    init() throws {
        let schema = Schema([Race.self, Bet.self, BetSelection.self, RaceEntry.self, Venue.self, TicketType.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - totalPurchase

    @Test func 馬券がnilのとき購入合計がゼロになる() {
        let race = Race(); container.mainContext.insert(race)
        race.bets = nil
        #expect(race.totalPurchase == 0)
    }

    @Test func 馬券が空のとき購入合計がゼロになる() {
        let race = Race(); container.mainContext.insert(race)
        race.bets = []
        #expect(race.totalPurchase == 0)
    }

    @Test func 馬券が1件のとき購入合計がその購入額になる() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 1000); ctx.insert(bet)
        race.bets = [bet]
        #expect(race.totalPurchase == 1000)
    }

    @Test func 複数馬券の購入合計が全購入額の合計になる() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet1 = Bet(race: race, purchaseAmount: 1000); ctx.insert(bet1)
        let bet2 = Bet(race: race, purchaseAmount: 500); ctx.insert(bet2)
        let bet3 = Bet(race: race, purchaseAmount: 200); ctx.insert(bet3)
        race.bets = [bet1, bet2, bet3]
        #expect(race.totalPurchase == 1700)
    }

    // MARK: - totalPayout

    @Test func 馬券がnilのとき払戻合計がゼロになる() {
        let race = Race(); container.mainContext.insert(race)
        race.bets = nil
        #expect(race.totalPayout == 0)
    }

    @Test func 全馬券が未精算のとき払戻合計がゼロになる() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet1 = Bet(race: race, purchaseAmount: 1000, payoutAmount: 0); ctx.insert(bet1)
        let bet2 = Bet(race: race, purchaseAmount: 500, payoutAmount: 0); ctx.insert(bet2)
        race.bets = [bet1, bet2]
        #expect(race.totalPayout == 0)
    }

    @Test func 一部精算済みの場合に払戻合計が精算済み馬券の払戻額の合計になる() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet1 = Bet(race: race, purchaseAmount: 1000, payoutAmount: 2500); ctx.insert(bet1)
        let bet2 = Bet(race: race, purchaseAmount: 500, payoutAmount: 0); ctx.insert(bet2)
        race.bets = [bet1, bet2]
        #expect(race.totalPayout == 2500)
    }

    @Test func 全馬券が精算済みの場合に払戻合計が全払戻額の合計になる() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet1 = Bet(race: race, purchaseAmount: 1000, payoutAmount: 2000); ctx.insert(bet1)
        let bet2 = Bet(race: race, purchaseAmount: 500, payoutAmount: 800); ctx.insert(bet2)
        race.bets = [bet1, bet2]
        #expect(race.totalPayout == 2800)
    }

    // MARK: - balance

    @Test func 馬券がnilのとき収支がゼロになる() {
        let race = Race(); container.mainContext.insert(race)
        race.bets = nil
        #expect(race.balance == 0)
    }

    @Test func 馬券がないとき収支がゼロになる() {
        let race = Race(); container.mainContext.insert(race)
        race.bets = []
        #expect(race.balance == 0)
    }

    @Test func 払戻が購入より多い場合に収支がプラスになる() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 1000, payoutAmount: 3000); ctx.insert(bet)
        race.bets = [bet]
        #expect(race.balance == 2000)
    }

    @Test func 払戻がゼロの場合に収支がマイナスになる() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 1000, payoutAmount: 0); ctx.insert(bet)
        race.bets = [bet]
        #expect(race.balance == -1000)
    }

    @Test func 払戻と購入が同額の場合に収支がゼロになる() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 1000, payoutAmount: 1000); ctx.insert(bet)
        race.bets = [bet]
        #expect(race.balance == 0)
    }

    @Test func 収支が払戻合計から購入合計を引いた値に等しい() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet1 = Bet(race: race, purchaseAmount: 500, payoutAmount: 1200); ctx.insert(bet1)
        let bet2 = Bet(race: race, purchaseAmount: 300, payoutAmount: 0); ctx.insert(bet2)
        race.bets = [bet1, bet2]
        #expect(race.balance == race.totalPayout - race.totalPurchase)
    }

    // MARK: - returnRate

    @Test func 馬券がnilのとき回収率がnilになる() {
        let race = Race(); container.mainContext.insert(race)
        race.bets = nil
        #expect(race.returnRate == nil)
    }

    @Test func 馬券が空のとき回収率がnilになる() {
        let race = Race(); container.mainContext.insert(race)
        race.bets = []
        #expect(race.returnRate == nil)
    }

    @Test func 購入合計がゼロのとき回収率がnilになる() {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 0, payoutAmount: 0); ctx.insert(bet)
        race.bets = [bet]
        #expect(race.returnRate == nil)
    }

    @Test func 利益がある場合に回収率が1より大きくなる() throws {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 1000, payoutAmount: 2000); ctx.insert(bet)
        race.bets = [bet]
        let rate = try #require(race.returnRate)
        #expect(rate > 1.0)
        #expect(rate == 2.0)
    }

    @Test func 損失がある場合に回収率が1より小さくなる() throws {
        let ctx = container.mainContext
        let race = Race(); ctx.insert(race)
        let bet = Bet(race: race, purchaseAmount: 1000, payoutAmount: 400); ctx.insert(bet)
        race.bets = [bet]
        let rate = try #require(race.returnRate)
        #expect(rate < 1.0)
        #expect(rate == 0.4)
    }

    // MARK: - finishPosition

    @Test func 着順が未設定のとき有効な馬番でfinishPositionがnilになる() {
        let race = Race()
        container.mainContext.insert(race)
        #expect(race.finishPosition(forHorseNumber: 1) == nil)
        #expect(race.finishPosition(forHorseNumber: 18) == nil)
    }

    @Test func 馬番が1着馬の場合に着順が1になる() {
        let race = Race(firstPlaceHorseNumber: 5, secondPlaceHorseNumber: 3, thirdPlaceHorseNumber: 8)
        container.mainContext.insert(race)
        #expect(race.finishPosition(forHorseNumber: 5) == 1)
    }

    @Test func 馬番が2着馬の場合に着順が2になる() {
        let race = Race(firstPlaceHorseNumber: 5, secondPlaceHorseNumber: 3, thirdPlaceHorseNumber: 8)
        container.mainContext.insert(race)
        #expect(race.finishPosition(forHorseNumber: 3) == 2)
    }

    @Test func 馬番が3着馬の場合に着順が3になる() {
        let race = Race(firstPlaceHorseNumber: 5, secondPlaceHorseNumber: 3, thirdPlaceHorseNumber: 8)
        container.mainContext.insert(race)
        #expect(race.finishPosition(forHorseNumber: 8) == 3)
    }

    @Test func 馬番が入賞外の場合に着順がnilになる() {
        let race = Race(firstPlaceHorseNumber: 5, secondPlaceHorseNumber: 3, thirdPlaceHorseNumber: 8)
        container.mainContext.insert(race)
        #expect(race.finishPosition(forHorseNumber: 1) == nil)
    }

    // MARK: - Property-Based Tests

    @Test func 任意の馬券群で収支が常に払戻と購入の差額の総和に等しい() {
        let ctx = container.mainContext
        for _ in 0 ..< 500 {
            let race = Race(); ctx.insert(race)
            let betCount = Int.random(in: 1 ... 10)
            var bets: [Bet] = []
            var expected = 0
            for _ in 0 ..< betCount {
                let purchase = Int.random(in: 100 ... 10000)
                let payout = Int.random(in: 0 ... 50000)
                let bet = Bet(race: race, purchaseAmount: purchase, payoutAmount: payout)
                ctx.insert(bet)
                bets.append(bet)
                expected += payout - purchase
            }
            race.bets = bets
            #expect(race.balance == expected)
        }
    }

    @Test func 収支が常に払戻合計から購入合計を引いた値に等しい() {
        let ctx = container.mainContext
        for _ in 0 ..< 500 {
            let race = Race(); ctx.insert(race)
            let betCount = Int.random(in: 1 ... 8)
            var bets: [Bet] = []
            for _ in 0 ..< betCount {
                let purchase = Int.random(in: 100 ... 5000)
                let payout = Int.random(in: 0 ... 20000)
                let bet = Bet(race: race, purchaseAmount: purchase, payoutAmount: payout)
                ctx.insert(bet)
                bets.append(bet)
            }
            race.bets = bets
            #expect(race.balance == race.totalPayout - race.totalPurchase)
        }
    }

    @Test func 払戻と購入が同額のとき回収率が常に1になる() {
        let ctx = container.mainContext
        for _ in 0 ..< 200 {
            let amount = Int.random(in: 100 ... 100_000)
            let race = Race(); ctx.insert(race)
            let bet = Bet(race: race, purchaseAmount: amount, payoutAmount: amount)
            ctx.insert(bet)
            race.bets = [bet]
            #expect(race.returnRate == 1.0)
        }
    }
}
