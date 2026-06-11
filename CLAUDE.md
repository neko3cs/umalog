# Umalog — CLAUDE.md

A personal iOS app for recording horse racing predictions and balance tracking. No betting, brokerage, or payment features — purely a self-contained record-keeping tool.

## Project Structure

- `src/umalog.xcodeproj` — Xcode project
- `src/umalog/` — App source (SwiftUI)
- `Design.md` — Design document (source of truth for requirements and policies)

## Development Rules

### File Operations
- **Never edit `.pbxproj`** (risk of corruption)
- **New Swift files must be added manually via Xcode GUI** — Claude Code only writes the code content

### Architecture
- UI: SwiftUI
- Persistence: SwiftData
- Minimum deployment target: **iOS 18**

## Data Model Constraints (CloudKit Compatibility)

Design for CloudKit compatibility from the start so iCloud sync can be added later without pain.

1. Never use `@Attribute(.unique)`
2. All properties must be optional or have default values
3. All relationships must be optional (`?`)
4. Use a numeric field (e.g. `sortIndex: Int = 0`) for ordering — never use ordered relationships
5. Keep schema changes within lightweight migration scope after CloudKit is enabled

## Feature Specs

### Prediction Marks
- 8 fixed marks: ◎ ○ ▲ △ ☆ 注 押 消
- One mark per horse per race (no multiple marks)
- Marks belong to `RaceEntry`, not `Horse` (same horse can have different marks in different races)

### Balance Tracking
- One race has many bets (Race 1 — Bet n)
- Balance aggregation is based on **race date**
- Unsettled bets (awaiting results): treat payout as **¥0**
- Return rate = total payout ÷ total purchase
- Aggregation periods: daily / monthly / yearly

### iCloud Sync
- **Default OFF**
- Enable only when the user explicitly turns it on in settings
- Sync target is the user's own private iCloud only (no public/shared DB)
- Not yet implemented — Apple Developer Account not yet subscribed

## Distribution and Review Policy

- Distribution region: **Japan only**
- Age rating: high (18+ equivalent)
- No links or buttons to betting sites (e.g. 即PAT/IPAT)
- App description and App Review Notes must state: "This is a record-keeping app with no betting features"
