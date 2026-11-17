import 'package:ephemeron/features/stream/application/stream_day_mark.dart';
import 'package:ephemeron/features/stream/engine/stream_time_viewport.dart';
import 'package:ephemeron/features/stream/presentation/day/day_canvas.dart';
import 'package:ephemeron/features/stream/presentation/stream_day_body_view.dart';
import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  StreamDayMark eventMark(String id, int startMin, int endMin) => StreamDayMark(
    id: id,
    kind: StreamDayMarkKind.event,
    startMs: startMin * 60 * 1000,
    endMs: endMin * 60 * 1000,
    title: id,
    colorArgb: 0xFF000000,
  );

  final marks = <StreamDayMark>[
    eventMark('m0', 0, 60),
    eventMark('m1', 120, 180),
    eventMark('m2', 240, 300),
  ];

  StreamTimeViewport makeViewport() => StreamTimeViewport(baseEpochMs: 0);

  Widget app({
    required StreamTimeViewport viewport,
    required List<StreamDayMark> marks,
    ValueChanged<String>? onMarkTap,
    double textScale = 1,
  }) {
    final timeLabel = ValueNotifier<String>('');
    final away = ValueNotifier<bool>(false);
    addTearDown(timeLabel.dispose);
    addTearDown(away.dispose);
    return MaterialApp(
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
          body: StreamDayBodyView(
            viewport: viewport,
            marks: marks,
            isToday: false,
            now: DateTime(2026, 11, 17, 12),
            timeLabel: timeLabel,
            away: away,
            onDateChanged: null,
            onReturnToNow: () {},
            l: AppLocalizations.of(context),
            date: DateTime(2026, 11, 17),
            onMarkTap: onMarkTap,
          ),
        ),
      ),
    );
  }

  Offset pointOn(WidgetTester tester, StreamTimeViewport viewport, int minute) {
    final rect = tester.getRect(find.byType(DayCanvas));
    final y = viewport.timeToPx(minute * 60 * 1000);
    return Offset(rect.left + rect.width / 2, rect.top + y);
  }

  testWidgets('tap on a mark reports its id once without panning', (
    tester,
  ) async {
    final viewport = makeViewport();
    final taps = <String>[];
    await tester.pumpWidget(
      app(viewport: viewport, marks: marks, onMarkTap: taps.add),
    );
    await tester.pump();

    final offsetBefore = viewport.offsetPx;
    await tester.tapAt(pointOn(tester, viewport, 150));
    await tester.pump();

    expect(taps, ['m1']);
    expect(viewport.offsetPx, offsetBefore);
  });

  testWidgets('tap on empty time reports nothing', (tester) async {
    final viewport = makeViewport();
    final taps = <String>[];
    await tester.pumpWidget(
      app(viewport: viewport, marks: marks, onMarkTap: taps.add),
    );
    await tester.pump();

    await tester.tapAt(pointOn(tester, viewport, 90));
    await tester.pump();

    expect(taps, isEmpty);
  });

  testWidgets('taps inside the edge margins still report the mark', (
    tester,
  ) async {
    final viewport = makeViewport();
    final taps = <String>[];
    await tester.pumpWidget(
      app(viewport: viewport, marks: marks, onMarkTap: taps.add),
    );
    await tester.pump();

    final rect = tester.getRect(find.byType(DayCanvas));
    final y = rect.top + viewport.timeToPx(30 * 60 * 1000);
    await tester.tapAt(Offset(rect.left + 10, y));
    await tester.pump();
    await tester.tapAt(Offset(rect.right - 10, y));
    await tester.pump();

    expect(taps, ['m0', 'm0']);
  });

  testWidgets('vertical drag pans and never opens a mark', (tester) async {
    final viewport = makeViewport();
    final taps = <String>[];
    await tester.pumpWidget(
      app(viewport: viewport, marks: marks, onMarkTap: taps.add),
    );
    await tester.pump();

    final before = viewport.offsetPx;
    await tester.drag(find.byType(DayCanvas), const Offset(0, -120));
    await tester.pump();

    expect(viewport.offsetPx, greaterThan(before));
    expect(taps, isEmpty);
  });

  testWidgets('pinch zooms and never opens a mark', (tester) async {
    final viewport = makeViewport();
    final taps = <String>[];
    await tester.pumpWidget(
      app(viewport: viewport, marks: marks, onMarkTap: taps.add),
    );
    await tester.pump();

    final before = viewport.minutesPerPixel;
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

    expect(viewport.minutesPerPixel, isNot(before));
    expect(taps, isEmpty);
  });

  testWidgets('320 dp at 2.0 text scale taps without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final viewport = makeViewport();
    final taps = <String>[];
    await tester.pumpWidget(
      app(viewport: viewport, marks: marks, onMarkTap: taps.add, textScale: 2),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tapAt(pointOn(tester, viewport, 150));
    await tester.pump();

    expect(taps, ['m1']);
    expect(tester.takeException(), isNull);
  });
}
