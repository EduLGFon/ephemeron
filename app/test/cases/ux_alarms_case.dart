import 'dart:async';

import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/core/ui/app_feedback.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/habit_repository.dart';
import 'package:ephemeron/features/alarms/application/alarm_providers.dart';
import 'package:ephemeron/features/alarms/data/alarm_repository.dart';
import 'package:ephemeron/features/alarms/presentation/alarm_settings_screen.dart';
import 'package:ephemeron/features/alarms/presentation/alarm_settings_format.dart';
import 'package:ephemeron/features/alarms/presentation/alarm_source_route.dart';
import 'package:ephemeron/features/alarms/presentation/ring_screen.dart';
import 'package:ephemeron/features/settings/application/settings_providers.dart';
import 'package:ephemeron/features/settings/data/settings_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RebuildHost extends StatefulWidget {
  const _RebuildHost({required this.child});

  final Widget child;

  @override
  State<_RebuildHost> createState() => _RebuildHostState();
}

class _RebuildHostState extends State<_RebuildHost> {
  int _rebuilds = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            TextButton(
              key: const ValueKey('host-rebuild'),
              onPressed: () => setState(() => _rebuilds++),
              child: Text('rebuild $_rebuilds'),
            ),
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
  }
}

class _GatedAlarmRepository extends AlarmRepository {
  _GatedAlarmRepository(super.db, this.row);

  final AlarmsIndexData row;
  final doneGate = Completer<void>();
  final plusGate = Completer<void>();
  bool doneStarted = false;
  bool plusStarted = false;

  @override
  Future<AlarmsIndexData?> byRequestCode(int requestCode) async => row;

  @override
  Future<AlarmsIndexData?> latestFired() async => row;

  @override
  Future<void> markDone(int requestCode) async {
    doneStarted = true;
    await doneGate.future;
  }

  @override
  Future<void> completeHabitPlusOne(int requestCode) async {
    plusStarted = true;
    await plusGate.future;
  }

  @override
  Future<int> rebuildWindow({bool dueTomorrowEnabled = true}) async => 0;
}

void _mockPlatformChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('ephemeron/alarms'),
    (call) async => null,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('ephemeron/system'),
    (call) async => null,
  );
  messenger.setMockMessageHandler(
    'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
    (message) async =>
        const StandardMessageCodec().encodeMessage(const <Object?>[]),
  );
}

