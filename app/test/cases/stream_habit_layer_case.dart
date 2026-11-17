import 'dart:async';

import 'package:ephemeron/features/stream/application/stream_ambient.dart';
import 'package:ephemeron/features/stream/engine/stream_time_viewport.dart';
import 'package:ephemeron/features/stream/presentation/habits/habit_glyph.dart';
import 'package:ephemeron/features/stream/presentation/habits/habit_gutter.dart';
import 'package:ephemeron/features/stream/presentation/habits/habit_gutter_item.dart';
import 'package:ephemeron/features/stream/presentation/stream_day_controller.dart';
import 'package:ephemeron/features/stream/presentation/surface/stream_habit_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const String _dayKeyValue = '2026-11-17';
final DateTime _day = DateTime(2026, 11, 17);

HabitGutterItem _item(String id, int? minutes) => HabitGutterItem(
  id: id,
  name: id,
  colorArgb: 0xFF4CAF50,
  timeMinutes: minutes,
  doneByDay: const {_dayKeyValue: false},
  streakCurrent: 3,
  streakBest: 5,
);

/// Real viewport/controller pair; no repositories or databases.
class _Fixture {
  _Fixture({bool attach = true}) {
    viewport = StreamTimeViewport(
      baseEpochMs: _day.millisecondsSinceEpoch,
      initialPreset: StreamZoomPreset.day,
    );
    controller = StreamDayBodyController();
    if (attach) controller.attach(viewport: viewport, date: _day);
  }

  late final StreamTimeViewport viewport;
  late final StreamDayBodyController controller;

  void dispose() {
    controller.dispose();
    viewport.dispose();
  }
}

Widget _host({
  required StreamDayBodyController controller,
  required List<HabitGutterItem> items,
  void Function(String habitId)? onToggle,
  Size size = const Size(360, 640),
  double textScale = 1,
}) {
  return ProviderScope(
    overrides: [
      streamHabitGutterItemsProvider.overrideWith(
        (ref, range) => Stream.value(items),
      ),
    ],
    child: MaterialApp(
      home: Builder(
        builder: (context) {
          final media = MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale));
          return MediaQuery(
            data: media,
            child: Scaffold(
              body: SizedBox(
                width: size.width,
                height: size.height,
                child: Stack(
                  children: [
                    StreamHabitLayer(
                      controller: controller,
                      day: _day,
                      currentDayKey: _dayKeyValue,
                      onToggle: onToggle ?? (_) {},
                      streakLabel: (id, current, best) => '$id $current/$best',
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await tester.pump();
}

Finder _glyph(String label) =>
    find.byWidgetPredicate((w) => w is HabitGlyph && w.semanticsLabel == label);

void main() {
  testWidgets('09:00 habit sits on the canvas y and all-day in the top slot', (
    tester,
  ) async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await _pump(
      tester,
      _host(
        controller: fixture.controller,
        items: [_item('all-day', null), _item('standup', 540)],
      ),
    );

    final expectedY = 540 / fixture.viewport.minutesPerPixel;
    expect(expectedY, closeTo(504, 1e-9));
    expect(tester.getTopLeft(_glyph('all-day')).dy, 0);
    expect(tester.getTopLeft(_glyph('standup')).dy, closeTo(expectedY, 0.01));
  });

  testWidgets('tapping a glyph calls onToggle once with the id', (
    tester,
  ) async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    final toggles = <String>[];
    await _pump(
      tester,
      _host(
        controller: fixture.controller,
        items: [_item('h1', 540)],
        onToggle: toggles.add,
      ),
    );

    await tester.tap(_glyph('h1'));
    await tester.pump();

    expect(toggles, ['h1']);
  });

  testWidgets('500 habits build a bounded number of glyphs', (tester) async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    final items = [for (var i = 0; i < 500; i++) _item('h$i', i % 1440)];
    await _pump(tester, _host(controller: fixture.controller, items: items));

    expect(find.byType(HabitGlyph).evaluate().length, lessThan(50));
  });

  testWidgets('320 dp at 2.0 text scale does not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await _pump(
      tester,
      _host(
        controller: fixture.controller,
        items: [_item('all-day', null), _item('verylonghabitname', 540)],
        size: const Size(320, 640),
        textScale: 2,
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('no attached viewport renders nothing', (tester) async {
    final fixture = _Fixture(attach: false);
    addTearDown(fixture.dispose);
    await _pump(
      tester,
      _host(controller: fixture.controller, items: [_item('h1', 540)]),
    );

    expect(find.byType(StreamHabitLayer), findsOneWidget);
    expect(find.byType(HabitGutter), findsNothing);
    expect(find.byType(HabitGlyph), findsNothing);
  });

  testWidgets('scroll offset moves glyphs by the expected delta', (
    tester,
  ) async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await _pump(
      tester,
      _host(controller: fixture.controller, items: [_item('h1', 540)]),
    );
    final before = tester.getTopLeft(_glyph('h1')).dy;

    fixture.viewport.setOffset(120);
    await tester.pump();

    final after = tester.getTopLeft(_glyph('h1')).dy;
    expect(before - after, closeTo(120, 0.01));
  });
}
