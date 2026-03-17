# How to run this with Codex

## Best practical setup
For this project, use Codex locally on the Mac that has Xcode installed, so Codex can create the project, edit files, and run build/test commands against your local toolchain.

## Recommended workflow
1. Create a new folder for the repo.
2. Put these files in the repo root:
   - `AGENTS.md`
   - `PRODUCT_SPEC.md`
   - `ACCEPTANCE_TESTS.md`
   - `TASK_PROMPTS.md`
3. Initialize Git and make a clean starting commit.
4. Open the folder with Codex (CLI, app, or IDE extension).
5. Run the prompts in `TASK_PROMPTS.md` one pass at a time.
6. After each pass, review the diff before moving on.
7. If Codex drifts, tell it to re-read the three spec files and continue from the next unchecked item in `PROGRESS.md`.

## Suggested commands
```bash
git init
git add .
git commit -m "Add Codex instructions and product spec"
```

If using the CLI:
```bash
codex
```

Then paste the current pass prompt.

## Important habit
Do not give one giant prompt and walk away.
Use staged passes with validation after each pass.

## If Codex gets stuck
Use a corrective prompt like this:

```text
Re-read AGENTS.md, PRODUCT_SPEC.md, and ACCEPTANCE_TESTS.md.
Compare the current implementation to PROGRESS.md.
Fix only the next incomplete item, then run build/tests and stop.
```
