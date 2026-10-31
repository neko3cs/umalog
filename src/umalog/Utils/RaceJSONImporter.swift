//
//  RaceJSONImporter.swift
//  umalog
//
//  Created by neko3cs on 2026/10/28.
//

import Foundation
import SwiftData

// MARK: - Schema

/// 取り込む JSON のルート（`schemaVersion` 1）。省略・`null` を許さないため、全プロパティを非オプショナルにしている。
struct RaceImportDocument: Decodable {
    /// スキーマのバージョン。1 だけを受け付ける。
    let schemaVersion: Int
    /// レース情報。
    let race: RaceImportRace
    /// 出走馬の一覧。再取り込み時は、ここに無い馬番の出走馬を削除する。
    let entries: [RaceImportEntry]
}

/// 取り込む JSON のレース部分。
struct RaceImportRace: Decodable {
    /// 開催日（`yyyy-MM-dd`）。
    let date: String
    /// 競馬場名。`venuePresets` にある名前だけを受け付ける。
    let venue: String
    /// レース番号（1〜12）。
    let raceNumber: Int
    /// レース名。空文字も可。
    let raceName: String
    /// 距離（メートル）。
    let distance: Int
    /// トラック種別（"turf" / "dirt"）。
    let trackType: String
    /// 馬場状態（良・稍重・重・不良）。
    let trackCondition: String
    /// グレード（`RaceGrade` の rawValue。空文字は未選択）。
    let grade: String
    /// 1 着の馬番。0 は未確定。
    let firstPlaceHorseNumber: Int
    /// 2 着の馬番。0 は未確定。
    let secondPlaceHorseNumber: Int
    /// 3 着の馬番。0 は未確定。
    let thirdPlaceHorseNumber: Int
}

/// 取り込む JSON の出走馬 1 頭分。
struct RaceImportEntry: Decodable {
    /// 馬番（1 以上）。
    let horseNumber: Int
    /// 馬名。空文字は不可。
    let horseName: String
    /// 騎手名。空文字も可。
    let jockeyName: String
    /// 調教師名。空文字も可。
    let trainerName: String
    /// 予想印（`PredictionMark` の rawValue）。空文字は印なし。
    let mark: String
}

// MARK: - Validated Data

/// 検証を通過した取り込みデータ。
struct RaceImportData {
    /// 開催日（その日の 0 時）。
    let date: Date
    /// 競馬場名。
    let venueName: String
    /// レース番号。
    let raceNumber: Int
    /// レース名。
    let raceName: String
    /// 距離（メートル）。
    let distance: Int
    /// トラック種別（"turf" / "dirt"）。
    let trackType: String
    /// 馬場状態。
    let trackCondition: String
    /// グレード。
    let grade: RaceGrade
    /// 1 着の馬番。0 は未確定。
    let firstPlaceHorseNumber: Int
    /// 2 着の馬番。0 は未確定。
    let secondPlaceHorseNumber: Int
    /// 3 着の馬番。0 は未確定。
    let thirdPlaceHorseNumber: Int
    /// 出走馬。
    let entries: [Entry]

    /// 検証を通過した出走馬 1 頭分。
    struct Entry {
        /// 馬番。
        let horseNumber: Int
        /// 馬名。
        let horseName: String
        /// 騎手名。
        let jockeyName: String
        /// 調教師名。
        let trainerName: String
        /// 予想印。印なしは nil。
        let mark: PredictionMark?
    }
}

// MARK: - Error

/// 取り込みを中止した原因の 1 件。
/// - Note: `RaceImportError` は `Error` として nonisolated なので、その `Equatable` から使えるよう `nonisolated` にしている。
nonisolated struct RaceImportIssue: Equatable {
    /// 原因のフィールドのパス（例: `entries[2].mark`）。JSON 全体の問題は `(JSON)`。
    let path: String
    /// 原因の説明。
    let message: String
}

/// 取り込みを中止したときのエラー。原因をすべて持つ。
struct RaceImportError: LocalizedError, Equatable {
    /// 原因の一覧。
    let issues: [RaceImportIssue]

    /// 原因を 1 行ずつ並べた説明。
    var errorDescription: String? {
        issues.map { "- \($0.path): \($0.message)" }.joined(separator: "\n")
    }

