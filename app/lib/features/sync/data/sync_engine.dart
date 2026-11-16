// Single-flight sync coordinator. Offline-first: optimistic local writes
// plus outbox; the user never waits on the network. Safe to kill anytime:
// remote upserts key on remoteId, outbox rows clear only after success.
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ephemeron/core/ids/ids.dart';
import 'package:ephemeron/core/time/time.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/mappers/google_mappers.dart';
import 'package:ephemeron/data/remote/google_api_client.dart';
import 'package:ephemeron/features/sync/domain/sync_issue.dart';

part 'sync_engine/push.dart';
part 'sync_engine/push_apply.dart';
part 'sync_engine/push_apply/events.dart';
part 'sync_engine/push_apply/exceptions.dart';
part 'sync_engine/push_apply/tasks.dart';
part 'sync_engine/push_error.dart';
part 'sync_engine/pull/discovery.dart';
part 'sync_engine/pull/calendars.dart';
part 'sync_engine/pull/calendars/claims.dart';
part 'sync_engine/pull/calendars/merge.dart';
part 'sync_engine/pull/tasks.dart';
part 'sync_engine/pull/helpers.dart';

enum SyncStatus { synced, syncing, offline, error }

/// Broad failure class for the last sync run. Auth failures drive reconnect;
/// rate/network/server failures are retried without asking for credentials.
enum SyncErrorKind { none, auth, rateLimited, network, server, unknown }

/// Result of discarding an outbox diagnostic row. Missing rows can happen when
/// a concurrent sync already pushed the change.
enum OutboxDiscardResult { discarded, missing, retriesLeft }

class SyncEngine {
  SyncEngine(
    this._db, {
    this._clientFactory,
    this.account,
    this.signedInAccounts,
  });

  final AppDatabase _db;
  final GoogleApiClient? Function()? _clientFactory;
  String? account;

  /// Accounts currently signed in. Used to avoid stealing a shared calendar
  /// stamped to another active account during discovery.
  ///
  /// Production callers always pass the account list. A null list fails
  /// closed: shared calendars whose owner is not the active account are not
  /// re-stamped or pulled, because dedupe cannot be proven without the list.
  final List<String>? signedInAccounts;
  bool _running = false;
  SyncStatus _status = SyncStatus.synced;
  String? _lastError;
  bool _authFailure = false;
  int? _authStatus;
  bool _skipped = false;
  bool _hadFailure = false;
  SyncErrorKind _errorKind = SyncErrorKind.none;

  /// Set when any op in the last run failed with an auth/permission error.
  /// Drives the reconnect banner; reset on every [syncNow].
  bool get authFailure => _authFailure;

  /// First HTTP status that caused [authFailure] (401 or 403). A 401 can mean
  /// a stale cached token and is worth a silent refresh; a 403 is a
  /// definitive authorization verdict for the current grant.
  int? get authStatus => _authStatus;

  /// Classified failure of the last run. Reset to [SyncErrorKind.none] on a
  /// fully successful sync.
  SyncErrorKind get errorKind => _errorKind;

  /// Set when [syncNow] returned early due to single-flight (_busy/_running).
  bool get skipped => _skipped;

  /// Cross-instance single-flight: the notifier, auto-sync timer, sign-in
  /// flow and headless worker each build their own engine.
  static bool _busy = false;
  final _rand = Random();

  /// Remote calendar/task-list ids seen for the active account in this run.
  /// Pull skips null-stamped rows that are absent here: they belong to an
  /// account that is not signed in (or a deleted remote), and querying them
  /// under this token only produces 404 noise.
  Set<String>? _accountCalendarIds;

  /// Calendars the active account can actually read events from. Excludes
  /// freeBusyReader entries, which have no event details to pull.
  Set<String>? _readableCalendarIds;
  Set<String>? _accountListIds;

  SyncStatus get status => _status;
  String? get lastError => _lastError;

  static const int maxAttempts = 5;

  int _now() => DateTime.now().toUtc().millisecondsSinceEpoch;

