// Sync diagnostics: non-personal labels, provider filtering, retry/discard.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/features/sync/application/sync_providers.dart';
import 'package:ephemeron/features/sync/data/sync_engine.dart';
import 'package:ephemeron/features/sync/domain/sync_issue.dart';
import 'package:ephemeron/features/sync/presentation/sync_issues_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

Future<void> _seedOutbox(
  AppDatabase db, {
  required String id,
  required int attempts,
  String? lastError,
  String? payload,
}) async {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  await db
      .into(db.outbox)
      .insert(
        OutboxCompanion.insert(
          id: id,
          entity: 'event',
          entityId: 'event-$id',
          op: 'update',
          payload: Value(payload),
          attempts: Value(attempts),
          lastError: Value(lastError),
          createdAt: now - 180000,
        ),
      );
}

Future<void> _seedSyncState(
  AppDatabase db, {
  required String key,
  String? value,
  String? lastError,
}) async {
  await db
      .into(db.syncState)
      .insert(
        SyncStateCompanion.insert(
          key: key,
          value: Value(value),
          lastSyncAt: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
          lastError: Value(lastError),
        ),
      );
}

Widget _app({
  required List<SyncOutboxIssue> changes,
  required List<SyncStateIssue> stateIssues,
  required SyncEngine engine,
  Future<void> Function()? syncAll,
}) {
  return ProviderScope(
    overrides: [
      syncOutboxIssuesProvider.overrideWith((ref) => Stream.value(changes)),
      syncStateIssuesProvider.overrideWith((ref) => Stream.value(stateIssues)),
      syncEngineProvider.overrideWithValue(engine),
      syncAllProvider.overrideWithValue(syncAll ?? () async {}),
    ],
    child: const MaterialApp(home: SyncIssuesScreen()),
  );
}

SyncOutboxIssue _outboxIssue({
  String id = 'op1',
  int attempts = 5,
  bool failed = true,
}) {
  return SyncOutboxIssue(
    id: id,
    operationLabel: 'Update',
    entityLabel: 'Event',
    attempts: attempts,
    createdAtUtc: DateTime.now().toUtc().subtract(const Duration(minutes: 3)),
    errorLabel: failed ? 'Change was rejected' : 'Rate limited',
    failed: failed,
  );
}

SyncStateIssue _stateIssue(
  String key, {
  SyncStateIssueKind kind = SyncStateIssueKind.calendar,
  String errorLabel = 'Access denied',
}) {
  return SyncStateIssue(
    key: key,
    kind: kind,
    errorLabel: errorLabel,
    lastSyncAtUtc: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
  );
}

