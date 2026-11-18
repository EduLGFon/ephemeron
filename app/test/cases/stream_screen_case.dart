import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/features/calendar/application/calendar_providers.dart';
import 'package:ephemeron/features/calendar/application/calendar_state.dart';
import 'package:ephemeron/features/stream/application/stream_capture_actions.dart';
import 'package:ephemeron/features/stream/application/stream_capture_gateway.dart';
import 'package:ephemeron/features/stream/application/stream_capture_outcome.dart';
import 'package:ephemeron/features/stream/application/stream_day_cache.dart';
import 'package:ephemeron/features/stream/application/stream_day_cache_scope.dart';
import 'package:ephemeron/features/stream/application/stream_day_mark.dart';
import 'package:ephemeron/features/stream/application/stream_day_providers.dart';
import 'package:ephemeron/features/stream/application/stream_command_actions.dart';
import 'package:ephemeron/features/stream/application/stream_level_data.dart';
import 'package:ephemeron/features/stream/application/stream_level_streaks.dart';
import 'package:ephemeron/features/stream/application/stream_peek_target.dart';
import 'package:ephemeron/features/stream/application/stream_school_preferences.dart';
import 'package:ephemeron/features/stream/application/stream_slipped_data.dart';
import 'package:ephemeron/features/stream/application/stream_sync_status.dart';
import 'package:ephemeron/features/stream/application/stream_theme_provider.dart';
import 'package:ephemeron/features/stream/application/stream_tray.dart';
import 'package:ephemeron/features/stream/application/stream_tray_actions.dart';
import 'package:ephemeron/features/stream/capture/capture_parser.dart'
    show CaptureDraft;
import 'package:ephemeron/features/stream/design/stream_theme_mode.dart';
import 'package:ephemeron/features/stream/presentation/capture/capture_bar.dart';
import 'package:ephemeron/features/stream/presentation/commands/command_palette.dart';
import 'package:ephemeron/features/stream/presentation/day/day_canvas.dart';
import 'package:ephemeron/features/stream/presentation/levels/month_view.dart';
import 'package:ephemeron/features/stream/presentation/levels/week_view.dart';
import 'package:ephemeron/features/stream/presentation/levels/year_view.dart';
import 'package:ephemeron/features/stream/presentation/stream_day_body.dart';
import 'package:ephemeron/features/stream/presentation/stream_header.dart';
import 'package:ephemeron/features/stream/presentation/chrome/breadcrumb.dart';
import 'package:ephemeron/features/stream/presentation/chrome/scrubber.dart';
import 'package:ephemeron/features/stream/presentation/now_pill.dart';
import 'package:ephemeron/features/stream/presentation/peek/peek_data.dart';
import 'package:ephemeron/features/stream/presentation/peek/peek_panel.dart';
import 'package:ephemeron/features/stream/presentation/school/gesture_school_overlay.dart';
import 'package:ephemeron/features/stream/presentation/slipped/slipped_item.dart';
import 'package:ephemeron/features/stream/presentation/chrome/time_rail.dart';
import 'package:ephemeron/features/stream/presentation/stream_screen.dart';
import 'package:ephemeron/features/stream/presentation/chrome/now_line.dart';
import 'package:ephemeron/features/stream/presentation/stream_time_format.dart';
import 'package:ephemeron/features/stream/presentation/surface/stream_agenda_host.dart';
import 'package:ephemeron/features/stream/presentation/surface/stream_launcher.dart';
import 'package:ephemeron/features/stream/presentation/surface/stream_offline_banner_host.dart';
import 'package:ephemeron/features/stream/presentation/surface/stream_peek_sheet.dart';
import 'package:ephemeron/features/stream/presentation/surface/stream_settings_sheet.dart';
import 'package:ephemeron/features/stream/presentation/tray/tray_chip.dart';
import 'package:ephemeron/features/stream/presentation/tray/tray_item.dart';
import 'package:ephemeron/features/stream/presentation/tray/tray_panel.dart';
import 'package:ephemeron/features/stream/presentation/tray/tray_strip.dart';
import 'package:ephemeron/features/stream/presentation/stream_route_params.dart';
import 'package:ephemeron/app/router/app_router.dart';
import 'package:ephemeron/app/shell/app_shell.dart';
import 'package:ephemeron/app/shell/destinations.dart';
import 'package:ephemeron/features/calendar/application/calendar_cache_coordinator.dart';
import 'package:ephemeron/features/settings/application/settings_providers.dart';
import 'package:ephemeron/features/today/presentation/today_screen.dart';
import 'package:ephemeron/features/settings/data/settings_repository.dart';
import 'package:ephemeron/features/sync/application/sync_providers.dart';
import 'package:ephemeron/features/sync/data/sync_engine.dart' show SyncStatus;
import 'package:ephemeron/features/tasks/application/tasks_providers.dart'
    show openTasksProvider, taskListsProvider;