    /// AI に貼り付けて JSON を直してもらうための文章。
    var reportForAI: String {
        """
        umalog への取り込みで次のエラーが出ました。エラーを直し、同じスキーマ（schemaVersion 1）の JSON だけを出力し直してください。
        \(errorDescription ?? "")
        """
    }
}

// MARK: - Plan

/// 取り込みでの 1 件ごとの変更の種類。
enum RaceImportChangeKind: Equatable {
    /// 新規作成。
    case create
    /// 更新。
    case update
    /// 変更なし。
    case unchanged
    /// 削除（JSON に無い出走馬）。
    case delete

    /// プレビューに出す表示名。
    var displayName: String {
        switch self {
        case .create: "新規作成"
        case .update: "更新"
        case .unchanged: "変更なし"
        case .delete: "削除"
        }
    }
}

/// 1 フィールドの変更前後の値。
struct RaceImportFieldChange: Equatable {
    /// フィールドの表示名。
    let label: String
    /// 変更前の値（表示用）。
    let oldValue: String
    /// 変更後の値（表示用）。
    let newValue: String

    /// 変更前後で値が違うかどうか。
    var isChanged: Bool {
        oldValue != newValue
    }
}

/// 出走馬 1 頭分の取り込み計画。
struct RaceImportEntryPlan: Identifiable {
    /// リスト表示用の識別子。削除と更新で馬番が重なることがあるため、馬番とは別に持つ。
    let id = UUID()
    /// 変更の種類。
    let kind: RaceImportChangeKind
    /// 馬番。
    let horseNumber: Int
    /// 馬名（削除なら既存の馬名）。
    let horseName: String
    /// 変更されるフィールド（更新のときだけ値を持つ）。
    let changes: [RaceImportFieldChange]
    /// 照合した既存の出走馬。新規作成なら nil。
    let existing: RaceEntry?
    /// 取り込む出走馬。削除なら nil。
    let imported: RaceImportData.Entry?
}

/// 保存前に差分をプレビューするための取り込み計画。
struct RaceImportPlan {
    /// 取り込むデータ。
    let data: RaceImportData
    /// 新規作成するレースの競馬場。更新では競馬場を変えないため nil。
    let venue: Venue?
    /// 更新するレース。新規作成なら nil。
    let existingRace: Race?
    /// レースの変更の種類。
    let raceKind: RaceImportChangeKind
    /// レースの変更されるフィールド。
    let raceChanges: [RaceImportFieldChange]
    /// 出走馬の計画（馬番順）。
    let entries: [RaceImportEntryPlan]

    /// 保存すると何か変わるかどうか。
    var hasChanges: Bool {
        raceKind != .unchanged || entries.contains { $0.kind != .unchanged }
    }
}

// MARK: - Importer

/// AI などが出力した JSON 文字列からレース・出走馬を登録・差分更新する。
/// - Note: `@Attribute(.unique)` は使えないため、レースは日付・競馬場・レース番号、出走馬はレース内の馬番でアプリ側で照合する。
enum RaceJSONImporter {
    /// 受け付けるスキーマのバージョン。
    static let schemaVersion = 1
    /// 受け付けるトラック種別。
    static let trackTypes = ["turf", "dirt"]

