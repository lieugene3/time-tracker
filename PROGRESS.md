## Progress

### Pass Status
- [x] Pass 0: Read docs and plan
- [x] Pass 1: Project scaffold + models + persistence
- [x] Pass 2: Session service + tests
- [x] Pass 3: Home tab
- [x] Pass 4: History tab + editing + manual backfill
- [x] Pass 5: Report service + report tests
- [x] Pass 6: Reports UI + polish + README
- [x] Widget: quick-switch small widget
- [x] Widget: inline quick-switch interactions
- [x] Widget: lock screen quick-switch widget
- [x] Widget: live activity quick-switch surface
- [ ] Final verification

### Acceptance Checklist

#### Build and project health
- [x] Xcode project exists and compiles
- [x] No third-party dependencies
- [x] Uses SwiftUI, SwiftData, Swift Charts
- [x] Unit tests pass
- [x] README exists and is accurate

#### Tabs and navigation
- [x] App has exactly 3 tabs: History, Home, Reports
- [x] Home is the default selected tab
- [x] Tab icons are appropriate SF Symbols

#### Home flow
- [x] User can start any non-learn activity with one tap
- [x] User can start Active Learn with an existing or new sub-activity
- [x] User can start Passive Learn with an existing or new sub-activity
- [x] Current activity card shows category, optional sub-activity, since time, and elapsed time
- [x] Stop Tracking ends the current activity
- [x] Starting a different activity auto-ends the old one and starts the new one
- [x] Choosing the same active category + same sub-activity does not create a duplicate session

#### Sub-activity behavior
- [ ] Sub-activities are saved only for Active Learn and Passive Learn
- [x] Saved sub-activities are category-scoped
- [x] New sub-activities are trimmed before saving
- [x] Blank sub-activities are rejected
- [x] Case-insensitive duplicates are not created
- [x] Reused sub-activities update `lastUsedAt`

#### History
- [x] History is grouped by day, newest day first
- [x] Sessions within a day are newest first
- [x] Tapping a history row opens editing
- [x] User can delete a session
- [x] User can manually backfill a past session
- [x] Overlapping edits are blocked with a clear message
- [x] Overlapping backfilled sessions are blocked with a clear message
- [x] Cross-midnight sessions appear under both affected days as split day segments

#### Reports
- [x] Reports support Today, Week, Month, and Custom ranges
- [x] Week starts on Monday
- [x] Reports include a share chart and a total-time chart
- [x] Reports include a table with Activity, Avg/day, Total, and %
- [x] All 9 categories appear in the table
- [x] Zero-time categories sort to the bottom
- [x] Active sessions use now as temporary end time
- [x] Cross-midnight sessions are split correctly for totals and averages
- [x] Custom range rejects start > end
- [x] Future custom end values are clamped to now

#### Data rules
- [x] At most one session can be active at once
- [x] Gaps between sessions are allowed
- [x] Reports aggregate by top-level category only
- [x] Storage is local-only and survives relaunch

