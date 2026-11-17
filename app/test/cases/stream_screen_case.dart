import 'package:ephemeron/features/stream/application/stream_day_mark.dart';
import 'package:ephemeron/features/stream/application/stream_day_providers.dart';
import 'package:ephemeron/features/stream/application/stream_theme_provider.dart';
import 'package:ephemeron/features/stream/design/stream_theme_mode.dart';
import 'package:ephemeron/features/stream/presentation/day/day_canvas.dart';
import 'package:ephemeron/features/stream/presentation/stream_day_body.dart';
import 'package:ephemeron/features/stream/presentation/stream_header.dart';
import 'package:ephemeron/features/stream/presentation/chrome/breadcrumb.dart';
import 'package:ephemeron/features/stream/presentation/chrome/scrubber.dart';
import 'package:ephemeron/features/stream/presentation/now_pill.dart';
import 'package:ephemeron/features/stream/presentation/chrome/time_rail.dart';
import 'package:ephemeron/features/stream/presentation/stream_screen.dart';
import 'package:ephemeron/features/stream/presentation/chrome/now_line.dart';
import 'package:ephemeron/features/stream/presentation/stream_time_format.dart';
import 'package:ephemeron/features/stream/presentation/surface/stream_launcher.dart';
import 'package:ephemeron/features/stream/stream_flags.dart';
import 'package:ephemeron/features/stream/presentation/stream_route_params.dart';
import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FixedStreamThemeNotifier extends StreamThemeNotifier {
  _FixedStreamThemeNotifier(this.mode);
  final StreamThemeMode mode;
  @override
  StreamThemeMode build() => mode;
}

final _fakeMarks = List<StreamDayMark>.generate(
  3,
  (i) => StreamDayMark(
    id: 'mark-$i',
    kind: StreamDayMarkKind.event,
    startMs: DateTime(2026, 11, 17, 8 + i).millisecondsSinceEpoch,
    endMs: DateTime(2026, 11, 17, 9 + i).millisecondsSinceEpoch,
    title: 'Mark $i',
    colorArgb: 0xFF123456,
  ),
);

Widget _app({
  required List<Override> overrides,
  required DateTime date,
  VoidCallback? onOpenCommand,
  VoidCallback? onOpenSettings,
  ValueChanged<DateTime>? onDateChanged,
  VoidCallback? onReturnToNow,
  StreamSyncStatus syncStatus = StreamSyncStatus.synced,
  String? syncLabel,
  Widget? homeOverride,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home:
          homeOverride ??
          StreamScreen(
            date: date,
            onOpenCommand: onOpenCommand,
            onOpenSettings: onOpenSettings,
            onDateChanged: onDateChanged,
            onReturnToNow: onReturnToNow,
            syncStatus: syncStatus,
            syncLabel: syncLabel,
          ),
    ),
  );
}

List<Override> _overrides() => <Override>[
  streamMarksForDayProvider.overrideWith(
    (ref, key) async => StreamDayMarks(marks: _fakeMarks, skippedCount: 0),
  ),
  streamThemeProvider.overrideWith(
    () => _FixedStreamThemeNotifier(StreamThemeMode.dark),
  ),
];

/// Minimal stand-in for the app router: the Stream route plus the launcher's
/// destinations. The real shell routes cannot be pushed from a bare test
/// router, so this asserts the navigation intent only.
GoRouter _launcherRouter() => GoRouter(
  initialLocation: '/stream/2026-11-17/day',
  routes: [
    GoRoute(
      path: '/stream/:date/:zoom',
      builder: (context, state) => StreamScreen(
        date: tryParseStreamDate(state.pathParameters['date']),
        zoom: state.pathParameters['zoom'],
      ),
    ),
    for (var i = 0; i < 7; i++)
      GoRoute(path: '/tab$i', builder: (_, _) => Text('tab$i')),
    GoRoute(path: '/search', builder: (_, _) => const Text('search')),
    GoRoute(path: '/settings', builder: (_, _) => const Text('settings')),
  ],
);

Widget _routerApp(GoRouter router) => ProviderScope(
  overrides: _overrides(),
  child: MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
  ),
);

/// Pushed routes are imperative matches, so [RouteMatchList.uri] keeps
/// reporting the base location; the last match is the visible one.
String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.last.matchedLocation;

