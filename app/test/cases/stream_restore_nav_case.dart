// Cold-start restore and More-sheet navigation for the Stream branch.
//
// These tests mount the real router and AppShell (or the real MoreSheet
// widget), never a mock of the behavior under test.
import 'package:drift/native.dart';
import 'package:ephemeron/app/router/app_router.dart';
import 'package:ephemeron/app/shell/app_shell.dart';
import 'package:ephemeron/app/shell/more_sheet.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/features/calendar/presentation/calendar_screen.dart';
import 'package:ephemeron/features/stream/presentation/day/day_canvas.dart';
import 'package:ephemeron/features/stream/presentation/stream_route_params.dart';
import 'package:ephemeron/features/stream/presentation/stream_screen.dart';
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

Map<String, Object> _prefs({Object? lastTab}) => <String, Object>{
  ..._basePrefs,
  'session.lastTab': ?lastTab,
};

void _setPhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Lets AppShell's startup channel reads complete in the widget test instead
/// of waiting on platform replies that never arrive.
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

String _streamLocation() => '/stream/${formatStreamDate(DateTime.now())}/day';

/// Pumps the production router, which builds the production AppShell and
/// session restore. Returns the live router for real-location assertions.
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
      overrides: [appDatabaseProvider.overrideWithValue(db)],
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

/// Unmounts the tree while pumps still run so Riverpod disposes its drift
/// stream subscriptions before the database closes.
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
  testWidgets('cold start with a persisted stream tab reopens stream', (
    tester,
  ) async {
    _setPhoneView(tester);
    final app = await _pumpApp(tester, _prefs(lastTab: 7));
    try {
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(StreamScreen), findsOneWidget);
      // A stale clamp to the legacy 0..6 range would land on /tab6.
      expect(_location(app.router), _streamLocation());
    } finally {
      await _unmount(tester, app.db);
    }
  });

  testWidgets('fresh install lands on the stream day view', (tester) async {
    _setPhoneView(tester);
    final app = await _pumpApp(tester, _prefs());
    try {
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(StreamScreen), findsOneWidget);
      expect(_location(app.router), _streamLocation());
      // Restore must not persist a legacy tab for a fresh install.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('session.lastTab'), isFalse);
    } finally {
      await _unmount(tester, app.db);
    }
  });

  testWidgets('a persisted legacy tab still restores that tab', (tester) async {
    _setPhoneView(tester);
    final app = await _pumpApp(tester, _prefs(lastTab: 0));
    try {
      expect(find.byType(AppShell), findsOneWidget);
      expect(_location(app.router), '/tab0');
      expect(find.byType(CalendarScreen), findsOneWidget);
    } finally {
      await _unmount(tester, app.db);
    }
  });

  testWidgets('More sheet stream entry opens the stream branch and back', (
    tester,
  ) async {
    _setPhoneView(tester);
    final app = await _pumpApp(tester, _prefs(lastTab: 1));
    try {
      expect(_location(app.router), '/tab1');

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('more-stream')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('more-stream')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      // goBranch(7) on a never-visited branch must resolve its concrete
      // initialLocation instead of asserting on the date/zoom parameters.
      expect(tester.takeException(), isNull);
      expect(_location(app.router), _streamLocation());
      expect(find.byType(StreamScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.calendar_month_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_location(app.router), '/tab0');
      expect(find.byType(CalendarScreen), findsOneWidget);
    } finally {
      await _unmount(tester, app.db);
    }
  });

  testWidgets('unknown zoom canonicalizes to the day level', (tester) async {
    _setPhoneView(tester);
    final app = await _pumpApp(tester, _prefs());
    try {
      app.router.go('/stream/2026-11-17/hour');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(_location(app.router), '/stream/2026-11-17/day');
      expect(find.byType(DayCanvas), findsOneWidget);
    } finally {
      await _unmount(tester, app.db);
    }
  });

  testWidgets('missing zoom renders the day level at 320 dp and 2.0 scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues(_basePrefs);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2.0),
            ),
            child: StreamScreen(date: DateTime(2026, 11, 17), zoom: null),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    try {
      expect(find.byType(DayCanvas), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await _unmount(tester, db);
    }
  });

  testWidgets('More sheet stream entry works at 320 dp and 2.0 scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2.0),
          ),
          child: Scaffold(
            body: MoreSheet(
              more: const <int>[4, 2],
              onSelected: (idx) => selected = idx,
              onReorder: () {},
              onSearch: () {},
              onSettings: () {},
              onCreate: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('more-stream')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('more-stream')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('more-stream')));
    await tester.pump();
    expect(selected, 7);
    expect(tester.takeException(), isNull);
  });
}