  /// Runs push then pull. Concurrent calls collapse into one run.
  ///
  /// Every stage is isolated: a failing push must not stop discovery, a
  /// failing discovery must not stop pulling known calendars, and one bad
  /// calendar must not stop the rest.
  Future<void> syncNow() async {
    if (_running || _busy) {
      debugPrint('[sync] syncNow skipped: already running');
      _skipped = true;
      return;
    }
    _running = true;
    _busy = true;
    _status = SyncStatus.syncing;
    _authFailure = false;
    _authStatus = null;
    _errorKind = SyncErrorKind.none;
    _hadFailure = false;
    _lastError = null;
    _skipped = false;
    // Discovery sets are per-run. Clear them so a failed discovery cannot
    // leave the previous run's ids filtering this run's pull.
    _accountCalendarIds = null;
    _readableCalendarIds = null;
    _accountListIds = null;
    debugPrint('[sync] syncNow start');
    try {
      final client = _clientFactory?.call();
      if (client == null) {
        debugPrint('[sync] no client (no token): offline');
        _status = SyncStatus.offline;
        return;
      }
      await _runStage('push', () async {
        final pushed = await _pushOutbox(client);
        debugPrint('[sync] push done ops=$pushed');
      });
      await _runStage('calendar discovery', () async {
        final cals = await _syncCalendarList(client);
        debugPrint(
          '[sync] calendar discovery done remote=${cals.$1} new=${cals.$2}',
        );
      });
      await _runStage('task-list discovery', () async {
        final lists = await _syncTaskLists(client);
        debugPrint(
          '[sync] task-list discovery done remote=${lists.$1} new=${lists.$2}',
        );
      });
      await _runStage('calendar pull', () async {
        final events = await _pullCalendars(client);
        debugPrint('[sync] calendar pull done events=$events');
      });
      await _runStage('tasks pull', () async {
        final tasks = await _pullTasks(client);
        debugPrint('[sync] tasks pull done tasks=$tasks');
      });
      if (_authFailure) {
        // Push or pull hit an auth/permission error (expired token, revoked
        // access, missing Tasks scope with a Calendar-only grant). The rows
        // are kept; the user must reconnect. Never report clean success.
        _status = SyncStatus.error;
        _errorKind = SyncErrorKind.auth;
        _lastError = 'Google auth';
        debugPrint('[sync] syncNow finished with auth failures');
      } else if (_hadFailure) {
        _status = SyncStatus.error;
        debugPrint('[sync] syncNow finished with failures kind=$_errorKind');
      } else {
        _status = SyncStatus.synced;
        _errorKind = SyncErrorKind.none;
        _lastError = null;
        debugPrint('[sync] syncNow ok');
      }
    } on GoogleApiException catch (e) {
      debugPrint('[sync] GoogleApiException status=${e.status}');
      _recordFailure(e);
      _status = SyncStatus.error;
      if (_authFailure) _lastError = 'Google auth';
    } catch (e) {
      debugPrint('[sync] unexpected error type=${e.runtimeType}');
      _recordFailure(e);
      _status = SyncStatus.error;
    } finally {
      _running = false;
      _busy = false;
    }
  }

