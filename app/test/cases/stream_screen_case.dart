import 'package:ephemeron/features/stream/application/stream_day_mark.dart';
import 'package:ephemeron/features/stream/application/stream_day_providers.dart';
import 'package:ephemeron/features/stream/application/stream_theme_provider.dart';
import 'package:ephemeron/features/stream/design/stream_theme_mode.dart';
import 'package:ephemeron/features/stream/presentation/day/day_canvas.dart';
import 'package:ephemeron/features/stream/presentation/now_pill.dart';
import 'package:ephemeron/features/stream/presentation/stream_header.dart';
import 'package:ephemeron/features/stream/presentation/stream_screen.dart';
import 'package:ephemeron/features/stream/presentation/chrome/now_line.dart';
import 'package:ephemeron/features/stream/stream_flags.dart';
import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ephemeron/features/stream/presentation/chrome/breadcrumb.dart';
import 'package:ephemeron/features/stream/presentation/chrome/scrubber.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
    startMs: DateTime(2026, 11, 16, 8 + i).millisecondsSinceEpoch,
    endMs: DateTime(2026, 11, 16, 9 + i).millisecondsSinceEpoch,
    title: 'Mark $i',
    colorArgb: 0xFF123456,
  ),
);

Widget _app({
  required List overrides,
  required DateTime date,
  StreamSyncStatus syncStatus = StreamSyncStatus.synced,
  String? syncLabel,
  VoidCallback? onOpenCommand,
  VoidCallback? onOpenSettings,
  VoidCallback? onReturnToNow,
  Widget? homeOverride,
}) {
  return ProviderScope(
    overrides: overrides.cast(),
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
            onReturnToNow: onReturnToNow,
            syncStatus: syncStatus,
            syncLabel: syncLabel,
          ),
    ),
  );
}

void main() {
  test('streamUiEnabled defaults to false', () {
    expect(streamUiEnabled, isFalse);
  });

  testWidgets('surface renders breadcrumb, canvas, now line, scrubber inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final overrides = [
      streamMarksForDayProvider.overrideWith(
        (ref, key) async => StreamDayMarks(marks: _fakeMarks, skippedCount: 0),
      ),
      streamThemeProvider.overrideWith(
        () => _FixedStreamThemeNotifier(StreamThemeMode.dark),
      ),
    ];

    await tester.pumpWidget(
      _app(overrides: overrides, date: DateTime(2026, 11, 16)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('2026-11-16'), findsOneWidget);
    expect(find.textContaining('Day'), findsOneWidget);

    expect(find.byType(DayCanvas), findsOneWidget);
    final canvas = tester.widget<DayCanvas>(find.byType(DayCanvas));
    expect(canvas.marks.length, 3);

    expect(find.byType(NowLine), findsOneWidget);

    final rect = tester.getRect(find.byType(Scrubber));
    const width = 360.0;
    expect(width - rect.right, greaterThanOrEqualTo(24.0));
  });

  testWidgets('layout modes show placeholders by width', (tester) async {
    final overrides = [
      streamMarksForDayProvider.overrideWith(
        (ref, key) async => StreamDayMarks(marks: _fakeMarks, skippedCount: 0),
      ),
      streamThemeProvider.overrideWith(
        () => _FixedStreamThemeNotifier(StreamThemeMode.dark),
      ),
    ];

    // Compact.
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _app(overrides: overrides, date: DateTime(2026, 11, 16)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('sidePanelPlaceholder')), findsNothing);
    expect(find.byKey(const Key('leftPanelPlaceholder')), findsNothing);
    expect(find.byKey(const Key('rightInspectorPlaceholder')), findsNothing);

    // Expanded.
    tester.view.physicalSize = const Size(900, 800);
    await tester.pumpWidget(
      _app(overrides: overrides, date: DateTime(2026, 11, 16)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('leftPanelPlaceholder')), findsOneWidget);
    expect(find.byKey(const Key('rightInspectorPlaceholder')), findsOneWidget);
  });

  testWidgets('interactions call callbacks and now pill', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var openCommand = 0;
    var openSettings = 0;
    var returnToNow = 0;

    final overrides = [
      streamMarksForDayProvider.overrideWith(
        (ref, key) async => StreamDayMarks(marks: _fakeMarks, skippedCount: 0),
      ),
      streamThemeProvider.overrideWith(
        () => _FixedStreamThemeNotifier(StreamThemeMode.dark),
      ),
    ];

    await tester.pumpWidget(
      _app(
        overrides: overrides.cast(),
        date: DateTime(2026, 11, 16),
        onOpenCommand: () => openCommand++,
        onOpenSettings: () => openSettings++,
        onReturnToNow: () => returnToNow++,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await tester.pump();
    expect(openSettings, 1);

    await tester.tap(find.byType(Breadcrumb));
    await tester.pump();
    expect(openCommand, 1);

    // Now pill may appear after viewport settle.
    await tester.pump(const Duration(milliseconds: 200));
    if (find.byType(NowPill).evaluate().isEmpty) {
      // Force away by pumping more.
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.byType(NowPill), findsOneWidget);
    await tester.tap(find.byType(NowPill));
    await tester.pump();
    expect(returnToNow, 1);
  });

  testWidgets('text scale 2.0 at 320 dp no overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final overrides = [
      streamMarksForDayProvider.overrideWith(
        (ref, key) async => StreamDayMarks(marks: _fakeMarks, skippedCount: 0),
      ),
      streamThemeProvider.overrideWith(
        () => _FixedStreamThemeNotifier(StreamThemeMode.dark),
      ),
    ];

    await tester.pumpWidget(
      _app(
        overrides: overrides.cast(),
        date: DateTime(2026, 11, 16),
        homeOverride: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: StreamScreen(date: DateTime(2026, 11, 16)),
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

    final overrides = [
      streamMarksForDayProvider.overrideWith(
        (ref, key) async => StreamDayMarks(marks: _fakeMarks, skippedCount: 0),
      ),
      streamThemeProvider.overrideWith(
        () => _FixedStreamThemeNotifier(StreamThemeMode.dark),
      ),
    ];

    for (final status in StreamSyncStatus.values) {
      final label = 'sync-label-$status';
      await tester.pumpWidget(
        _app(
          overrides: overrides.cast(),
          date: DateTime(2026, 11, 16),
          syncStatus: status,
          syncLabel: label,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.bySemanticsLabel(label), findsWidgets);
    }
  });
}
