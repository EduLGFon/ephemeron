// Read-only Microsoft Graph pull engine. Upserts calendars, events, To Do lists
// and tasks for one account. Local-only fields are preserved on update.
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../../data/drift/app_database.dart';
import '../../../domain/microsoft/microsoft_graph_models.dart';
import 'microsoft_graph_client.dart';

part 'microsoft_sync_engine/calendars_events.dart';
part 'microsoft_sync_engine/deletions_reconcile.dart';
part 'microsoft_sync_engine/tasks_reconcile.dart';

class MicrosoftSyncResult {
  const MicrosoftSyncResult({
    required this.calendars,
    required this.events,
    required this.taskLists,
    required this.tasks,
    required this.authFailure,
  });

  final int calendars;
  final int events;
  final int taskLists;
  final int tasks;
  final bool authFailure;
}

class MicrosoftSyncEngine {
  MicrosoftSyncEngine(
    this._db,
    this._client,
    this.account, {
    DateTime? windowStart,
    DateTime? windowEnd,
    List<String>? signedInAccounts,
  }) : _windowStart =
           (windowStart ??
                   DateTime.now().toUtc().subtract(const Duration(days: 30)))
               .toUtc(),
       _windowEnd =
           (windowEnd ?? DateTime.now().toUtc().add(const Duration(days: 90)))
               .toUtc(),
       _signedInAccounts = signedInAccounts == null
           ? null
           : Set.unmodifiable(
               signedInAccounts
                   .map((a) => a.trim().toLowerCase())
                   .where((a) => a.isNotEmpty),
             );

  final AppDatabase _db;
  final MicrosoftGraphClient _client;
  final String account;
  final DateTime _windowStart;
  final DateTime _windowEnd;

  /// All accounts currently signed in, used to pick a single reader for a
  /// shared calendar. Null means the caller did not provide the account list.
  final Set<String>? _signedInAccounts;

  bool _authFailure = false;
  bool get authFailure => _authFailure;

  Future<MicrosoftSyncResult> syncNow() async {
    _authFailure = false;
    var calendarCount = 0;
    var eventCount = 0;
    var listCount = 0;
    var taskCount = 0;
    try {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      late final List<MsCalendar> calendars;
      try {
        calendars = await _client.listCalendars();
      } on MicrosoftGraphException catch (e) {
        // Status only: a failing calendar listing must stay visible.
        debugPrint('[ms-sync] listCalendars failed status=${e.status}');
        rethrow;
      }
      final calSync = await _syncCalendars(calendars, now);
      calendarCount = calSync.count;
      // Remote deletions: reconcile calendars only after a complete, successful
      // `/me/calendars` listing. Soft-delete own-account, clean Microsoft
      // calendars that disappeared from Graph. Shared/second-account rows and
      // local-only rows are never touched.
      await _reconcileDeletedCalendars(calendars, now);

      eventCount = await _syncEvents(calendars, calSync.idsByRemote);

      // Task lists. To Do is not available for every account/tenant: Graph
      // answers 404/410 when the API is absent. That must not fail calendar
      // sync, so skip To Do for this run. A skipped run never reconciles task
      // lists or tasks, so nothing is soft-deleted from an unavailable fetch.
      var todoAvailable = true;
      List<MsTodoList> todoLists = const [];
      try {
        todoLists = await _client.listTodoLists();
      } on MicrosoftGraphException catch (e) {
        if (e.isUnauthorized || e.isForbidden) {
          _authFailure = true;
          todoAvailable = false;
        } else if (e.isNotFound || e.isGone) {
          debugPrint('[ms-sync] listTodoLists unavailable status=${e.status}');
          todoAvailable = false;
        } else {
          // Transient/server failures already exhausted the client retry: keep
          // the failure visible instead of masking it.
          debugPrint('[ms-sync] listTodoLists failed status=${e.status}');
          rethrow;
        }
      }

      if (todoAvailable) {
        final remoteListIds = {
          for (final l in todoLists)
            if (l.id.isNotEmpty) l.id,
        };
        final listSync = await _syncTaskLists(todoLists, now);
        listCount = listSync.count;
        // Remote deletions: reconcile task lists only after a complete,
        // successful list fetch. Soft-delete lists (and their MS-synced,
        // non-dirty tasks) that disappeared from Graph. Never acts on
        // partial/failed sync or dirty rows.
        await _reconcileDeletedTaskLists(remoteListIds, now);

        taskCount = await _syncTasks(todoLists, listSync.idsByRemote, now);
      }

      return MicrosoftSyncResult(
        calendars: calendarCount,
        events: eventCount,
        taskLists: listCount,
        tasks: taskCount,
        authFailure: _authFailure,
      );
    } on MicrosoftGraphException catch (e) {
      if (e.isUnauthorized || e.isForbidden) {
        _authFailure = true;
        return MicrosoftSyncResult(
          calendars: calendarCount,
          events: eventCount,
          taskLists: listCount,
          tasks: taskCount,
          authFailure: true,
        );
      }
      rethrow;
    }
  }

  String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
