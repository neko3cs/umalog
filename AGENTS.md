# Umalog — AGENTS.md

A personal iOS app for recording horse racing predictions and balance tracking.

---

## Key References

- **`docs/Design.md`** — Original design document covering app concept, feature requirements, data model intent, and App Store policy. Written before implementation began and not kept up to date, so treat it as background context rather than a description of current behavior. When it conflicts with the code, trust the code.

---

## What This App Is (and Is Not)

Umalog is a **self-contained record-keeping tool**. It never places or intermediates bets.

**Three non-negotiables — must never be violated:**
1. Local-only by default (no server, no account, no external data transmission)
2. Completely free and unlimited
3. Privacy-first: user data never leaves the device

Never suggest: betting features, external APIs, user accounts, or monetization.

---

## Architecture

- **UI**: SwiftUI (iOS 18+, Swift 6.2)
- **Persistence**: SwiftData
- **UIKit**: `ShakeWindow` only — shake-to-undo (SwiftUI has no native shake API)

## Data Models

Transaction: `Race` → `RaceEntry` (出走馬), `Race` → `Bet` → `BetSelection` (買い目)
Master: `Venue` (競馬場), `TicketType` (券種)
`PredictionMark` is an enum (8 fixed values) — not a SwiftData model.

## Screens

- `RaceListView` — race list, home tab
- `RaceDetailView` — race detail with entries and bets
- `RaceFormView` / `RaceEntryFormView` / `BetFormView` — input forms
- `BalanceSummaryView` — balance aggregation by daily / monthly / yearly / custom period
- `SettingsView` — app settings

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

# Mutation tests — currently broken on Xcode 26 beta (SIGBUS exit 138), skip
cd src && muter run --configuration muter.conf.yml
```

For Claude Code: use the `/test-ios-project` skill to run the full sequence above.

---

## Development Rules

### File Operations
- Never edit `.pbxproj` — a malformed edit silently breaks the build with no clear error.
- New Swift files: owner adds via Xcode GUI first, then AI writes the code content.

### Code Comments
Documentation comments (`///`) must be used on all types, properties, and functions. Use DocC keywords so Xcode Quick Help renders them correctly:

```swift
/// Calculates the net balance for this race.
///
/// - Returns: Total payout minus total purchase across all bets.
/// - Note: Unsettled bets (payoutAmount == 0) are counted as ¥0 payout.
var balance: Int { ... }
```

Inline `//` comments are reserved for logic a reader would likely misread without explanation. Must not be used to narrate what the code obviously does.

### Commits
Must not commit until the owner has explicitly confirmed the behavior. Always wait for the instruction.

---

## Why Certain Decisions Were Made

### `.pbxproj` is off-limits
Xcode regenerates it in opaque ways. Merge conflicts or malformed edits silently break the build with no actionable error message.

### CloudKit compatibility is enforced from day one
Adding CloudKit to an existing SwiftData schema requires all properties to be optional and bans `@Attribute(.unique)`. Retrofitting this after the fact would mean a risky, painful migration — so the constraints are baked in upfront even though CloudKit isn't active yet.

### `identifier_name` SwiftLint rule is disabled
Unit test functions are named as Japanese specification sentences (e.g. `払戻が購入より多い場合に収支がプラスになる()`). SwiftLint v0.63.3's `validates_start_with_lowercase` option does not suppress violations for non-ASCII identifiers — the only working fix is disabling the rule entirely in both `.swiftlint.yml` files.

### Test names are Japanese specification sentences
Tests follow TDD behavior-spec style: the function name IS the specification. The test suite is a living requirements document. This is intentional and non-negotiable.

### ShakeWindow exists alongside SwiftUI
SwiftUI has no native shake gesture API. `ShakeWindow` overrides `UIWindow.motionEnded` and posts to `undoManager`. It is the only UIKit component in the app.

### Muter is configured but currently broken
Muter crashes with SIGBUS (exit 138) on Xcode 26 beta due to SwiftSyntax incompatibility. Do not try to work around it — skip the mutation step until Muter releases a compatible version.

---

## Implicit Constraints

- **Ordering**: must use `sortIndex: Int = 0` — never use SwiftData ordered relationships (CloudKit incompatible).
- **Relationships**: must be optional (`?`) — CloudKit requirement.
- **iCloud sync**: default OFF when implemented. User's private iCloud only. Not yet implemented.
- **Balance aggregation**: keyed by race **date**, not insert time. Unsettled bets = ¥0 payout.
- **Prediction marks**: exactly 8 fixed values (`◎ ○ ▲ △ ☆ 注 押 消`). Must not add or remove marks.

---

## Current State (2026-06-23)

- Unit tests: 172 cases, all green. UI tests: 21 cases, all green.
- Coverage: model layer ~100%, `umalogTests` target 99.49%.
- SwiftFormat + SwiftLint: fully configured and passing.
- Muter: skipped (Xcode 26 beta incompatibility — awaiting upstream fix).
- Apple Developer Account: not yet subscribed — CloudKit and App Store submission blocked.

---

## Distribution and Review Policy

- Japan only, age rating 18+.
- Never add links or buttons to external betting services (即PAT, IPAT, etc.).
- App Store description and Review Notes must state: "This is a record-keeping app with no betting features."
- Source is publicly available on GitHub (OSS).
