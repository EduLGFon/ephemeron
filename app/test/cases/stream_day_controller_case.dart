import 'package:ephemeron/features/stream/application/stream_day_mark.dart';
import 'package:ephemeron/features/stream/application/stream_day_providers.dart';
import 'package:ephemeron/features/stream/engine/stream_time_viewport.dart';
import 'package:ephemeron/features/stream/presentation/stream_day_body.dart';
import 'package:ephemeron/features/stream/presentation/stream_day_controller.dart';
import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

DateTime _dayStart(DateTime date) => DateTime(date.year, date.month, date.day);

StreamTimeViewport _viewport(DateTime date, StreamZoomPreset preset) {
  return StreamTimeViewport(
    baseEpochMs: _dayStart(date).millisecondsSinceEpoch,
    initialPreset: preset,
  );
}

Widget _host({required DateTime date, StreamDayBodyController? controller}) {
  return ProviderScope(
    overrides: [
      streamMarksForDayProvider.overrideWith(
        (ref, key) async =>
            const StreamDayMarks(marks: <StreamDayMark>[], skippedCount: 0),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: StreamDayBody(
          date: date,
          now: DateTime(2026, 11, 17, 10),
          controller: controller,
        ),
      ),
    ),
  );
}

void main() {
  test('attach exposes viewport, date and clock and notifies once', () {
    final date = DateTime(2026, 11, 17);
    final viewport = _viewport(date, StreamZoomPreset.day);
    final controller = StreamDayBodyController();
    addTearDown(controller.dispose);
    addTearDown(viewport.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);
    final fixed = DateTime(2026, 11, 17, 9, 30);
    DateTime clock() => fixed;

    controller.attach(viewport: viewport, date: date, clock: clock);

    expect(controller.attached, isTrue);
    expect(controller.viewport, same(viewport));
    expect(controller.date, date);
    expect(controller.clock, same(clock));
    expect(controller.now, fixed);
    expect(controller.scrollListenable, same(viewport.offsetPxListenable));
    expect(notifications, 1);
  });

  test('attach twice is idempotent', () {
    final date = DateTime(2026, 11, 17);
    final viewport = _viewport(date, StreamZoomPreset.day);
    final controller = StreamDayBodyController();
    addTearDown(controller.dispose);
    addTearDown(viewport.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.attach(viewport: viewport, date: date);
    controller.attach(viewport: viewport, date: date);

    expect(notifications, 1);
    expect(controller.date, date);
  });

  test('detach of a different viewport is ignored', () {
    final date = DateTime(2026, 11, 17);
    final viewport = _viewport(date, StreamZoomPreset.day);
    final other = _viewport(date, StreamZoomPreset.hour);
    final controller = StreamDayBodyController();
    addTearDown(controller.dispose);
    addTearDown(viewport.dispose);
    addTearDown(other.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.attach(viewport: viewport, date: date);

    controller.detach(other);

    expect(controller.attached, isTrue);
    expect(controller.viewport, same(viewport));
    expect(notifications, 1);
  });

  test('detach clears the binding and mappings', () {
    final date = DateTime(2026, 11, 17);
    final viewport = _viewport(date, StreamZoomPreset.day);
    final controller = StreamDayBodyController();
    addTearDown(controller.dispose);
    addTearDown(viewport.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.attach(viewport: viewport, date: date, clock: () => date);

    controller.detach(viewport);

    expect(controller.attached, isFalse);
    expect(controller.viewport, isNull);
    expect(controller.date, isNull);
    expect(controller.clock, isNull);
    expect(controller.now, isNull);
    expect(controller.scrollListenable, isNull);
    expect(controller.timeToY(date), isNull);
    expect(controller.pxToTime(0), isNull);
    expect(notifications, 2);
  });

  test('timeToY maps midnight and noon at day and hour presets', () {
    final date = DateTime(2026, 11, 17);
    final start = _dayStart(date);
    final noon = DateTime(2026, 11, 17, 12);
    final hourHeights = {
      StreamZoomPreset.day: 56.0,
      StreamZoomPreset.hour: 160.0,
    };
    for (final entry in hourHeights.entries) {
      final viewport = _viewport(date, entry.key);
      final controller = StreamDayBodyController();
      addTearDown(controller.dispose);
      addTearDown(viewport.dispose);
      controller.attach(viewport: viewport, date: date);
      final hourHeight = 60.0 / viewport.minutesPerPixel;

      expect(hourHeight, entry.value);
      expect(controller.timeToY(start), 0);
      expect(controller.timeToY(noon), closeTo(12 * hourHeight, 1e-9));
    }
  });

  test('timeToY follows local elapsed time across a DST boundary', () {
    final date = DateTime(2026, 3, 8);
    final start = _dayStart(date);
    final localTime = DateTime(2026, 3, 8, 5, 30);
    final elapsedMinutes = localTime.difference(start).inMinutes;
    for (final preset in StreamZoomPreset.values) {
      final viewport = _viewport(date, preset);
      final controller = StreamDayBodyController();
      addTearDown(controller.dispose);
      addTearDown(viewport.dispose);
      controller.attach(viewport: viewport, date: date);
      final hourHeight = 60.0 / viewport.minutesPerPixel;

      expect(
        controller.timeToY(localTime),
        closeTo(elapsedMinutes / 60 * hourHeight, 1e-9),
      );
    }
  });

  test('pxToTime round-trips within one minute', () {
    final date = DateTime(2026, 11, 17);
    for (final preset in StreamZoomPreset.values) {
      final viewport = _viewport(date, preset)..setViewportHeight(800);
      final controller = StreamDayBodyController();
      addTearDown(controller.dispose);
      addTearDown(viewport.dispose);
      controller.attach(viewport: viewport, date: date);
      viewport.setOffset(137.5);
      final pxPerMinute = 1 / viewport.minutesPerPixel;

      for (final y in [0.0, 120.0, 400.0]) {
        final roundTrip = controller.timeToY(controller.pxToTime(y)!)!;
        expect((roundTrip - y).abs(), lessThanOrEqualTo(pxPerMinute + 1e-9));
      }
    }
  });

  test('scrollListenable fires when the viewport offset changes', () {
    final date = DateTime(2026, 11, 17);
    final viewport = _viewport(date, StreamZoomPreset.day);
    final controller = StreamDayBodyController();
    addTearDown(controller.dispose);
    addTearDown(viewport.dispose);
    controller.attach(viewport: viewport, date: date);
    var fires = 0;
    void listener() => fires++;
    final listenable = controller.scrollListenable!;
    listenable.addListener(listener);

    viewport.setOffset(120);
    viewport.setOffset(120);

    expect(fires, 1);
    listenable.removeListener(listener);
  });

  test('dispose detaches and later viewport notifications do not throw', () {
    final date = DateTime(2026, 11, 17);
    final viewport = _viewport(date, StreamZoomPreset.day);
    addTearDown(viewport.dispose);
    final controller = StreamDayBodyController()
      ..attach(viewport: viewport, date: date);
    controller.addListener(() {});

    controller.dispose();

    expect(controller.attached, isFalse);
    expect(() => viewport.setOffset(42), returnsNormally);
    expect(() => viewport.notify(), returnsNormally);
  });

  testWidgets('StreamDayBody attaches and detaches the controller', (
    tester,
  ) async {
    final controller = StreamDayBodyController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(date: DateTime(2026, 11, 17), controller: controller),
    );

    expect(controller.attached, isTrue);
    expect(controller.date, DateTime(2026, 11, 17));
    expect(controller.now, DateTime(2026, 11, 17, 10));

    await tester.pumpWidget(const SizedBox.shrink());

    expect(controller.attached, isFalse);
  });

  testWidgets('date change re-attaches with the new date', (tester) async {
    final controller = StreamDayBodyController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(date: DateTime(2026, 11, 17), controller: controller),
    );
    final firstViewport = controller.viewport;
    var notifications = 0;
    controller.addListener(() => notifications++);

    await tester.pumpWidget(
      _host(date: DateTime(2026, 11, 18), controller: controller),
    );

    expect(controller.date, DateTime(2026, 11, 18));
    expect(controller.viewport, isNotNull);
    expect(controller.viewport, isNot(same(firstViewport)));
    expect(notifications, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(controller.attached, isFalse);
  });
}