  Future<void> _runStage(String stage, Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      // Catch Object, not just Exception: a thrown Error (for example a
      // StateError from a malformed response) must only fail this stage and
      // not abort later stages.
      debugPrint('[sync] $stage failed type=${e.runtimeType}');
      _recordFailure(e);
    }
  }

  /// Records a non-fatal failure. Auth always wins; otherwise the highest
  /// priority kind wins. Never stores tokens, emails, or event content.
  void _recordFailure(Object error) {
    final kind = _classifyError(error);
    if (kind == SyncErrorKind.auth) {
      _authFailure = true;
      if (error is GoogleApiException) _authStatus ??= error.status;
    }
    _hadFailure = true;
    if (_errorPriority(kind) >= _errorPriority(_errorKind)) {
      _errorKind = kind;
      _lastError = _errorLabel(kind);
    }
  }

  static SyncErrorKind _classifyError(Object error) {
    if (error is GoogleApiException) {
      if (error.isAuthFailure) return SyncErrorKind.auth;
      if (error.isRateLimited) return SyncErrorKind.rateLimited;
      if (error.isServerError) return SyncErrorKind.server;
      return SyncErrorKind.unknown;
    }
    final name = error.runtimeType.toString();
    if (error is TimeoutException ||
        error is http.ClientException ||
        name == 'SocketException' ||
        name == 'HandshakeException' ||
        name == 'HttpException') {
      return SyncErrorKind.network;
    }
    return SyncErrorKind.unknown;
  }

  static int _errorPriority(SyncErrorKind kind) => switch (kind) {
    SyncErrorKind.auth => 5,
    SyncErrorKind.rateLimited => 4,
    SyncErrorKind.network => 3,
    SyncErrorKind.server => 2,
    SyncErrorKind.unknown => 1,
    SyncErrorKind.none => 0,
  };

  static String _errorLabel(SyncErrorKind kind) => switch (kind) {
    SyncErrorKind.auth => 'Google auth',
    SyncErrorKind.rateLimited => 'Google rate limited',
    SyncErrorKind.network => 'network',
    SyncErrorKind.server => 'Google server',
    SyncErrorKind.unknown => 'sync failed',
    SyncErrorKind.none => 'sync failed',
  };

  Future<int> pendingCount() async {
    final rows =
        await (_db.select(_db.outbox)..where(
              (o) =>
                  o.nextTryAt.isNull() |
                  o.nextTryAt.isSmallerOrEqualValue(_now()),
            ))
            .get();
    return rows.length;
  }

  Future<void> retryFailed(String outboxId) async {
    await (_db.update(_db.outbox)..where((o) => o.id.equals(outboxId))).write(
      const OutboxCompanion(
        attempts: Value(0),
        nextTryAt: Value(null),
        lastError: Value(null),
      ),
    );
  }

  /// Removes only an exhausted row. A queued row with retries left is kept so
  /// discarding a diagnostic can never silently drop a valid user change. A
  /// row that vanished concurrently reports [OutboxDiscardResult.missing].
  Future<OutboxDiscardResult> discardFailed(String outboxId) async {
    final row = await (_db.select(
      _db.outbox,
    )..where((o) => o.id.equals(outboxId))).getSingleOrNull();
    if (row == null) return OutboxDiscardResult.missing;
    if (row.attempts < maxAttempts) return OutboxDiscardResult.retriesLeft;
    await (_db.delete(_db.outbox)..where((o) => o.id.equals(outboxId))).go();
    return OutboxDiscardResult.discarded;
  }

  /// Pending/failed outbox rows for the user-facing diagnostics screen.
  Stream<List<SyncOutboxIssue>> watchOutboxIssues() {
    return (_db.select(_db.outbox)
          ..where(
            (o) =>
                o.lastError.isNotNull() |
                o.attempts.isBiggerOrEqualValue(maxAttempts),
          )
          ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
        .watch()
        .map(
          (rows) => [
            for (final row in rows)
              SyncOutboxIssue(
                id: row.id,
                operationLabel: syncOperationLabel(row.op),
                entityLabel: syncEntityLabel(row.entity),
                attempts: row.attempts,
                createdAtUtc: DateTime.fromMillisecondsSinceEpoch(
                  row.createdAt,
                  isUtc: true,
                ),
                // PRIVACY: never surface the payload or raw remote response.
                errorLabel: syncErrorLabel(row.lastError),
                failed: row.attempts >= maxAttempts,
              ),
          ],
        );
  }

  /// Per-calendar and per-task-list failures recorded in syncState. Only the
  /// non-personal error label and local metadata key leave this layer.
  Stream<List<SyncStateIssue>> watchSyncStateIssues() {
    // Only meta keys written by _setSyncMeta: cal:<localId>:meta and
    // tasks[:<localId>]:meta. Token and reader rows can never match, even if
    // an old or imported row carries a non-null lastError.
    return (_db.select(_db.syncState)
          ..where(
            (s) =>
                (s.key.like('cal:%:meta') | s.key.like('tasks%:meta')) &
                s.lastError.isNotNull() &
                s.lastError.equals('').not(),
          )
          ..orderBy([(s) => OrderingTerm.desc(s.lastSyncAt)]))
        .watch()
        .map(
          (rows) => [
            for (final row in rows)
              SyncStateIssue(
                key: row.key,
                kind: row.key.startsWith('cal:')
                    ? SyncStateIssueKind.calendar
                    : SyncStateIssueKind.taskList,
                errorLabel: syncErrorLabel(row.lastError),
                lastSyncAtUtc: row.lastSyncAt == null
                    ? null
                    : DateTime.fromMillisecondsSinceEpoch(
                        row.lastSyncAt!,
                        isUtc: true,
                      ),
              ),
          ],
        );
  }

  /// Clears a recorded per-calendar/task-list error before retrying sync.
  Future<void> clearSyncStateError(String key) async {
    await (_db.update(_db.syncState)..where((s) => s.key.equals(key))).write(
      const SyncStateCompanion(lastError: Value(null)),
    );
  }

  Stream<List<OutboxData>> watchFailed() {
    return (_db.select(_db.outbox)
          ..where(
            (o) =>
                o.attempts.isBiggerOrEqualValue(maxAttempts) &
                o.lastError.isNotNull(),
          )
          ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
        .watch();
  }

  int _backoffMs(int attempts) {
    final base = 5000 * (1 << attempts.clamp(0, 5));
    return base + _rand.nextInt(1000);
  }

  static bool _isGoogleEntity(String entity) =>
      entity == 'event' ||
      entity == 'task' ||
      entity == 'task_list' ||
      entity == 'event_remote' ||
      entity == 'task_remote';

  Map<String, dynamic> _opPayload(OutboxData op) {
    final raw = op.payload;
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }

  String _iso(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String();
}