import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey, MethodChannel;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FixedStreamThemeNotifier extends StreamThemeNotifier {
  _FixedStreamThemeNotifier(this.mode);
  final StreamThemeMode mode;
  @override
  StreamThemeMode build() => mode;
}

class _RecordingThemeNotifier extends StreamThemeNotifier {
  _RecordingThemeNotifier(this.mode);
  StreamThemeMode mode;
  int setModeCalls = 0;
  StreamThemeMode? lastMode;

  @override
  StreamThemeMode build() => mode;

  @override
  Future<void> setMode(StreamThemeMode value) async {
    setModeCalls++;
    lastMode = value;
    mode = value;
    state = value;
  }
}

class _FixedSchoolNotifier extends StreamSchoolCompletedNotifier {
  _FixedSchoolNotifier(this.completed);
  final bool completed;
  @override
  Future<bool> build() async => completed;
  @override
  Future<void> markCompleted() async => state = const AsyncData(true);
}

class _RecordingSchoolNotifier extends StreamSchoolCompletedNotifier {
  _RecordingSchoolNotifier({required this.completed});
  bool completed;
  int resetCalls = 0;

  @override
  Future<bool> build() async => completed;

  @override
  Future<void> reset() async {
    resetCalls++;
    completed = false;
    state = const AsyncData(false);
  }
}

/// Interface filler: the fake actions below override submit, so no gateway
/// method is ever called.
class _UnusedCaptureGateway implements StreamCaptureGateway {
  @override
  Future<Never> noSuchMethod(Invocation invocation) =>
      Future<Never>.error(UnimplementedError('unused capture gateway'));
}

class _FakeCaptureActions extends StreamCaptureActions {
  _FakeCaptureActions() : super(_UnusedCaptureGateway());

  final List<CaptureDraft> drafts = <CaptureDraft>[];
  final List<DateTime> submittedAt = <DateTime>[];

  @override
  Future<CaptureOutcome> submit(
    CaptureDraft draft, {
    required DateTime now,
  }) async {
    drafts.add(draft);
    submittedAt.add(now);
    return CaptureOutcome(kind: draft.kind, id: 'captured-${drafts.length}');
  }
}

class _FakeCacheGateway implements StreamDayCacheGateway {
  final List<CalendarRange> calls = <CalendarRange>[];

  @override
  Future<void> rebuild(CalendarRange range) async => calls.add(range);
}

class _NullBuiltRange extends CalendarBuiltRange {
  @override
  CalendarRange? build() => null;
}

class _TrayUpdate {
  const _TrayUpdate({
    required this.taskId,
    required this.plannedStart,
    required this.plannedEnd,
    required this.dueTime,
  });

  final String taskId;
  final String? plannedStart;
  final String? plannedEnd;
  final int? dueTime;
}

class _FakeTrayGateway implements StreamTrayGateway {
  final updates = <_TrayUpdate>[];
  final rebuiltDays = <DateTime>[];

  @override
  Future<void> updateTask(
    String taskId, {
    required String? plannedStart,
    required String? plannedEnd,
    required String? plannedDate,
    int? dueTime,
  }) async {
    updates.add(
      _TrayUpdate(
        taskId: taskId,
        plannedStart: plannedStart,
        plannedEnd: plannedEnd,
        dueTime: dueTime,
      ),
    );
  }

  @override
  Future<void> rebuildDay(DateTime day) async => rebuiltDays.add(day);
}

class _FakeCommandExecutor extends StreamCommandExecutor {
  _FakeCommandExecutor()
    : super(setThemeMode: (_) async {}, syncNow: () async {});

  final List<StreamCommandIntent> intents = <StreamCommandIntent>[];

  @override
  Future<StreamCommandResult> execute(StreamCommandIntent intent) async {
    intents.add(intent);
    return const StreamCommandHandled();
  }
}

const List<TrayItem> _trayItems = <TrayItem>[
  TrayItem(
    id: 't1',
    title: 'Unscheduled one',
    listId: 'l1',
    listName: 'Work',
    colorArgb: 0xFF336699,
  ),
  TrayItem(
    id: 't2',
    title: 'Unscheduled two',
    listId: 'l1',
    listName: 'Work',
    colorArgb: 0xFF336699,
  ),
  TrayItem(
    id: 't3',
    title: 'Unscheduled three',
    listId: 'l2',
    listName: 'Home',
    colorArgb: 0xFF996633,
  ),
];

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
  String? zoom,
  DateTime? now,
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
            zoom: zoom,
            now: now,
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