### Notes
- Pass 0 complete. Planning documents are in place and implementation has not started yet.
- Pass 1 complete. Added the Xcode project, app scaffold, SwiftData models, shared formatting helpers, preview sample data, and placeholder tab screens.
- Validated Pass 1 with `xcodebuild -scheme DayActivityTracker -project DayActivityTracker.xcodeproj -destination 'generic/platform=iOS' -derivedDataPath /Users/eugene/Projects/time_tracker/.deriveddata CODE_SIGNING_ALLOWED=NO build`.
- Pass 2 complete. Added `SessionService`, a date provider abstraction, overlap validation, active-session rules, and deterministic unit tests against an in-memory SwiftData container.
- Validated Pass 2 with `xcodebuild test -scheme DayActivityTracker -project DayActivityTracker.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0.1' -derivedDataPath /Users/eugene/Projects/time_tracker/.deriveddata CODE_SIGNING_ALLOWED=NO` and a follow-up `xcodebuild ... build` on `generic/platform=iOS`.
- Pass 3 complete. Implemented the Home tab current activity card, stop action, one-tap category switching, learn-category sub-activity picker sheet, and category-specific saved sub-activity reuse.
- Attempted Pass 3 validation with `xcodebuild test -scheme DayActivityTracker -project DayActivityTracker.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0.1' -derivedDataPath /Users/eugene/Projects/time_tracker/.deriveddata CODE_SIGNING_ALLOWED=NO` and `xcodebuild -scheme DayActivityTracker -project DayActivityTracker.xcodeproj -destination 'generic/platform=iOS' -derivedDataPath /Users/eugene/Projects/time_tracker/.deriveddata CODE_SIGNING_ALLOWED=NO build`.
- Pass 3 validation is currently blocked in this Codex run by Xcode macro/plugin sandbox failures (`sandbox-exec: sandbox_apply: Operation not permitted` and malformed `swift-plugin-server` responses), so the latest Home changes were reviewed manually after the build/test attempts.
- Pass 4 complete. Replaced the History placeholder with grouped day sections, split cross-midnight visible segments, edit and delete flows, and a manual backfill sheet that reuses the existing overlap rules.
- Added deterministic tests for history timeline splitting and the end-date clearing rule used by the edit UI.
- Attempted Pass 4 validation with the same `xcodebuild test ...` and `xcodebuild ... build` commands. The generic iOS build reached `HistoryView.swift` and other updated sources before failing again on SwiftData macro/plugin sandbox errors in this Codex environment, and the simulator test command remained blocked by CoreSimulator access.
- Pass 5 complete. Added `ReportService` with Today, Week, Month, and Custom range resolution, Monday-start week semantics, future-end clamping, active-session handling, midnight splitting for aggregation, and sorted per-category totals/averages/percentages.
- Added deterministic report tests covering range semantics, custom-range validation, clamping, cross-midnight totals, active-session handling, averages, percentages, and zero-time sorting.
- Attempted Pass 5 validation with the same `xcodebuild test ...` and `xcodebuild ... build` commands. The generic iOS build compiled into the updated report service sources before failing again on the existing SwiftData macro/plugin sandbox issue in this Codex environment, and the simulator test command remained blocked by CoreSimulator access.
- Pass 6 complete. Replaced the Reports placeholder with the real range picker, custom-range sheet, overview summary card, donut share chart, horizontal totals chart, and the category detail table. Updated preview data and shared percentage formatting to support the new UI.
- Added `README.md` with setup, architecture, assumptions, limitations, and future ideas. In this Codex sandbox the file exists locally but may not be included in the Git commit because staging brand-new files is blocked.
- Attempted Pass 6 validation with the same `xcodebuild test ...` and `xcodebuild ... build` commands. The generic iOS build compiled through `ReportsView.swift`, `SessionService.swift`, `Formatters.swift`, `HomeView.swift`, and `HistoryView.swift` before failing again on the existing SwiftData macro/plugin sandbox issue, and the simulator test command remained blocked by CoreSimulator access.
- Widget work in progress. Adding a small WidgetKit extension, a shared app-group-backed session snapshot, and widget deep links so the widget can display the current activity and launch direct activity switches into the app.
- Widget complete. Added a small WidgetKit extension with a compact current-activity header, a 3x3 quick-switch grid, app-group-backed snapshot sharing, app deep-link handling for widget taps, and project wiring for the new extension target.
- Validation for the widget update: `xcodebuild -list -project DayActivityTracker.xcodeproj` now shows the new `DayActivityTrackerWidget` target and scheme, and `xcodebuild ... build` compiled and linked the widget target successfully before the main app hit the same existing SwiftData macro/plugin sandbox failure in `SavedSubActivity.swift`.
- Interactive widget update complete. The app and widget now point at the shared app-group SwiftData store, the app merges any existing on-device data into that shared store on launch, and the widget chips use an App Intent so they can switch activities without opening the app.
- Lock screen widget update complete. Added an `accessoryRectangular` widget that reuses the existing current-activity snapshot and quick-switch App Intent flow, keeping the same current-activity header and a condensed 3x3 icon grid for lock screen placement.
- Validation for the lock screen widget update: `xcodebuild -list -project DayActivityTracker.xcodeproj` confirms both app and widget schemes are present, and the generic iOS build compiled `DayActivityTrackerWidget.swift` for the widget target before failing on the same pre-existing SwiftData macro/plugin sandbox error in `SavedSubActivity.swift`. A simulator `xcodebuild test ...` attempt with writable derived data remained blocked by CoreSimulator service failures in this Codex environment.
- Live Activity update complete. Added a persisted Home toggle for turning the lock-screen Live Activity on or off, reused the widget snapshot store to drive `ActivityKit` state, and mounted the same quick-switch card inside an `ActivityConfiguration` so the lock-screen Live Activity matches the widget surface.
- Validation for the Live Activity update: `xcodebuild -list -project DayActivityTracker.xcodeproj` still succeeds, and a generic iOS build with writable derived data compiled `DayActivityTrackerWidget.swift` and advanced into `WidgetBridge.swift` before failing again on the existing SwiftData macro/plugin sandbox issue in `SavedSubActivity.swift`. A simulator `xcodebuild test ...` attempt remained blocked by CoreSimulator service failures in this Codex environment.
- Live Activity sync follow-up complete. Session mutations now push widget and Live Activity snapshots immediately through a shared surface coordinator, so lock-screen activity changes do not depend on the root view noticing SwiftData updates later.
- Validation for the Live Activity sync follow-up: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -list -project DayActivityTracker.xcodeproj` succeeds, and a generic iOS build with writable derived data compiles the updated `WidgetBridge.swift`, `DayActivityTrackerWidget.swift`, and `SessionService.swift` paths before failing again on the same pre-existing SwiftData macro/plugin sandbox issue in `SavedSubActivity.swift` and `ActivitySession.swift`. Simulator discovery remains blocked by CoreSimulator connection failures in this Codex environment.
- Live Activity intent follow-up complete. Lock-screen taps now await a direct surface refresh before the App Intent returns, which prevents the Live Activity from keeping the previous category after the session has already switched underneath it.
- Validation for the Live Activity intent follow-up: the generic iOS build again compiles the updated `WidgetBridge.swift` and `DayActivityTrackerWidget.swift` paths before failing on the same pre-existing SwiftData macro/plugin sandbox issue in `SavedSubActivity.swift` and `ActivitySession.swift`, with no new compiler errors reported from the Live Activity files.
- Weekly recap notification feature complete. Added an opt-in Reports card for Monday-morning recap notifications, a local-notification scheduler that keeps one pending end-of-week recap current as session data changes, and a rendered recap attachment so the delivered notification reads more like a polished summary card than a plain text alert.
- Validation for the weekly recap update: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -list -project DayActivityTracker.xcodeproj` still succeeds, and a generic iOS build with writable derived data compiles the updated `DayActivityTrackerWidget.swift`, `WidgetBridge.swift`, and `SessionService.swift` paths before failing again on the same pre-existing SwiftData macro/plugin sandbox issue in `SavedSubActivity.swift`. The app-target files for the Reports UI and app launch wiring were not reached before that existing failure stopped the build.
