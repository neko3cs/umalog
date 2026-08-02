# Umalog — AGENTS.md

A personal iOS app for recording horse racing predictions and balance tracking. Design docs live in `docs/`: `requirements.md` (why/for whom), `specification.md` (what to build), `architecture.md` (how — policy, ADRs, invariants), `design.md` (how — per-feature detail). When a doc conflicts with the code, trust the code.

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

- **UI**: SwiftUI (`IPHONEOS_DEPLOYMENT_TARGET = 26.0`) — **Persistence**: SwiftData — **UIKit**: `ShakeWindow` only (shake-to-undo; SwiftUI has no native shake API)
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
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -only-testing:umalogTests

# UI tests
xcodebuild test -project src/umalog.xcodeproj -scheme umalog \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -only-testing:umalogUITests

# Coverage
xcrun xccov view --report --only-targets umalogTests src/TestResults.xcresult

# Mutation tests — skip; Muter crashes (SIGBUS exit 138) on Xcode 26
```

For Claude Code: use the `/test-ios-project` skill to run the full sequence above.

---

## Development Rules

- **No git worktrees in this repo** — this overrides the global "work in a worktree" default. Branch in the main working directory (`git checkout -b`) instead. Reason: the owner reviews changes in Xcode, which is open on this checkout; a separate worktree path puts the code where they can't see it. Branch + PR still apply — don't commit to `main`.
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
- `identifier_name` SwiftLint rule is disabled: test functions are Japanese specification sentences (e.g. `払戻が購入より多い場合に収支がプラスになる()`); SwiftLint has no other way to suppress non-ASCII violations (established on v0.63.3; not re-verified since).
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
- **`IPHONEOS_DEPLOYMENT_TARGET = 26.0` but test destination says `OS=26.5`**: this machine only has the `18.6` and `26.5` simulator runtimes installed — there is no `26.0` runtime, so `26.5` is the lowest available OS that still satisfies the `26.0` minimum. The `iPhone 16` device model only exists under the `18.6` runtime; `26.5` only has `iPhone 17`-generation devices. Don't "fix" the destination back to `iPhone 16`/`18.6` — it will build but is below the actual deployment target.
- **Project Format bumps must go through Xcode's GUI picker, never a hand-typed `objectVersion`**: owner wanted "Xcode 26.3" format; there was no documented mapping to confirm the right integer, and guessing risked the exact silent-corruption failure mode this file already warns about. Owner selected it in Xcode's Project Document inspector instead, which wrote `objectVersion = 100` (jumped from `77` — nowhere near a linear guess, confirming the caution was warranted). Xcode also dropped several now-implicit-default keys (`buildActionMask`, `runOnlyForDeploymentPostprocessing`, `defaultConfigurationIsVisible`, empty `dependencies`/`packageProductDependencies` arrays) as part of the same format upgrade — that's expected format normalization, not data loss.
- **`swipeLeft()` on a `List` row wrapping a `NavigationLink` can silently fail or reveal-then-collapse the delete action within ~1s** on the iOS 26 simulator — confirmed via `xcresulttool` screen-recording frame extraction (`ffmpeg -ss <t> -i recording.mp4 ...`), not an app bug (standard `List` + `ForEach.onDelete` + `NavigationLink`, no custom gesture code). Retry the swipe (see `レース削除Test.testレースをスワイプして削除できる()`) instead of trusting a single `swipeLeft()`.
- **Dev machine upgraded Intel 8GB → Apple M5 32GB (2026-07-10)**: `umalog.xctestplan`'s `parallelizable: true` is intentional on this hardware. The Intel-era `parallelizationEnabled: false` (added in `1657934` for RAM-constrained stability) must not be reintroduced from stale references to that commit.
- **`SWIFT_VERSION = 5.0` in the pbxproj — the build does NOT run in Swift 6 language mode**: measured 2026-08-02 against a Swift 6.3.3 toolchain. Strict concurrency is therefore not enforced at compile time, so `@MainActor`/`Sendable` mistakes surface at runtime rather than as build errors — don't assume a clean build means concurrency-correct. `swiftformat --swiftversion 6.2` is only a formatter dialect flag and does not change the language mode. Never bump `SWIFT_VERSION` as a drive-by fix: it lives in the pbxproj, which must not be hand-edited (see Development Rules).

---

## Open Issues

- [ ] **#34** レース検索機能（キーワード検索）— integrate into the existing `RaceFilterView` sheet, not a separate search screen. Spec settled, unblocked.
- [ ] **#25** iCloud同期 — blocked: Apple Developer Account not subscribed.
- [ ] **#14** マルチプラットフォーム対応（macOS / iPadOS）— low priority.
- [ ] **#1** JRA出走馬自動取得 — blocked: owner must decide on netkeiba URL-paste vs other source, ToS review required.

---

## Current State & Handoff (2026-08-02)

- `main` is clean, no open PRs; PR #35 / #36 (UI test animation disable + swipe-delete retry) are merged. Nothing is in flight.
- Next: **#34** (レース検索機能). See `PLAN.md` for the approach and the one open decision.
- Toolchain drifted since the last handoff (Xcode 26.6, Swift 6.3.3, SwiftLint 0.65.0, SwiftFormat 0.62.1). Unit tests re-verified green on it (2026-08-02); UI tests not yet re-run against it.

---

## Incidents

| Date | What went wrong | Prevention |
| :--- | :--- | :--- |
| 2026-06-30 | Committed and pushed before owner confirmed behavior | Never `git commit` / `git push` without explicit owner instruction |
| 2026-07-01 | PR #21 shipped with venue/grade filter rows completely unresponsive to taps despite 27 passing unit tests | Unit tests on a value type (`RaceFilter`) don't verify View wiring — add an interaction-level UI test or manual Simulator click-through for every new tappable control before merging |
| 2026-07-03 | New UI test asserted `title.contains("1日間")`, which would have silently passed for `"31日間"`/`"21日間"` too — caught locally before merge | Anchor Japanese day-count substring checks with surrounding punctuation or exact match, not bare digit-suffix `contains` |
| 2026-07-10 | `git reset --soft` / `git stash pop` were blocked by the Claude Code auto-mode permission classifier as irreversible-history operations, even after the owner approved via a clarifying question | For git history-rewriting ops during a stash-and-park workflow, have the owner run the command directly in their terminal rather than retrying through the agent |
| 2026-07-10 | Suspected `f05166f`'s accidental `parallelizationEnabled` regression as the root cause of a flaky UI test based on git-history alone; the real cause (swipeLeft gesture flakiness) only surfaced after extracting screen-recording frames from the xcresult bundle | A plausible git-history hypothesis is not confirmation — reproduce and inspect actual failure evidence (xcresult screen recording / accessibility tree) before committing to a root cause |
| 2026-08-02 | This file pointed at `.claude/plans/1-jra-immutable-cascade.md`, which was never git-tracked and had since been lost, and its Open Issues list had gone two issues stale (#34, #25 missing) | Only reference paths that are committed to the repo; anything under an untracked dir must be linked as a GitHub Issue instead |