List<Override> _overrides({
  List<TrayItem> tray = const <TrayItem>[],
  _FakeCaptureActions? actions,
  _FakeCacheGateway? cache,
  bool schoolCompleted = true,
  StreamThemeNotifier Function()? theme,
  StreamSchoolCompletedNotifier Function()? school,
}) => <Override>[
  streamMarksForDayProvider.overrideWith(
    (ref, key) async => StreamDayMarks(marks: _fakeMarks, skippedCount: 0),
  ),
  streamThemeProvider.overrideWith(
    theme ?? () => _FixedStreamThemeNotifier(StreamThemeMode.dark),
  ),
  streamTrayItemsProvider.overrideWith(
    (ref) => Stream<List<TrayItem>>.value(tray),
  ),
  streamDayCacheGatewayProvider.overrideWithValue(cache ?? _FakeCacheGateway()),
  streamCaptureActionsProvider.overrideWithValue(
    actions ?? _FakeCaptureActions(),
  ),
  streamSlippedItemsProvider.overrideWith(
    (ref) => Stream<List<SlippedItem>>.value(const <SlippedItem>[]),
  ),
  streamSchoolCompletedProvider.overrideWith(
    school ?? () => _FixedSchoolNotifier(schoolCompleted),
  ),
];

/// Covers one level range with the shared fake marks and no habit ribbons.
List<Override> _levelOverrides(
  StreamLevel level,
  DateTime date, {
  StreamLevelHabitStreaks streaks = const StreamLevelHabitStreaks(),
}) {
  final range = streamLevelRangeFor(
    level,
    date,
    firstDayOfWeek: DateTime.monday,
  );
  return <Override>[
    streamLevelMarksProvider(range).overrideWithValue(
      AsyncData(StreamLevelMarks(marks: _fakeMarks, skipped: 0, covered: true)),
    ),
    streamLevelHabitStreaksProvider(range)
        .overrideWithValue(AsyncData(streaks)),
  ];
}

/// Minimal stand-in for the app router: the Stream route plus the launcher's
/// destinations. The real shell routes cannot be pushed from a bare test
/// router, so this asserts the navigation intent only.
GoRouter _launcherRouter({
  DateTime? now,
  String initialLocation = '/stream/2026-11-17/day',
}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/stream/:date/:zoom',
      builder: (context, state) => StreamScreen(
        date: tryParseStreamDate(state.pathParameters['date']),
        zoom: state.pathParameters['zoom'],
        now: now,
      ),
    ),
    for (var i = 0; i < 7; i++)
      GoRoute(path: '/tab$i', builder: (_, _) => Text('tab$i')),
    GoRoute(path: '/search', builder: (_, _) => const Text('search')),
    GoRoute(path: '/settings', builder: (_, _) => const Text('settings')),
  ],
);

Widget _routerApp(GoRouter router, {List<Override>? overrides}) =>
    ProviderScope(
      overrides: overrides ?? _overrides(),
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );

/// Stream screen without sync overrides, so the live provider drives the
/// header. Tests pass the status they want the provider to expose.
Widget _statusApp(StreamSyncStatus status) => ProviderScope(
  overrides: [
    ..._overrides(),
    streamSyncStatusProvider.overrideWithValue(status),
  ],
  child: MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: StreamScreen(
      date: DateTime(2026, 11, 17),
      now: DateTime(2026, 11, 17, 10),
    ),
  ),
);

/// Pushed routes are imperative matches, so [RouteMatchList.uri] keeps
/// reporting the base location; the last match is the visible one.
String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.last.matchedLocation;

