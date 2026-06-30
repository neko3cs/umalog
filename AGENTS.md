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

---

## Open Issues

- [ ] **#1** JRA出走馬自動取得 — plan in `.claude/plans/1-jra-immutable-cascade.md`; blocked: owner must decide on netkeiba URL-paste vs other source, ToS review required.
- [ ] **#14** マルチプラットフォーム対応（macOS / iPadOS）— low priority.

---

## Current State & Handoff (2026-07-01)

- Tests: 210 unit, 25 UI — all green. SwiftFormat + SwiftLint clean.
- Completed: Issue #4 (RaceFilter value type, filter sheet, chips, sort toggle) — PR #21 merged.
- Next: Issue #1 — owner decision on scraping strategy needed before coding starts. #14 unstarted.

---

## Incidents

| Date | What went wrong | Prevention |
| :--- | :--- | :--- |
| 2026-06-30 | Committed and pushed before owner confirmed behavior | Never `git commit` / `git push` without explicit owner instruction |
