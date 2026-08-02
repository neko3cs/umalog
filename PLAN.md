# PLAN.md

## Goal
- Issue #34: add keyword search to the existing race filter.

## Approach
- Extend `RaceFilter` with a `keyword: String` field and a `matchesKeyword(_:)` predicate chained into the existing `apply(to:)` `&&` chain (`src/umalog/Views/RaceFilterView.swift:34`): every condition there is already a `matchesX` private method, so AND-composition with venue/category/grade/date and the existing "条件に一致するレースがありません" empty state both come for free.
- Keyword matches if it is a substring of any one of `Race.raceName`, `Race.memo`, `RaceEntry.horseName`, `RaceEntry.jockeyName` (OR within the keyword condition). `Race.entries` is `[RaceEntry]?`, so the to-many hop must nil-coalesce before searching.
- Filter in memory over `[Race]` rather than pushing into a SwiftData `#Predicate`: the OR spans a to-many relationship, and the four sibling conditions are already in-memory — splitting the evaluation across two layers would be the bigger cost at this data scale.

## Rejected
- A dedicated search screen or a separate search button: owner scoped this out in #34 — keyword input belongs inside the existing filter sheet, nowhere else.
- External API or a full-text search engine for speed: scoped out in #34, and it would violate the local-only Non-Negotiable in `AGENTS.md`.

## Next
- Add `keyword` to `RaceFilter` (field + `isActive` + `matchesKeyword`) with unit tests in `src/umalogTests/RaceFilterTests.swift`, then wire the `TextField` into `RaceFilterView` and the removable chip into `FilterChipsView`.
- Note for the UI step: a new tappable/editable control here must get an interaction-level UI test, not just `RaceFilter` unit tests — that exact gap shipped the broken filter rows in PR #21 (see the 2026-07-01 incident in `AGENTS.md`). Also prefer a plain `TextField`; `Toggle` with a custom `Binding` inside `Form` rows is a known-dead control in this project.

## Undecided
- Should keyword matching be case-insensitive / diacritic-insensitive, and should kana be normalized (hiragana vs katakana, half- vs full-width)? #34 says only 部分一致. This is spec-level — file it as a comment on Issue #34 before implementing the matcher.
- Is `SWIFT_VERSION = 5.0` in the pbxproj intentional, given the project documents itself as Swift 6.2 and the toolchain is now 6.3.3? Swift 5 language mode means strict concurrency is not enforced at compile time. Worth its own Issue; do not change it as part of #34.