void main() {
  testWidgets('stream day view opens inside AppShell when opted in', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'settings.onboarded': true,
      'stream.school.completed': true,
      'settings.streamEnabled': true,
    });
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in const ['ephemeron/system', 'ephemeron/alarms']) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (call) async => null,
      );
    }
    addTearDown(() {
      for (final name in const ['ephemeron/system', 'ephemeron/alarms']) {
        messenger.setMockMethodCallHandler(MethodChannel(name), null);
      }
    });
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    GoRouter? router;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          // The root redirect paints Today first; its real cache build is
          // unrelated to Stream and would add drift work to this test.
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

    // Root is Today now; Stream is opt-in at its canonical branch URL.
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(TodayScreen), findsOneWidget);

    final streamDate = DateTime(2026, 11, 17);
    router!.go(AppDestination.streamLocation(streamDate));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(StreamScreen), findsOneWidget);
    expect(find.byType(TodayScreen), findsNothing);
    expect(_location(router!), '/stream/${formatStreamDate(streamDate)}/day');

    // Unmount while pumps still run so Riverpod cancels its drift stream
    // subscriptions, then close the in-memory database.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  });

  test('invalid date and zoom fall back', () {
    final p = parseStreamRouteParams(date: 'nope', zoom: 'hour');
    expect(p.zoom, 'day');
    expect(p.date, isNotNull);
  });

  test('valid zoom levels map to levels', () {
    expect(parseStreamRouteParams(zoom: 'week').zoom, 'week');
    expect(parseStreamRouteParams(zoom: 'month').zoom, 'month');
    expect(parseStreamRouteParams(zoom: 'year').zoom, 'year');
    expect(streamLevelForZoom('day'), StreamLevel.day);
    expect(streamLevelForZoom('week'), StreamLevel.week);
    expect(streamLevelForZoom('month'), StreamLevel.month);
    expect(streamLevelForZoom('year'), StreamLevel.year);
    expect(streamLevelForZoom('hour'), StreamLevel.day);
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
      _app(
        overrides: _overrides(),
        date: DateTime(2026, 11, 17),
        now: DateTime(2026, 11, 17, 10),
      ),
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

  testWidgets('week zoom renders WeekView and the Week breadcrumb', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final date = DateTime(2026, 11, 17);
    final overrides = <Override>[
      ..._overrides(),
      ..._levelOverrides(StreamLevel.week, date),
    ];
    await tester.pumpWidget(
      _app(overrides: overrides, date: date, zoom: 'week'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(WeekView), findsOneWidget);
    expect(find.byType(StreamDayBody), findsNothing);
    final l = AppLocalizations.of(tester.element(find.byType(StreamScreen)));
    final header = tester.widget<StreamHeader>(find.byType(StreamHeader));
    expect(header.levelLabel, l.streamWeek);
    expect(find.text(l.streamWeek), findsOneWidget);
  });

  testWidgets('month zoom renders MonthView and the Month breadcrumb', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final date = DateTime(2026, 11, 17);
    final overrides = <Override>[
      ..._overrides(),
      ..._levelOverrides(StreamLevel.month, date),
    ];
    await tester.pumpWidget(
      _app(overrides: overrides, date: date, zoom: 'month'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MonthView), findsOneWidget);
    expect(find.byType(StreamDayBody), findsNothing);
    final l = AppLocalizations.of(tester.element(find.byType(StreamScreen)));
    final header = tester.widget<StreamHeader>(find.byType(StreamHeader));
    expect(header.levelLabel, l.streamMonth);
    expect(find.text(l.streamMonth), findsOneWidget);
  });

  testWidgets('unknown zoom falls back to the day level', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        overrides: _overrides(),
        date: DateTime(2026, 11, 17),
        now: DateTime(2026, 11, 17, 10),
        zoom: 'hour',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(DayCanvas), findsOneWidget);
    expect(find.byType(WeekView), findsNothing);
    expect(find.byType(MonthView), findsNothing);
    expect(find.byType(YearView), findsNothing);
    final l = AppLocalizations.of(tester.element(find.byType(StreamScreen)));
    final header = tester.widget<StreamHeader>(find.byType(StreamHeader));
    expect(header.levelLabel, l.streamDay);
  });

  testWidgets('year zoom renders YearView and the Year breadcrumb', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final date = DateTime(2026, 11, 17);
    final overrides = <Override>[
      ..._overrides(),
      ..._levelOverrides(StreamLevel.year, date),
    ];
    await tester.pumpWidget(
      _app(overrides: overrides, date: date, zoom: 'year'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(YearView), findsOneWidget);
    expect(find.byType(StreamDayBody), findsNothing);
    final l = AppLocalizations.of(tester.element(find.byType(StreamScreen)));
    final header = tester.widget<StreamHeader>(find.byType(StreamHeader));
    expect(header.levelLabel, l.streamYear);
    expect(find.text(l.streamYear), findsOneWidget);
  });

  testWidgets('month and year zoom show habit ribbons from level streaks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final date = DateTime(2026, 11, 17);
    final monthStreaks = [
      MonthHabitStreak(habitId: 'm1', doneDays: {3, 4}, colorArgb: 0xFF224466),
    ];
    final yearStreaks = [
      YearHabitStreak(
        habitId: 'y1',
        doneDayKeys: const {'2026-01-02', '2026-01-04'},
        colorArgb: 0xFF335577,
      ),
    ];
    final overrides = <Override>[
      ..._overrides(),
      ..._levelOverrides(
        StreamLevel.month,
        date,
        streaks: StreamLevelHabitStreaks(monthStreaks: monthStreaks),
      ),
      ..._levelOverrides(
        StreamLevel.year,
        date,
        streaks: StreamLevelHabitStreaks(yearStreaks: yearStreaks),
      ),
    ];

    await tester.pumpWidget(
      _app(overrides: overrides, date: date, zoom: 'month'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final monthView = tester.widget<MonthView>(find.byType(MonthView));
    expect(monthView.habitStreaks!.single.habitId, 'm1');
    expect(monthView.habitStreaks!.single.doneDays, {3, 4});
    expect(monthView.onHabitTap, isNotNull);

    await tester.pumpWidget(
      _app(overrides: overrides, date: date, zoom: 'year'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final yearView = tester.widget<YearView>(find.byType(YearView));
    expect(yearView.habitStreaks.single.habitId, 'y1');
    expect(yearView.habitStreaks.single.doneDayKeys, {
      '2026-01-02',
      '2026-01-04',
    });
    expect(yearView.onHabitTap, isNotNull);
    final l = AppLocalizations.of(tester.element(find.byType(StreamScreen)));
    expect(
      yearView.habitStreakSemanticsLabel(
        yearView.habitStreaks.single,
        DateTime(2026, 1, 2),
        DateTime(2026, 1, 4),
      ),
      l.streamMonthStreakSemantics(3, 2, 4),
    );
  });

  testWidgets('week, month and year at 320 dp and 2.0 scale do not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final date = DateTime(2026, 11, 17);
    final overrides = <Override>[
      ..._overrides(tray: _trayItems),
      ..._levelOverrides(StreamLevel.week, date),
      ..._levelOverrides(StreamLevel.month, date),
      ..._levelOverrides(StreamLevel.year, date),
    ];
    for (final zoom in ['week', 'month', 'year']) {
      await tester.pumpWidget(
        _app(
          overrides: overrides,
          date: date,
          homeOverride: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: StreamScreen(date: date, zoom: zoom),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(CaptureBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('palette zoom candidates navigate to matching URLs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final date = DateTime(2026, 11, 17);
    const targets = <String, String>{
      'Day': 'day',
      'Week': 'week',
      'Month': 'month',
      'Year': 'year',
    };
    for (final entry in targets.entries) {
      final router = _launcherRouter();
      final overrides = <Override>[
        ..._overrides(),
        ..._levelOverrides(StreamLevel.week, date),
        ..._levelOverrides(StreamLevel.month, date),
        ..._levelOverrides(StreamLevel.year, date),
      ];
      await tester.pumpWidget(_routerApp(router, overrides: overrides));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Breadcrumb));
      await tester.pump();
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byType(CommandPalette),
          matching: find.text(entry.key),
        ),
      );
      await tester.pumpAndSettle();

      expect(_location(router), '/stream/2026-11-17/${entry.value}');
    }
  });

  testWidgets('palette Agenda candidate toggles the agenda lens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = _launcherRouter();
    final overrides = <Override>[
      ..._overrides(),
      ..._levelOverrides(StreamLevel.day, DateTime(2026, 11, 17)),
    ];
    await tester.pumpWidget(_routerApp(router, overrides: overrides));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Breadcrumb));
    await tester.pump();
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('streamCommandField')),
      'agenda',
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byType(StreamAgendaHost), findsOneWidget);
    expect(find.byType(DayCanvas), findsNothing);
    final toggle = tester.widget<Switch>(
      find.byKey(const Key('streamAgendaToggle')),
    );
    expect(toggle.value, isTrue);

    await tester.tap(find.byKey(const Key('streamAgendaToggle')));
    await tester.pump();
    expect(find.byType(StreamAgendaHost), findsNothing);
    expect(find.byType(DayCanvas), findsOneWidget);
  });

  testWidgets('offline banner shows the message and retry starts sync', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var retries = 0;
    final overrides = <Override>[
      ..._overrides(),
      streamSyncStatusProvider.overrideWithValue(StreamSyncStatus.offline),
      syncAllProvider.overrideWithValue(() async {
        retries++;
      }),
    ];
    await tester.pumpWidget(
      _app(
        overrides: overrides,
        date: DateTime(2026, 11, 17),
        now: DateTime(2026, 11, 17, 10),
        syncStatus: StreamSyncStatus.offline,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(StreamOfflineBannerHost), findsOneWidget);
    final l = AppLocalizations.of(tester.element(find.byType(StreamScreen)));
    expect(find.text(l.streamOfflineMessage), findsOneWidget);

    await tester.tap(find.text(l.streamOfflineRetry));
    await tester.pump();
    expect(retries, 1);
  });

  testWidgets('tapping a mark opens the peek sheet', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mark = _fakeMarks.last;
    final target = StreamPeekTarget(
      data: PeekData(
        id: 'peek-task',
        title: 'Peek task title',
        startMs: mark.startMs,
        endMs: mark.endMs,
      ),
      editable: true,
      sourceTaskId: 'peek-task',
      sourcePriority: 0,
    );
    final overrides = <Override>[
      ..._overrides(),
      streamPeekTargetProvider(mark)
          .overrideWithValue(AsyncValue<StreamPeekTarget?>.data(target)),
      taskListsProvider.overrideWith((ref) => Stream.value(const <TaskList>[])),
    ];
    await tester.pumpWidget(
      _app(
        overrides: overrides,
        date: DateTime(2026, 11, 17),
        now: DateTime(2026, 11, 17, 9),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final viewport = tester.widget<DayCanvas>(find.byType(DayCanvas)).viewport;
    final rect = tester.getRect(find.byType(DayCanvas));
    final y = viewport.timeToPx(
      DateTime(2026, 11, 17, 10, 30).millisecondsSinceEpoch,
    );
    await tester.tapAt(Offset(rect.center.dx, rect.top + y));
    await tester.pumpAndSettle();

    expect(find.byType(StreamPeekSheet), findsOneWidget);
    expect(find.byType(PeekPanel), findsOneWidget);
    expect(find.text('Peek task title'), findsOneWidget);
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
        _app(
          overrides: overrides,
          date: DateTime(2026, 11, 17),
          now: DateTime(2026, 11, 17, 10),
        ),
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
        now: DateTime(2026, 11, 17, 10),
        onOpenCommand: () => openCommand++,
        onOpenSettings: () => openSettings++,
        onReturnToNow: () => returnToNow++,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(NowPill), findsNothing);

    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await tester.pumpAndSettle();
    expect(openSettings, 1);
    expect(find.byType(StreamSettingsSheet), findsOneWidget);
    await tester.tap(find.byKey(const Key('streamSettingsSheetClose')));
    await tester.pumpAndSettle();
    expect(find.byType(StreamSettingsSheet), findsNothing);

    await tester.tap(find.byType(Breadcrumb));
    await tester.pump();
    await tester.pump();
    expect(openCommand, 1);
    expect(find.byKey(const Key('streamCommandField')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byKey(const Key('streamCommandField')), findsNothing);

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
        overrides: _overrides(tray: _trayItems),
        date: DateTime(2026, 11, 17),
        now: DateTime(2026, 11, 17, 10),
        homeOverride: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: StreamScreen(
            date: DateTime(2026, 11, 17),
            now: DateTime(2026, 11, 17, 10),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(CaptureBar), findsOneWidget);
    expect(find.byType(TrayStrip), findsOneWidget);

    await tester.tap(find.byType(Breadcrumb));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('streamCommandField')), findsOneWidget);
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
          now: DateTime(2026, 11, 17, 10),
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
        now: DateTime(2026, 11, 17, 10),
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

  testWidgets('header avatar opens the stream settings sheet', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_routerApp(_launcherRouter()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await tester.pumpAndSettle();

    final l = AppLocalizations.of(
      tester.element(find.byType(StreamSettingsSheet)),
    );
    expect(find.byType(StreamSettingsSheet), findsOneWidget);
    expect(find.text(l.streamSettingsSheetTitle), findsOneWidget);
    expect(find.text(l.streamSettingsThemeSection), findsOneWidget);
    expect(find.byKey(const Key('streamSettingsTheme-dark')), findsOneWidget);
    expect(find.byKey(const Key('streamSettingsMore')), findsOneWidget);
  });

  testWidgets('selecting a theme mode calls setMode and keeps the sheet open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final theme = _RecordingThemeNotifier(StreamThemeMode.system);
    await tester.pumpWidget(
      _routerApp(_launcherRouter(), overrides: _overrides(theme: () => theme)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('streamSettingsTheme-trueBlack')));
    await tester.pumpAndSettle();

    expect(theme.setModeCalls, 1);
    expect(theme.lastMode, StreamThemeMode.trueBlack);
    expect(find.byType(StreamSettingsSheet), findsOneWidget);
  });

  testWidgets('More settings pushes /settings and closes the sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = _launcherRouter();
    await tester.pumpWidget(_routerApp(router));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('streamSettingsMore')));
    await tester.pumpAndSettle();

    expect(_location(router), '/settings');
    expect(find.byType(StreamSettingsSheet), findsNothing);
    expect(find.text('settings'), findsOneWidget);
  });

  testWidgets('Replay Gesture School resets completion and shows the school', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final school = _RecordingSchoolNotifier(completed: true);
    await tester.pumpWidget(
      _routerApp(
        _launcherRouter(),
        overrides: _overrides(school: () => school),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('streamSettingsReplaySchool')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(school.resetCalls, 1);
    expect(find.byType(StreamSettingsSheet), findsNothing);
    expect(find.byType(GestureSchoolOverlay), findsOneWidget);
  });

  testWidgets('settings sheet at 320 dp and 2.0 text scale does not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(_routerApp(_launcherRouter()));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(StreamSettingsSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
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

  testWidgets('dock replaces the capture tray placeholder', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        overrides: _overrides(tray: _trayItems),
        date: DateTime(2026, 11, 17),
        now: DateTime(2026, 11, 17, 10),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('captureTrayPlaceholder')), findsNothing);
    expect(find.byType(CaptureBar), findsOneWidget);
    expect(find.byType(TrayStrip), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('capture submit runs the action and clears the bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final actions = _FakeCaptureActions();
    await tester.pumpWidget(
      _app(
        overrides: _overrides(actions: actions),
        date: DateTime(2026, 11, 17),
        now: DateTime(2026, 11, 17, 10),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byType(TextField), 'buy milk');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(actions.drafts, hasLength(1));
    expect(actions.drafts.single.title, 'buy milk');
    expect(actions.submittedAt.single, isNotNull);
    expect(find.text('buy milk'), findsNothing);
    final l = AppLocalizations.of(tester.element(find.byType(StreamScreen)));
    expect(find.text(l.streamCaptureCaptured), findsOneWidget);
  });

  testWidgets('day body is wrapped in the occurrence cache scope', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cache = _FakeCacheGateway();
    final overrides = <Override>[
      ..._overrides(cache: cache),
      calendarBuiltRangeProvider.overrideWith(() => _NullBuiltRange()),
    ];
    await tester.pumpWidget(
      _app(
        overrides: overrides,
        date: DateTime(2026, 11, 17),
        now: DateTime(2026, 11, 17, 10),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(StreamDayCacheScope), findsOneWidget);
    expect(cache.calls, isNotEmpty);
    expect(cache.calls.single.fromUtc, DateTime.utc(2026, 11, 16));
  });

  testWidgets('tray handle opens the tray panel', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        overrides: _overrides(tray: _trayItems),
        date: DateTime(2026, 11, 17),
        now: DateTime(2026, 11, 17, 10),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final l = AppLocalizations.of(tester.element(find.byType(StreamScreen)));
    await tester.tap(find.bySemanticsLabel(l.streamTrayHandle));
    await tester.pumpAndSettle();

    expect(find.byType(TrayPanel), findsOneWidget);
    expect(find.text('Unscheduled one'), findsWidgets);
  });

  testWidgets('tray tap without a loaded task opens the tasks tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = _launcherRouter();
    final overrides = <Override>[
      ..._overrides(tray: <TrayItem>[_trayItems.first]),
      openTasksProvider(null)
          .overrideWithValue(AsyncValue<List<Task>>.data(const <Task>[])),
    ];
    await tester.pumpWidget(_routerApp(router, overrides: overrides));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TrayChip));
    await tester.pumpAndSettle();

    expect(_location(router), '/tab1');
  });

  testWidgets('capture bar stays above the keyboard inset', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    // Physical pixels at DPR 1, so the real MediaQuery reports 300 logical px
    // of bottom viewInsets; no synthetic MediaQuery wrapper is used.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      _app(
        overrides: _overrides(tray: _trayItems),
        date: DateTime(2026, 11, 17),
        now: DateTime(2026, 11, 17, 10),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final capture = find.byType(CaptureBar);
    expect(capture, findsOneWidget);
    final rect = tester.getRect(capture);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.height, greaterThan(0));
    // Scaffold shrinks the body by the inset, so the dock stays above it.
    expect(rect.bottom, lessThanOrEqualTo(800 - 300 + 0.5));
    expect(
      tester.getRect(find.byType(TrayStrip)).bottom,
      lessThanOrEqualTo(800 - 300 + 0.5),
    );
  });

  testWidgets('tray tap opens the task editor for a loaded task', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    const task = Task(
      id: 't1',
      title: 'Tray task title',
      priority: 0,
      pinned: false,
      wontDo: false,
      sortOrder: 0,
      createdAt: 0,
      updatedAt: 0,
      dirty: false,
    );
    const item = TrayItem(
      id: 't1',
      title: 'Tray task title',
      listId: 'l1',
      listName: 'Work',
      colorArgb: 0xFF336699,
    );
    final overrides = <Override>[
      ..._overrides(tray: const <TrayItem>[item]),
      appDatabaseProvider.overrideWithValue(db),
      settingsRepositoryProvider.overrideWith(
        (ref) async => SettingsRepository(prefs),
      ),
      openTasksProvider(null)
          .overrideWithValue(AsyncValue<List<Task>>.data(<Task>[task])),
    ];
    await tester.pumpWidget(
      _app(
        overrides: overrides,
        date: DateTime(2026, 11, 17),
        now: DateTime(2026, 11, 17, 10),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byType(TrayChip));
    await tester.pumpAndSettle();

    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields.any((field) => field.controller?.text == task.title), isTrue);
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  });

  testWidgets('long-press tray chip drag onto the canvas schedules the task', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gateway = _FakeTrayGateway();
    const task = Task(
      id: 't1',
      title: 'Unscheduled one',
      priority: 0,
      pinned: false,
      wontDo: false,
      sortOrder: 0,
      createdAt: 0,
      updatedAt: 0,
      dirty: false,
    );
    final overrides = <Override>[
      ..._overrides(tray: <TrayItem>[_trayItems.first]),
      streamTrayGatewayProvider.overrideWithValue(gateway),
      openTasksProvider(null)
          .overrideWithValue(const AsyncValue<List<Task>>.data(<Task>[task])),
    ];
    await tester.pumpWidget(
      _app(
        overrides: overrides,
        date: DateTime(2026, 11, 17),
        now: DateTime(2026, 11, 17, 10),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final viewport = tester.widget<DayCanvas>(find.byType(DayCanvas)).viewport;
    final rect = tester.getRect(find.byType(DayCanvas));
    final dropTime = DateTime(2026, 11, 17, 9, 45);
    final drop = Offset(
      rect.center.dx,
      rect.top + viewport.timeToPx(dropTime.millisecondsSinceEpoch),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TrayChip)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(drop);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(gateway.updates, hasLength(1));
    expect(gateway.updates.single.taskId, 't1');
    expect(gateway.updates.single.plannedStart, '2026-11-17T09:45');
    expect(gateway.updates.single.plannedEnd, '2026-11-17T10:15');
    expect(gateway.updates.single.dueTime, 9 * 60 + 45);
    expect(gateway.rebuiltDays, [DateTime(2026, 11, 17)]);
  });

  testWidgets('tray tap with no task and no router reports the failure', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final overrides = <Override>[
      ..._overrides(tray: <TrayItem>[_trayItems.first]),
      openTasksProvider(null)
          .overrideWithValue(AsyncValue<List<Task>>.data(const <Task>[])),
    ];
    await tester.pumpWidget(
      _app(
        overrides: overrides,
        date: DateTime(2026, 11, 17),
        now: DateTime(2026, 11, 17, 10),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byType(TrayChip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final l = AppLocalizations.of(tester.element(find.byType(StreamScreen)));
    expect(find.text(l.streamTrayTaskUnavailable), findsOneWidget);
  });

  test('stream sync status maps every sync status', () {
    const expected = <SyncStatus, StreamSyncStatus>{
      SyncStatus.synced: StreamSyncStatus.synced,
      SyncStatus.syncing: StreamSyncStatus.syncing,
      SyncStatus.offline: StreamSyncStatus.offline,
      SyncStatus.error: StreamSyncStatus.attention,
    };
    for (final entry in expected.entries) {
      expect(streamSyncStatusFromSync(entry.key), entry.value);
    }
  });

  test('streamSyncStatusProvider reads the combined status', () {
    for (final status in SyncStatus.values) {
      final container = ProviderContainer(
        overrides: [combinedSyncStatusProvider.overrideWithValue(status)],
      );
      addTearDown(container.dispose);
      expect(
        container.read(streamSyncStatusProvider),
        streamSyncStatusFromSync(status),
      );
    }
  });

  testWidgets('breadcrumb opens the palette and Esc closes it', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_routerApp(_launcherRouter()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Breadcrumb));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('streamCommandField')), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byKey(const Key('streamCommandField')), findsNothing);
  });

  testWidgets('Ctrl+K opens the palette', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_routerApp(_launcherRouter()));
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('streamCommandField')), findsOneWidget);
  });

  testWidgets('selecting Today navigates to the expected date', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = _launcherRouter(
      now: DateTime(2026, 11, 17, 10),
      initialLocation: '/stream/2026-11-15/day',
    );
    await tester.pumpWidget(_routerApp(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Breadcrumb));
    await tester.pump();
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('streamCommandField')),
      'today',
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(_location(router), '/stream/2026-11-17/day');
    expect(find.byKey(const Key('streamCommandField')), findsNothing);
  });

  testWidgets('sync now and theme run the fake executor once', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final executor = _FakeCommandExecutor();
    final overrides = <Override>[
      ..._overrides(),
      streamCommandExecutorProvider.overrideWithValue(executor),
    ];
    await tester.pumpWidget(
      _routerApp(_launcherRouter(), overrides: overrides),
    );
    await tester.pumpAndSettle();

    for (final query in ['sync', 'dark']) {
      await tester.tap(find.byType(Breadcrumb));
      await tester.pump();
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('streamCommandField')),
        query,
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.byKey(const Key('streamCommandField')), findsNothing);
    }

    expect(executor.intents, hasLength(2));
    expect(executor.intents[0], isA<StreamCommandSyncNow>());
    expect(
      executor.intents[1],
      isA<StreamCommandTheme>().having(
        (intent) => intent.mode,
        'mode',
        StreamThemeMode.dark,
      ),
    );
  });

  testWidgets('sync status provider drives the header label', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final status in StreamSyncStatus.values) {
      await tester.pumpWidget(_statusApp(status));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final header = tester.widget<StreamHeader>(find.byType(StreamHeader));
      final l = AppLocalizations.of(tester.element(find.byType(StreamScreen)));
      final expected = switch (status) {
        StreamSyncStatus.synced => l.streamSyncSynced,
        StreamSyncStatus.syncing => l.streamSyncSyncing,
        StreamSyncStatus.offline => l.streamSyncOffline,
        StreamSyncStatus.attention => l.streamSyncAttention,
      };
      expect(header.syncStatus, status);
      expect(header.syncLabel, expected);
      expect(find.bySemanticsLabel(expected), findsWidgets);
    }
  });

  testWidgets('first-run school overlay covers the stream', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        overrides: _overrides(schoolCompleted: false),
        date: DateTime(2026, 11, 17),
        now: DateTime(2026, 11, 17, 10),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(GestureSchoolOverlay), findsOneWidget);
  });
}
