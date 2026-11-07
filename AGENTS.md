# Umalog — AGENTS.md

Design docs live in `docs/`: `requirements.md` (why/for whom), `specification.md` (what to build), `architecture.md` (how — policy, ADRs, invariants), `design.md` (how — per-feature detail). Read `architecture.md`'s invariants (CloudKit-compatible models, balance by race date, the 8 prediction marks) before touching a model. When a doc conflicts with the code, trust the code.

---

## Non-Negotiables

**Must never be violated:**
1. Local-only by default — no server, no account, no external data transmission
2. Completely free and unlimited
3. Privacy-first: user data never leaves the device

Never suggest: betting features, external APIs, user accounts, or monetization.
Never add links or buttons to external betting services (即PAT, IPAT, etc.).
App Store: Japan only, age rating 18+. Description and Review Notes must state "no betting features."
iCloud sync (not yet built): default OFF, the user's private iCloud only.

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
# umalog.xctestplan has "codeCoverage": false, so without -enableCodeCoverage YES
# on the unit-test run this reports "No coverage data".
# --only-targets takes no argument; `--only-targets umalogTests` fails with
# "unrecognized file format". Line coverage only — xccov has no branch coverage.

# Combined coverage — target ≥ 85% for umalog.app (owner-agreed 2026-10-31, #43).
# Run both test commands above with -enableCodeCoverage YES and their own
# -resultBundlePath, then merge. A UI run can record umalog.app as 0/0 while all
# tests pass (seen once on 2026-10-31) — rerun it rather than trusting the drop.
xcrun xcresulttool merge unit.xcresult ui.xcresult --output-path merged.xcresult
xcrun xccov view --report --only-targets merged.xcresult

