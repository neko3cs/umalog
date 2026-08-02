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
- Not started yet. This repo doesn't use worktrees (see `AGENTS.md`), and the checkout is currently on `docs/restructure-design-docs` with PR #37 open under owner review. Wait for that branch to be merged/closed (or explicitly set aside) before checking out a new branch for #34 — only one branch can be on disk for the owner to see in Xcode at a time.
- Once clear to start: add `keyword` to `RaceFilter` (field + `isActive` + `matchesKeyword`) with unit tests in `src/umalogTests/RaceFilterTests.swift`, then wire the `TextField` into `RaceFilterView` and the removable chip into `FilterChipsView`.
- Note for the UI step: a new tappable/editable control here must get an interaction-level UI test, not just `RaceFilter` unit tests — that exact gap shipped the broken filter rows in PR #21 (see the 2026-07-01 incident in `AGENTS.md`). Also prefer a plain `TextField`; `Toggle` with a custom `Binding` inside `Form` rows is a known-dead control in this project.

## Undecided
- Should keyword matching be case-insensitive / diacritic-insensitive, and should kana be normalized (hiragana vs katakana, half- vs full-width)? #34 says only 部分一致. This is spec-level — file it as a comment on Issue #34 before implementing the matcher.
- `SWIFT_VERSION = 5.0` (Swift 5 language mode, not 6): now documented as a standing fact in `AGENTS.md` Tacit Knowledge — don't touch it as part of #34. Whether it's an intentional choice or an oversight is still genuinely unknown and would need its own Issue if pursued; not blocking #34.
