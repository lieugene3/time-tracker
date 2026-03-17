## Progress

### Pass Status
- [x] Pass 0: Read docs and plan
- [x] Pass 1: Project scaffold + models + persistence
- [ ] Pass 2: Session service + tests
- [ ] Pass 3: Home tab
- [ ] Pass 4: History tab + editing + manual backfill
- [ ] Pass 5: Report service + report tests
- [ ] Pass 6: Reports UI + polish + README
- [ ] Final verification

### Acceptance Checklist

#### Build and project health
- [x] Xcode project exists and compiles
- [x] No third-party dependencies
- [ ] Uses SwiftUI, SwiftData, Swift Charts
- [ ] Unit tests pass
- [ ] README exists and is accurate

#### Tabs and navigation
- [x] App has exactly 3 tabs: History, Home, Reports
- [x] Home is the default selected tab
- [x] Tab icons are appropriate SF Symbols

#### Home flow
- [ ] User can start any non-learn activity with one tap
- [ ] User can start Active Learn with an existing or new sub-activity
- [ ] User can start Passive Learn with an existing or new sub-activity
- [ ] Current activity card shows category, optional sub-activity, since time, and elapsed time
- [ ] Stop Tracking ends the current activity
- [ ] Starting a different activity auto-ends the old one and starts the new one
- [ ] Choosing the same active category + same sub-activity does not create a duplicate session

#### Sub-activity behavior
- [ ] Sub-activities are saved only for Active Learn and Passive Learn
- [ ] Saved sub-activities are category-scoped
- [ ] New sub-activities are trimmed before saving
- [ ] Blank sub-activities are rejected
- [ ] Case-insensitive duplicates are not created
- [ ] Reused sub-activities update `lastUsedAt`

#### History
- [ ] History is grouped by day, newest day first
- [ ] Sessions within a day are newest first
- [ ] Tapping a history row opens editing
- [ ] User can delete a session
- [ ] User can manually backfill a past session
- [ ] Overlapping edits are blocked with a clear message
- [ ] Overlapping backfilled sessions are blocked with a clear message
- [ ] Cross-midnight sessions appear under both affected days as split day segments

#### Reports
- [ ] Reports support Today, Week, Month, and Custom ranges
- [ ] Week starts on Monday
- [ ] Reports include a share chart and a total-time chart
- [ ] Reports include a table with Activity, Avg/day, Total, and %
- [ ] All 9 categories appear in the table
- [ ] Zero-time categories sort to the bottom
- [ ] Active sessions use now as temporary end time
- [ ] Cross-midnight sessions are split correctly for totals and averages
- [ ] Custom range rejects start > end
- [ ] Future custom end values are clamped to now

#### Data rules
- [ ] At most one session can be active at once
- [ ] Gaps between sessions are allowed
- [ ] Reports aggregate by top-level category only
- [ ] Storage is local-only and survives relaunch

### Notes
- Pass 0 complete. Planning documents are in place and implementation has not started yet.
- Pass 1 complete. Added the Xcode project, app scaffold, SwiftData models, shared formatting helpers, preview sample data, and placeholder tab screens.
- Validated Pass 1 with `xcodebuild -scheme DayActivityTracker -project DayActivityTracker.xcodeproj -destination 'generic/platform=iOS' -derivedDataPath /Users/eugene/Projects/time_tracker/.deriveddata CODE_SIGNING_ALLOWED=NO build`.
