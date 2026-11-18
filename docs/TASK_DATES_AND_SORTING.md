# Task Dates and Sorting

## Task date model
Tasks keep two independent optional dates, both local YYYY-MM-DD strings:
- dueDate: deadline. dueTime (minutes of day) belongs to due date; controls timed calendar block and reminders.
- plannedDate: when user intends to work. No time component, nullable.
Either/both/neither. Clearing writes null; update uses nullable callback so cleared value reaches Drift. plannedDate local-only (not sent to Google Tasks). Google-imported tasks leave plannedDate null and fall back to due date. Backups include plannedDate.

Recurring task completion creates next task. When both dates exist, planned date moves by same day delta as due date (e.g. daily due 2026-03-02 planned 2026-03-01 -> due 2026-03-03 planned 2026-03-02).

## Calendar behavior
Task occurrences use planned date when set, else due date:
- Planned-date task is all-day on plannedDate, even if dueTime exists. Not shown on due date.
- Due-only task: all-day when dueTime null, else timed block using dueTime and durationMin (default 30 min).
Occurrence rebuild loads tasks whose effective date falls in window. Window cache remains derived data, rebuilt normally.

## Sort modes
Sorting is presentation concern in SharedPreferences, not a new table.
Tasks: custom (local sortOrder), name (case-insensitive title), created (newest first), due (due date ascending, undated last; default, preserves previous behavior).
Task lists: custom (local sortOrder; default), name (case-insensitive), created (newest first).
Comparators in features/tasks/application/task_sorting.dart. Pinned tasks stay on top in every mode except explicit custom order. Ties fall back to sortOrder then id. Normal list chips follow active list sort. Smart lists keep sort inside filter JSON; selecting one does not apply global task sort.

## Drag UX
Custom task order uses single reorderable task list, no overdue/rest split. An explicit drag handle reorders; long-press opens the row action sheet; swipe complete/delete and tap edit remain. Search disables reorder. List updates optimistically and persists sortOrder 0..n in one transaction.
List manager uses same long-press in custom mode. Changing to Name/Created hides dragging and sorts visible lists without rewriting stored positions, so returning to Custom restores arrangement.
Reorder local-only. Google Tasks has no position field, so no updated timestamps or outbox ops.

## Schema migration and compatibility
Migration v9->v10 adds one nullable column: ALTER TABLE tasks ADD COLUMN planned_date TEXT. schemaVersion now 10. Existing rows keep null planned date and behave as due-only. No data rewrite. Backups from before restore with null planned date; new backups carry field.
Sort settings add two SharedPreferences keys: tasks.sort, lists.sort. Missing/unknown stored values fall back to due and custom.

## Verification
Run from app/: dart format, flutter analyze, flutter test.
Covered: task repository (planned date create/update/clear, recurring planned-date shift, reorder sortOrder + outbox neutrality, task/list comparators); occurrence cache (planned date wins + all-day; due-only timed fallback unchanged); backup (round-trip preserves plannedDate); settings (taskSort/taskListSort defaults + round-trip); db (schema version 10 + nullable planned_date column).
Drag gestures code-reviewed not widget-tested; repository reorder path and comparators covered. Verified 2026-11-04: flutter analyze no issues, full flutter test passed (261 tests).