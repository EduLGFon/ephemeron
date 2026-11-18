import 'package:ephemeron/core/design/components/app_headers.dart';
import 'package:ephemeron/core/design/theme.dart';
import 'package:ephemeron/core/design/tokens.dart';
import 'package:ephemeron/features/settings/data/settings_repository.dart';
import 'package:ephemeron/features/settings/presentation/onboarding_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ThemeData _theme() =>
    EphemeronTheme.build(mode: 'light', platformBrightness: Brightness.light);

Widget _onboardingApp({double textScale = 1, EdgeInsets? padding}) {
  return ProviderScope(
    child: MaterialApp(
      theme: _theme(),
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
      home: const OnboardingScreen(),
    ),
  );
}

void _setViewport(
  WidgetTester tester, {
  double width = 600,
  double height = 800,
}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('onboarding has three skippable pages and optional Google', (
    tester,
  ) async {
    _setViewport(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_onboardingApp());
    await tester.pumpAndSettle();

    expect(find.text('Ephemeron'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.textContaining('Everything in one calm place'), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-skip')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-primary')));
    await tester.pumpAndSettle();

    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(find.textContaining('Alarms that actually ring'), findsOneWidget);
    expect(
      find.text('No notification permission is requested now.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('onboarding-primary')));
    await tester.pumpAndSettle();

    expect(find.text('Step 3 of 3'), findsOneWidget);
    expect(find.textContaining('Sync only if you want it'), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-google')), findsOneWidget);
    expect(
      find.text('You can connect accounts later in Settings.'),
      findsOneWidget,
    );
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('header applies the status bar inset exactly once', (
    tester,
  ) async {
    _setViewport(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      _onboardingApp(padding: const EdgeInsets.only(top: 24)),
    );
    await tester.pumpAndSettle();

    final title = find.descendant(
      of: find.byType(AppPageHeader),
      matching: find.text('Ephemeron'),
    );
    expect(title, findsOneWidget);
    expect(tester.getTopLeft(title).dy, 24 + DsSpace.x12);
  });

  testWidgets('skip marks onboarding complete and never blocks local use', (
    tester,
  ) async {
    _setViewport(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_onboardingApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
    await tester.pumpAndSettle();

    final repo = SettingsRepository(await SharedPreferences.getInstance());
    expect(repo.onboarded, isTrue);
  });

  testWidgets('get started on the last page marks onboarding complete', (
    tester,
  ) async {
    _setViewport(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_onboardingApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('onboarding-primary')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-primary')));
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-primary')));
    await tester.pumpAndSettle();

    final repo = SettingsRepository(await SharedPreferences.getInstance());
    expect(repo.onboarded, isTrue);
  });

  testWidgets('onboarding does not overflow at 320dp and 200% text', (
    tester,
  ) async {
    _setViewport(tester, width: 320, height: 640);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_onboardingApp(textScale: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('onboarding-primary')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('onboarding-primary')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Get started'), findsOneWidget);
  });
}
