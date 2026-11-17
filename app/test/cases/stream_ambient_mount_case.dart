import 'dart:async';

import 'package:ephemeron/features/stream/application/stream_ambient.dart';
import 'package:ephemeron/features/stream/application/stream_day_mark.dart';
import 'package:ephemeron/features/stream/engine/stream_time_viewport.dart';
import 'package:ephemeron/features/stream/presentation/countdowns/countdown_edge_chips.dart';
import 'package:ephemeron/features/stream/presentation/countdowns/countdown_landmark.dart';
import 'package:ephemeron/features/stream/presentation/countdowns/countdown_landmark_item.dart';
import 'package:ephemeron/features/stream/presentation/day/day_canvas.dart';
import 'package:ephemeron/features/stream/presentation/day/day_canvas_painter.dart';
import 'package:ephemeron/features/stream/presentation/habits/habit_glyph.dart';
import 'package:ephemeron/features/stream/presentation/habits/habit_gutter_item.dart';
import 'package:ephemeron/features/stream/presentation/stream_day_body_view.dart';
import 'package:ephemeron/features/stream/presentation/stream_day_controller.dart';
import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

final DateTime _day = DateTime(2026, 11, 17);
final DateTime _now = DateTime(2026, 11, 17, 10);
const String _dayKey = '2026-11-17';

/// Real viewport/controller pair; no repositories or databases.
class _Fixture {
  _Fixture() {
    viewport = StreamTimeViewport(
      baseEpochMs: _day.millisecondsSinceEpoch,
      initialPreset: StreamZoomPreset.day,
    );
    controller = StreamDayBodyController()
      ..attach(viewport: viewport, date: _day);
  }

  late final StreamTimeViewport viewport;
  late final StreamDayBodyController controller;
  final ValueNotifier<String> timeLabel = ValueNotifier<String>('10:00');
  final ValueNotifier<bool> away = ValueNotifier<bool>(false);

  void dispose() {
    controller.dispose();
    viewport.dispose();
    timeLabel.dispose();
    away.dispose();
  }
}

HabitGutterItem _habit(String id, int? minutes) => HabitGutterItem(
  id: id,
  name: id,
  colorArgb: 0xFF4CAF50,
  timeMinutes: minutes,
  doneByDay: const {_dayKey: false},
  streakCurrent: 3,
  streakBest: 5,
);

CountdownLandmarkItem _countdown(String id, String title, String dayKey) =>
    CountdownLandmarkItem(id: id, title: title, targetDayKey: dayKey);

Widget _host({
  required _Fixture fixture,
  List<HabitGutterItem> habits = const <HabitGutterItem>[],
  List<CountdownLandmarkItem> countdowns = const <CountdownLandmarkItem>[],
  void Function(String habitId)? onHabitToggle,
  ValueChanged<String>? onCountdownTap,
  Size size = const Size(360, 640),
  double textScale = 1,
}) {
  return ProviderScope(
    overrides: [
      streamHabitGutterItemsProvider.overrideWith(
        (ref, range) => Stream<List<HabitGutterItem>>.value(habits),
      ),
      streamCountdownLandmarkItemsProvider.overrideWith(
        (ref) => Stream<List<CountdownLandmarkItem>>.value(countdowns),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: SizedBox(
            width: size.width,
            height: size.height,
            child: StreamDayBodyView(
              viewport: fixture.viewport,
              controller: fixture.controller,
              marks: const <StreamDayMark>[],
              isToday: false,
              now: _now,
              timeLabel: fixture.timeLabel,
              away: fixture.away,
              onDateChanged: null,
              onReturnToNow: () {},
              l: AppLocalizations.of(context),
              date: _day,
              currentDayKey: _dayKey,
              onHabitToggle: onHabitToggle ?? (_) {},
              onCountdownTap: onCountdownTap ?? (_) {},
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

Finder _glyph(String label) =>
    find.byWidgetPredicate((w) => w is HabitGlyph && w.semanticsLabel == label);

void main() {
  testWidgets('habit gutter renders fake items and toggles once', (
    tester,
  ) async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    final toggles = <String>[];
    await _pump(
      tester,
      _host(
        fixture: fixture,
        habits: [_habit('all-day', null), _habit('standup', 540)],
        onHabitToggle: toggles.add,
      ),
    );

    expect(_glyph('all-day'), findsOneWidget);
    expect(_glyph('standup'), findsOneWidget);

    await tester.tap(_glyph('standup'));
    await tester.pump();

    expect(toggles, ['standup']);
  });

  testWidgets('countdown landmark renders and reports its id on tap', (
    tester,
  ) async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    final taps = <String>[];
    await _pump(
      tester,
      _host(
        fixture: fixture,
        countdowns: [_countdown('c1', 'Launch', _dayKey)],
        onCountdownTap: taps.add,
      ),
    );

    expect(find.byType(CountdownLandmark), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);

    await tester.tap(find.byType(CountdownLandmark));
    await tester.pump();

    expect(taps, ['c1']);
  });

  testWidgets('pan and zoom still work and the day canvas paints', (
    tester,
  ) async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await _pump(
      tester,
      _host(
        fixture: fixture,
        habits: [_habit('standup', 540)],
        countdowns: [_countdown('c1', 'Launch', _dayKey)],
      ),
    );

    expect(find.byType(DayCanvas), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is DayCanvasPainter,
      ),
      findsOneWidget,
    );

    final beforeOffset = fixture.viewport.offsetPx;
    await tester.drag(find.byType(DayCanvas), const Offset(0, -120));
    await tester.pump();
    expect(fixture.viewport.offsetPx, greaterThan(beforeOffset));

    final beforeMpp = fixture.viewport.minutesPerPixel;
    final center = tester.getCenter(find.byType(DayCanvas));
    final first = await tester.startGesture(center + const Offset(-40, 0));
    final second = await tester.startGesture(center + const Offset(40, 0));
    await tester.pump();
    await first.moveBy(const Offset(0, -30));
    await second.moveBy(const Offset(0, 30));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();

    expect(fixture.viewport.minutesPerPixel, isNot(beforeMpp));
    expect(tester.takeException(), isNull);
  });

  testWidgets('320 dp at 2.0 text scale does not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await _pump(
      tester,
      _host(
        fixture: fixture,
        size: const Size(320, 640),
        textScale: 2,
        habits: [
          _habit('all-day-habit-with-a-long-name', null),
          _habit('timed-habit-with-a-long-name', 540),
        ],
        countdowns: [
          _countdown(
            'today',
            'A long countdown title that should fit',
            _dayKey,
          ),
          _countdown('a', 'Another long countdown title', '2026-11-18'),
          _countdown('b', 'One more long countdown title', '2026-11-19'),
          _countdown('c', 'Yet another long countdown title', '2026-11-20'),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(_glyph('timed-habit-with-a-long-name'), findsOneWidget);
    expect(find.byType(CountdownLandmark), findsOneWidget);
    expect(find.byType(CountdownEdgeChips), findsOneWidget);
  });
}
