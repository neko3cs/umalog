//
//  umalogTests.swift
//  umalogTests
//
//  Created by neko3cs on 2026/06/11.
//

import Testing
@testable import umalog

// テストスイートは各ファイルに分割されています:
//
// - RaceModelTests.swift    : Race モデルの収支計算ロジック
// - BetModelTests.swift     : Bet モデルの収支・券種名ロジック
// - RaceEntryModelTests.swift: RaceEntry モデルの予想印変換ロジック
// - PredictionMarkTests.swift: PredictionMark enum の rawValue・Codable
// - CSVExporterTests.swift  : CSV エクスポートのフォーマット・エスケープ