# Mutation tests — skip; Muter crashes (SIGBUS exit 138) on Xcode 26 and, per the
# owner, doesn't support current Xcode (not re-run on 27.1).
# PBT — skip; SwiftCheck isn't adopted until it supports the current Swift
# (owner decision 2026-10-31). Don't add it as a dependency during a quality gate.
# CodeQL — skip; it supports Swift 5.4–6.3 and this project needs Swift 6.4
# (Xcode 27.1, iOS 27 SDK; checked 2026-10-31). Tracing still fails with Rosetta 2
# installed (SwiftPM's sandbox-exec "Bad CPU type", then clang spawn ENOENT).
# Re-run once CodeQL supports Swift 6.4.
# Sanitizers — the ASan runtime links into umalog.app/umalog.debug.dylib, not the
# `umalog` stub; check that file with `otool -L` to confirm instrumentation.
```

### GitHub Actions

`.github/workflows/ios-quality.yml` (`iOS 品質チェック`) provides formatting, lint, build, full unit/UI tests, and an 85% combined app line-coverage gate. A hosted run with unit tests and two UI groups on separate runners took **34 minutes** (Xcode 27.1, 2026-11-05; one measurement, not a guaranteed duration). Consider this cost when choosing between hosted full-suite checks and local checks on the M5 Mac.

- **Automatic runs (#78)**: it runs on a non-draft PR — when it is opened ready, marked Ready for review, or pushed to while ready. Every push to a ready PR costs a full run, so batch review fixes into one push. Draft PRs only get runs whose jobs are all skipped. A new run on the same PR, or converting the PR back to draft, cancels the one in progress (`concurrency` is keyed on `refs/pull/<n>/merge`). PR runs test the merge commit with `main`, not the branch tip; GitHub starts none while the PR has merge conflicts. A manual run on the same branch is a separate concurrency group and is not cancelled. PRs from forks are skipped so outside code never runs on the `xcode-27` runners.

- **Hosted UI test distribution**: balance the groups by measured execution time at test-class granularity. When tests grow or timings drift, use per-class durations from xcresult to rebalance `UI_GROUP_A` so both UI jobs finish at similar times. Group B is the complement, so new classes enter B automatically; check its load after adding tests. Keep this tuning separate from local M5 parallelism.

Manual dispatch requires the workflow to be present on `main`. Push the target branch first, then select it in Actions → iOS 品質チェック → Run workflow, or use:

```bash
gh workflow run ios-quality.yml -R neko3cs/umalog --ref <branch>
gh run list -R neko3cs/umalog --workflow ios-quality.yml --branch <branch> --limit 5
gh run watch <run-id> -R neko3cs/umalog --exit-status
```

Check the run's commit SHA and conclusion; download logs and `.xcresult` bundles from Artifacts (retained for 7 days).

For Claude Code: use the `/test-code` skill to run the full sequence above, but override its iOS default destination (`iPhone 16,OS=latest`) with the one above. Use `iPhone 18 Pro` / `OS=27.0`, matching `IPHONEOS_DEPLOYMENT_TARGET = 27.0` (owner's choice, 2026-09-27); the `18.6` and `26.5` runtimes on this machine are below the deployment target, and `iPhone 16` exists only under `18.6`.

---

## Development Rules

- **No git worktrees in this repo** — this overrides the global "work in a worktree" default. Branch in the main working directory (`git checkout -b`) instead. Reason: the owner reviews changes in Xcode, which is open on this checkout; a separate worktree path puts the code where they can't see it. Branch + PR still apply — don't commit to `main`.
- **Commits**: on a feature branch, commit and push freely — no confirmation needed, including for `AGENTS.md` edits (owner, 2026-10-31; this overrides the global doctrine's "confirm before overwriting AGENTS.md"). Never commit, push, or merge to `main` directly — that goes through a PR the owner merges.
- **No `PLAN.md`** (owner, 2026-11-04): hand-off state goes in a comment on the working Issue or in the PR body. Never point this file at an untracked path — anything not committed goes in an Issue.
- **DocC comments** (`///`) required on all types, properties, and functions. Use `- Returns:`, `- Parameter:`, `- Note:` keywords for Xcode Quick Help.
- **Inline `//`** only for logic a reader would likely misread — never narrate obvious code.
- **ADR numbers in `docs/architecture.md` follow the order the decisions were made**, not topic. Check commit/PR history for the decision date before assigning a number.
- **UIKit only where SwiftUI has no API**: shake-to-undo (`ShakeWindow`, wired through `AppDelegate` / `SceneDelegate`).
- **Every new tappable control needs an interaction-level UI test or a Simulator click-through**: unit tests on a value type (e.g. `RaceFilter`) don't verify the View wiring.
- **UI-test an edit flow from a persisted record opened fresh** (save → reopen from race detail → tap the row), not from an in-session draft — a draft hid #46.
- **Run every new UI test with `-test-iterations 5 -parallel-testing-worker-count 5`** before trusting a single pass.

---

## Tacit Knowledge

### Swift / SwiftUI / SwiftData

