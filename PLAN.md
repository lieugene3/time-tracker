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

7. Add a compact quick-switch widget.
   - Create a small WidgetKit extension that shows the current activity, the start time, and a dense activity launcher grid.
   - Bridge the app and widget with a shared snapshot store and deep-link handling so widget taps can switch activities safely through the main app.

8. Make the widget interactive.
   - Move app and widget persistence into the shared app-group container so the extension can update sessions directly.
   - Replace widget deep links with App Intent buttons that switch activities inline and keep the widget snapshot in sync.

9. Add a lock screen widget variant.
   - Reuse the existing widget provider and app-intent flow for an iPhone lock screen family.
   - Mirror the current quick-switch widget with a condensed accessory-rectangular layout that fits platform constraints.

10. Add an opt-in Live Activity.
   - Add a Home toggle that enables or disables a lock-screen Live Activity for the quick-switch surface.
   - Reuse the existing widget snapshot and intent flow so the Live Activity mirrors the widget UI and stays in sync with session changes.

11. Add a weekly recap notification.
   - Compute a Monday-start weekly summary for learn, exercise, personal, and media hours/day.
   - Keep a single end-of-week local notification refreshed as session data changes, and expose an in-app opt-in control.
