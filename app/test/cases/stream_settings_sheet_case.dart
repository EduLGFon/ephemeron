import 'package:ephemeron/features/stream/application/stream_theme_provider.dart';
import 'package:ephemeron/features/stream/design/stream_theme_mode.dart';
import 'package:ephemeron/features/stream/presentation/surface/stream_settings_sheet.dart';
import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _FakeThemeNotifier extends StreamThemeNotifier {
  _FakeThemeNotifier(this.initial);

  final StreamThemeMode initial;
  int setModeCalls = 0;
  StreamThemeMode? lastMode;

  @override
  StreamThemeMode build() => initial;

  @override
  Future<void> setMode(StreamThemeMode mode) async {
    setModeCalls++;
    lastMode = mode;
    state = mode;
  }
}

late _FakeThemeNotifier _theme;

Widget _app({
  StreamThemeMode initial = StreamThemeMode.system,
  VoidCallback? onClose,
  VoidCallback? onOpenAppSettings,
  VoidCallback? onReplaySchool,
  Widget Function(Widget child)? wrap,
}) {
  final content = Scaffold(
    body: StreamSettingsSheet(
      onClose: onClose ?? () {},
      onOpenAppSettings: onOpenAppSettings ?? () {},
      onReplaySchool: onReplaySchool,
    ),
  );
  return ProviderScope(
    overrides: [
      streamThemeProvider.overrideWith(() {
        _theme = _FakeThemeNotifier(initial);
        return _theme;
      }),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: wrap == null ? content : wrap(content),
    ),
  );
}

Key _themeKey(StreamThemeMode mode) => Key('streamSettingsTheme-${mode.name}');

void main() {
  testWidgets('current mode is the only selected row', (tester) async {
    await tester.pumpWidget(_app(initial: StreamThemeMode.dark));

    for (final mode in StreamThemeMode.values) {
      final data = tester
          .getSemantics(find.byKey(_themeKey(mode)))
          .getSemanticsData();
      expect(
        data.flagsCollection.isSelected.name,
        mode == StreamThemeMode.dark ? 'isTrue' : 'isFalse',
        reason: mode.name,
      );
    }
  });

  testWidgets('tapping a mode calls setMode with that mode', (tester) async {
    await tester.pumpWidget(_app());

    for (final mode in StreamThemeMode.values) {
      await tester.tap(find.byKey(_themeKey(mode)));
      await tester.pump();
      expect(_theme.lastMode, mode);
    }
    expect(_theme.setModeCalls, StreamThemeMode.values.length);
  });

  testWidgets('close and action rows report taps', (tester) async {
    var closed = 0;
    var settings = 0;
    var replay = 0;
    await tester.pumpWidget(
      _app(
        onClose: () => closed++,
        onOpenAppSettings: () => settings++,
        onReplaySchool: () => replay++,
      ),
    );

    await tester.tap(find.byKey(const Key('streamSettingsSheetClose')));
    await tester.tap(find.byKey(const Key('streamSettingsMore')));
    await tester.tap(find.byKey(const Key('streamSettingsReplaySchool')));
    await tester.pump();

    expect(closed, 1);
    expect(settings, 1);
    expect(replay, 1);
  });

  testWidgets('replay row is omitted without its callback', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(_app());

    expect(find.byKey(const Key('streamSettingsReplaySchool')), findsNothing);
    expect(find.text(l.streamSettingsReplaySchool), findsNothing);
    expect(find.byKey(const Key('streamSettingsMore')), findsOneWidget);
  });

  testWidgets('rows expose labels, button semantics and 48 dp height', (
    tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(_app(onReplaySchool: () {}));

    final labels = <StreamThemeMode, String>{
      StreamThemeMode.light: l.streamSettingsThemeLight,
      StreamThemeMode.dark: l.streamSettingsThemeDark,
      StreamThemeMode.trueBlack: l.streamSettingsThemeTrueBlack,
      StreamThemeMode.system: l.streamSettingsThemeSystem,
    };
    for (final entry in labels.entries) {
      expect(find.bySemanticsLabel(entry.value), findsOneWidget);
      final node = tester.getSemantics(find.byKey(_themeKey(entry.key)));
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(
        tester.getSize(find.byKey(_themeKey(entry.key))).height,
        greaterThanOrEqualTo(48),
      );
    }
    for (final label in [l.streamSettingsMore, l.streamSettingsReplaySchool]) {
      expect(find.bySemanticsLabel(label), findsOneWidget);
    }
    expect(
      tester.getSize(find.byKey(const Key('streamSettingsMore'))).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('320 dp at 2.0 text scale does not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        onReplaySchool: () {},
        wrap: (child) => MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: child,
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