Widget _ringApp(ProviderContainer container) {
  final router = GoRouter(
    initialLocation: '/ring',
    routes: [
      GoRoute(path: '/ring', builder: (_, _) => const RingScreen()),
      GoRoute(
        path: '/tab0',
        builder: (_, _) => const Scaffold(body: Text('calendar')),
      ),
      GoRoute(
        path: '/tab3',
        builder: (_, _) => const Scaffold(body: Text('habits')),
      ),
    ],
  );
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('alarmSourceRoute', () {
    test('maps each source type to its section', () {
      expect(alarmSourceRoute('event'), '/tab0');
      expect(alarmSourceRoute('task'), '/tab1');
      expect(alarmSourceRoute('habit'), '/tab3');
      expect(alarmSourceRoute('habit_reminder'), '/tab3');
      expect(alarmSourceRoute('countdown'), '/tab4');
      expect(alarmSourceRoute('focus'), '/tab5');
      expect(alarmSourceRoute('test'), '/alarm-settings');
    });

    test('reminder variants follow their parent section', () {
      expect(alarmSourceRoute('event_reminder'), '/tab0');
      expect(alarmSourceRoute('task_reminder'), '/tab1');
      expect(alarmSourceRoute('task_due_tomorrow'), '/tab1');
      expect(alarmSourceRoute('countdown_reminder'), '/tab4');
    });

    test('null and unknown sources fall back to calendar', () {
      expect(alarmSourceRoute(null), '/tab0');
      expect(alarmSourceRoute(''), '/tab0');
      expect(alarmSourceRoute('unexpected'), '/tab0');
    });
  });

  group('alarmSourceLabel', () {
    test('labels known sources and their reminder variants', () {
      expect(alarmSourceLabel('event'), 'Event');
      expect(alarmSourceLabel('event_reminder'), 'Event');
      expect(alarmSourceLabel('task'), 'Task');
      expect(alarmSourceLabel('task_due_tomorrow'), 'Task');
      expect(alarmSourceLabel('habit'), 'Habit');
      expect(alarmSourceLabel('habit_reminder'), 'Habit');
      expect(alarmSourceLabel('countdown'), 'Countdown');
      expect(alarmSourceLabel('countdown_reminder'), 'Countdown');
      expect(alarmSourceLabel('focus'), 'Focus');
      expect(alarmSourceLabel('test'), 'Test');
    });

    test('unknown sources have no chip label', () {
      expect(alarmSourceLabel(null), isNull);
      expect(alarmSourceLabel('unexpected'), isNull);
    });
  });

  group('formatAlarmFireTime', () {
    test('converts UTC milliseconds to local time', () {
      final local = DateTime(2026, 3, 2, 14, 30);
      final ms = local.toUtc().millisecondsSinceEpoch;

      expect(
        formatAlarmFireTime(ms, DateFormat('yyyy-MM-dd HH:mm')),
        '2026-03-02 14:30',
      );
    });

    test('uses the supplied device formatter', () {
      final local = DateTime(2026, 11, 9, 7, 5);
      final ms = local.toUtc().millisecondsSinceEpoch;

      expect(
        formatAlarmFireTime(ms, DateFormat('yyyy/MM/dd HH:mm')),
        '2026/11/09 07:05',
      );
    });
  });

  testWidgets('permission tiles resolve their futures once across rebuilds', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    var exactCalls = 0;
    var fullScreenCalls = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('ephemeron/alarms'),
      (call) async {
        if (call.method == 'canScheduleExact') {
          exactCalls++;
          return false;
        }
        return null;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('ephemeron/system'),
      (call) async {
        if (call.method == 'canUseFullScreenIntent') {
          fullScreenCalls++;
          return false;
        }
        return null;
      },
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(
        const MethodChannel('ephemeron/alarms'),
        null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('ephemeron/system'),
        null,
      );
    });

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final settings = SettingsRepository(await SharedPreferences.getInstance());
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        settingsRepositoryProvider.overrideWith((ref) async => settings),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _RebuildHost(child: AlarmSettingsScreen()),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(exactCalls, 1);
    expect(fullScreenCalls, 1);

    await tester.tap(find.byKey(const ValueKey('host-rebuild')));
    await tester.pumpAndSettle();

    expect(exactCalls, 1);
    expect(fullScreenCalls, 1);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('permission tiles re-query after returning from settings', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    var exactCalls = 0;
    var fullScreenCalls = 0;
    var exactGranted = false;
    var fullScreenGranted = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('ephemeron/alarms'),
      (call) async {
        if (call.method == 'canScheduleExact') {
          exactCalls++;
          return exactGranted;
        }
        if (call.method == 'openExactAlarmSettings') {
          exactGranted = true;
          return null;
        }
        return null;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('ephemeron/system'),
      (call) async {
        if (call.method == 'canUseFullScreenIntent') {
          fullScreenCalls++;
          return fullScreenGranted;
        }
        return null;
      },
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(
        const MethodChannel('ephemeron/alarms'),
        null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('ephemeron/system'),
        null,
      );
    });

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final settings = SettingsRepository(await SharedPreferences.getInstance());
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        settingsRepositoryProvider.overrideWith((ref) async => settings),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _RebuildHost(child: AlarmSettingsScreen()),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(exactCalls, 1);
    expect(find.text('Not granted'), findsNWidgets(2));

    await tester.tap(find.widgetWithText(FilledButton, 'Open settings').first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Open settings'),
      ),
    );
    await tester.pumpAndSettle();

    expect(exactCalls, greaterThan(1));
    expect(find.text('Granted'), findsOneWidget);

    fullScreenGranted = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(fullScreenCalls, greaterThan(1));
    expect(find.text('Granted'), findsNWidgets(2));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Done haptic fires only after the action resolves', (
    tester,
  ) async {
    _mockPlatformChannels();
    final haptics = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add('${call.arguments}');
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final previousHaptics = AppFeedback.hapticsEnabled;
    AppFeedback.hapticsEnabled = true;
    addTearDown(() => AppFeedback.hapticsEnabled = previousHaptics);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final row = AlarmsIndexData(
      id: 'alarm-1',
      sourceType: 'task',
      sourceId: 'task-1',
      fireAtUtc: 0,
      requestCode: 42,
      state: 'fired',
      kind: 'alarm',
      title: 'Task alarm',
      preset: 'notification',
    );
    final repo = _GatedAlarmRepository(db, row);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        alarmRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    container.read(activeRingRequestProvider.notifier).set(42);

    await tester.pumpWidget(_ringApp(container));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Done'));
    await tester.pump();

    expect(repo.doneStarted, isTrue);
    expect(haptics, isEmpty);

    repo.doneGate.complete();
    await tester.pumpAndSettle();

    expect(haptics, isNotEmpty);
    expect(haptics.single, contains('mediumImpact'));
  });

  testWidgets('+1 haptic fires only after the action resolves', (tester) async {
    _mockPlatformChannels();
    final haptics = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add('${call.arguments}');
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final previousHaptics = AppFeedback.hapticsEnabled;
    AppFeedback.hapticsEnabled = true;
    addTearDown(() => AppFeedback.hapticsEnabled = previousHaptics);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final habitId = await HabitRepository(
      db,
    ).createHabit(name: 'Stretch', startDate: '2026-01-01', goalAmount: 10);
    final row = AlarmsIndexData(
      id: 'alarm-2',
      sourceType: 'habit',
      sourceId: habitId,
      fireAtUtc: 0,
      requestCode: 43,
      state: 'fired',
      kind: 'alarm',
      title: 'Habit alarm',
      preset: 'notification',
    );
    final repo = _GatedAlarmRepository(db, row);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        alarmRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    container.read(activeRingRequestProvider.notifier).set(43);

    await tester.pumpWidget(_ringApp(container));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('+1'));
    await tester.pump();

    expect(repo.plusStarted, isTrue);
    expect(haptics, isEmpty);

    repo.plusGate.complete();
    await tester.pumpAndSettle();

    expect(haptics, isNotEmpty);
    expect(haptics.single, contains('mediumImpact'));
  });
}
