import 'package:drift/native.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/focus_repository.dart';
import 'package:ephemeron/features/focus/presentation/focus_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('overtime countdown formats negative remaining', () {
    expect(formatFocusCountdown(-300000), '-05:00');
    expect(formatFocusCountdown(120000), '02:00');
  });

  test('updateNote persists note without finishing', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = FocusRepository(db);
    final id = await repo.startSession(durationMin: 25);
    await repo.updateNote(id, 'hello');
    final s = await (db.select(
      db.focusSessions,
    )..where((f) => f.id.equals(id))).getSingle();
    expect(s.note, 'hello');
    expect(s.endUtc, isNull);
  });
}
