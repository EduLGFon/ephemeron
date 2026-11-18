// Cases for the screen-level focus control mounted in the Stream chrome row
// (after the agenda toggle). Uses a deterministic injected clock; the real
// screen wiring is covered by the screen case and analyze.
import 'package:ephemeron/features/stream/presentation/focus/focus_band.dart';
import 'package:ephemeron/features/stream/presentation/focus/focus_clock.dart';
import 'package:ephemeron/features/stream/presentation/focus/focus_timer_controls.dart';
import 'package:ephemeron/features/stream/presentation/surface/stream_focus_band_host.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const Key _entryKey = Key('streamFocusEntry');
const Key _bandKey = Key('streamFocusBand');

class _Harness {
  _Harness() {
    clock = FocusClock(now: () => time);
  }

  late final FocusClock clock;
  DateTime time = DateTime(2026, 1, 1, 12);
  int toggleChanges = 0;

  /// Replicates the chrome row the screen mounts the host in: agenda text,
  /// switch, then the focus control inside a Flexible.
  Widget build({
    double width = 360,
    double height = 640,
    double textScale = 1,
  }) => MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: height,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text('Agenda'),
                    const SizedBox(width: 4),
                    Switch(
                      key: const Key('streamAgendaToggle'),
                      value: true,
                      onChanged: (_) => toggleChanges++,
                    ),
                    const SizedBox(width: 8),
                    Flexible(child: StreamFocusBandHost(clock: clock)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  void dispose() => clock.dispose();
}

Future<void> _pump(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await tester.pump();
}

void main() {
  testWidgets('entry starts a session; band and elapsed render; stop returns', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.dispose);
    await _pump(tester, h.build());

    // Idle: only the entry affordance is visible, no band yet.
    expect(find.byKey(_entryKey), findsOneWidget);
    expect(find.byKey(_bandKey), findsNothing);

    // Start a session and confirm the band and controls mount.
    await tester.tap(find.byKey(_entryKey));
    await tester.pump();
    expect(find.byKey(_bandKey), findsOneWidget);
    expect(find.byType(FocusBand), findsOneWidget);
    expect(find.byType(FocusTimerControls), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);

    h.time = h.time.add(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('00:05'), findsOneWidget);

    // Stop ends the session and brings the entry affordance back.
    await tester.tap(find.byIcon(Icons.stop));
    await tester.pump();
    expect(find.byKey(_bandKey), findsNothing);
    expect(find.byKey(_entryKey), findsOneWidget);
  });

  testWidgets('pause freezes elapsed and resume continues', (tester) async {
    final h = _Harness();
    addTearDown(h.dispose);
    await _pump(tester, h.build());

    await tester.tap(find.byKey(_entryKey));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();
    h.time = h.time.add(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('00:00'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    h.time = h.time.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('00:02'), findsOneWidget);
  });

  testWidgets('chrome row: agenda switch stays tappable next to the entry', (
    tester,
  ) async {
    // Regression: the first floating overlay version intercepted the agenda
    // toggle's tap after the tray-drag merge.
    final h = _Harness();
    addTearDown(h.dispose);
    await _pump(tester, h.build());

    await tester.tap(find.byKey(const Key('streamAgendaToggle')));
    await tester.pump();
    expect(h.toggleChanges, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320dp at 2.0 text scale does not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = _Harness();
    addTearDown(h.dispose);
    await _pump(tester, h.build(width: 320, textScale: 2));

    expect(tester.takeException(), isNull);

    // Active pill shrinks inside the row instead of overflowing.
    await tester.tap(find.byKey(_entryKey));
    await tester.pump();
    expect(tester.takeException(), isNull);
    final bandRect = tester.getRect(find.byKey(_bandKey));
    expect(bandRect.right, lessThanOrEqualTo(320));
    expect(bandRect.left, greaterThanOrEqualTo(0));
  });
}
