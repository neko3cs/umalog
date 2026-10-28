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

- **UI**: SwiftUI (`IPHONEOS_DEPLOYMENT_TARGET = 27.0`) — **Persistence**: SwiftData — **UIKit**: `ShakeWindow` only (shake-to-undo; SwiftUI has no native shake API)
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
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0' \
  -only-testing:umalogTests \
  -enableCodeCoverage YES -resultBundlePath src/TestResults.xcresult

# UI tests
xcodebuild test -project src/umalog.xcodeproj -scheme umalog \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0' \
  -only-testing:umalogUITests \
  -parallel-testing-worker-count 5
# Diagnostics are off in umalog.xctestplan. On a failure, rerun just that test
# (-only-testing:umalogUITests/<Class>/<test>()) with -collect-test-diagnostics
# on-failure — the flag overrides the test plan — to get simulator logs and crash reports.

# Coverage
xcrun xccov view --report --only-targets src/TestResults.xcresult
# umalog.xctestplan has "codeCoverage": false (since 33c7ce9), so without
# -enableCodeCoverage YES on the unit-test run this reports "No coverage data".
# --only-targets takes no argument; `--only-targets umalogTests` fails with
# "unrecognized file format". Line coverage only — xccov has no branch coverage.

# Mutation tests — skip; Muter crashes (SIGBUS exit 138) on Xcode 26
```

For Claude Code: use the `/test-ios-project` skill to run the full sequence above, but override its default destination (`iPhone 16,OS=latest`) with the one above — no `iPhone 16` exists under the iOS 27.0 runtime.

---

## Development Rules

- **No git worktrees in this repo** — this overrides the global "work in a worktree" default. Branch in the main working directory (`git checkout -b`) instead. Reason: the owner reviews changes in Xcode, which is open on this checkout; a separate worktree path puts the code where they can't see it. Branch + PR still apply — don't commit to `main`.
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
- **SwiftLint `file_length` (700) / `type_body_length` in views**: split the view into its own file and move helpers into an `extension` in that same file — a same-file extension can still reach the type's `private` members (see `SelectionFormView.swift`).
- **Toolbar buttons must have `.accessibilityIdentifier`**: With multiple `ToolbarItem(.navigationBarTrailing)` items, `app.navigationBars["X"].buttons["Add"]` races against SwiftData's re-render in XCUITest — `waitForExistence` on the bar then `tap()` on a child element can miss. Always set `.accessibilityIdentifier` on toolbar buttons and use `findElement("id")` / `tapWhenReady` in UI tests.
- **`Toggle` with a custom `Binding(get:set:)` inside `Form`/`List` rows can silently fail to register taps**: confirmed via real mouse clicks in the Simulator (not an XCUITest artifact) — a sibling `Picker` bound directly to `$filter.category` in the same sheet worked fine. Prefer a `Button` + checkmark row over `Toggle` for per-item multi-select rows in a `Form`/`List`.
- **Japanese day-count strings in UI test assertions must be anchored, not bare-`contains`**: `label.contains("1日間")` false-matches `"21日間"`/`"31日間"` since digits aren't word-bounded. Anchor with surrounding punctuation (e.g. `"(1日間)"`) or use exact string equality.
- **ZIP backup memo filenames**: current format is `<yyyyMMdd>_<venue>_R<n>_<raceName>.md` (venue + race number added 2026-07-04 to stop same-named races at different venues from overwriting each other's memo). `ZipImporter` must keep the legacy `<yyyyMMdd>_<raceName>` fallback — users' existing backups depend on it.
- **`xcodebuild -resultBundlePath` fails if the bundle already exists**: `rm -rf src/TestResults.xcresult` first. A failure "Early unexpected exit, operation never finished bootstrapping" usually means the destination simulator isn't booted — `xcrun simctl boot` it and retry. On the iOS 27.0 runtime an unbooted destination can instead hang `xcodebuild` silently for 10+ min (0% CPU, no output) — boot it first (`xcrun simctl boot <udid> && xcrun simctl bootstatus <udid> -b`). Separately, `xcodebuild` can stay alive at 0% CPU after printing `** TEST SUCCEEDED **`, or stop mid-run (simulator shut down / `** BUILD INTERRUPTED **`) under Xcode 27.1 — judge the run by the log's `** TEST … **` line and `xcresulttool get test-results summary`, then kill it and rerun if needed; no failing test is involved.
- **Test destination is `iPhone 18 Pro` / `OS=27.0`, matching `IPHONEOS_DEPLOYMENT_TARGET = 27.0`** (owner's choice, 2026-09-27). This machine still has the `18.6` and `26.5` simulator runtimes installed, but both are below the deployment target — don't pick them as a destination (`iPhone 16` exists only under `18.6`).
- **iOS 27.0 parallel UI tests: "Lost connection to the application" is a simulator-clone flake, not an app bug**: seen 2026-09-27 on Xcode 27.0 (1/27 failed with that message plus one `xctrunner` launch-denied error on a clone); the same test passed 3/3 when rerun alone with `-parallel-testing-enabled NO`. Rerun the single test before investigating app code.
- **Project Format bumps must go through Xcode's GUI picker, never a hand-typed `objectVersion`**: there is no documented version→integer mapping, and a wrong guess can silently break the project. Picking "Xcode 26.3" in the Project Document inspector wrote `objectVersion = 100` (from `77` — nowhere near a linear guess). Xcode also drops now-default keys (`buildActionMask`, `runOnlyForDeploymentPostprocessing`, empty `dependencies` arrays, …) during the bump — that's normalization, not data loss.
- **`swipeLeft()` on a `List` row wrapping a `NavigationLink` can silently fail or reveal-then-collapse the delete action within ~1s** on the iOS 26 simulator — confirmed via `xcresulttool` screen-recording frame extraction (`ffmpeg -ss <t> -i recording.mp4 ...`), not an app bug (standard `List` + `ForEach.onDelete` + `NavigationLink`, no custom gesture code). Retry the swipe (see `レース削除Test.testレースをスワイプして削除できる()`) instead of trusting a single `swipeLeft()`.
- **Dev machine upgraded Intel 8GB → Apple M5 32GB (2026-07-10)**: `umalog.xctestplan`'s `parallelizable: true` is intentional on this hardware. The Intel-era `parallelizationEnabled: false` (added in `1657934` for RAM-constrained stability) must not be reintroduced from stale references to that commit.
- **`SWIFT_VERSION = 5.0` in the pbxproj — the build does NOT run in Swift 6 language mode**: measured 2026-08-02 against a Swift 6.3.3 toolchain. Strict concurrency is therefore not enforced at compile time, so `@MainActor`/`Sendable` mistakes surface at runtime rather than as build errors — don't assume a clean build means concurrency-correct. `swiftformat --swiftversion 6.2` is only a formatter dialect flag and does not change the language mode. Never bump `SWIFT_VERSION` as a drive-by fix: switching to Swift 6 mode turns on strict concurrency project-wide and is a deliberate, owner-approved change.
- **ADR numbers in `docs/architecture.md` follow the chronological order of the decisions, not topical grouping**: owner reordered ADR-007/008 back to decision order in the PR #37 review (2026-08-02). Check commit/PR history for when a decision was actually made before assigning a number.
- **`.sheet(isPresented:)` + a separate `@State` for the edit target reads a stale value on first presentation**: the sheet opened as "add" instead of "edit" (#46). Drive edit sheets with `.sheet(item:)` and pass the target in (see `SelectionFormTarget` in `BetFormView.swift`).
- **XCUITest sees a `LabeledContent` row as one element labelled `"<label>, <value>"`**: query `app.staticTexts["買い目, 1>2,3[流し]"]`, not the bare value (see `流し馬券追加Test.sheetValue`). Rows scrolled out of a `Form` are not in the accessibility tree at all — `swipeUp()` before asserting on lower sections. A sheet over the race detail leaves the same `StaticText` in the tree behind it — filter by `isHittable`.
- **ZIP backups carry no master data**: `TicketType` / `Venue` are not exported; `ZipImporter` re-links records to the target device's masters by name. A selection imported without that link opens as "カスタム券種" on edit (#48). Owner decision (2026-10-20): enforce this only at ZIP import — do not add launch-time scans or save-time integrity checks (custom ticket types are being removed in #40). Already-imported unlinked data is fixed by exporting and re-importing.
- **ZIPFoundation 0.9.20 deprecation warning** (`'v4' is deprecated: watchOS 9.0 is the oldest supported version`) comes from its `Package@swift-5.9.swift`, not our code. Fixed upstream in `676ffa3` but unreleased; owner chose to wait for the next release — don't pin to `main`.
- **Test diagnostics are off in `umalog.xctestplan` (`"diagnosticCollectionPolicy" : "Never"`); UI tests run with 5 workers (#50, measured 2026-10-26 on the M5 32GB machine)**: under the default, xcodebuild collected simulator diagnostics even on all-pass runs (4 of 5 runs; iOS 27 simulator system processes such as PosterBoard / intelligencetasksd crash constantly) and then hit a 600 s timeout (`Failure collecting diagnostics from simulator`). Wall time for all 33 UI tests, build excluded: diagnostics on — 5 workers 863 s, 4: 310 s (no timeout that run), 3: 933 s, 2: 1023 s, 1: 1335 s; off — 5: 287–293 s, 4: 295 s, 3: 330 s, 2: 414 s, 1: 726 s. The policy was set through Xcode's test plan editor (Configurations › Shared Settings › Diagnostics) — it wrote `"Never"`, capitalised; don't hand-type it. It applies to unit tests too (owner's choice, 2026-10-26); `never` still keeps failure messages, activity logs, screenshots, UI hierarchy, screen recordings and the app's own crash log, and drops CoreSimulator / Simulator logs and simulator system-process crash reports. The worker count cannot live in the test plan or the scheme — only `-parallel-testing-worker-count` sets it, so Xcode's GUI picks its own count. Test plan options are baked into the `.xctestrun` by `build-for-testing`, so rebuild before `test-without-building` after changing them. Splitting the heavy classes (`流し馬券追加Test`, `馬券追加Test`) made no measurable difference and was reverted.
- **Save explicitly right after inserting a record that is shown at once — and only then**: a just-inserted SwiftData model has a temporary ID until autosave (observed 5–11 s later, or on backgrounding) swaps it for a permanent one. At the swap, `ForEach` rows keyed by that ID are torn down and rebuilt (UI tests then see `{{inf, inf}, {0, 0}}` frames and fail with "Activation point invalid", #55); a model passed straight to `.sheet(item:)` rebuilds the sheet and wipes its `@State` (#53, hence `EditTarget`); a master used as a `Picker` option changes hash and crashes with `KEY_TYPE_OF_DICTIONARY_VIOLATES_HASHABLE_REQUIREMENTS`. In-place edits keep their IDs — leave those to autosave. Every explicit save carries a comment saying why it can't wait.
- **Long text in UI tests: paste it, don't `typeText` it**: typing a multi-line string into a `TextEditor` / vertical `TextField` inside a `Form` grows its row past `.frame(height:)` / `lineLimit` and pushes later rows off-screen; pasting the same text does not (found 2026-10-28 from the xcresult screen recording). Set `UIPasteboard.general.string` in the test and tap `app.buttons["Paste"]` (see `JSON取り込みTest.test長いJSONを貼って確認してもエラーが画面内に表示される`).
- **Manual Simulator checks: launch with `--UITesting`**: `xcrun simctl launch <udid> net.neko3cs.umalog --UITesting` uses the in-memory store. A plain launch (or tapping the home-screen icon) opens the owner's real data on the shared `iPhone 18 Pro` simulator — never save anything there.
- **Non-ASCII text can't be pushed to the Simulator clipboard from the agent**: `xcrun simctl pbcopy` fails on Japanese text (`NSCocoaErrorDomain 261`), and so does the iOS Simulator control tool's `text` action (it goes through the clipboard). `pbpaste` from the agent shell also returned empty. Use ASCII-only payloads, or ask the owner to `pbcopy` a file (the Simulator syncs the Mac clipboard).

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
| 2026-10-19 | PR #45's UI test re-opened an unsaved draft after the selection sheet had already been shown once, so it passed while tapping a saved bet's selection opened a blank "add" sheet (#46) | UI-test edit flows from a persisted record opened fresh (save → reopen from race detail → tap the row), not from an in-session draft |
| 2026-10-24 | UI tests failing only under parallel load looked like simulator flakes but were real temporary-ID bugs (#53 lost edits, #55 rebuilt rows) | Before calling an intermittent UI test failure a flake, check the xcresult UI hierarchy and crash log at the failure for wrong app state |
| 2026-10-26 | Adding `save()` after record inserts crashed the app: seeded masters were still unsaved and changed ID inside a `Picker` | When adding an explicit save, check what else is pending in the context (seeded or master inserts) and save it at its own insert site |
| 2026-10-28 | JSON import UI tests used one-line JSON, so an error rendered below a tall input field (off-screen; "確認が反応しない") still passed — the owner found it in the Simulator | Test long input the way users enter it (multi-line paste) and assert the result `isHittable`, not just that it exists |
| 2026-10-28 | Deleted the UI test xcresult in the same command that ran the suite, so 2 failures under parallel load could only be re-run, not inspected | Keep each run's `-resultBundlePath` until its failures are examined; delete it afterwards |
