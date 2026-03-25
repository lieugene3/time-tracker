# Day Activity Tracker

## Overview
Day Activity Tracker is a local-first iPhone app for logging what you are doing throughout the day, reviewing and editing history, and viewing category-based reports over common time ranges.

## Stack
- SwiftUI
- SwiftData
- Swift Charts
- iOS 17+
- iPhone-only MVP
- No backend
- No login
- No third-party dependencies

## Architecture
- `App/` contains the app entry point and root tab wiring.
- `Models/` contains the SwiftData models and the activity category enum.
- `Services/` contains the session rules, history/report aggregation helpers, and date-provider abstraction used for deterministic tests.
- `Features/Home/` contains the current-activity and fast-switching UI.
- `Features/History/` contains grouped history, cross-midnight visual splitting, editing, and backfill flows.
- `Features/Reports/` contains the range picker, custom range flow, charts, and detail table.
- `Shared/` contains date, duration, and percentage formatting plus preview data.
- `DayActivityTrackerTests/` contains deterministic service-level tests.

## Setup
1. Open `DayActivityTracker.xcodeproj` in Xcode 16+.
2. Select the `DayActivityTracker` scheme.
3. Run on an iPhone simulator with iOS 17 or later.

Command-line examples:
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme DayActivityTracker -project DayActivityTracker.xcodeproj -destination 'generic/platform=iOS' -derivedDataPath /Users/eugene/Projects/time_tracker/.deriveddata CODE_SIGNING_ALLOWED=NO build`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme DayActivityTracker -project DayActivityTracker.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0.1' -derivedDataPath /Users/eugene/Projects/time_tracker/.deriveddata CODE_SIGNING_ALLOWED=NO`

## Assumptions
- Week calculations use Monday as the first day of the week.
- Weekly recap notifications are delivered on Monday at 8:00 AM local time and summarize the Monday-through-Sunday week that just ended.
- Reports aggregate only top-level categories for MVP.
- Learn sub-activities are optional and only apply to Active Learn and Passive Learn.
- Local device time is the source of truth for display and aggregation semantics.

## Limitations
- Storage is local-only for v1. There is no sync or export/import yet.
- iPhone lock screen widgets only support the `accessoryInline`, `accessoryCircular`, and `accessoryRectangular` families, so the lock screen quick-switch widget uses a condensed accessory-rectangular grid rather than a separate accessory-grid family.
- The Live Activity uses the same quick-switch surface as the widget, but iOS still controls Live Activity lifetime and may automatically end it after several hours, so it cannot be made permanently persistent purely from app code.
- The weekly recap notification is kept current by refreshing a single pending local notification whenever the app or widget updates session data, but iOS still controls local-notification delivery and the app cannot guarantee a background refresh if the notification permission is revoked or the user never reopens the app after a long idle period.
- The current Codex sandbox blocks reliable `xcodebuild` macro/plugin execution, so command-line validation can fail even when the edited source parses cleanly.
- The History and Reports feature code currently lives in existing tracked files because this sandbox also blocks staging newly added source files.
- README staging is subject to the same sandbox limitation, so if Git does not include this file automatically it may need to be staged outside this Codex run.

## Future Ideas
- CSV or share/export support for reports.
- Search and filters in History.
- More flexible report comparisons and trend views.
- Widgets or shortcuts for faster activity switching.
- Optional sync across devices in a later version.
