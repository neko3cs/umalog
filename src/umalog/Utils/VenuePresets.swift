//
//  VenuePresets.swift
//  umalog
//
//  Created by neko3cs on 2026/06/11.
//

import Foundation

/// アプリが扱う競馬場の定義。
struct VenuePresetData {
    /// 競馬場名。
    let name: String
    /// 区分（`RaceCategory`）。この競馬場を選んだレースの区分になる。
    let category: RaceCategory
}

/// アプリが扱う競馬場の一覧（中央 10 場・地方 15 場・海外 24 場）。レース入力で選べるのはこの競馬場だけ。
/// - Note: 既存ユーザーには起動時に足りない競馬場だけを末尾へ追加するため、既存の並び順を変えないよう新しい競馬場は末尾に足す。
let venuePresets: [VenuePresetData] = [
    // 中央（JRA）
    .init(name: "札幌", category: .central),
    .init(name: "函館", category: .central),
    .init(name: "福島", category: .central),
    .init(name: "新潟", category: .central),
    .init(name: "東京", category: .central),
    .init(name: "中山", category: .central),
    .init(name: "中京", category: .central),
    .init(name: "京都", category: .central),
    .init(name: "阪神", category: .central),
    .init(name: "小倉", category: .central),
    // 地方（NAR）
    .init(name: "大井", category: .local),
    .init(name: "船橋", category: .local),
    .init(name: "川崎", category: .local),
    .init(name: "浦和", category: .local),
    .init(name: "園田", category: .local),
    .init(name: "姫路", category: .local),
    .init(name: "門別", category: .local),
    .init(name: "名古屋", category: .local),
    .init(name: "笠松", category: .local),
    .init(name: "高知", category: .local),
    .init(name: "佐賀", category: .local),
    .init(name: "金沢", category: .local),
    .init(name: "盛岡", category: .local),
    .init(name: "水沢", category: .local),
    .init(name: "帯広", category: .local),
    // 海外
    // フランス
    .init(name: "パリロンシャン", category: .overseas),
    .init(name: "シャンティイ", category: .overseas),
    .init(name: "ドーヴィル", category: .overseas),
    // イギリス
    .init(name: "アスコット", category: .overseas),
    .init(name: "エプソム", category: .overseas),
    .init(name: "ニューマーケット", category: .overseas),
    .init(name: "グッドウッド", category: .overseas),
    .init(name: "ヨーク", category: .overseas),
    // 香港
    .init(name: "シャティン", category: .overseas),
    .init(name: "ハッピーバレー", category: .overseas),
    // UAE
    .init(name: "メイダン", category: .overseas),
    // サウジアラビア
    .init(name: "キングアブドゥルアジーズ", category: .overseas),
    // アメリカ
    .init(name: "サンタアニタパーク", category: .overseas),
    .init(name: "チャーチルダウンズ", category: .overseas),
    .init(name: "デルマー", category: .overseas),
    .init(name: "キーンランド", category: .overseas),
    .init(name: "ベルモントパーク", category: .overseas),
    .init(name: "サラトガ", category: .overseas),
    // オーストラリア
    .init(name: "フレミントン", category: .overseas),
    .init(name: "ムーニーバレー", category: .overseas),
    .init(name: "コーフィールド", category: .overseas),
    .init(name: "ランドウィック", category: .overseas),
    .init(name: "ローズヒル", category: .overseas),
    // シンガポール
    .init(name: "クランジ", category: .overseas),
]

/// アプリが扱う券種の一覧。買い目入力で選べるのはこの券種だけ。
/// - Note: 既存ユーザーには起動時に足りない券種だけを末尾へ追加するため、既存の並び順を変えないよう新しい券種は末尾に足す。
let defaultTicketTypeNames: [(name: String, sortIndex: Int)] = [
    ("単勝", 0), ("複勝", 1), ("枠連", 2), ("馬連", 3),
    ("ワイド", 4), ("馬単", 5), ("三連複", 6), ("三連単", 7),
    ("枠単", 8), ("応援馬券", 9),
]

// MARK: - JRA 騎手プリセット（オートコンプリート用）

/// 騎手名入力のオートコンプリート候補に使う JRA 騎手プリセット。
let jockeyPresets: [String] = [
    // ベテラン・トップ騎手
    "武豊", "横山典弘", "幸英明", "和田竜二", "勝浦正樹",
    "田中勝春", "江田照男", "内田博幸", "北村宏司", "石橋脩",
    "藤岡佑介", "藤岡康太", "酒井学", "大野拓弥", "三浦皇成",
    "津村明秀", "丹内祐次", "嘉藤貴行", "黒岩悠",
    // 中堅・現役主力
    "川田将雅", "戸崎圭太", "横山武史", "横山和生", "田辺裕信",
    "池添謙一", "北村友一", "松山弘平", "浜中俊", "岩田康誠",
    "鮫島克駿", "国分恭介", "国分優作", "団野大成", "菅原明良",
    "西村淳也", "松若風馬", "菊沢一樹", "武藤雅", "山田敬士",
    "高倉稜", "嶋田純次", "草野太郎", "木幡巧也", "木幡育也",
    "木幡初也",
    // 外国人騎手
    "C.ルメール", "M.デムーロ", "ヒューイットソン",
    // 若手・新人（2020年以降デビュー）
    "岩田望来", "坂井瑠星", "小崎綾也", "永野猛蔵", "今村聖奈",
    "古川奈穂", "横山琉人", "富田暁", "角田大河", "角田大和",
    "西塚洸二", "佐藤翔馬", "永島まなみ", "河原田菜々", "小林勝太",
    "城戸義政", "田口貫太", "佐々木大輔", "黛弘人", "服部寿希",
    "中井裕二", "永島太郎",
]

// MARK: - JRA 調教師プリセット（オートコンプリート用）

/// 調教師名入力のオートコンプリート候補に使う JRA 調教師プリセット。
let trainerPresets: [String] = [
    // 大手・有力厩舎
    "国枝栄", "矢作芳人", "池江泰寿", "友道康夫", "安田隆行",
    "藤原英昭", "杉山晴紀", "木村哲也", "中内田充正", "千田輝彦",
    "須貝尚介", "高野友和", "武幸四郎", "牧浦充徳", "堀宣行",
    "音無秀孝", "大久保龍志", "佐々木晶三", "高木登", "萩原清",
    // 中堅厩舎
    "上原博之", "鈴木伸尋", "森秀行", "矢作昇平", "辻野泰之",
    "小手川準", "新谷功一", "尾関知人", "黒岩陽一", "宮田敬介",
    "鹿戸雄一", "畠山吉宏", "栗田徹", "斉藤崇史", "中竹和也",
    "北出成人", "高柳大輔", "高柳瑞樹", "林徹", "牧田和弥",
    "加藤和宏", "杉浦宏昭", "平田修", "笹田和秀", "北橋修二",
    "浅見秀一", "鮫島一歩", "大江原哲", "矢野英一", "茶木太樹",
    "武井亮", "飯田雄三",
    // 元騎手・転身組
    "蛯名正義", "福永祐一", "田中博康", "加藤士津八", "西村真幸",
    "武英智",
    // 若手・近年開業
    "安田翔伍", "寺島良", "久保田貴士", "武市康男",
]
