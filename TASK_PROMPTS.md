# Codex Task Prompts

Use these prompts in order. Do not ask Codex to do everything in one shot.

---

## Pass 0 — Read docs and plan

```text
Read AGENTS.md, PRODUCT_SPEC.md, and ACCEPTANCE_TESTS.md completely.
Then inspect the repo and create a concise PLAN.md that breaks implementation into small passes.
Also create PROGRESS.md with an initial checklist derived from ACCEPTANCE_TESTS.md.
Do not implement code yet.
```

---

## Pass 1 — Project scaffold + models + persistence

```text
Using the spec files in this repo, create the DayActivityTracker Xcode project from scratch for iOS 17+ using SwiftUI, SwiftData, and Swift Charts.

In this pass only:
- create the app entry point
- create the root TabView with History, Home, Reports in that order, with Home as default
- add the SwiftData model container
- implement the core models and enums
- create the initial folder/file structure
- add shared date/duration formatting helpers
- add preview/sample data helpers
- make the project compile

After coding, run a build and fix any build issues before stopping.
Update PROGRESS.md.
```

---

## Pass 2 — Session service + tests

```text
Implement SessionService and DateProvider/Clock abstraction.
Cover session creation, switching, stopping, overlap validation, and active-session uniqueness.
Add unit tests for the service logic.

After coding:
- run the relevant tests
- fix failures
- run a full build
- update PROGRESS.md with what passed and what remains
```

---

## Pass 3 — Home tab

```text
Implement the Home tab end-to-end.
Requirements:
- current activity card
- stop tracking button
- one-tap start for non-learn categories
- sheet flow for Active Learn and Passive Learn
- saved sub-activities scoped by parent category
- create new sub-activity, de-duplicated case-insensitively after trimming
- continue without sub-activity
- no duplicate session when the selected activity matches the active one exactly

After coding:
- run build/tests
- fix issues
- update PROGRESS.md
```

---

## Pass 4 — History tab + editing + manual backfill

```text
Implement the History tab.
Requirements:
- group by day from newest to oldest
- newest sessions first within each day
- if a session crosses midnight, display split visible segments under both affected days
- tapping a row opens edit UI for the underlying source session
- add manual backfill UI for creating a completed past session
- validate no overlaps during edit or backfill
- support delete

Add or update tests for overlap prevention and cross-midnight history segmentation.

After coding:
- run tests
- run build
- fix issues
- update PROGRESS.md
```

---

## Pass 5 — Report service + report tests

```text
Implement ReportService and its tests.
Requirements:
- Today, Week, Month, Custom ranges
- week starts Monday
- active sessions use now as temporary end
- split sessions at midnight boundaries
- aggregate by top-level category only
- compute total time, average/day, and percentage
- clamp future custom end to now
- reject custom start > end

Add deterministic tests for totals, averages, percentages, week behavior, and cross-midnight sessions.

After coding:
- run tests
- fix issues
- run full build
- update PROGRESS.md
```

---

## Pass 6 — Reports UI + polish + README

```text
Implement the Reports UI using Swift Charts and add the report table.
Then polish the app:
- accessibility labels
- light/dark support
- previews for all main screens
- README with architecture, setup, assumptions, limitations, and future ideas

Before stopping:
- run full test suite
- run full build
- ensure no core-feature TODOs remain
- update PROGRESS.md with final status
```

---

## Final verification prompt

```text
Perform a final verification pass.
- Re-read ACCEPTANCE_TESTS.md and compare the code against every checkbox.
- Run the full test suite.
- Run a full build.
- Fix any failures.
- Then summarize what is complete, any remaining limitations, and which files are most important to review.
```
