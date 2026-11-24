import 'package:drift/native.dart';
import 'package:ephemeron/core/design/components/app_chips.dart';
import 'package:ephemeron/core/design/components/app_fields.dart';
import 'package:ephemeron/core/design/components/app_headers.dart';
import 'package:ephemeron/core/design/theme.dart';
import 'package:ephemeron/core/design/tokens.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/features/alarms/application/alarm_providers.dart';
import 'package:ephemeron/features/alarms/data/alarm_repository.dart';
import 'package:ephemeron/features/settings/data/settings_repository.dart';
import 'package:ephemeron/features/settings/presentation/settings_screen.dart';
import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAlarmRepo extends AlarmRepository {
  _FakeAlarmRepo() : super(AppDatabase.forTesting(NativeDatabase.memory()));

  int rebuildCalls = 0;
  bool? lastDueTomorrow;

  @override
  Future<int> rebuildWindow({bool dueTomorrowEnabled = true}) async {
    rebuildCalls++;
    lastDueTomorrow = dueTomorrowEnabled;
    return 0;
  }
}

ThemeData _theme() =>
    EphemeronTheme.build(mode: 'light', platformBrightness: Brightness.light);

Widget _settingsApp({
  List overrides = const [],
  double textScale = 1,
  EdgeInsets? padding,
}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(
      theme: _theme(),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(textScale),
            padding: padding ?? media.padding,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const SettingsScreen(),
    ),
  );
}