- **`RaceGrade.unspecified`, not `.none`**: Swift resolves `.none` as `Optional<RaceGrade>.none` (nil) in `#expect` — the empty/default enum case must be named `.unspecified`.
- **`@MainActor` extension inheritance**: `extension AlreadyMainActorStruct { }` inherits `@MainActor` automatically — re-annotating causes SIGBUS crash in Swift 6.2.
- **`ModelContainer` must be stored before `.mainContext`**: Inline `try ModelContainer(...).mainContext` releases the container immediately; always store in a named `let` first.
- **`SWIFT_VERSION = 5.0` in the pbxproj — the build does NOT run in Swift 6 language mode** (measured with Swift 6.3.3): strict concurrency isn't enforced at compile time, so `@MainActor`/`Sendable` mistakes surface at runtime — a clean build doesn't mean concurrency-correct. `swiftformat --swiftversion 6.2` only picks a formatter dialect. Never bump `SWIFT_VERSION` as a drive-by fix; Swift 6 mode is a deliberate, owner-approved change.
- **Save explicitly right after inserting a record that is shown at once — and only then**: a just-inserted SwiftData model has a temporary ID until autosave (observed 5–11 s later, or on backgrounding) swaps it for a permanent one. At the swap, `ForEach` rows keyed by that ID are rebuilt (UI tests fail with "Activation point invalid", #55); a model passed straight to `.sheet(item:)` rebuilds the sheet and wipes its `@State` (#53, hence `EditTarget`); a master used as a `Picker` option changes hash and crashes with `KEY_TYPE_OF_DICTIONARY_VIOLATES_HASHABLE_REQUIREMENTS`. In-place edits keep their IDs — leave those to autosave. When adding a save, check what else is pending in the context (seeded or master inserts) and save it at its own insert site. Every explicit save carries a comment saying why it can't wait.
- **`.sheet(isPresented:)` + a separate `@State` for the edit target reads a stale value on first presentation** (#46). Drive edit sheets with `.sheet(item:)` and pass the target in (see `SelectionFormTarget` in `BetFormView.swift`).
- **`Toggle` with a custom `Binding(get:set:)` inside `Form`/`List` rows can silently fail to register taps** — real Simulator clicks, not an XCUITest artifact. Use a `Button` + checkmark row for per-item multi-select rows.

### Data & backups

- **ZIP backup memo filenames**: `<yyyyMMdd>_<venue>_R<n>_<raceName>.md` (venue + race number stop same-named races at different venues from overwriting each other's memo). `ZipImporter` must keep the legacy `<yyyyMMdd>_<raceName>` fallback — users' existing backups depend on it.
- **ZIP backups carry no master data**: `TicketType` / `Venue` are not exported; `ZipImporter` re-links records to the target device's masters by name. An unlinked selection opens as the old custom ticket type on edit (#48). Owner decision (2026-10-20): enforce this only at ZIP import — no launch-time scans or save-time integrity checks. Already-imported unlinked data is fixed by exporting and re-importing.

### Tooling

- **Keep CI orchestration in YAML**: use jq for JSON processing rather than adding helper scripts solely for CI; the owner prioritizes fewer files and less code to read.
- **CI output must serve a purpose**: retain results and actionable diagnostics; avoid precautionary prints, redundant summaries, and unnecessary progress output.
- **SwiftLint `type_body_length` in tests**: 400-line limit per declaration. Move overflow tests into a bare `extension MyTest { }` — SwiftLint counts each body separately. No `@MainActor` on the extension (see above).
- **SwiftLint `file_length` (700) / `type_body_length` in views**: split the view into its own file and move helpers into an `extension` in that same file — a same-file extension can still reach the type's `private` members (see `SelectionFormView.swift`).
- **`identifier_name` is disabled in SwiftLint**: test functions are Japanese specification sentences (e.g. `払戻が購入より多い場合に収支がプラスになる()`); SwiftLint can't suppress non-ASCII violations any other way (v0.63.3).
- **swiftformat rewrites plain-identifier test names** (`swiftTestingTestCaseNames`, 0.64.4): it turns them into backticked raw identifiers, lower-cases ASCII acronyms (`ID`, `URL` → `id`, `url`) and puts spaces around numbers — including kanji numerals (`一覧` → `一 覧`, `三連複` → `三 連複`, `二重` → `二 重`). Names already in backticks are left alone, so write such names backticked from the start (`` `三連複の軸 1 頭流し…` ``), avoid acronyms (`識別子`, `場所`), and re-check the `func` lines after formatting.
- **Project Format bumps go through Xcode's GUI picker, never a hand-typed `objectVersion`**: there is no documented version→integer mapping ("Xcode 26.3" wrote `100`, from `77`). Xcode also drops now-default keys (`buildActionMask`, empty `dependencies`, …) during the bump — that's normalization, not data loss.
- **ZIPFoundation 0.9.20 deprecation warning** (`'v4' is deprecated: watchOS 9.0 ...`) comes from its `Package@swift-5.9.swift`, not our code. Fixed upstream in `676ffa3` but unreleased; owner chose to wait for the next release — don't pin to `main`.
- **Agent sandbox and git/gh** (seen in Claude Code, 2026-11-04, git 2.54.0): the sandbox denies writes to `.git/config`, so `git push -u` pushes but can't record the upstream — push without `-u`. `error: fsmonitor_ipc__send_query ...` on every git command is harmless noise. `gh` fails TLS verification (`x509: OSStatus -26276`) even with `api.github.com` allowed — run `gh` outside the sandbox.
- **`gh issue view <n> --comments` prints nothing when piped** (gh 2.103.3, 2026-11-08): exit 0, zero bytes — it looks like an empty Issue. Use `gh issue view <n> --json title,body,comments` instead.
- **History-rewriting git ops** (`git reset --soft`, `git stash pop`, …): the agent's permission classifier blocks them even after the owner approves in chat. Ask the owner to run them in their own terminal instead of retrying.

### Running tests

- **`xcodebuild -resultBundlePath` fails if the bundle already exists**: `rm -rf` it first — but only after its failures are examined; never in the same command that runs the suite.
- **Boot the destination simulator before `xcodebuild`** (`xcrun simctl boot <udid> && xcrun simctl bootstatus <udid> -b`): unbooted, it fails with "Early unexpected exit, operation never finished bootstrapping" or, on the iOS 27.0 runtime, hangs silently for 10+ min at 0% CPU.
- **Judge a run by the log's `** TEST … **` line and `xcresulttool get test-results summary`**: under Xcode 27.1 `xcodebuild` can stay alive at 0% CPU after `** TEST SUCCEEDED **`, or stop mid-run (`** BUILD INTERRUPTED **`) with no failing test — kill it and rerun.
- **`The iOS 27.0 simulator runtime is not available` while `xcrun simctl runtime list` shows it Ready**: CoreSimulator lost the mount — `killall -9 com.apple.CoreSimulator.CoreSimulatorService`, boot the device, rerun.
- **Before calling an intermittent UI-test failure a flake, check the xcresult** (UI hierarchy, crash log, screen recording — `ffmpeg -ss <t> -i recording.mp4 ...`) for wrong app state: #53 / #55 looked like flakes but were temporary-ID bugs. Only "Lost connection to the application" on a parallel clone (Xcode 27.0) is a known simulator flake — rerun that test alone with `-parallel-testing-enabled NO`.
- **`umalog.xctestplan` is set up for the M5 32GB machine**: `parallelizable: true` is intentional — don't reintroduce the Intel-era `parallelizationEnabled: false` (`1657934`).
- **Test diagnostics are off (`"diagnosticCollectionPolicy" : "Never"`, #50)**: with them on, xcodebuild collected iOS 27 system-process crash reports even on all-pass runs and hit a 600 s timeout. It was set in Xcode's test plan editor (Configurations › Shared Settings › Diagnostics) — don't hand-type it. It covers unit tests too and still keeps failure messages, screenshots, UI hierarchy, screen recordings and the app's own crash log. The worker count (5, fastest measured) can only be set with `-parallel-testing-worker-count`, not in the test plan or scheme. Test plan options are baked into the `.xctestrun` by `build-for-testing` — rebuild before `test-without-building`. Splitting the heavy classes gave no speed-up.
- **A failure inside a shared UI-test helper reports the helper's file and line** (e.g. `ScenarioTests.swift:38` for a `tapWhenReady` timeout). Check `sourceLocation.filePath` in `xcresulttool get test-results test-details`.

### Simulator & XCUITest

- **Manual Simulator checks: launch with `--UITesting`**: `xcrun simctl launch <udid> net.neko3cs.umalog --UITesting` uses the in-memory store. A plain launch (or tapping the home-screen icon) opens the owner's real data on the shared `iPhone 18 Pro` simulator — never save anything there.
- **Calendar/locale-dependent behaviour needs a relaunch with `-AppleLocale`**: `Locale.current` can't be changed from inside the process (setting `AppleLocale` in `UserDefaults` has no effect), so unit tests always run in the simulator's calendar. Launch the app with `["-AppleLocale", "ja_JP@calendar=japanese"]` (or `@calendar=buddhist`) from a UI test — see `暦法の違うZIP往復Test`, which exports, relaunches in another calendar and restores from the ZIP left in the temp directory.
- **Non-ASCII text can't be pushed to the Simulator clipboard from the agent**: `xcrun simctl pbcopy` fails on Japanese text (`NSCocoaErrorDomain 261`), and so does the iOS Simulator control tool's `text` action; `pbpaste` returns empty. Use ASCII-only payloads, or ask the owner to `pbcopy` a file.
- **Long text in UI tests: paste it, don't `typeText` it**: typing a multi-line string into a `TextEditor` / vertical `TextField` in a `Form` grows the row and pushes later rows off-screen. Set `UIPasteboard.general.string` and tap `app.buttons["Paste"]`, then assert the result `isHittable`, not just that it exists (see `JSON取り込みTest.test長いJSONを貼って確認してもエラーが画面内に表示される`).
- **Japanese day-count strings in assertions must be anchored**: `label.contains("1日間")` also matches `"21日間"`. Use `"(1日間)"` or exact equality.
- **XCUITest sees a `LabeledContent` row as one element labelled `"<label>, <value>"`**: query `app.staticTexts["買い目, 1>2,3[流し]"]` (see `流し馬券追加Test.sheetValue`). Rows scrolled out of a `Form` aren't in the accessibility tree — `swipeUp()` first. A sheet over the race detail leaves the same `StaticText` behind it — filter by `isHittable`.
- **Toolbar buttons must have `.accessibilityIdentifier`**: with several `ToolbarItem(.navigationBarTrailing)` items, `app.navigationBars["X"].buttons["Add"]` races SwiftData's re-render. Use `findElement("id")` / `tapWhenReady` in UI tests.
- **XCUITest element quirks on iOS 27.0**: a compact `DatePicker` in a `Form` row has no label — assert on the row title (`app.staticTexts["開始日"]`). In export mode, `UIDocumentPickerViewController`'s Cancel is an `Other` element — query `descendants(matching: .any)`. The top of a sheet's `TextEditor` sits under the nav bar: tap lower (`dy: 0.3`) and retry until `app.keyboards` appears. `swipeDown()` on an unscrolled sheet dismisses it.
- **`swipeLeft()` on a `List` row wrapping a `NavigationLink` can fail or reveal-then-collapse the delete action** (iOS 26 simulator; not an app bug). Retry the swipe (see `レース削除Test.testレースをスワイプして削除できる()`).
- **Swipe-to-delete on plain `List` rows**: `swipeLeft()` starts at the element's centre, so on a narrow `StaticText` it barely moves; dragging to the left edge full-swipes and deletes without showing the button. Drag from x≈360 to x≈220 (see `swipeToDelete(rowLabeled:)` in `DetailScenarioTests.swift`).
- **Shake-to-undo can't be driven from XCUITest** (no shake API): the undo closures in `RaceDetailView` and `ContentView`'s undo alert stay uncovered by design — don't chase them for coverage.
- **The system document picker can't be driven end-to-end from UI tests**: on parallel clones, taps on a file cell are ignored; saving onto an existing same-named file fails silently; and the picker opens in the last-used folder — the owner's `このiPhone内/Backup` on the shared simulator (with `-parallel-testing-worker-count 1` no clone is used, so exports land in the owner's Files). Test the round trip with `--UITestingSkipDocumentPicker` (`ZIP往復Test`) and the post-pick code in `DocumentPickerCoordinatorTests.swift`; keep picker UI tests to open-and-cancel.