    /// `yyyy-MM-dd` の日付を端末のタイムゾーンで読み書きするフォーマッター。
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }()

    // MARK: Parse

    /// テキストを解析・検証する。コードフェンスや前後の説明文は取り除く。
    /// - Parameter text: 貼り付けられたテキスト。
    /// - Returns: 検証を通過したデータ。
    /// - Throws: 構文エラーや不正な値があれば、原因のフィールドをすべて含む `RaceImportError`。
    static func parse(_ text: String) throws -> RaceImportData {
        guard let json = extractJSONObject(from: text) else {
            throw RaceImportError(issues: [RaceImportIssue(path: "(JSON)", message: "JSON オブジェクト（{ ... }）が見つかりません")])
        }
        let document: RaceImportDocument
        do {
            document = try JSONDecoder().decode(RaceImportDocument.self, from: Data(json.utf8))
        } catch let error as DecodingError {
            throw RaceImportError(issues: [issue(from: error)])
        }
        return try validate(document)
    }

    /// テキストから最初の `{` と最後の `}` に挟まれた部分を取り出す。
    /// - Note: 入力中に変換された全角の引用符（“ ”）は JSON の `"` に戻す。
    /// - Parameter text: 貼り付けられたテキスト。
    /// - Returns: JSON オブジェクト部分。見つからなければ nil。
    static func extractJSONObject(from text: String) -> String? {
        let normalized = text
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
        guard let start = normalized.firstIndex(of: "{"),
              let end = normalized.lastIndex(of: "}"),
              start < end
        else { return nil }
        return String(normalized[start ... end])
    }

    /// デコードエラーを、原因のフィールドを示す取り込みエラーに変換する。
    /// - Parameter error: `JSONDecoder` のエラー。
    /// - Returns: 原因のフィールドと説明。
    private static func issue(from error: DecodingError) -> RaceImportIssue {
        switch error {
        case let .keyNotFound(key, context):
            RaceImportIssue(path: path(context.codingPath + [key]), message: "必須のフィールドがありません（省略できません）")
        case let .valueNotFound(_, context):
            RaceImportIssue(path: path(context.codingPath), message: "null は使えません。値を指定してください")
        case let .typeMismatch(type, context):
            RaceImportIssue(path: path(context.codingPath), message: "型が違います（\(typeName(type)) を指定してください）")
        case let .dataCorrupted(context):
            if context.codingPath.isEmpty {
                RaceImportIssue(path: "(JSON)", message: "JSON の構文が正しくありません（\(context.underlyingError?.localizedDescription ?? context.debugDescription)）")
            } else {
                RaceImportIssue(path: path(context.codingPath), message: "値が正しくありません")
            }
        @unknown default:
            RaceImportIssue(path: "(JSON)", message: "JSON を読み込めません")
        }
    }

    /// コーディングパスを `entries[2].mark` の形式にする。
    /// - Parameter codingPath: デコードエラーのパス。
    /// - Returns: 表示用のパス。
    private static func path(_ codingPath: [any CodingKey]) -> String {
        let joined = codingPath.reduce(into: "") { result, key in
            if let index = key.intValue {
                result += "[\(index)]"
            } else {
                result += result.isEmpty ? key.stringValue : ".\(key.stringValue)"
            }
        }
        return joined.isEmpty ? "(JSON)" : joined
    }

    /// JSON の型名を返す。
    /// - Parameter type: デコードしようとした型。
    /// - Returns: 表示用の型名。
    private static func typeName(_ type: Any.Type) -> String {
        if type == Int.self {
            return "整数"
        }
        if type == String.self {
            return "文字列"
        }
        // 配列の不一致は要素型によらず Array<Any> で報告されることがあるため、型名で判定する
        if String(describing: type).hasPrefix("Array") {
            return "配列"
        }
        return "オブジェクト"
    }

    /// デコードした JSON の値を検証する。不正な値はすべて集めてから中止する。
    /// - Parameter document: デコードした JSON。
    /// - Returns: 検証を通過したデータ。
    /// - Throws: 不正な値が 1 つでもあれば `RaceImportError`。
    static func validate(_ document: RaceImportDocument) throws -> RaceImportData {
        var issues: [RaceImportIssue] = []
        let race = document.race

        if document.schemaVersion != schemaVersion {
            issues.append(.init(path: "schemaVersion", message: "対応しているのは \(schemaVersion) だけです"))
        }
        let (date, grade) = validateRace(race, issues: &issues)
        let entries = validateEntries(document.entries, issues: &issues)
        validatePlaces(race, horseNumbers: Set(entries.map(\.horseNumber)), issues: &issues)

        guard issues.isEmpty, let date, let grade else {
            throw RaceImportError(issues: issues)
        }
        return RaceImportData(
            date: date, venueName: race.venue, raceNumber: race.raceNumber, raceName: race.raceName,
            distance: race.distance, trackType: race.trackType, trackCondition: race.trackCondition, grade: grade,
            firstPlaceHorseNumber: race.firstPlaceHorseNumber, secondPlaceHorseNumber: race.secondPlaceHorseNumber,
            thirdPlaceHorseNumber: race.thirdPlaceHorseNumber, entries: entries,
        )
    }

    /// レース部分の値を検証する（着順は出走馬がそろってから `validatePlaces` で検証する）。
    /// - Parameters:
    ///   - race: デコードしたレース部分。
    ///   - issues: 不正な値を追加する先。
    /// - Returns: 解釈できた開催日とグレード。不正なら nil。
    private static func validateRace(_ race: RaceImportRace, issues: inout [RaceImportIssue]) -> (date: Date?, grade: RaceGrade?) {
        let date = dateFormatter.date(from: race.date)
        // isLenient = false でも "2026-1-5" のような桁不足を受け付けるため、書き戻して一致を確かめる
        if date.map(dateFormatter.string(from:)) != race.date {
            issues.append(.init(path: "race.date", message: "\"\(race.date)\" は日付（yyyy-MM-dd）ではありません"))
        }
        let venueNames = venuePresets.map(\.name)
        if !venueNames.contains(race.venue) {
            issues.append(.init(path: "race.venue", message: "\"\(race.venue)\" は使えません。使える値: \(venueNames.joined(separator: ", "))"))
        }
        if !(1 ... 12).contains(race.raceNumber) {
            issues.append(.init(path: "race.raceNumber", message: "1〜12 で指定してください"))
        }
        if race.distance <= 0 {
            issues.append(.init(path: "race.distance", message: "1 以上の整数（メートル）で指定してください"))
        }
        if !trackTypes.contains(race.trackType) {
            issues.append(.init(path: "race.trackType", message: "\"\(race.trackType)\" は使えません。使える値: \(trackTypes.joined(separator: ", "))"))
        }
        if !Race.trackConditions.contains(race.trackCondition) {
            issues.append(.init(path: "race.trackCondition", message: "\"\(race.trackCondition)\" は使えません。使える値: \(Race.trackConditions.joined(separator: ", "))"))
        }
        let grade = RaceGrade(rawValue: race.grade)
        if grade == nil {
            let grades = RaceGrade.allCases.map { "\"\($0.rawValue)\"" }.joined(separator: ", ")
            issues.append(.init(path: "race.grade", message: "\"\(race.grade)\" は使えません。使える値: \(grades)"))
        }
        return (date, grade)
    }

    /// 出走馬の値を検証する。
    /// - Parameters:
    ///   - importEntries: デコードした出走馬。
    ///   - issues: 不正な値を追加する先。
    /// - Returns: 出走馬（不正な値を含むものも含め、JSON の順）。
    private static func validateEntries(_ importEntries: [RaceImportEntry], issues: inout [RaceImportIssue]) -> [RaceImportData.Entry] {
        var entries: [RaceImportData.Entry] = []
        var seenNumbers: Set<Int> = []
        for (index, entry) in importEntries.enumerated() {
            let entryPath = "entries[\(index)]"
            if entry.horseNumber < 1 {
                issues.append(.init(path: "\(entryPath).horseNumber", message: "1 以上の整数で指定してください"))
            } else if !seenNumbers.insert(entry.horseNumber).inserted {
                issues.append(.init(path: "\(entryPath).horseNumber", message: "馬番 \(entry.horseNumber) が重複しています"))
            }
            if entry.horseName.isEmpty {
                issues.append(.init(path: "\(entryPath).horseName", message: "空文字は使えません"))
            }
            let mark = PredictionMark(rawValue: entry.mark)
            if mark == nil, !entry.mark.isEmpty {
                let marks = PredictionMark.allCases.map(\.rawValue).joined(separator: " ")
                issues.append(.init(path: "\(entryPath).mark", message: "\"\(entry.mark)\" は使えません。使える値: \(marks)、印なしは空文字"))
            }
            entries.append(.init(
                horseNumber: entry.horseNumber, horseName: entry.horseName,
                jockeyName: entry.jockeyName, trainerName: entry.trainerName, mark: mark,
            ))
        }
        return entries
    }

    /// 1〜3 着の馬番を検証する。0（未確定）以外は出走馬にあり、互いに重複しないこと。
    /// - Parameters:
    ///   - race: デコードしたレース部分。
    ///   - horseNumbers: 出走馬の馬番。
    ///   - issues: 不正な値を追加する先。
    private static func validatePlaces(_ race: RaceImportRace, horseNumbers: Set<Int>, issues: inout [RaceImportIssue]) {
        let places = [
            ("firstPlaceHorseNumber", race.firstPlaceHorseNumber),
            ("secondPlaceHorseNumber", race.secondPlaceHorseNumber),
            ("thirdPlaceHorseNumber", race.thirdPlaceHorseNumber),
        ]
        var seenPlaces: Set<Int> = []
        for (key, number) in places where number != 0 {
            if !horseNumbers.contains(number) {
                issues.append(.init(path: "race.\(key)", message: "馬番 \(number) は entries にありません。未確定なら 0 を指定してください"))
            } else if !seenPlaces.insert(number).inserted {
                issues.append(.init(path: "race.\(key)", message: "馬番 \(number) が他の着順と重複しています"))
            }
        }
    }

    // MARK: Plan

    /// 保存前にプレビューする取り込み計画を作る。データは変更しない。
    /// - Note: 追加（`target` が nil）と更新（`target` を指定）を混ぜない。追加は既存のレースを更新せず、
    ///   更新は JSON の日付・競馬場・レース番号を使わない。AI の出力がぶれても、別のレースに紐づいたり二重登録されたりしないため。
    /// - Parameters:
    ///   - data: 検証を通過したデータ。
    ///   - context: 照合先のモデルコンテキスト。
    ///   - target: 更新するレース。レース詳細から取り込むときに渡し、nil なら新規作成として扱う。
    /// - Returns: レースと出走馬ごとの変更内容。
    /// - Throws: 新規作成で、競馬場マスターに競馬場が無い場合や同じレースが既にある場合は `RaceImportError`。
    static func makePlan(for data: RaceImportData, in context: ModelContext, target: Race? = nil) throws -> RaceImportPlan {
        if let target {
            return updatePlan(for: data, target: target)
        }
        return try createPlan(for: data, in: context)
    }

    /// 新規作成の取り込み計画を作る。
    /// - Parameters:
    ///   - data: 検証を通過したデータ。
    ///   - context: 照合先のモデルコンテキスト。
    /// - Returns: レースと全出走馬を新規作成する計画。
    /// - Throws: 競馬場マスターに競馬場が無い場合や、日付・競馬場・レース番号が同じレースが既にある場合は `RaceImportError`。
    private static func createPlan(for data: RaceImportData, in context: ModelContext) throws -> RaceImportPlan {
        let venues = try context.fetch(FetchDescriptor<Venue>())
        guard let venue = venues.first(where: { $0.name == data.venueName }) else {
            throw RaceImportError(issues: [.init(path: "race.venue", message: "\"\(data.venueName)\" が競馬場マスターにありません")])
        }
        if try context.fetch(FetchDescriptor<Race>()).contains(where: { isSameRace($0, as: data) }) {
            let key = "\(data.date.japaneseShortDateString) \(data.venueName) R\(data.raceNumber)"
            throw RaceImportError(issues: [.init(
                path: "race",
                message: "このレース（\(key)）は既に登録されています。予想を更新するときは、レース詳細の「編集」›「JSONで更新」から取り込んでください",
            )])
        }
        let entries = data.entries.sorted { $0.horseNumber < $1.horseNumber }.map {
            RaceImportEntryPlan(kind: .create, horseNumber: $0.horseNumber, horseName: $0.horseName, changes: [], existing: nil, imported: $0)
        }
        return RaceImportPlan(data: data, venue: venue, existingRace: nil, raceKind: .create, raceChanges: [], entries: entries)
    }

    /// 指定したレースを更新する取り込み計画を作る。JSON の日付・競馬場・レース番号は使わない。
    /// - Parameters:
    ///   - data: 検証を通過したデータ。
    ///   - target: 更新するレース。
    /// - Returns: 変わったフィールドの更新、新しい馬番の追加、JSON に無い馬番の削除を含む計画。
    private static func updatePlan(for data: RaceImportData, target: Race) -> RaceImportPlan {
        let raceChanges = raceChanges(from: target, to: data)
        var remaining = (target.entries ?? []).sorted { $0.sortIndex < $1.sortIndex }
        var entryPlans: [RaceImportEntryPlan] = []
        for imported in data.entries {
            if let index = remaining.firstIndex(where: { $0.horseNumber == imported.horseNumber }) {
                let existing = remaining.remove(at: index)
                let changes = entryChanges(from: existing, to: imported)
                entryPlans.append(.init(
                    kind: changes.isEmpty ? .unchanged : .update, horseNumber: imported.horseNumber,
                    horseName: imported.horseName, changes: changes, existing: existing, imported: imported,
                ))
            } else {
                entryPlans.append(.init(
                    kind: .create, horseNumber: imported.horseNumber, horseName: imported.horseName,
                    changes: [], existing: nil, imported: imported,
                ))
            }
        }
        // JSON に無い馬番の出走馬は削除する（オーナー決定、Issue #44）
        entryPlans += remaining.map {
            RaceImportEntryPlan(kind: .delete, horseNumber: $0.horseNumber, horseName: $0.horseName, changes: [], existing: $0, imported: nil)
        }
        return RaceImportPlan(
            data: data, venue: nil, existingRace: target,
            raceKind: raceChanges.isEmpty ? .unchanged : .update, raceChanges: raceChanges,
            entries: entryPlans.sorted { $0.horseNumber < $1.horseNumber },
        )
    }

    /// 既存のレースが取り込むデータと同じレースか（日付・競馬場名・レース番号が一致するか）を返す。
    /// - Note: 手入力のレースは時刻を持つため、日付は同じ日かどうかで比べる。
    /// - Parameters:
    ///   - race: 既存のレース。
    ///   - data: 取り込むデータ。
    /// - Returns: 同じレースなら true。
    static func isSameRace(_ race: Race, as data: RaceImportData) -> Bool {
        race.venue?.name == data.venueName
            && race.raceNumber == data.raceNumber
            && Calendar.current.isDate(race.date, inSameDayAs: data.date)
    }

    /// 既存のレースと取り込むデータの、値が違うフィールドを返す。更新では使わない日付・競馬場・レース番号と、競馬場から決まる区分は比べない。
    /// - Parameters:
    ///   - race: 既存のレース。
    ///   - data: 取り込むデータ。
    /// - Returns: 変更されるフィールド。
    private static func raceChanges(from race: Race, to data: RaceImportData) -> [RaceImportFieldChange] {
        [
            RaceImportFieldChange(label: "レース名", oldValue: race.raceName, newValue: data.raceName),
            RaceImportFieldChange(
                label: "グレード", oldValue: RaceGrade(rawValue: race.grade)?.displayName ?? race.grade, newValue: data.grade.displayName,
            ),
            RaceImportFieldChange(label: "トラック", oldValue: trackTypeName(race.trackType), newValue: trackTypeName(data.trackType)),
            RaceImportFieldChange(label: "距離", oldValue: "\(race.distance)m", newValue: "\(data.distance)m"),
            RaceImportFieldChange(label: "馬場状態", oldValue: race.trackCondition, newValue: data.trackCondition),
            RaceImportFieldChange(label: "1着", oldValue: placeName(race.firstPlaceHorseNumber), newValue: placeName(data.firstPlaceHorseNumber)),
            RaceImportFieldChange(label: "2着", oldValue: placeName(race.secondPlaceHorseNumber), newValue: placeName(data.secondPlaceHorseNumber)),
            RaceImportFieldChange(label: "3着", oldValue: placeName(race.thirdPlaceHorseNumber), newValue: placeName(data.thirdPlaceHorseNumber)),
        ].filter(\.isChanged)
    }

    /// 既存の出走馬と取り込む出走馬の、値が違うフィールドを返す。
    /// - Parameters:
    ///   - entry: 既存の出走馬。
    ///   - imported: 取り込む出走馬。
    /// - Returns: 変更されるフィールド。
    private static func entryChanges(from entry: RaceEntry, to imported: RaceImportData.Entry) -> [RaceImportFieldChange] {
        [
            RaceImportFieldChange(label: "馬名", oldValue: entry.horseName, newValue: imported.horseName),
            RaceImportFieldChange(label: "騎手", oldValue: entry.jockeyName, newValue: imported.jockeyName),
            RaceImportFieldChange(label: "調教師", oldValue: entry.trainerName, newValue: imported.trainerName),
            RaceImportFieldChange(label: "印", oldValue: entry.predictionMark ?? "なし", newValue: imported.mark?.rawValue ?? "なし"),
        ].filter(\.isChanged)
    }

    /// トラック種別の表示名を返す。
    /// - Parameter trackType: "turf" / "dirt"。
    /// - Returns: "芝" / "ダート"。
    private static func trackTypeName(_ trackType: String) -> String {
        trackType == "turf" ? "芝" : "ダート"
    }

    /// 着順の馬番の表示名を返す。
    /// - Parameter number: 馬番。0 は未確定。
    /// - Returns: "3番" / "未確定"。
    private static func placeName(_ number: Int) -> String {
        number == 0 ? "未確定" : "\(number)番"
    }

    // MARK: Apply

    /// 取り込み計画を保存する。
    /// - Parameters:
    ///   - plan: `makePlan(for:in:)` で作った計画。
    ///   - context: 保存先のモデルコンテキスト。
    /// - Returns: 作成または更新したレース。
    /// - Throws: 保存に失敗した場合のエラー。
    @discardableResult
    static func apply(_ plan: RaceImportPlan, in context: ModelContext) throws -> Race {
        let data = plan.data
        let race: Race
        if let existingRace = plan.existingRace {
            race = existingRace
        } else {
            race = Race(
                date: data.date, venue: plan.venue, raceNumber: data.raceNumber,
                category: plan.venue?.category ?? RaceCategory.central.rawValue,
            )
            context.insert(race)
        }
        race.raceName = data.raceName
        race.distance = data.distance
        race.trackType = data.trackType
        race.trackCondition = data.trackCondition
        race.grade = data.grade.rawValue
        race.firstPlaceHorseNumber = data.firstPlaceHorseNumber
        race.secondPlaceHorseNumber = data.secondPlaceHorseNumber
        race.thirdPlaceHorseNumber = data.thirdPlaceHorseNumber

        let kept = plan.entries.filter { $0.kind != .delete }.compactMap(\.existing)
        var nextSortIndex = (kept.map(\.sortIndex).max() ?? -1) + 1
        for entryPlan in plan.entries {
            switch entryPlan.kind {
            case .create:
                guard let imported = entryPlan.imported else { continue }
                context.insert(RaceEntry(
                    race: race, horseNumber: imported.horseNumber, horseName: imported.horseName,
                    jockeyName: imported.jockeyName, trainerName: imported.trainerName,
                    predictionMark: imported.mark?.rawValue, sortIndex: nextSortIndex,
                ))
                nextSortIndex += 1
            case .update:
                guard let entry = entryPlan.existing, let imported = entryPlan.imported else { continue }
                entry.horseName = imported.horseName
                entry.jockeyName = imported.jockeyName
                entry.trainerName = imported.trainerName
                entry.mark = imported.mark
            case .delete:
                if let entry = entryPlan.existing {
                    context.delete(entry)
                }
            case .unchanged:
                break
            }
        }
        // 取り込んだレース・出走馬はすぐ一覧と詳細画面に出る。自動保存を待つと表示後に一時 ID が恒久 ID に変わり、
        // 行が作り直されるため、ここで保存する（Issue #55）
        try context.save()
        return race
    }

    // MARK: Prompt

    /// AI に渡すプロンプト。出力のルール・JSON Schema・出力例を含む。
    /// - Note: JSON Schema だけでは「着順の馬番は entries にある」「JSON に無い馬は削除される」を伝えきれないため、指示文を添える。
    static var promptForAI: String {
        """
        競馬予想アプリ umalog に取り込むため、予想したレース 1 件を、次の JSON Schema に従う JSON で出力してください。

        出力のルール:
        - JSON だけを出力し、説明文は付けないでください。
        - すべてのフィールドが必須です。省略や null は使えません。分からない文字列は空文字 "" にしてください（horseName は空文字不可）。
        - 着順（firstPlaceHorseNumber / secondPlaceHorseNumber / thirdPlaceHorseNumber）は、レース前など未確定なら 0 にしてください。0 以外は entries にある馬番で、互いに重複させないでください。
        - 印を付けない馬の mark は空文字 "" にしてください。
        - entries には出走馬を全頭含め、horseNumber を重複させないでください。予想を見直して出し直すときも全頭を含めてください。含まれない馬番の出走馬はアプリから削除されます。

        JSON Schema:
        \(jsonSchema)

        出力例:
        \(exampleJSON)
        """
    }

    /// 取り込む JSON の JSON Schema（draft 2020-12）。競馬場・印・グレードなどの選択肢はアプリの定義から組み立てる。
    static var jsonSchema: String {
        let integer: (Int, String) -> [String: Any] = { minimum, description in
            ["type": "integer", "minimum": minimum, "description": description]
        }
        let enumeration: ([String], String) -> [String: Any] = { values, description in
            ["type": "string", "enum": values, "description": description]
        }
        let raceProperties: [String: Any] = [
            "date": [
                "type": "string", "format": "date", "pattern": "^\\d{4}-\\d{2}-\\d{2}$",
                "description": "開催日（yyyy-MM-dd）",
            ],
            "venue": enumeration(venuePresets.map(\.name), "競馬場名"),
            "raceNumber": ["type": "integer", "minimum": 1, "maximum": 12, "description": "レース番号"],
            "raceName": ["type": "string", "description": "レース名。分からなければ空文字"],
            "distance": integer(1, "距離（メートル）"),
            "trackType": enumeration(trackTypes, "turf: 芝、dirt: ダート"),
            "trackCondition": enumeration(Race.trackConditions, "馬場状態"),
            "grade": enumeration(
                RaceGrade.allCases.map(\.rawValue),
                "グレード。" + RaceGrade.allCases.map { "\"\($0.rawValue)\": \($0.displayName)" }.joined(separator: "、"),
            ),
            "firstPlaceHorseNumber": integer(0, "1 着の馬番。未確定なら 0"),
            "secondPlaceHorseNumber": integer(0, "2 着の馬番。未確定なら 0"),
            "thirdPlaceHorseNumber": integer(0, "3 着の馬番。未確定なら 0"),
        ]
        let entryProperties: [String: Any] = [
            "horseNumber": integer(1, "馬番。レース内で重複不可"),
            "horseName": ["type": "string", "minLength": 1, "description": "馬名"],
            "jockeyName": ["type": "string", "description": "騎手名。分からなければ空文字"],
            "trainerName": ["type": "string", "description": "調教師名。分からなければ空文字"],
            "mark": enumeration(PredictionMark.allCases.map(\.rawValue) + [""], "予想印。印なしは空文字"),
        ]
        let schema: [String: Any] = [
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "title": "umalog レース取り込み（schemaVersion 1）",
            "type": "object",
            "additionalProperties": false,
            "required": ["schemaVersion", "race", "entries"],
            "properties": [
                "schemaVersion": ["const": schemaVersion],
                "race": [
                    "type": "object", "additionalProperties": false,
                    "required": raceProperties.keys.sorted(), "properties": raceProperties,
                ],
                "entries": [
                    "type": "array", "description": "出走馬全頭",
                    "items": [
                        "type": "object", "additionalProperties": false,
                        "required": entryProperties.keys.sorted(), "properties": entryProperties,
                    ],
                ],
            ],
        ]
        let data = (try? JSONSerialization.data(withJSONObject: schema, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])) ?? Data()
        return String(bytes: data, encoding: .utf8) ?? ""
    }

    /// プロンプトに載せる出力例。
    static let exampleJSON = """
    {
      "schemaVersion": 1,
      "race": {
        "date": "2026-10-25",
        "venue": "東京",
        "raceNumber": 11,
        "raceName": "天皇賞（秋）",
        "distance": 2000,
        "trackType": "turf",
        "trackCondition": "良",
        "grade": "G1",
        "firstPlaceHorseNumber": 0,
        "secondPlaceHorseNumber": 0,
        "thirdPlaceHorseNumber": 0
      },
      "entries": [
        { "horseNumber": 1, "horseName": "馬名", "jockeyName": "騎手名", "trainerName": "調教師名", "mark": "◎" }
      ]
    }
    """
}
