//
//  VenuePresets.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import Foundation

struct VenuePresetData {
    let name: String
    let sortIndex: Int
}

let venuePresets: [VenuePresetData] = [
    // 中央（JRA）
    .init(name: "札幌", sortIndex: 0),
    .init(name: "函館", sortIndex: 1),
    .init(name: "福島", sortIndex: 2),
    .init(name: "新潟", sortIndex: 3),
    .init(name: "東京", sortIndex: 4),
    .init(name: "中山", sortIndex: 5),
    .init(name: "中京", sortIndex: 6),
    .init(name: "京都", sortIndex: 7),
    .init(name: "阪神", sortIndex: 8),
    .init(name: "小倉", sortIndex: 9),
    // 地方（NAR）
    .init(name: "大井", sortIndex: 10),
    .init(name: "船橋", sortIndex: 11),
    .init(name: "川崎", sortIndex: 12),
    .init(name: "浦和", sortIndex: 13),
    .init(name: "園田", sortIndex: 14),
    .init(name: "姫路", sortIndex: 15),
    .init(name: "門別", sortIndex: 16),
    .init(name: "名古屋", sortIndex: 17),
    .init(name: "笠松", sortIndex: 18),
    .init(name: "高知", sortIndex: 19),
    .init(name: "佐賀", sortIndex: 20),
    .init(name: "金沢", sortIndex: 21),
    .init(name: "盛岡", sortIndex: 22),
    .init(name: "水沢", sortIndex: 23),
]

let defaultTicketTypeNames: [(name: String, sortIndex: Int)] = [
    ("単勝", 0), ("複勝", 1), ("枠連", 2), ("馬連", 3),
    ("ワイド", 4), ("馬単", 5), ("三連複", 6), ("三連単", 7),
]