void main() {
  test('error labels use a closed allowlist', () {
    expect(syncErrorLabel('auth 401: reconnect Google'), 'Needs permission');
    expect(syncErrorLabel('Google auth'), 'Needs permission');
    expect(syncErrorLabel('AUTH'), 'Needs permission');
    expect(syncErrorLabel('rate limited'), 'Rate limited');
    expect(syncErrorLabel('forbidden'), 'Access denied');
    expect(syncErrorLabel('Google 404'), 'No longer available');
    expect(syncErrorLabel('failed: 400'), 'Change was rejected');
    expect(syncErrorLabel('error 500'), 'Server error');
    expect(syncErrorLabel('private remote body'), 'Sync failed');
    expect(syncErrorLabel('alice@example.com'), 'Sync failed');
    expect(syncErrorLabel(''), 'Sync failed');
    expect(syncOperationLabel('update'), 'Update');
    expect(syncEntityLabel('task_list'), 'Task list');
    expect(syncEntityLabel('unknown_entity'), 'Change');
  });

  test('outbox diagnostics expose labels but never payloads', () async {
    final db = _db();
    addTearDown(db.close);
    await _seedOutbox(
      db,
      id: 'op-failed',
      attempts: 5,
      lastError: 'failed: 400',
      payload: '{"summary":"Private therapy","email":"alice@example.com"}',
    );
    await _seedOutbox(
      db,
      id: 'op-queued',
      attempts: 1,
      lastError: 'rate limited',
      payload: '{"summary":"Secret project"}',
    );
    await _seedOutbox(db, id: 'op-clean', attempts: 0);
    final engine = SyncEngine(db, clientFactory: () => null);

    final issues = await engine.watchOutboxIssues().first.timeout(
      const Duration(seconds: 5),
    );

    expect(issues.map((issue) => issue.id).toSet(), {'op-failed', 'op-queued'});
    final failed = issues.firstWhere((issue) => issue.id == 'op-failed');
    expect(failed.errorLabel, 'Change was rejected');
    expect(failed.failed, isTrue);
    final queued = issues.firstWhere((issue) => issue.id == 'op-queued');
    expect(queued.errorLabel, 'Rate limited');
    expect(queued.failed, isFalse);
    expect(failed.toString(), isNot(contains('alice@example.com')));
    expect(failed.toString(), isNot(contains('Private therapy')));
  });

  test(
    'syncState diagnostics provider excludes tokens, readers and clean rows',
    () async {
      final db = _db();
      addTearDown(db.close);
      await _seedSyncState(db, key: 'cal:c1:meta', lastError: 'Google 403');
      await _seedSyncState(db, key: 'tasks:l1:meta', lastError: 'rate limited');
      await _seedSyncState(db, key: 'tasks', lastError: '');
      await _seedSyncState(db, key: 'cal:v2:c1:token', value: 'secret-token');
      await _seedSyncState(
        db,
        key: 'cal:reader:remote',
        value: 'a@example.com',
      );
      final engine = SyncEngine(db, clientFactory: () => null);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          syncEngineProvider.overrideWithValue(engine),
        ],
      );
      // A bare read of `.future` does not keep a StreamProvider alive.
      final subscription = container.listen(
        syncStateIssuesProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      addTearDown(container.dispose);

      final issues = await container
          .read(syncStateIssuesProvider.future)
          .timeout(const Duration(seconds: 5));

      final byKey = {for (final issue in issues) issue.key: issue};
      expect(byKey.keys.toSet(), {'cal:c1:meta', 'tasks:l1:meta'});
      expect(byKey['cal:c1:meta']!.errorLabel, 'Access denied');
      expect(byKey['tasks:l1:meta']!.errorLabel, 'Rate limited');
      expect(issues.any((issue) => issue.key.contains('token')), isFalse);
      expect(issues.any((issue) => issue.key.contains('reader')), isFalse);
      expect(issues.toString(), isNot(contains('secret-token')));
      expect(issues.toString(), isNot(contains('a@example.com')));
    },
  );

  test('discardFailed refuses a row that still has retries', () async {
    final db = _db();
    addTearDown(db.close);
    await _seedOutbox(db, id: 'op1', attempts: 1, lastError: 'rate limited');
    final engine = SyncEngine(db, clientFactory: () => null);

    expect(await engine.discardFailed('op1'), isFalse);
    expect(await db.select(db.outbox).get(), hasLength(1));
  });

  testWidgets('sync issues screen renders non-personal rows and retries', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(700, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = _db();
    addTearDown(db.close);
    await _seedOutbox(
      db,
      id: 'op1',
      attempts: 5,
      lastError: 'failed: 400',
      payload: '{"summary":"Private therapy","email":"alice@example.com"}',
    );
    await _seedSyncState(db, key: 'cal:c1:meta', lastError: 'Google 403');
    final engine = SyncEngine(db, clientFactory: () => null);
    var synced = false;

    await tester.pumpWidget(
      _app(
        changes: [_outboxIssue()],
        stateIssues: [
          _stateIssue('cal:c1:meta'),
          _stateIssue(
            'tasks:l1:meta',
            kind: SyncStateIssueKind.taskList,
            errorLabel: 'Rate limited',
          ),
        ],
        engine: engine,
        syncAll: () async => synced = true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Update event'), findsOneWidget);
    expect(find.textContaining('Change was rejected'), findsOneWidget);
    expect(find.textContaining('5 attempts'), findsOneWidget);
    expect(find.text('Calendar sync'), findsOneWidget);
    expect(find.textContaining('Access denied'), findsOneWidget);
    expect(find.text('Task-list sync'), findsOneWidget);
    expect(find.textContaining('Rate limited'), findsOneWidget);
    expect(find.textContaining('alice@example.com'), findsNothing);
    expect(find.textContaining('Private therapy'), findsNothing);
    expect(find.textContaining('super-secret-token'), findsNothing);

    await tester.tap(find.byKey(SyncIssuesScreen.outboxRetryKey('op1')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));

    expect(synced, isTrue);
    final retried = await (db.select(
      db.outbox,
    )..where((o) => o.id.equals('op1'))).getSingle();
    expect(retried.attempts, 0);
    expect(retried.lastError, isNull);

    await tester.tap(find.byKey(SyncIssuesScreen.stateRetryKey('cal:c1:meta')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));

    final cleared = await (db.select(
      db.syncState,
    )..where((s) => s.key.equals('cal:c1:meta'))).getSingle();
    expect(cleared.lastError, isNull);
  });

  testWidgets('discard requires confirmation and removes a failed row', (
    tester,
  ) async {
    final db = _db();
    addTearDown(db.close);
    await _seedOutbox(db, id: 'op2', attempts: 5, lastError: 'failed: 409');
    final engine = SyncEngine(db, clientFactory: () => null);

    await tester.pumpWidget(
      _app(
        changes: [_outboxIssue(id: 'op2')],
        stateIssues: const [],
        engine: engine,
        syncAll: () async {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(SyncIssuesScreen.outboxDiscardKey('op2')));
    await tester.pumpAndSettle();
    expect(find.text('Discard change?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));

    expect(await db.select(db.outbox).get(), isEmpty);
  });
}
