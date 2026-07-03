# Umalog — AGENTS.md

A personal iOS app for recording horse racing predictions and balance tracking. `docs/Design.md` is background context only — when it conflicts with the code, trust the code.

---

## Non-Negotiables

**Must never be violated:**
1. Local-only by default — no server, no account, no external data transmission
2. Completely free and unlimited
3. Privacy-first: user data never leaves the device

Never suggest: betting features, external APIs, user accounts, or monetization.
Never add links or buttons to external betting services (即PAT, IPAT, etc.).
App Store: Japan only, age rating 18+. Description and Review Notes must state "no betting features."

---

## Architecture & Data Model

- **UI**: SwiftUI (iOS 18+, Swift 6.2) — **Persistence**: SwiftData — **UIKit**: `ShakeWindow` only (shake-to-undo; SwiftUI has no native shake API)
- **Screens**: `RaceListView` (home), `RaceDetailView`, `RaceFormView` / `RaceEntryFormView` / `BetFormView`, `BalanceSummaryView`, `SettingsView`
- **Models**: `Race` → `RaceEntry` (出走馬), `Race` → `Bet` → `BetSelection` (買い目). Master: `Venue`, `TicketType`. `PredictionMark` is an enum (8 fixed values).

---

## Commands

```bash
# Format
swiftformat src/umalog src/umalogTests --swiftversion 6.2

# Lint
swiftlint lint --config .swiftlint.yml

# Unit tests
xcodebuild test -project src/umalog.xcodeproj -scheme umalog \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' \
  -only-testing:umalogTests

# UI tests
xcodebuild test -project src/umalog.xcodeproj -scheme umalog \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' \
  -only-testing:umalogUITests

# Coverage
xcrun xccov view --report --only-targets umalogTests src/TestResults.xcresult

# Mutation tests — skip; Muter crashes (SIGBUS exit 138) on Xcode 26 beta
```

For Claude Code: use the `/test-ios-project` skill to run the full sequence above.

---

## Development Rules

- **Never edit `.pbxproj`** — malformed edits silently break the build with no actionable error.
- **New Swift files**: owner adds via Xcode GUI first, then AI writes the code content.
- **DocC comments** (`///`) required on all types, properties, and functions. Use `- Returns:`, `- Parameter:`, `- Note:` keywords for Xcode Quick Help.
- **Inline `//`** only for logic a reader would likely misread — never narrate obvious code.
- **Commits**: must not commit until the owner explicitly confirms behavior ("コミットして" or equivalent).

---

## Constraints

**CloudKit compatibility** (enforced now even though CloudKit is not yet active — retrofitting would require a painful, risky schema migration):
- All relationships must be optional (`?`)
- Ordering must use `sortIndex: Int = 0` — never use SwiftData ordered relationships
- `@Attribute(.unique)` is banned

**Other invariants:**
- Balance aggregation keyed by race **date**, not insert time. Unsettled bets = ¥0 payout.
- Prediction marks: exactly 8 fixed values (`◎ ○ ▲ △ ☆ 注 押 消`). Must not add or remove.
- `identifier_name` SwiftLint rule is disabled: test functions are Japanese specification sentences (e.g. `払戻が購入より多い場合に収支がプラスになる()`); SwiftLint v0.63.3 cannot suppress non-ASCII violations any other way.
- iCloud sync: not yet implemented. Default OFF when added. User's private iCloud only.
- Apple Developer Account: not yet subscribed — CloudKit and App Store submission blocked.

---

## Tacit Knowledge

- **`RaceGrade.unspecified`, not `.none`**: Swift resolves `.none` as `Optional<RaceGrade>.none` (nil) in `#expect` — the empty/default enum case must be named `.unspecified`.
- **`@MainActor` extension inheritance**: `extension AlreadyMainActorStruct { }` inherits `@MainActor` automatically — re-annotating causes SIGBUS crash in Swift 6.2.
- **`ModelContainer` must be stored before `.mainContext`**: Inline `try ModelContainer(...).mainContext` releases the container immediately; always store in a named `let` first.
- **SwiftLint `type_body_length` in tests**: 400-line limit per declaration. Move overflow tests into a bare `extension MyTest { }` — SwiftLint counts each body separately. No `@MainActor` on the extension (see above).
- **Toolbar buttons must have `.accessibilityIdentifier`**: With multiple `ToolbarItem(.navigationBarTrailing)` items, `app.navigationBars["X"].buttons["Add"]` races against SwiftData's re-render in XCUITest — `waitForExistence` on the bar then `tap()` on a child element can miss. Always set `.accessibilityIdentifier` on toolbar buttons and use `findElement("id")` / `tapWhenReady` in UI tests.
- **`Toggle` with a custom `Binding(get:set:)` inside `Form`/`List` rows can silently fail to register taps**: confirmed via real mouse clicks in the Simulator (not an XCUITest artifact) — a sibling `Picker` bound directly to `$filter.category` in the same sheet worked fine. Prefer a `Button` + checkmark row over `Toggle` for per-item multi-select rows in a `Form`/`List`.
- **Japanese day-count strings in UI test assertions must be anchored, not bare-`contains`**: `label.contains("1日間")` false-matches `"21日間"`/`"31日間"` since digits aren't word-bounded. Anchor with surrounding punctuation (e.g. `"(1日間)"`) or use exact string equality.
- **ZIP backup memo filenames**: current format is `<yyyyMMdd>_<venue>_R<n>_<raceName>.md` (venue + race number added 2026-07-04 to stop same-named races at different venues from overwriting each other's memo). `ZipImporter` must keep the legacy `<yyyyMMdd>_<raceName>` fallback — users' existing backups depend on it.
- **`xcodebuild -resultBundlePath` fails if the bundle already exists**: `rm -rf src/TestResults.xcresult` first. A failure "Early unexpected exit, operation never finished bootstrapping" usually means the destination simulator isn't booted — `xcrun simctl boot` it and retry.

---

## Open Issues

- [ ] **#1** JRA出走馬自動取得 — plan in `.claude/plans/1-jra-immutable-cascade.md`; blocked: owner must decide on netkeiba URL-paste vs other source, ToS review required.
- [ ] **#14** マルチプラットフォーム対応（macOS / iPadOS）— low priority.

---

## Current State & Handoff (2026-07-04)

- Tests: 221 unit, 28 UI — all green. SwiftFormat + SwiftLint clean.
- In progress: branch `fix/code-review-cleanup` (3 local commits, not pushed): finish-position guard for horse number 0, month-end clamping in balance year/month pickers, ZIP memo restore fixes + CSV builder dedup. Awaiting owner decision on push/PR.
- Decided: ZIP memo filenames include venue and race number; importer keeps legacy-name fallback for old backups.
- Next: after the fix branch lands, no queued issue besides #1 (blocked on owner scraping strategy decision) and #14 (low priority, unstarted).

---

## Incidents

| Date | What went wrong | Prevention |
| :--- | :--- | :--- |
| 2026-06-30 | Committed and pushed before owner confirmed behavior | Never `git commit` / `git push` without explicit owner instruction |
| 2026-07-01 | PR #21 shipped with venue/grade filter rows completely unresponsive to taps despite 27 passing unit tests | Unit tests on a value type (`RaceFilter`) don't verify View wiring — add an interaction-level UI test or manual Simulator click-through for every new tappable control before merging |
| 2026-07-03 | New UI test asserted `title.contains("1日間")`, which would have silently passed for `"31日間"`/`"21日間"` too — caught locally before merge | Anchor Japanese day-count substring checks with surrounding punctuation or exact match, not bare digit-suffix `contains` |
