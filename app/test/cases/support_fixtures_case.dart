import 'package:drift/drift.dart' show Value;
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/test_fixtures.dart';

void main() {
  test('newTestDb opens and supports insert/read/reset', () async {
    final db = newTestDb();
    addTearDown(() async {
      await db.close();
    });

    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.calendars)
        .insert(
          CalendarsCompanion.insert(
            id: 'cal-1',
            name: 'Test Calendar',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.notes)
        .insert(
          NotesCompanion.insert(
            id: 'note-1',
            title: const Value('Hello FTS'),
            body: const Value('body'),
            createdAt: now,
            updatedAt: now,
          ),
        );

    final rowsBeforeReset = await db.select(db.calendars).get();
    expect(rowsBeforeReset, hasLength(1));
    expect(rowsBeforeReset.single.name, 'Test Calendar');
    final ftsBeforeReset = await db
        .customSelect('SELECT rowid FROM notes_fts')
        .get();
    expect(ftsBeforeReset, isNotEmpty);

    await resetTestDb(db);

    final rowsAfterReset = await db.select(db.calendars).get();
    expect(rowsAfterReset, isEmpty);
    final ftsAfterReset = await db
        .customSelect('SELECT rowid FROM notes_fts')
        .get();
    expect(ftsAfterReset, isEmpty);
  });

  testWidgets('settle completes on a finite animation without throwing', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, const MaterialApp(home: _FiniteAnimationProbe()));

    // The animation is 300ms; settle should return once frames stop scheduling.
    await settle(
      tester,
      step: const Duration(milliseconds: 20),
      max: const Duration(seconds: 1),
    );

    expect(find.text('done'), findsOneWidget);
  });
}

class _FiniteAnimationProbe extends StatefulWidget {
  const _FiniteAnimationProbe();

  @override
  State<_FiniteAnimationProbe> createState() => _FiniteAnimationProbeState();
}

class _FiniteAnimationProbeState extends State<_FiniteAnimationProbe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isCompleted) {
          return const Text('done', textDirection: TextDirection.ltr);
        }
        return const Text('running', textDirection: TextDirection.ltr);
      },
    );
  }
}
