import 'package:ephemeron/features/calendar/application/calendar_state.dart';
import 'package:ephemeron/features/stream/application/stream_day_cache.dart';
import 'package:ephemeron/features/stream/application/stream_day_mark.dart';
import 'package:ephemeron/features/stream/application/stream_day_providers.dart';
import 'package:ephemeron/features/stream/application/stream_school_preferences.dart';
import 'package:ephemeron/features/stream/application/stream_slipped_data.dart';
import 'package:ephemeron/features/stream/application/stream_theme_provider.dart';
import 'package:ephemeron/features/stream/application/stream_tray.dart';
import 'package:ephemeron/features/stream/design/stream_theme_mode.dart';
import 'package:ephemeron/features/stream/presentation/chrome/now_line.dart';
import 'package:ephemeron/features/stream/presentation/school/gesture_school_overlay.dart';
import 'package:ephemeron/features/stream/presentation/slipped/slipped_item.dart';
import 'package:ephemeron/features/stream/presentation/slipped/slipped_trail.dart';
import 'package:ephemeron/features/stream/presentation/stream_header.dart';
import 'package:ephemeron/features/stream/presentation/stream_screen.dart';
import 'package:ephemeron/features/stream/presentation/tray/tray_item.dart';
import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _FixedThemeNotifier extends StreamThemeNotifier {
  @override
  StreamThemeMode build() => StreamThemeMode.dark;
}

class _FixedSchoolNotifier extends StreamSchoolCompletedNotifier {
  _FixedSchoolNotifier(this.completed);

  final bool completed;

  @override
  Future<bool> build() async => completed;

  @override
  Future<void> markCompleted() async => state = const AsyncData(true);
}

class _NoopCacheGateway implements StreamDayCacheGateway {
  @override
  Future<void> rebuild(CalendarRange range) async {}
}

const _twoSlipped = <SlippedItem>[
  SlippedItem(
    id: 'a',
    title: 'First slipped',
    daysOverdue: 1,
    listColorArgb: 0xFF336699,
  ),
  SlippedItem(
    id: 'b',
    title: 'Second slipped',
    daysOverdue: 4,
    listColorArgb: 0xFF996633,
  ),
];

Widget _app({
  List<SlippedItem> slipped = _twoSlipped,
  bool schoolCompleted = true,
  double textScale = 1.0,
}) {
  return ProviderScope(
    overrides: [
      streamMarksForDayProvider.overrideWith(
        (ref, key) async =>
            const StreamDayMarks(marks: <StreamDayMark>[], skippedCount: 0),
      ),
      streamThemeProvider.overrideWith(_FixedThemeNotifier.new),
      streamTrayItemsProvider.overrideWith(
        (ref) => Stream<List<TrayItem>>.value(const <TrayItem>[]),
      ),
      streamDayCacheGatewayProvider.overrideWithValue(_NoopCacheGateway()),
      streamSlippedItemsProvider.overrideWith(
        (ref) => Stream<List<SlippedItem>>.value(slipped),
      ),
      streamSchoolCompletedProvider.overrideWith(
        () => _FixedSchoolNotifier(schoolCompleted),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: StreamScreen(
        date: DateTime(2026, 11, 17),
        now: DateTime(2026, 11, 17, 10),
        syncStatus: StreamSyncStatus.synced,
      ),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void _useSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('slipped trail mounts under the now label and opens triage', (
    tester,
  ) async {
    _useSize(tester, const Size(360, 800));
    await _pump(tester, _app());
    final l = AppLocalizations.of(tester.element(find.byType(StreamScreen)));

    expect(find.byType(SlippedTrail), findsOneWidget);
    expect(find.text(l.streamSlippedCount(2)), findsOneWidget);
    final nowRect = tester.getRect(find.byType(NowLine));
    final trailRect = tester.getRect(find.byType(SlippedTrail));
    expect(trailRect.top, greaterThan(nowRect.bottom));
    expect(trailRect.left, closeTo(nowRect.left, 0.1));

    await tester.tap(find.byType(SlippedTrail));
    await tester.pumpAndSettle();

    expect(find.text(l.streamSlippedTitle), findsOneWidget);
    expect(find.text('First slipped'), findsOneWidget);
    expect(find.text('Second slipped'), findsOneWidget);
  });

  testWidgets('no trail when nothing slipped', (tester) async {
    _useSize(tester, const Size(360, 800));
    await _pump(tester, _app(slipped: const <SlippedItem>[]));

    expect(find.byType(SlippedTrail), findsNothing);
  });

  testWidgets('first run shows the gesture school over the stream', (
    tester,
  ) async {
    _useSize(tester, const Size(360, 800));
    await _pump(tester, _app(schoolCompleted: false));

    expect(find.byType(GestureSchoolOverlay), findsOneWidget);
  });

  testWidgets('completed school leaves the stream bare', (tester) async {
    _useSize(tester, const Size(360, 800));
    await _pump(tester, _app());

    expect(find.byType(GestureSchoolOverlay), findsNothing);
  });

  testWidgets('320 dp at 2.0 text scale does not overflow', (tester) async {
    _useSize(tester, const Size(320, 640));
    await _pump(tester, _app(textScale: 2.0));

    expect(find.byType(SlippedTrail), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
