import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ephemeron/app/session/session_restore.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/core/time/device_date_format.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/features/calendar/presentation/event_editor_sheet.dart';
import 'package:ephemeron/features/settings/application/settings_providers.dart';
import 'package:ephemeron/features/settings/data/settings_repository.dart';

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

const _staleTitle = 'Stale draft title';
final _staleStart = DateTime(2025, 1, 6, 7);
final _staleEnd = DateTime(2025, 1, 6, 8);
final _explicitStart = DateTime(2026, 5, 14, 15, 30);
final _explicitEnd = DateTime(2026, 5, 14, 16, 30);

Future<void> _seedStaleDraft(AppDatabase db) async {
  await DraftStore(db).save('event', 'new', {
    'title': _staleTitle,
    'startMs': _staleStart.millisecondsSinceEpoch,
    'endMs': _staleEnd.millisecondsSinceEpoch,
  });
}

Future<void> _pumpHost(
  WidgetTester tester,
  AppDatabase db,
  SharedPreferences prefs, {
  DateTime? initialDay,
  DateTime? initialStart,
  DateTime? initialEnd,
  bool? initialAllDay,
}) async {
  const systemChannel = MethodChannel('ephemeron/system');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    systemChannel,
    (call) async => call.method == 'canPostNotifications' ? true : null,
  );
  addTearDown(() => messenger.setMockMethodCallHandler(systemChannel, null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        settingsRepositoryProvider.overrideWith(
          (ref) async => SettingsRepository(prefs),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showEventEditor(
                  context,
                  initialDay: initialDay,
                  initialStart: initialStart,
                  initialEnd: initialEnd,
                  initialAllDay: initialAllDay,
                ),
                child: const Text('Open event'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open event'));
  await tester.pumpAndSettle();
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(Container());
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('explicit grid slot timing wins over a stale new-event draft', (
    WidgetTester tester,
  ) async {
    final db = _db();
    addTearDown(db.close);
    await _seedStaleDraft(db);
    await _pumpHost(
      tester,
      db,
      await SharedPreferences.getInstance(),
      initialStart: _explicitStart,
      initialEnd: _explicitEnd,
    );

    final ctx = tester.element(find.text('Open event'));
    final explicitDate = DeviceDateFormat.date(ctx, _explicitStart);
    final staleDate = DeviceDateFormat.date(ctx, _staleStart);
    // Non-time draft fields still restore.
    expect(find.text(_staleTitle), findsOne);
    // Explicit grid timing wins over the draft's stale start/end.
    expect(find.text(explicitDate), findsNWidgets(2));
    expect(find.text(staleDate), findsNothing);
    expect(find.text(DeviceDateFormat.time(ctx, _explicitStart)), findsOne);
    expect(find.text(DeviceDateFormat.time(ctx, _explicitEnd)), findsOne);
    expect(find.text(DeviceDateFormat.time(ctx, _staleStart)), findsNothing);
    expect(find.text(DeviceDateFormat.time(ctx, _staleEnd)), findsNothing);

    await _disposeTree(tester);
  });

  testWidgets('explicit all-day create wins over a stale timed draft', (
    WidgetTester tester,
  ) async {
    final db = _db();
    addTearDown(db.close);
    await _seedStaleDraft(db);
    final day = DateTime(2026, 5, 14);
    await _pumpHost(
      tester,
      db,
      await SharedPreferences.getInstance(),
      initialDay: day,
      initialAllDay: true,
    );

    final ctx = tester.element(find.text('Open event'));
    expect(find.text(_staleTitle), findsOne);
    final allDay = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'All day'),
    );
    expect(allDay.value, isTrue);
    expect(find.text(DeviceDateFormat.date(ctx, day)), findsNWidgets(2));
    expect(find.text(DeviceDateFormat.date(ctx, _staleStart)), findsNothing);
    expect(find.text(DeviceDateFormat.time(ctx, _staleStart)), findsNothing);
    expect(find.text(DeviceDateFormat.time(ctx, _staleEnd)), findsNothing);

    await _disposeTree(tester);
  });

  testWidgets('no explicit time still restores the new-event draft', (
    WidgetTester tester,
  ) async {
    final db = _db();
    addTearDown(db.close);
    await _seedStaleDraft(db);
    await _pumpHost(tester, db, await SharedPreferences.getInstance());

    final ctx = tester.element(find.text('Open event'));
    expect(find.text(_staleTitle), findsOne);
    expect(
      find.text(DeviceDateFormat.date(ctx, _staleStart)),
      findsNWidgets(2),
    );
    expect(find.text(DeviceDateFormat.time(ctx, _staleStart)), findsOne);

    await _disposeTree(tester);
  });
}
