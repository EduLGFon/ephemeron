// Today-first UI <-> Stream interchangeability with the new branch indices.
import 'package:drift/native.dart';
import 'package:ephemeron/app/router/app_router.dart';
import 'package:ephemeron/app/shell/destinations.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/features/calendar/application/calendar_cache_coordinator.dart';
import 'package:ephemeron/features/stream/presentation/stream_screen.dart';
import 'package:ephemeron/features/tasks/presentation/tasks_screen.dart';
import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Map<String, Object> _basePrefs = <String, Object>{
  'settings.onboarded': true,
  'stream.school.completed': true,
  'settings.streamEnabled': true,
  'session.navVersion': 2,
};

Map<String, Object> _prefs({int? lastTab}) => <String, Object>{
  ..._basePrefs,
  'session.lastTab': ?lastTab,
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

class _Harness {
  _Harness(this.router, this.db);

  final GoRouter router;
  final AppDatabase db;
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

void main() {
  testWidgets('round trip Tasks -> Stream -> Tasks persists new indices', (
    tester,
  ) async {
    _setPhoneView(tester);
    final app = await _pumpApp(tester, _prefs(lastTab: 1));
    final router = app.router;
    try {
      expect(_location(router), '/tasks');
      expect(find.byType(TasksScreen), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('shell-more')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey<String>('more-stream')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(StreamScreen), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('session.lastTab'), 8);
      expect(prefs.getString('session.lastRoute'), startsWith('/stream/'));

      await tester.tap(find.byKey(const ValueKey<String>('shell-dest-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_location(router), '/tasks');
      expect(prefs.getInt('session.lastTab'), 1);
      expect(prefs.getString('session.lastRoute'), '/tasks');
    } finally {
      await _unmount(tester, app.db);
    }
  });

  testWidgets('cold start with lastTab=1 restores Tasks', (tester) async {
    _setPhoneView(tester);
    final app = await _pumpApp(tester, _prefs(lastTab: 1));
    try {
      expect(_location(app.router), '/tasks');
      expect(find.byType(TasksScreen), findsOneWidget);
    } finally {
      await _unmount(tester, app.db);
    }
  });

  testWidgets('Stream is reachable at the canonical branch URL', (
    tester,
  ) async {
    _setPhoneView(tester);
    final app = await _pumpApp(tester, _prefs(lastTab: 0));
    try {
      app.router.go(AppDestination.streamLocation(DateTime(2026, 11, 17)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(_location(app.router), '/stream/2026-11-17/day');
      expect(find.byType(StreamScreen), findsOneWidget);
    } finally {
      await _unmount(tester, app.db);
    }
  });
}
