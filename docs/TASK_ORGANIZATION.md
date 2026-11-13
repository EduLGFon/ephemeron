# Task Organization: Lists and Smart Lists

## Problem
Task lists existed in schema but partially usable: create/filter only, no rename/recolor/delete from UI. Delete path silently detached tasks and deleted local row immediately, risking lost remote id before Google delete pushed. Smart lists stored filter JSON but UI only wrote showCompleted; no builder, saved-view management, result count, reactive result stream.

## Task-list management UX
Tasks screen shows normal list chips first, color dot + tooltip with source label (sourceLabel: list name + account email, or "On this device"). Long-press list chip opens list manager.
Tasks AppBar overflow: Manage lists, Manage smart lists.
Manage lists: every active list with color dot, name, source label, active-task count. Row menu: rename, change color, delete. Tap row opens name/color editor.
Create list: name + one color from shared preset palette. Local-first, queues task_list create outbox.
Rename/change color: local row immediately, marks dirty, queues task_list update. Color local-only (Google Tasks lists expose no color); changing color never issues remote patch.
Delete list: always states consequence, picks safe default:
- Another list exists: default Move tasks to selected list.
- No other list: only Delete tasks.
- Moving keeps tasks alive in destination. Tasks with no destination go to unlisted bucket.
- Deleting tasks soft-deletes; stay in Trash until restore/permanent delete. No auto expiry.
- List only soft-deleted (deletedAt) and task_list delete outbox queued. Row + remoteId survive until sync deletes remote list.

## Google Tasks list sync
GoogleApiClient gained taskListCreate(title) POST /users/@me/lists, taskListPatch(listId,title) PATCH, taskListDelete(listId) DELETE.
Outbox application for task_list:
- No remoteId: create remotely, store returned id/etag, clear dirty.
- Existing remoteId: patch title remotely, update etag, clear dirty.
- Delete operation or deletedAt set: delete remote list when linked, detach remaining local tasks (FK safety), then hard-delete local list row. Local-only lists skip remote call.
Account scoping: task_list rows stamped googleAccount after successful push. Ops owned by another signed-in account skipped, not deleted.
Discovery: soft-deleted local lists never resurrected/renamed. Remote list already linked never inserted twice. 404 on queued list delete clears local tombstone.
Ordering: list task moves/deletes queued before list delete. List delete removes remote catalog entry after local task changes prepared.

## Smart lists
Saved views use existing smart_lists.filterJson. Builder supports: name + include-completed; due window (any/today/overdue/next 7 days/this month/custom inclusive dueFrom/dueTo); priority multi-select P1-P4; list multi-select; tag multi-select; text query over title/notes (LIKE wildcards stripped); sort (due date, priority, newest created, title). Save creates; opening existing updates.

Tasks screen renders smart-list chips after normal list chips, filter icon + live result count. Selecting smart list sets selectedSmartListProvider, clears normal list filter (and persisted selected list), displays streamed result query. Selecting All or normal list clears smart selection. Long-press smart chip opens edit/delete. Smart-list manager shows every saved view with live count, edit, delete. Empty result shows "No tasks match" with Edit smart list action.

Filter JSON parsing in domain/tasks/smart_filter.dart, defensive: invalid JSON, non-object, unknown keys, wrong types fall back to defaults. Legacy filters with only dueFrom/dueTo treated as custom due window.

## Compatibility
No schema/migration change. task_lists and smart_lists keep columns (deletedAt, dirty, remoteId, remoteEtag, googleAccount, filterJson). Existing IDs, smart-list IDs, filter keys, selected-list setting remain valid. Google list color device-local; preserved across sync because discovery updates only name for clean rows. Old smart lists storing only showCompleted continue to work. Deleting remote-backed list backward compatible: local row retained until remote delete succeeds.

## Verification
Run from app/: dart format, flutter analyze, gen_test_runner after adding/moving case, flutter test.
Covered: task_repository_case (list update/delete, watchLists hides deleted, move vs delete tasks, unlisted move, smart-list CRUD + reactive watch, list/tag/priority/due/query/completed filters, all four sorts, due-window presets); sync_engine_case (list create stores remote id + clears dirty, rename patches, delete removes remote then purges local, local-only delete, account scoping, discovery tombstone/duplicate guards); smart_filter_case (invalid JSON, unknown keys, wrong types, legacy bounds, due presets, round-trip).
Widget long-press code-reviewed not widget-tested; existing smoke test still builds app. Verified 2026-11-04: flutter analyze no issues, full flutter test passed (241 tests).