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

// MARK: - JRA 騎手プリセット（オートコンプリート用）

let jockeyPresets: [String] = [
    "武豊", "川田将雅", "C.ルメール", "横山武史", "戸崎圭太",
    "田辺裕信", "池添謙一", "北村友一", "横山典弘", "松山弘平",
    "三浦皇成", "内田博幸", "浜中俊", "岩田康誠", "岩田望来",
    "坂井瑠星", "西村淳也", "横山和生", "菅原明良", "鮫島克駿",
    "国分恭介", "国分優作", "M.デムーロ", "北村宏司", "丹内祐次",
    "津村明秀", "ヒューイットソン", "石橋脩", "幸英明", "大野拓弥",
    "藤岡佑介", "藤岡康太", "和田竜二", "酒井学", "勝浦正樹",
    "小崎綾也", "団野大成", "永野猛蔵", "今村聖奈", "古川奈穂",
]

// MARK: - JRA 調教師プリセット（オートコンプリート用）

let trainerPresets: [String] = [
    "国枝栄", "矢作芳人", "池江泰寿", "友道康夫", "安田隆行",
    "藤原英昭", "杉山晴紀", "木村哲也", "中内田充正", "千田輝彦",
    "須貝尚介", "高野友和", "武幸四郎", "牧浦充徳", "福永祐一",
    "田中博康", "加藤士津八", "西村真幸", "上原博之", "萩原清",
    "堀宣行", "音無秀孝", "蛯名正義", "高木登", "大久保龍志",
    "北出成人", "中竹和也", "斉藤崇史", "鈴木伸尋", "森秀行",
    "矢作昇平", "辻野泰之", "小手川準", "新谷功一", "尾関知人",
    "黒岩陽一", "宮田敬介", "鹿戸雄一", "畠山吉宏", "栗田徹",
]
