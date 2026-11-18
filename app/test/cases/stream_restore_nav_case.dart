// Cold-start restore and navigation for the Today-first shell with the opt-in
// Stream. Mounts the real router and AppShell; never mocks the behavior under
// test.
import 'package:drift/native.dart';
import 'package:ephemeron/app/router/app_router.dart';
import 'package:ephemeron/app/shell/app_shell.dart';
import 'package:ephemeron/app/shell/destinations.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/features/calendar/presentation/calendar_screen.dart';
import 'package:ephemeron/features/stream/presentation/stream_screen.dart';
import 'package:ephemeron/features/tasks/presentation/tasks_screen.dart';
import 'package:ephemeron/features/today/presentation/today_screen.dart';
import 'package:ephemeron/features/calendar/application/calendar_cache_coordinator.dart';
import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Harness {
  _Harness(this.router, this.db);

  final GoRouter router;
  final AppDatabase db;
}

const Map<String, Object> _basePrefs = <String, Object>{
  'settings.onboarded': true,
  'stream.school.completed': true,
};

Map<String, Object> _prefs({
  Object? lastTab,
  Object? navVersion,
  bool stream = false,
}) => <String, Object>{
  ..._basePrefs,
  if (stream) 'settings.streamEnabled': true,
  'session.lastTab': ?lastTab,
  'session.navVersion': ?navVersion,
};

void _setPhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _mockPlatformChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final name in const ['ephemeron/system', 'ephemeron/alarms']) {
    messenger.setMockMethodCallHandler(
      MethodChannel(name),
      (call) async => null,
    );
  }
}

Future<_Harness> _pumpApp(
  WidgetTester tester,
  Map<String, Object> prefs,
) async {
  _mockPlatformChannels();
  SharedPreferences.setMockInitialValues(prefs);
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  GoRouter? router;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        calendarRangeOccurrencesProvider.overrideWith(
          (ref, range) => Stream<List<OccurrenceCacheData>>.value(
            const <OccurrenceCacheData>[],
          ),
        ),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          final r = ref.watch(appRouterProvider);
          router = r;
          return MaterialApp.router(
            routerConfig: r,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
          );
        },
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
  return _Harness(router!, db);
}

Future<void> _unmount(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await db.close();
  await tester.pump();
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.last.matchedLocation;

String _streamLocation() => AppDestination.streamLocation();

void main() {
  testWidgets('fresh install lands on Today', (tester) async {
    _setPhoneView(tester);
    final app = await _pumpApp(tester, _prefs());
    try {
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(_location(app.router), '/today');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('session.lastTab'), isFalse);
      expect(prefs.getInt('session.navVersion'), 2);
    } finally {
      await _unmount(tester, app.db);
    }
  });

  testWidgets('legacy Calendar tab migrates to the new Calendar branch', (
    tester,
  ) async {
    _setPhoneView(tester);
    final app = await _pumpApp(tester, _prefs(lastTab: 0));
    try {
      expect(_location(app.router), '/calendar');
      expect(find.byType(CalendarScreen), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('session.lastTab'), 2);
      expect(prefs.getInt('session.navVersion'), 2);
    } finally {
      await _unmount(tester, app.db);
    }
  });

  testWidgets('legacy Stream tab falls back to Today when Stream is off', (
    tester,
  ) async {
    _setPhoneView(tester);
    final app = await _pumpApp(tester, _prefs(lastTab: 7));
    try {
      expect(_location(app.router), '/today');
      expect(find.byType(TodayScreen), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('session.lastTab'), 0);
    } finally {
      await _unmount(tester, app.db);
    }
  });

  testWidgets('legacy Stream tab reopens Stream when enabled', (tester) async {
    _setPhoneView(tester);
    final app = await _pumpApp(tester, _prefs(lastTab: 7, stream: true));
    try {
      expect(_location(app.router), _streamLocation());
      expect(find.byType(StreamScreen), findsOneWidget);
    } finally {
      await _unmount(tester, app.db);
    }
  });

  testWidgets('navVersion 2 restores new branch indices directly', (
    tester,
  ) async {
    _setPhoneView(tester);
    final app = await _pumpApp(tester, _prefs(lastTab: 7, navVersion: 2));
    try {
      expect(_location(app.router), '/matrix');
    } finally {
      await _unmount(tester, app.db);
    }
  });

  testWidgets('navVersion 2 stream branch is hidden when disabled', (
    tester,
  ) async {
    _setPhoneView(tester);
    final app = await _pumpApp(tester, _prefs(lastTab: 8, navVersion: 2));
    try {
      expect(_location(app.router), '/today');
    } finally {
      await _unmount(tester, app.db);
    }
  });

  testWidgets('direct stream URL shows Today and normalizes the route', (
    tester,
  ) async {
    _setPhoneView(tester);
    final app = await _pumpApp(tester, _prefs(lastTab: 1));
    try {
      app.router.go('/stream/2026-11-17/day');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(_location(app.router), '/today');
    } finally {
      await _unmount(tester, app.db);
    }
  });

  testWidgets('legacy /tab1 redirects to Tasks', (tester) async {
    _setPhoneView(tester);
    final app = await _pumpApp(tester, _prefs(lastTab: 1));
    try {
      app.router.go('/tab1');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_location(app.router), '/tasks');
      expect(find.byType(TasksScreen), findsOneWidget);
    } finally {
      await _unmount(tester, app.db);
    }
  });

  testWidgets('unknown stream zoom canonicalizes to the day level', (
    tester,
  ) async {
    _setPhoneView(tester);
    final app = await _pumpApp(tester, _prefs(lastTab: 1, stream: true));
    try {
      app.router.go('/stream/2026-11-17/hour');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(_location(app.router), '/stream/2026-11-17/day');
    } finally {
      await _unmount(tester, app.db);
    }
  });

  testWidgets('More shows Stream only when enabled and opens it', (
    tester,
  ) async {
    _setPhoneView(tester);
    final app = await _pumpApp(tester, _prefs(lastTab: 1));
    try {
      expect(_location(app.router), '/tasks');

      await tester.tap(find.byKey(const ValueKey<String>('shell-more')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey<String>('more-stream')), findsNothing);
      expect(find.byKey(const ValueKey<String>('more-dest-5')), findsOneWidget);
    } finally {
      await _unmount(tester, app.db);
    }
  });

  testWidgets('enabled Stream entry opens Stream and returns to Calendar', (
    tester,
  ) async {
    _setPhoneView(tester);
    final app = await _pumpApp(tester, _prefs(lastTab: 1, stream: true));
    try {
      await tester.tap(find.byKey(const ValueKey<String>('shell-more')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey<String>('more-stream')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('more-stream')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      expect(_location(app.router), _streamLocation());
      expect(find.byType(StreamScreen), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('shell-dest-2')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_location(app.router), '/calendar');
    } finally {
      await _unmount(tester, app.db);
    }
  });
}
