# Product Spec — Day Activity Tracker

## App summary
A native iPhone time tracker that records the user's current activity as sessions, lets them review and edit history, manually backfill sessions, and see visual reports over selected time ranges.

## Root tabs
Use exactly 3 tabs in this order:
1. History
2. Home
3. Reports

Default selected tab on launch: Home.

## Core activity categories
- Active Learn
- Passive Learn
- Media
- Commute/Travel
- Social
- Work
- Exercise
- Sleep
- Personal

## Core concepts
The app tracks **sessions**.

A session has:
- category
- optional sub-activity
- start datetime
- end datetime (optional if currently running)
- createdAt
- updatedAt

Rules:
- At most one session can be active at a time
- Selecting a new activity automatically ends the previous active session at now and starts a new one
- If the chosen category + sub-activity exactly matches the active session, do nothing
- A session may be manually created in the past (backfilled)
- Gaps are allowed

## Learn sub-activities
Only **Active Learn** and **Passive Learn** support sub-activities.

Requirements:
- show saved sub-activities scoped to the chosen learn category
- allow selecting an existing saved sub-activity
- allow typing a new one
- trim whitespace
- reject blank values
- de-duplicate case-insensitively after trimming whitespace
- save unique new sub-activities for reuse
- update `lastUsedAt` when used
- allow continuing with no sub-activity

## Data model

### ActivityCategory
Use the exact display names above.
Include helpers:
- displayName
- stable identity/raw value
- `supportsSubActivities`

### ActivitySession
Fields:
- id: UUID
- categoryRaw: String
- subActivityName: String?
- startAt: Date
- endAt: Date?
- createdAt: Date
- updatedAt: Date

Helpers:
- category enum wrapper
- `isActive`
- `effectiveEndDate(now:)`
- `duration(now:)`

### SavedSubActivity
Fields:
- id: UUID
- parentCategoryRaw: String
- name: String
- createdAt: Date
- lastUsedAt: Date
- isArchived: Bool

Helpers:
- parentCategory enum wrapper

## Home tab
### Purpose
Let the user quickly start, switch, or stop their current activity.

### UI requirements
- title
- current activity card at top
- if active, show:
  - category name
  - optional sub-activity
  - `Since <time>`
  - elapsed duration
  - stop tracking button
- if nothing active, show:
  - `No current activity`
  - prompt text like `Choose what you're doing now`

### Activity chooser
Show all categories as tappable buttons/cards in a fast layout.

Behavior:
- non-learn categories start immediately
- Active Learn and Passive Learn open a picker sheet

### Learn picker sheet
For the selected learn category:
- show saved sub-activities sorted by `lastUsedAt` descending
- tap one to start immediately
- text field to create a new sub-activity
- save and start if valid
- include `Continue without sub-activity`

## History tab
### Purpose
Show sessions grouped by day from most recent to oldest, with editing.

### Grouping and ordering
- group by day
- sort day groups newest to oldest
- within each day, sort entries newest to oldest

### Important cross-midnight rule
If a single session spans midnight, split it into day-specific visible segments in History so that the session appears under **each** affected day.

Example:
- Session: Work from Mar 10 11:00 PM to Mar 11 1:00 AM
- History should show:
  - under Mar 11: 12:00 AM–1:00 AM (1h)
  - under Mar 10: 11:00 PM–12:00 AM (1h)

These visible rows must still be editable back to the underlying source session.

### History row content
Show:
- category
- optional sub-activity
- start time
- end time or `Now`
- duration

### Day header
- show Today / Yesterday when appropriate
- otherwise show a formatted date

### Editing
Tapping a row opens an edit screen or sheet.

Edit UI must allow:
- change category
- change sub-activity
- change start datetime
- change end datetime
- clear end datetime only if the edited session is the most recent session and there is no other active session
- save changes
- delete session

### Manual backfilling
History must include an obvious action to add a new past session manually.

Backfill UI must allow:
- selecting category
- optional sub-activity for learn categories
- picking start datetime
- picking end datetime
- saving a completed session

Validation for backfill/edit:
- end must be later than start
- edited/backfilled sessions must not overlap any other session
- only one active session may exist
- if switching from learn to non-learn, clear sub-activity
- if switching to learn, allow sub-activity editing
- on overlap, block save and show a clear validation message

## Reports tab
### Purpose
Show visual and tabular summaries by category.

### Period picker
Provide:
- Today
- Week
- Month
- Custom

### Date range semantics
- Today = start of current day to now
- Week = start of current week (Monday) to now
- Month = start of current calendar month to now
- Custom = user chooses start and end date/time
- clamp future end values to now
- if custom start > custom end, block apply with validation

### Calculations
For the selected range, compute by top-level category:
- total time
- average per day
- percentage of tracked time

Rules:
- include only the overlapped portion of sessions inside the range
- active sessions use now as temporary end
- split sessions across midnight boundaries
- average/day = category total / number of calendar days touched by selected range, minimum 1
- percentage = category total / total tracked time in range
- if total tracked time is 0, percentage is 0

### Visuals
Include:
1. donut or pie chart for category share
2. bar chart for total time by category

### Table
Under the charts, show a table with:
- Activity
- Avg/day
- Total
- %

Behavior:
- show all 9 categories
- sort by total descending
- zero-time categories at bottom
- show total tracked time and selected range label above the table or in a summary area

## Formatting
- use local date/time formatting
- current activity `Since` uses short local time
- duration formatting examples:
  - 42m
  - 3h 25m
  - include days when needed

## Persistence
- use SwiftData model container at app root
- persist between launches
- sample data only in DEBUG/previews

## Suggested files
- DayActivityTrackerApp.swift
- RootTabView.swift
- Models/ActivityCategory.swift
- Models/ActivitySession.swift
- Models/SavedSubActivity.swift
- Services/DateProvider.swift
- Services/SessionService.swift
- Services/ReportService.swift
- Shared/Formatters.swift
- Shared/SampleData.swift
- Features/Home/HomeView.swift
- Features/Home/HomeViewModel.swift
- Features/Home/ActivityPickerSheet.swift
- Features/Home/CurrentActivityCard.swift
- Features/History/HistoryView.swift
- Features/History/HistoryViewModel.swift
- Features/History/SessionRowView.swift
- Features/History/EditSessionView.swift
- Features/History/AddSessionView.swift
- Features/Reports/ReportsView.swift
- Features/Reports/ReportsViewModel.swift
- Features/Reports/CustomRangeSheet.swift
- Features/Reports/ReportTableView.swift
- Tests/SessionServiceTests.swift
- Tests/ReportServiceTests.swift

## Required tests
1. Starting first session
2. Switching activities ends old session and starts new one
3. Stop tracking ends current session
4. Prevent overlaps during edit
5. Prevent overlaps during manual backfill
6. Saving and reusing Active Learn sub-activities
7. Saving and reusing Passive Learn sub-activities
8. Report totals for today
9. Report totals across a week
10. Correct percentage calculations
11. Correct average/day calculations
12. Correct handling of sessions that cross midnight
13. Correct treatment of an active session with no endAt
14. History segmentation of cross-midnight sessions

## Definition of done
- project compiles
- all three tabs work
- switching activities works correctly
- data persists after relaunch
- history is grouped and editable
- manual backfilling works
- reports show charts and table for today/week/month/custom
- tests pass
- no TODO placeholders for core features
