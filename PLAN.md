## Execution Plan

1. Create the app skeleton and Xcode project.
   - Add the SwiftUI app entry, root tabs, SwiftData container, model types, shared formatters, previews, and sample data.
   - Confirm the project builds on an available iPhone simulator.

2. Build core session logic and tests.
   - Add a date provider abstraction and `SessionService`.
   - Cover starting, switching, stopping, overlap validation, and active-session rules with unit tests.

3. Implement the Home tab.
   - Show the current session card, fast-start activity buttons, and the learn-category sheet flow.
   - Persist and reuse sub-activities with the required validation and de-duplication rules.

4. Implement the History tab.
   - Group sessions by day, split cross-midnight sessions visually, and support edit, delete, and manual backfill flows.
   - Add tests for overlap prevention and history segmentation.

5. Build reporting logic and tests.
   - Implement report ranges, Monday-start week handling, cross-midnight splitting, active-session handling, totals, averages, and percentages.
   - Add deterministic tests for report calculations.

6. Finish the Reports tab and polish.
   - Add the charts, summary table, custom range flow, accessibility labels, previews, and final README documentation.
   - Re-run the full test suite and full build, then compare against the acceptance checklist.
