import 'package:ephemeron/features/stream/capture/capture_parser.dart';
import 'package:ephemeron/features/stream/presentation/capture/capture_bar.dart';
import 'package:ephemeron/features/stream/presentation/surface/stream_capture_chips.dart';
import 'package:ephemeron/features/stream/presentation/surface/stream_capture_dock.dart';
import 'package:ephemeron/features/stream/presentation/tray/tray_chip.dart';
import 'package:ephemeron/features/stream/presentation/tray/tray_item.dart';
import 'package:ephemeron/features/stream/presentation/tray/tray_strip.dart';
import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

final DateTime _now = DateTime(2026, 11, 17, 9, 0);

const StreamCaptureDockLabels _labels = StreamCaptureDockLabels(
  captureHint: 'Capture a task, event, habit or countdown',
  captureLabel: 'Capture',
  submitLabel: 'Add',
  clearLabel: 'Clear',
  closeLabel: 'Close',
  trayEmpty: 'No unscheduled tasks',
  trayCount: '3 unscheduled tasks',
  trayHandle: 'Open task tray',
);

List<TrayItem> _items(int count) => <TrayItem>[
  for (var i = 0; i < count; i++)
    TrayItem(
      id: 't$i',
      title: 'A very long unscheduled task title $i',
      listId: 'l1',
      listName: 'Work',
      colorArgb: 0xFF336699,
    ),
];

Widget _app(Widget child, {MediaQueryData Function(MediaQueryData)? media}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: MediaQuery(
          data: media?.call(MediaQuery.of(context)) ?? MediaQuery.of(context),
          child: Align(alignment: Alignment.bottomCenter, child: child),
        ),
      ),
    ),
  );
}

Widget _dock({
  List<TrayItem> items = const <TrayItem>[],
  StreamCaptureDockLabels labels = _labels,
  ValueChanged<CaptureDraft>? onSubmitted,
  VoidCallback? onExpandRequested,
  ValueChanged<String>? onItemTap,
}) {
  return Builder(
    builder: (context) {
      final l = AppLocalizations.of(context);
      return StreamCaptureDock(
        now: _now,
        locale: CaptureLocale.en,
        items: items,
        labels: labels,
        chipsBuilder: (draft) =>
            buildStreamCaptureChips(draft, l: l, localeName: 'en'),
        onSubmitted: onSubmitted,
        onExpandRequested: onExpandRequested,
        onItemTap: onItemTap,
      );
    },
  );
}

void main() {
  testWidgets('dock renders capture bar and tray strip without SafeArea', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_dock()));
    expect(find.byType(CaptureBar), findsOneWidget);
    expect(find.byType(TrayStrip), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(StreamCaptureDock),
        matching: find.byType(SafeArea),
      ),
      findsNothing,
    );
  });

  testWidgets('empty tray shows the localized empty label', (tester) async {
    await tester.pumpWidget(_app(_dock()));
    expect(find.text(_labels.trayEmpty), findsOneWidget);
  });

  testWidgets('three tray items show the count badge', (tester) async {
    await tester.pumpWidget(_app(_dock(items: _items(3))));
    expect(find.text('3'), findsOneWidget);
    expect(find.byType(TrayChip), findsNWidgets(3));
  });

  testWidgets('submitting a draft calls the callback with the draft', (
    tester,
  ) async {
    CaptureDraft? received;
    await tester.pumpWidget(_app(_dock(onSubmitted: (d) => received = d)));
    await tester.enterText(find.byType(TextField), 'call dentist tomorrow 3pm');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(received, isNotNull);
    expect(received!.title, 'call dentist');
    expect(received!.date, DateTime(2026, 11, 18));
  });

  testWidgets('tray expand handle calls the callback', (tester) async {
    var expanded = 0;
    await tester.pumpWidget(
      _app(_dock(items: _items(1), onExpandRequested: () => expanded++)),
    );
    await tester.tap(find.bySemanticsLabel(_labels.trayHandle));
    await tester.pump();
    expect(expanded, 1);
  });

  testWidgets('tray item tap calls the callback with the id', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      _app(_dock(items: _items(1), onItemTap: tapped.add)),
    );
    await tester.tap(find.byType(TrayChip));
    await tester.pump();
    expect(tapped, <String>['t0']);
  });

  testWidgets('preview chips show kind date time repeat list and priority', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_dock()));
    await tester.enterText(
      find.byType(TextField),
      'call dentist tomorrow 3pm every day #work !high',
    );
    await tester.pump();

    expect(find.byType(ActionChip), findsNWidgets(6));
    expect(find.textContaining('Habit'), findsOneWidget);
    expect(find.textContaining('Date:'), findsOneWidget);
    expect(find.textContaining('Time:'), findsOneWidget);
    expect(find.textContaining('Repeat:'), findsOneWidget);
    expect(find.textContaining('List:'), findsOneWidget);
    expect(find.textContaining('Priority:'), findsOneWidget);
  });

  testWidgets('320 dp at 2.0 scale does not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        _dock(items: _items(3)),
        media: (m) => m.copyWith(textScaler: const TextScaler.linear(2.0)),
      ),
    );
    await tester.enterText(
      find.byType(TextField),
      'call dentist tomorrow 3pm every day #work !high',
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard inset is applied with 120 ms padding animation', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _dock(),
        media: (m) =>
            m.copyWith(viewInsets: const EdgeInsets.only(bottom: 240)),
      ),
    );
    final padding = tester.widget<AnimatedPadding>(
      find.byKey(const Key('streamDockKeyboardPadding')),
    );
    expect(padding.padding, const EdgeInsets.only(bottom: 240));
    expect(padding.duration, const Duration(milliseconds: 120));
  });

  testWidgets('reduce motion removes the padding animation', (tester) async {
    await tester.pumpWidget(
      _app(
        _dock(),
        media: (m) => m.copyWith(
          viewInsets: const EdgeInsets.only(bottom: 120),
          disableAnimations: true,
        ),
      ),
    );
    final padding = tester.widget<AnimatedPadding>(
      find.byKey(const Key('streamDockKeyboardPadding')),
    );
    expect(padding.duration, Duration.zero);
  });
}