void _setViewport(
  WidgetTester tester, {
  double width = 600,
  double height = 6000,
}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  List overrides = const [],
  double textScale = 1,
  EdgeInsets? padding,
}) async {
  await tester.pumpWidget(
    _settingsApp(overrides: overrides, textScale: textScale, padding: padding),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('theme and accessibility settings round trip', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final repo = SettingsRepository(await SharedPreferences.getInstance());

    expect(repo.primaryColorHex, isNull);
    expect(repo.backgroundColorHex, isNull);
    expect(repo.localeCode, 'system');
    expect(repo.powerSavingMode, PowerSavingMode.auto);
    expect(repo.haptics, isTrue);
    expect(repo.streamEnabled, isFalse);
    expect(repo.dynamicColor, isFalse);
    expect(repo.uiDensity, 'comfortable');
    expect(repo.time24h, isTrue);
    expect(repo.navOrderV2, SettingsRepository.defaultNavOrderV2);

    await repo.setPrimaryColorHex('#112233');
    await repo.setBackgroundColorHex('#fbf7f0');
    await repo.setBrightness('amoled');
    await repo.setLocaleCode('pt');
    await repo.setPowerSavingMode(PowerSavingMode.off);
    await repo.setReduceAnimations(true);
    await repo.setHaptics(false);
    await repo.setStreamEnabled(true);
    await repo.setDynamicColor(true);
    await repo.setUiDensity('compact');
    await repo.setTime24h(false);
    await repo.setNavOrderV2(<int>[4, 0, 1, 2, 3, 5, 6, 7, 8]);

    expect(repo.primaryColorHex, '#112233');
    expect(repo.backgroundColorHex, '#fbf7f0');
    expect(repo.brightness, 'amoled');
    expect(repo.localeCode, 'pt');
    expect(repo.powerSavingMode, PowerSavingMode.off);
    expect(repo.reduceAnimations, isTrue);
    expect(repo.haptics, isFalse);
    expect(repo.streamEnabled, isTrue);
    expect(repo.dynamicColor, isTrue);
    expect(repo.uiDensity, 'compact');
    expect(repo.time24h, isFalse);
    expect(repo.navOrderV2, <int>[4, 0, 1, 2, 3, 5, 6, 7, 8]);
  });

  testWidgets('header applies the status bar inset exactly once', (
    tester,
  ) async {
    _setViewport(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await _pumpSettings(tester, padding: const EdgeInsets.only(top: 24));

    final title = find.descendant(
      of: find.byType(AppPageHeader),
      matching: find.text('Settings'),
    );
    expect(title, findsOneWidget);
    expect(tester.getTopLeft(title).dy, 24 + DsSpace.x12);
  });

  testWidgets('color presets and brightness show the current selection', (
    tester,
  ) async {
    _setViewport(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'settings.primaryColor': '#E53935',
      'settings.backgroundColor': '#121212',
      'settings.brightness': 'dark',
    });
    await _pumpSettings(tester);

    expect(
      find.byKey(const ValueKey('primary-selected-#e53935')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('background-selected-#121212')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<AppChip>(find.byKey(const ValueKey('brightness-dark')))
          .selected,
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('primary-color-#00897b')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('primary-selected-#00897b')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('primary-selected-#e53935')),
      findsNothing,
    );
    expect(
      (await SharedPreferences.getInstance()).getString(
        'settings.primaryColor',
      ),
      '#00897b',
    );

    await tester.tap(find.byKey(const ValueKey('brightness-amoled')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AppChip>(find.byKey(const ValueKey('brightness-amoled')))
          .selected,
      isTrue,
    );
    expect(
      (await SharedPreferences.getInstance()).getString('settings.brightness'),
      'amoled',
    );

    await tester.tap(find.byKey(const ValueKey('brightness-system')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AppChip>(find.byKey(const ValueKey('brightness-system')))
          .selected,
      isTrue,
    );
    expect(
      (await SharedPreferences.getInstance()).getString('settings.brightness'),
      'system',
    );
  });

  testWidgets('custom hex fields show values and keep validation', (
    tester,
  ) async {
    _setViewport(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'settings.primaryColor': '#112233',
    });
    await _pumpSettings(tester);

    final field = find.byKey(const ValueKey('primary-hex-field'));
    expect(tester.widget<TextField>(field).controller?.text, '#112233');

    await tester.enterText(field, 'not-a-color');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('Enter a valid hex like #RRGGBB.'), findsOneWidget);

    await tester.enterText(field, '#445566');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(field).controller?.text, '#445566');
    expect(find.text('Enter a valid hex like #RRGGBB.'), findsNothing);
    expect(
      (await SharedPreferences.getInstance()).getString(
        'settings.primaryColor',
      ),
      '#445566',
    );
  });

  testWidgets('due tomorrow reminder reflects stored value', (tester) async {
    _setViewport(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'alarms.taskDueTomorrowReminder': false,
    });
    final fakeAlarm = _FakeAlarmRepo();
    await _pumpSettings(
      tester,
      overrides: [alarmRepositoryProvider.overrideWithValue(fakeAlarm)],
    );

    final toggle = tester.widget<Switch>(
      find.byKey(const ValueKey('due-tomorrow-switch')),
    );
    expect(toggle.value, isFalse);
  });

  testWidgets('due tomorrow reminder toggle persists and rebuilds alarms', (
    tester,
  ) async {
    _setViewport(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final fakeAlarm = _FakeAlarmRepo();
    await _pumpSettings(
      tester,
      overrides: [alarmRepositoryProvider.overrideWithValue(fakeAlarm)],
    );

    final switchKey = find.byKey(const ValueKey('due-tomorrow-switch'));
    expect(tester.widget<Switch>(switchKey).value, isTrue);

    await tester.tap(switchKey);
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(switchKey).value, isFalse);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'alarms.taskDueTomorrowReminder',
      ),
      isFalse,
    );
    expect(fakeAlarm.rebuildCalls, 1);
    expect(fakeAlarm.lastDueTomorrow, isFalse);
  });

  testWidgets('appearance, time and stream controls persist', (tester) async {
    _setViewport(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'settings.brightness': 'system',
      'settings.streamEnabled': true,
      'settings.dynamicColor': true,
      'settings.uiDensity': 'compact',
      'settings.time24h': false,
    });
    await _pumpSettings(tester);

    expect(
      tester
          .widget<AppChip>(find.byKey(const ValueKey('brightness-system')))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<AppChip>(find.byKey(const ValueKey('density-compact')))
          .selected,
      isTrue,
    );
    expect(
      tester.widget<Switch>(find.byKey(const ValueKey('stream-toggle'))).value,
      isTrue,
    );
    expect(
      tester
          .widget<Switch>(find.byKey(const ValueKey('time-24h-switch')))
          .value,
      isFalse,
    );
    expect(
      tester
          .widget<Switch>(find.byKey(const ValueKey('dynamic-color-switch')))
          .value,
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('brightness-dark')));
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getString('settings.brightness'),
      'dark',
    );

    await tester.tap(find.byKey(const ValueKey('density-comfortable')));
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getString('settings.uiDensity'),
      'comfortable',
    );

    await tester.tap(find.byKey(const ValueKey('stream-toggle')));
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getBool('settings.streamEnabled'),
      isFalse,
    );

    await tester.tap(find.byKey(const ValueKey('time-24h-switch')));
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getBool('settings.time24h'),
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('dynamic-color-switch')));
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getBool('settings.dynamicColor'),
      isFalse,
    );
  });

  testWidgets('navigation order shows the saved order and persists changes', (
    tester,
  ) async {
    _setViewport(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'settings.navOrderV2': <String>[
        '4',
        '0',
        '1',
        '2',
        '3',
        '5',
        '6',
        '7',
        '8',
      ],
    });
    await _pumpSettings(tester);

    expect(
      find.textContaining(
        'Current order: Focus > Today > Tasks > Calendar > Habits > Countdowns > Notes > Matrix > Stream',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('settings-nav-order')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('nav-order-item-4')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-order-reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-order-save')));
    await tester.pumpAndSettle();

    expect(
      (await SharedPreferences.getInstance()).getStringList(
        'settings.navOrderV2',
      ),
      <String>['0', '1', '2', '3', '4', '5', '6', '7', '8'],
    );
  });

  testWidgets('title-row search button navigates to global search', (
    tester,
  ) async {
    _setViewport(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('global-search'))),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          theme: _theme(),
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final searchButton = find.byKey(const ValueKey('settings-search-toggle'));
    expect(
      find.descendant(of: find.byType(AppPageHeader), matching: searchButton),
      findsOneWidget,
    );
    expect(find.byType(AppSearchField), findsNothing);
    expect(find.byKey(const ValueKey('settings-search-field')), findsNothing);

    await tester.tap(searchButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('global-search'), findsOneWidget);
  });

  testWidgets('settings screen does not overflow at 320dp and 200% text', (
    tester,
  ) async {
    _setViewport(tester, width: 320, height: 640);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await _pumpSettings(tester, textScale: 2);
    expect(tester.takeException(), isNull);

    final scrollable = find.byType(Scrollable).first;
    for (var i = 0; i < 40; i++) {
      await tester.drag(scrollable, const Offset(0, -250));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'denied exact alarm action stays reachable at 320dp and 200% text',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      _setViewport(tester, width: 320, height: 640);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('ephemeron/system'),
        (call) async => call.method == 'canPostNotifications' ? true : null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('ephemeron/alarms'),
        (call) async => call.method == 'canScheduleExact' ? false : null,
      );
      addTearDown(() {
        messenger.setMockMethodCallHandler(
          const MethodChannel('ephemeron/system'),
          null,
        );
        messenger.setMockMethodCallHandler(
          const MethodChannel('ephemeron/alarms'),
          null,
        );
      });

      await _pumpSettings(tester, textScale: 2);
      expect(tester.takeException(), isNull);

      final tile = find.byKey(const ValueKey('settings-exact-alarm'));
      await tester.scrollUntilVisible(
        tile,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(tile, findsOneWidget);
      expect(
        find.byKey(const ValueKey('exact-alarm-open-settings')),
        findsOneWidget,
      );
      expect(find.text('Open settings'), findsOneWidget);
    },
  );
}