void main() {
  test('streamUiEnabled defaults to false', () {
    expect(streamUiEnabled, isFalse);
  });

  test('invalid date and zoom fall back', () {
    final p = parseStreamRouteParams(date: 'nope', zoom: 'hour');
    expect(p.zoom, 'day');
    expect(p.date, isNotNull);
  });

  testWidgets('time labels respect 24-hour preference', (tester) async {
    for (final use24 in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(alwaysUse24HourFormat: use24),
            child: Builder(
              builder: (context) {
                final out = formatStreamTimeOfDay(
                  context,
                  DateTime(2026, 1, 1, 13, 5),
                );
                expect(out, use24 ? contains('13:05') : contains('PM'));
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pump();
    }
  });

  testWidgets('surface renders and scrubber is inset', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(overrides: _overrides(), date: DateTime(2026, 11, 17)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('2026-11-17'), findsOneWidget);
    expect(find.textContaining('Day'), findsOneWidget);
    expect(find.byType(DayCanvas), findsOneWidget);
    final canvas = tester.widget<DayCanvas>(find.byType(DayCanvas));
    expect(canvas.marks.length, 3);
    expect(find.byType(NowLine), findsOneWidget);

    final rect = tester.getRect(find.byType(Scrubber));
    expect(360.0 - rect.right, greaterThanOrEqualTo(24.0));
  });

  testWidgets('now line sits near 35 percent for injected now', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime(2026, 11, 17, 22, 9);
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(),
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: SizedBox(
            width: 360,
            height: 800,
            child: StreamDayBody(date: DateTime(2026, 11, 17), now: now),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final rect = tester.getRect(find.byType(NowLine));
    expect(rect.top, closeTo(800 * 0.35 - 10, 30));
  });

  testWidgets('now line absent on non-today date', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(),
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: SizedBox(
            width: 360,
            height: 800,
            child: StreamDayBody(
              date: DateTime(2026, 11, 15),
              now: DateTime(2026, 11, 17, 10, 0),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(NowLine), findsNothing);
  });

  testWidgets('layout breakpoints', (tester) async {
    final overrides = _overrides();
    for (final width in [360.0, 600.0, 840.0, 900.0]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(overrides: overrides, date: DateTime(2026, 11, 17)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      if (width < 600) {
        expect(find.byKey(const Key('sidePanelPlaceholder')), findsNothing);
        expect(find.byKey(const Key('leftPanelPlaceholder')), findsNothing);
      } else if (width < 840) {
        expect(find.byKey(const Key('sidePanelPlaceholder')), findsOneWidget);
      } else {
        expect(find.byKey(const Key('leftPanelPlaceholder')), findsOneWidget);
        expect(
          find.byKey(const Key('rightInspectorPlaceholder')),
          findsOneWidget,
        );
      }
    }
  });

  testWidgets('interactions and now pill', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var openCommand = 0;
    var openSettings = 0;
    var returnToNow = 0;

    await tester.pumpWidget(
      _app(
        overrides: _overrides(),
        date: DateTime(2026, 11, 17),
        onOpenCommand: () => openCommand++,
        onOpenSettings: () => openSettings++,
        onReturnToNow: () => returnToNow++,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(NowPill), findsNothing);

    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await tester.pump();
    expect(openSettings, 1);

    await tester.tap(find.byType(Breadcrumb));
    await tester.pump();
    expect(openCommand, 1);

    await tester.drag(find.byType(DayCanvas), const Offset(0, -600));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(NowPill), findsOneWidget);

    await tester.tap(find.byType(NowPill));
    await tester.pump();
    expect(returnToNow, 1);
    expect(find.byType(NowPill), findsNothing);
  });

  testWidgets('text scale at 320 dp no overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        overrides: _overrides(),
        date: DateTime(2026, 11, 17),
        homeOverride: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: StreamScreen(date: DateTime(2026, 11, 17)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sync indicator renders caller label with semantics', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final status in StreamSyncStatus.values) {
      final label = 'sync-label-$status';
      await tester.pumpWidget(
        _app(
          overrides: _overrides(),
          date: DateTime(2026, 11, 17),
          syncStatus: status,
          syncLabel: label,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.bySemanticsLabel(label), findsWidgets);
    }
  });

  testWidgets('null sync label leaves avatar labeled', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        overrides: _overrides(),
        date: DateTime(2026, 11, 17),
        syncLabel: null,
        syncStatus: StreamSyncStatus.synced,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final header = tester.widget<StreamHeader>(find.byType(StreamHeader));
    expect(header.syncLabel, isNull);
    expect(header.settingsLabel, isNotNull);
    expect(header.settingsLabel, isNotEmpty);
    expect(find.bySemanticsLabel(header.settingsLabel!), findsOneWidget);
  });

  testWidgets('settings navigation', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/stream/2026-11-17/day',
      routes: [
        GoRoute(
          path: '/stream/:date/:zoom',
          builder: (context, state) => StreamScreen(
            date: tryParseStreamDate(state.pathParameters['date']),
            zoom: state.pathParameters['zoom'],
          ),
        ),
        GoRoute(path: '/settings', builder: (_, _) => const Text('settings')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(),
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(router.routerDelegate.currentConfiguration.uri.path, '/settings');
  });

  testWidgets('rail window covers injected now', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime(2026, 11, 17, 22, 9);
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(),
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: SizedBox(
            width: 360,
            height: 800,
            child: StreamDayBody(date: DateTime(2026, 11, 17), now: now),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('10:00 PM'), findsOneWidget);
    expect(find.textContaining('6:00 AM'), findsOneWidget);

    final railRect = tester.getRect(find.byType(TimeRail));
    final labels = find.descendant(
      of: find.byType(TimeRail),
      matching: find.byType(Text),
    );
    final nearBottom = labels.evaluate().any((e) {
      final r = tester.getRect(find.byWidget(e.widget));
      return r.bottom >= railRect.bottom - 60;
    });
    expect(nearBottom, isTrue);
  });

  testWidgets('rail delta follows canvas scroll', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime(2026, 11, 17, 22, 9);
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(),
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: SizedBox(
            width: 360,
            height: 800,
            child: StreamDayBody(date: DateTime(2026, 11, 17), now: now),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final before = tester.getRect(find.text('10:00 PM'));
    await tester.drag(find.byType(DayCanvas), const Offset(0, -300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final after = tester.getRect(find.text('10:00 PM'));
    expect((after.top - before.top).abs(), closeTo(300, 40));
  });

  testWidgets('date change updates router location', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Fixed wall clock so the viewport starts at a known time; the drag below
    // is derived from the viewport mapping to cross exactly one local midnight.
    final now = DateTime(2026, 11, 17, 10, 0);
    final router = GoRouter(
      initialLocation: '/stream/2026-11-17/day',
      routes: [
        GoRoute(
          path: '/stream/:date/:zoom',
          builder: (context, state) => StreamScreen(
            date: tryParseStreamDate(state.pathParameters['date']),
            zoom: state.pathParameters['zoom'],
            now: now,
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(),
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final viewport = tester.widget<DayCanvas>(find.byType(DayCanvas)).viewport;
    final centerPx = viewport.offsetPx + viewport.viewportHeight / 2;
    final targetMs = DateTime(2026, 11, 18, 12).millisecondsSinceEpoch;
    final targetPx =
        (targetMs - viewport.baseEpochMs) /
        (viewport.minutesPerPixel * 60000.0);
    await tester.drag(find.byType(DayCanvas), Offset(0, centerPx - targetPx));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/stream/2026-11-18/day',
    );
    expect(find.textContaining('2026-11-18'), findsOneWidget);
  });

  testWidgets('stream day body re-centers on date change', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(),
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: SizedBox(
            width: 360,
            height: 800,
            child: StreamDayBody(
              date: DateTime(2026, 11, 17),
              now: DateTime(2026, 11, 17, 10, 0),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(NowLine), findsOneWidget);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(),
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: SizedBox(
            width: 360,
            height: 800,
            child: StreamDayBody(
              date: DateTime(2026, 11, 15),
              now: DateTime(2026, 11, 17, 10, 0),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(NowLine), findsNothing);
  });

  testWidgets('header menu opens the launcher', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_routerApp(_launcherRouter()));
    await tester.pumpAndSettle();

    final header = tester.widget<StreamHeader>(find.byType(StreamHeader));
    expect(header.menuLabel, isNotNull);
    expect(header.menuLabel, isNotEmpty);
    expect(find.bySemanticsLabel(header.menuLabel!), findsOneWidget);

    await tester.tap(find.byKey(const Key('streamHeaderMenu')));
    await tester.pumpAndSettle();

    expect(find.byType(StreamLauncher), findsOneWidget);
    expect(
      find.byKey(const Key('streamLauncherDestination-tasks')),
      findsOneWidget,
    );
  });

  testWidgets('launcher destinations navigate and close the sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const destinations = <StreamLauncherDestination, String>{
      StreamLauncherDestination.tasks: '/tab1',
      StreamLauncherDestination.settings: '/settings',
      StreamLauncherDestination.search: '/search',
    };
    for (final entry in destinations.entries) {
      final router = _launcherRouter();
      await tester.pumpWidget(_routerApp(router));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('streamHeaderMenu')));
      await tester.pumpAndSettle();
      expect(find.byType(StreamLauncher), findsOneWidget);

      await tester.tap(
        find.byKey(Key('streamLauncherDestination-${entry.key.name}')),
      );
      await tester.pumpAndSettle();

      expect(_location(router), entry.value);
      expect(find.byType(StreamLauncher), findsNothing);
    }
  });
}
