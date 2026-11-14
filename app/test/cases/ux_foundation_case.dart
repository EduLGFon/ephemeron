import 'package:ephemeron/core/theme/app_theme.dart';
import 'package:ephemeron/core/theme/theme_tokens.dart';
import 'package:ephemeron/core/ui/app_feedback.dart';
import 'package:ephemeron/core/ui/app_motion.dart';
import 'package:ephemeron/core/ui/app_skeleton.dart';
import 'package:ephemeron/core/ui/empty_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

ThemeData _theme([AppBrightness brightness = AppBrightness.light]) {
  return buildTheme(
    primary: primaryPresets.first,
    background: backgroundPresets.first,
    brightness: brightness,
  );
}

Widget _app(Widget home, {ThemeData? theme}) {
  return MaterialApp(theme: theme ?? _theme(), home: home);
}

void main() {
  testWidgets('empty state renders primary and secondary actions', (
    tester,
  ) async {
    var primaryTaps = 0;
    var secondaryTaps = 0;

    await tester.pumpWidget(
      _app(
        Scaffold(
          body: EmptyState(
            icon: Icons.inbox_outlined,
            title: 'Nothing here',
            subtitle: 'Create your first item.',
            actionLabel: 'Create',
            onAction: () => primaryTaps++,
            secondaryActionLabel: 'Learn more',
            onSecondaryAction: () => secondaryTaps++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.text('Create your first item.'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(TextButton), findsOneWidget);

    await tester.tap(find.text('Create'));
    await tester.tap(find.text('Learn more'));
    await tester.pumpAndSettle();

    expect(primaryTaps, 1);
    expect(secondaryTaps, 1);
  });

  testWidgets('undo snack bar shows and fires the undo action', (tester) async {
    var undone = false;

    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showUndoSnackBar(
                  context,
                  'Task deleted',
                  onUndo: () => undone = true,
                ),
                child: const Text('delete'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Task deleted'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(undone, isTrue);
  });

  testWidgets('skeleton list builds without reduced motion', (tester) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Builder(builder: (context) => AppSkeleton.list(context)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const ValueKey('app-skeleton-list')), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Dispose the pulse controller before the test ends.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion stops the skeleton pulse', (tester) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: AppSkeleton.list(context),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );

    expect(find.byKey(const ValueKey('app-skeleton-list')), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppMotion collapses durations when animations are disabled', (
    tester,
  ) async {
    late BuildContext captured;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(AppMotion.reduced(captured), isFalse);
    expect(
      AppMotion.duration(captured, AppDurations.normal),
      AppDurations.normal,
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child ?? const SizedBox.shrink(),
        ),
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pump();
    expect(AppMotion.reduced(captured), isTrue);
    expect(AppMotion.duration(captured, AppDurations.normal), Duration.zero);
  });

  testWidgets('PressableScale tracks presses without owning onTap', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Center(
            child: PressableScale(
              child: Material(
                child: InkWell(
                  onTap: () {},
                  child: const SizedBox(width: 80, height: 80),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final scale = find.byType(AnimatedScale);
    expect(tester.widget<AnimatedScale>(scale).scale, 1);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(InkWell)),
    );
    await tester.pump();
    expect(tester.widget<AnimatedScale>(scale).scale, 0.97);

    await gesture.up();
    await tester.pump();
    expect(tester.widget<AnimatedScale>(scale).scale, 1);
  });

  testWidgets('theme builds and core widgets render for every brightness', (
    tester,
  ) async {
    for (final brightness in AppBrightness.values) {
      final theme = _theme(brightness);
      final expected = brightness == AppBrightness.light
          ? Brightness.light
          : Brightness.dark;

      expect(theme.colorScheme.brightness, expected);
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
      expect(theme.textTheme.headlineLarge?.fontFamily, 'Fraunces');
      expect(theme.textTheme.headlineMedium?.fontFamily, 'Inter');
      expect(theme.textTheme.headlineSmall?.fontFamily, 'Inter');
      if (brightness == AppBrightness.amoled) {
        expect(theme.scaffoldBackgroundColor, Colors.black);
        expect(theme.colorScheme.surface, Colors.black);
        expect(theme.colorScheme.surfaceContainerHighest, isNot(Colors.black));
      }

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: ListView(
              children: [
                const Card(child: ListTile(title: Text('Card title'))),
                const Padding(
                  padding: EdgeInsets.all(AppSpace.lg),
                  child: TextField(
                    decoration: InputDecoration(hintText: 'Search'),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(AppSpace.lg),
                  child: Chip(label: Text('Chip')),
                ),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: 0,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Card title'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Chip'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
