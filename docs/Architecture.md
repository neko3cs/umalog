# Umalog アーキテクチャ設計書

本書はUmalogのUML図（ユースケース図・アクティビティ図・クラス図・ステートマシン図・シーケンス図）を用いて設計をまとめたものです。各図の元データは[docs/uml](uml)配下にdrawio形式で置いてあり、draw.ioで編集できます。図が実装と食い違う場合はコード（`src/umalog`）を正とします。

## 1. アーキテクチャ概要

- **UI**: SwiftUI（iOS 18+, Swift 6.2）
- **永続化**: SwiftData（ローカルのみ、サーバーなし）
- **UIKit連携**: `ShakeWindow`のみ（シェイクによるUndo検出。SwiftUIにシェイク検出APIがないための橋渡し）
- **データフロー**: `RaceListView`/`RaceDetailView`などのViewが`@Query`/`@Environment(\.modelContext)`経由でSwiftDataに直接アクセスする。専用のViewModel層は存在しない。
- **非機能要件**: ローカル限定・完全無料・プライバシーファースト（`AGENTS.md`のNon-Negotiablesを参照）。

画面構成は`ContentView`の3タブ構成とする。1つ目は`RaceListView`（ホーム）で、`RaceDetailView`と`RaceFormView`/`RaceEntryFormView`/`BetFormView`へ遷移する。2つ目は収支を集計する`BalanceSummaryView`、3つ目はマスタ管理・ZIPバックアップ／復元・初期化を行う`SettingsView`とする。

---

## 2. ユースケース図

要件（誰が何をしたいか）を表す。アクターは「ユーザー（利用者本人）」の1人のみで、外部システムやアカウントは存在しない（ローカル単独利用）。

![ユースケース図](uml/usecase.png)

- **レース管理**: レースの登録・編集・削除・絞り込み／並び替え
- **出走馬・予想管理**: 出走馬登録、予想印付け、着順入力
- **馬券管理**: 馬券登録（通常／BOX／フォーメーション）と払戻入力。「組合せ点数を自動計算する」は`«include»`される内部機能（`Bet.combinationCount`）
- **メモ・収支確認**: Markdownメモ、日／月／年／期間別の収支集計
- **データ管理**: ZIPバックアップ作成・復元（復元は「既存レースデータを置換する」を`«include»`）、データ初期化、競馬場／券種マスタ管理
- **取り消し**:「シェイクで直前操作を取り消す」は「レースを削除する」を`«extend»`する（削除操作に対するUndo機能）

---

## 3. アクティビティ図

処理・業務の流れを表す。ユーザーとシステム（SwiftData/CSVExporter等）の2レーンで、レース登録から収支確認までの基本業務フローを示す。

![アクティビティ図](uml/activity.png)

ポイント:
- 予想印の入力は任意（出走馬登録後の分岐）
- 馬券登録時、組合せ点数と購入額はシステム側（`Bet.combinationCount`）が自動計算する
- レース結果が未確定の場合はその時点で終了してよく、着順・払戻は後から改めて入力できる（`firstPlaceHorseNumber`などの初期値`0`が「未入力」を表す設計）
- 収支（`balance`/`returnRate`）は払戻額入力のたびにシステムが自動計算する

---

## 4. クラス図

静的な構造（骨格）を表す。SwiftDataの`@Model`クラス（`Race`/`RaceEntry`/`Bet`/`BetSelection`/`Venue`/`TicketType`）から成る。加えて、値のみの`enum`（`PredictionMark`/`RaceGrade`）を持つ。

![クラス図](uml/class.png)

- `Race` *— `RaceEntry`/`Bet`、`Bet` *— `BetSelection`は`deleteRule: .cascade`によるコンポジション（親削除で子も削除）
- `Venue` — `Race`は`deleteRule: .nullify`（競馬場削除時はレース側の参照だけが`nil`になり、レース自体は残る）関連
- `TicketType` — `Bet`/`BetSelection`も同様にnullifyの関連（`Bet.ticketType`はレガシー互換用フィールド）
- CloudKit互換のため、全リレーションはoptionalとする。順序はSwiftDataのordered relationshipを使わず`sortIndex: Int`で管理する（`AGENTS.md`の制約と一致）
- `RaceEntry.mark`は`predictionMark: String?`を`PredictionMark` enumとして読み書きするアクセサである。`Race.grade`も同様に`RaceGrade`のrawValueを保存する文字列である

