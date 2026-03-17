# Day Activity Tracker — Codex Instructions

Read this file first. Then read `PRODUCT_SPEC.md` and `ACCEPTANCE_TESTS.md` before making changes.

## Goal
Build a complete native iPhone app called **Day Activity Tracker** from scratch.

## Non-negotiable stack
- SwiftUI
- SwiftData
- Swift Charts
- iPhone-only MVP
- iOS 17+
- Local-only storage for v1
- No login
- No backend
- No third-party dependencies

## Product decisions already made
- Root tabs, in this exact order: **History**, **Home**, **Reports**
- Default selected tab on launch: **Home**
- Week starts on **Monday**
- Local-only storage, no sync for v1
- Manual backfilling is allowed
- If a session crosses midnight:
  - **History must split it into both days visually**
  - **Reports must split it across day boundaries for aggregation**
- Reports aggregate by **top-level category** only for MVP
- Sub-activities exist only for **Active Learn** and **Passive Learn**
- At most one active session may exist at any time
- Gaps are allowed; do not infer missing activities

## Delivery standard
- Produce a real, compiling Xcode project
- Do not stop at pseudocode or scaffolding
- No TODO placeholders for core features
- Prefer correctness and maintainability over fancy styling
- Use a clean, feature-based structure
- Add previews and unit tests
- Keep the UI simple, native, and fast

## Required development workflow
1. Start by reading `PRODUCT_SPEC.md` and `ACCEPTANCE_TESTS.md`.
2. Write a short execution plan into `PLAN.md` before major implementation.
3. Implement in small, reviewable passes.
4. After each meaningful pass:
   - build the app
   - run relevant tests
   - fix failures before moving on
5. Keep a brief progress log in `PROGRESS.md`.
6. If you need to make a tradeoff, document it in `README.md` under assumptions/limitations.

## Build and validation expectations
Assume Xcode is installed. Prefer command-line validation during development.

Use commands like:
- `xcodebuild -list`
- `xcodebuild -scheme DayActivityTracker -destination 'platform=iOS Simulator,name=iPhone 16' build`
- `xcodebuild test -scheme DayActivityTracker -destination 'platform=iOS Simulator,name=iPhone 16'`

If the available simulator differs, detect an available iPhone simulator and use it.

## Architecture expectations
Use folders similar to:
- App/
- Models/
- Services/
- Shared/
- Features/Home/
- Features/History/
- Features/Reports/
- Tests/

Prefer MVVM-style separation with lightweight services.

## Important implementation rules
- Store sessions in SwiftData
- Use a service layer for session logic and reporting logic
- Inject a date/clock abstraction for deterministic tests
- Enforce non-overlap when editing or backfilling
- Prevent creating a second active session
- When switching activities, end the previous active session and start the new one immediately
- If the user chooses the exact same currently active category + sub-activity, do nothing
- For learn categories, de-duplicate saved sub-activities case-insensitively after trimming whitespace
- If changing from a learn category to a non-learn category, clear sub-activity
- For custom report ranges, clamp future end times to now

## History-specific rule for sessions crossing midnight
If a stored session overlaps multiple calendar days, the History screen must display split rows/segments under each affected day. Editing should still map back to the same underlying session.

## Reports-specific rule for averages
- Week uses Monday-start calendar semantics
- Average/day = category total divided by number of calendar days touched by the selected range, minimum 1
- Use current time as the temporary end time for any active session

## UX expectations
- Support light/dark mode
- Use Dynamic Type reasonably
- Use SF Symbols
- Add accessibility labels to key controls
- Home should optimize for one-tap switching

## Before you declare completion
Verify all of the following:
- project compiles
- all tests pass
- all 3 tabs work
- switching activities works correctly
- persistence survives relaunch
- history is grouped by day and editable
- reports support today/week/month/custom with charts and table
- cross-midnight sessions are correctly split in history and reports
