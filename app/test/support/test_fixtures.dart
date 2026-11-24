import 'package:drift/native.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Creates a fresh in-memory [AppDatabase] for tests.
///
/// Uses [AppDatabase.forTesting] with a [NativeDatabase.memory] executor so
/// each test gets an isolated database without touching disk.
///
/// The caller is responsible for closing the returned database, for example via
/// `addTearDown(db.close)` or an explicit `await db.close()`.
AppDatabase newTestDb() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}

/// Deletes rows from every user table in [db] and resets sqlite sequence state.
///
/// Foreign key checks are temporarily disabled so deletion is FK-safe regardless
/// of table order, while still iterating every table from [db.allTables]. If the
/// `sqlite_sequence` table exists, its rows are removed so autoincrement counters
/// reset for the next test. FTS content stays consistent because deletes from
/// content tables fire the schema's FTS sync triggers.
Future<void> resetTestDb(AppDatabase db) async {
  await db.customStatement('PRAGMA foreign_keys = OFF');
  try {
    for (final table in db.allTables) {
      await db.delete(table).go();
    }
    final sequenceTables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='sqlite_sequence'",
        )
        .get();
    if (sequenceTables.isNotEmpty) {
      await db.customStatement('DELETE FROM sqlite_sequence');
    }
  } finally {
    await db.customStatement('PRAGMA foreign_keys = ON');
  }
}

/// Pumps frames until no frame is scheduled or [max] elapsed.
///
/// The loop is bounded by [max] and returns normally once no frame is scheduled.
/// Pump errors propagate to the caller instead of being swallowed.
Future<void> settle(
  WidgetTester tester, {
  Duration step = const Duration(milliseconds: 50),
  Duration max = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(max);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(step);
    if (!tester.binding.hasScheduledFrame) {
      return;
    }
  }
  // Final pump to drain any pending microtasks at deadline.
  await tester.pump(Duration.zero);
}

/// Pumps [app] into the widget tree and performs one bounded [settle].
Future<void> pumpApp(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await settle(tester);
}