---

## 5. ステートマシン図

動的な振る舞い①：状態の変化を表す。`Race`に明示的なステータス列（enum）は存在しないため、これは**保持しているフィールドの充足状況から導出した概念的な状態遷移**である（実装上のリテラルな状態機械ではない点に注意）。

![ステートマシン図](uml/state.png)

- **基本情報登録済み** → **出走馬登録済み**（`entries.count > 0`）
- **出走馬登録済み** → **着順確定済み**（1〜3着の馬番を入力、`firstPlaceHorseNumber > 0`など）
- **着順確定済み** ⇄ **馬券精算済み**（全馬券の払戻額を入力／再編集）。`AGENTS.md`に記載の通り「未精算の馬券は払戻額 ¥0」という設計上の取り決めにより、精算済みか否かを`payoutAmount`の値だけで判定する
- どの状態からも「レースを削除する」（`RaceListView.deleteRace`）へ遷移でき、シェイク操作により`UndoManager`経由で直前状態に復元できる

---

## 6. シーケンス図

動的な振る舞い②：やり取りの順番を表す。本アプリ特有の「スワイプ削除 → シェイクで取り消し（Undo）」の一連のやり取りを取り上げる（`RaceListView.deleteRace`と`ContentView`のシェイクハンドリング）。

![シーケンス図](uml/sequence.png)

- 削除前に`RaceSnapshot`へレースと子データ（出走馬・馬券・買い目）のスナップショットを取る。`UndoManager.registerUndo`にクロージャとして復元処理を登録してから、`ModelContext`で削除する
- シェイクは`UIWindow.motionEnded` → `NotificationCenter`（`.deviceDidShake`）→ `ContentView.onReceive`という経路で検出する。これはUIKitからSwiftUIへのブリッジである
- Undo実行はアラートのdismissアニメーション完了を待つため350ms遅延させてから行う（`List`の差分計算崩れを防止するため。`AGENTS.md`のタシットナレッジ参照）

---

## 7. アーキテクチャ上の申し送り事項

- **`Bet`のレガシーフィールド**: `ticketType`/`ticketTypeName`/`selection`/`unitPrice`は`BetSelection`導入前の旧データモデルの互換用として残っている。`AppDelegate.migrateToSelectionModelIfNeeded`が起動時に`BetSelection`未生成の旧馬券を移行するため、削除する際はこの移行ロジックとの整合を確認すること
- **ZIPバックアップの結合キー**: `ZipImporter`はCSV上で永続IDを持てないため、レースを「日付＋競馬場名＋レース番号」の合成キーで突き合わせている。同一日・同一競馬場・同一レース番号のレースが重複登録された場合はインポート時に取り違える余地があるため、キー設計を変更する場合は要注意
- **Undo/スナップショットの重複実装**: レース削除（`RaceListView`）と出走馬・馬券削除（`RaceDetailView`）でそれぞれ個別に`Snapshot`構造体と復元クロージャを実装している。共通化されていないため、削除可能な画面を新設する場合は同様のスナップショット実装が都度必要になる
- **シェイクUndoのUIKit依存**: `ShakeWindow`は`UIWindow.motionEnded`のオーバーライドに依存し、加速度センサーのないプラットフォームでは機能しない。Issue #14（macOS/iPadOS対応）に着手する際は、シェイク以外のUndo導線（メニュー操作など）を別途用意する必要がある
- **JRA出走馬自動取得（Issue #1）と非機能要件の整合**: ネットワーク経由の取得は「ローカル限定・外部へのデータ送信なし」という非交渉事項と衝突しうる。実装する場合はユーザーが明示的に貼り付けた内容を解析するなど、アプリが自発的に通信しない設計にする必要がある（`AGENTS.md`のOpen Issues参照）
