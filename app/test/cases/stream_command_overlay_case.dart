import 'package:ephemeron/features/stream/application/stream_command_actions.dart';
import 'package:ephemeron/features/stream/design/stream_theme_mode.dart';
import 'package:ephemeron/features/stream/presentation/surface/stream_command_overlay.dart';
import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

const _fieldKey = Key('streamCommandField');

Widget _app({
  required ValueNotifier<bool> open,
  required List<StreamCommandIntent> selected,
  required VoidCallback onBuild,
  DateTime? now,
  double textScale = 1,
}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) {
        onBuild();
        final l = AppLocalizations.of(context);
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: StreamCommandOverlay(
              open: open,
              now: now ?? DateTime(2026, 11, 17, 10),
              labels: StreamCommandOverlayLabels.of(l),
              onClose: () => open.value = false,
              onSelected: selected.add,
            ),
          ),
        );
      },
    ),
  );
}

Future<void> _open(WidgetTester tester, ValueNotifier<bool> open) async {
  open.value = true;
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('opening shows the field and candidates', (tester) async {
    final open = ValueNotifier<bool>(false);
    addTearDown(open.dispose);
    final selected = <StreamCommandIntent>[];

    await tester.pumpWidget(
      _app(open: open, selected: selected, onBuild: () {}),
    );
    expect(find.byKey(_fieldKey), findsNothing);

    await _open(tester, open);

    expect(find.byKey(_fieldKey), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Tomorrow'), findsOneWidget);
    expect(find.text('Day'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Year'), findsOneWidget);
    expect(find.text('Settings'), findsNothing);
    expect(selected, isEmpty);

    // The palette caps the visible list at six; the remaining candidates are
    // reachable through the query filter.
    for (final entry in const <String, String>{
      'settings': 'Settings',
      'search': 'Search',
      'sync': 'Sync now',
      'light': 'Theme: Light',
    }.entries) {
      await tester.enterText(find.byKey(_fieldKey), entry.key);
      await tester.pump();
      expect(find.text(entry.value), findsOneWidget);
    }
  });

  testWidgets('typing filters candidates', (tester) async {
    final open = ValueNotifier<bool>(false);
    addTearDown(open.dispose);
    final selected = <StreamCommandIntent>[];

    await tester.pumpWidget(
      _app(open: open, selected: selected, onBuild: () {}),
    );
    await _open(tester, open);
    await tester.enterText(find.byKey(_fieldKey), 'tom');
    await tester.pump();

    expect(find.text('Tomorrow'), findsOneWidget);
    expect(find.text('Settings'), findsNothing);
    expect(find.text('Sync now'), findsNothing);
  });

  testWidgets('ArrowDown and Enter select Tomorrow once', (tester) async {
    final open = ValueNotifier<bool>(false);
    addTearDown(open.dispose);
    final selected = <StreamCommandIntent>[];

    await tester.pumpWidget(
      _app(open: open, selected: selected, onBuild: () {}),
    );
    await _open(tester, open);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(selected, hasLength(1));
    expect(
      selected.single,
      isA<StreamCommandGoToDate>().having(
        (intent) => intent.date,
        'date',
        DateTime(2026, 11, 18),
      ),
    );
    expect(open.value, isFalse);
    expect(find.byKey(_fieldKey), findsNothing);
  });

  testWidgets('zoom candidates map to their level intents', (tester) async {
    final open = ValueNotifier<bool>(false);
    addTearDown(open.dispose);
    final selected = <StreamCommandIntent>[];

    await tester.pumpWidget(
      _app(open: open, selected: selected, onBuild: () {}),
    );

    const levels = <String, String>{
      'Day': 'day',
      'Week': 'week',
      'Month': 'month',
      'Year': 'year',
    };
    for (final entry in levels.entries) {
      selected.clear();
      await _open(tester, open);
      await tester.tap(find.text(entry.key));
      await tester.pump();

      expect(selected, hasLength(1));
      expect(
        selected.single,
        isA<StreamCommandZoom>().having(
          (intent) => intent.level,
          'level',
          entry.value,
        ),
      );
    }
  });

  testWidgets('agenda candidate maps to the agenda intent', (tester) async {
    final open = ValueNotifier<bool>(false);
    addTearDown(open.dispose);
    final selected = <StreamCommandIntent>[];

    await tester.pumpWidget(
      _app(open: open, selected: selected, onBuild: () {}),
    );
    await _open(tester, open);
    await tester.enterText(find.byKey(_fieldKey), 'agenda');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(selected, hasLength(1));
    expect(selected.single, isA<StreamCommandAgenda>());
  });

  testWidgets('theme candidate maps to the dark mode intent', (tester) async {
    final open = ValueNotifier<bool>(false);
    addTearDown(open.dispose);
    final selected = <StreamCommandIntent>[];

    await tester.pumpWidget(
      _app(open: open, selected: selected, onBuild: () {}),
    );
    await _open(tester, open);
    await tester.enterText(find.byKey(_fieldKey), 'dark');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(selected, hasLength(1));
    expect(
      selected.single,
      isA<StreamCommandTheme>().having(
        (intent) => intent.mode,
        'mode',
        StreamThemeMode.dark,
      ),
    );
  });

  testWidgets('Esc and the scrim close the overlay', (tester) async {
    final open = ValueNotifier<bool>(false);
    addTearDown(open.dispose);
    final selected = <StreamCommandIntent>[];

    await tester.pumpWidget(
      _app(open: open, selected: selected, onBuild: () {}),
    );
    await _open(tester, open);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(open.value, isFalse);
    expect(find.byKey(_fieldKey), findsNothing);

    await _open(tester, open);
    await tester.tapAt(const Offset(2, 2));
    await tester.pump();
    expect(open.value, isFalse);
    expect(find.byKey(_fieldKey), findsNothing);
  });

  testWidgets('320 dp at 2.0 text scale does not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final open = ValueNotifier<bool>(false);
    addTearDown(open.dispose);
    final selected = <StreamCommandIntent>[];

    await tester.pumpWidget(
      _app(open: open, selected: selected, onBuild: () {}, textScale: 2.0),
    );
    await _open(tester, open);

    expect(find.byKey(_fieldKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('typing does not rebuild the parent', (tester) async {
    var builds = 0;
    final open = ValueNotifier<bool>(false);
    addTearDown(open.dispose);
    final selected = <StreamCommandIntent>[];

    await tester.pumpWidget(
      _app(open: open, selected: selected, onBuild: () => builds++),
    );
    await _open(tester, open);
    final before = builds;

    await tester.enterText(find.byKey(_fieldKey), 't');
    await tester.pump();
    await tester.enterText(find.byKey(_fieldKey), 'to');
    await tester.pump();

    expect(builds, before);
  });
}
