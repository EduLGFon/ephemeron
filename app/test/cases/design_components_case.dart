import 'package:ephemeron/core/design/components/app_buttons.dart';
import 'package:ephemeron/core/design/components/app_chips.dart';
import 'package:ephemeron/core/design/components/app_fields.dart';
import 'package:ephemeron/core/design/components/app_headers.dart';
import 'package:ephemeron/core/design/components/app_overlays.dart';
import 'package:ephemeron/core/design/components/app_page.dart';
import 'package:ephemeron/core/design/components/app_states.dart';
import 'package:ephemeron/core/design/components/app_surface.dart';
import 'package:ephemeron/core/design/components/sync_indicator.dart';
import 'package:ephemeron/core/design/layout.dart';
import 'package:ephemeron/core/design/platform.dart';
import 'package:ephemeron/core/design/theme.dart';
import 'package:ephemeron/core/design/tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

ThemeData _theme() =>
    EphemeronTheme.build(mode: 'light', platformBrightness: Brightness.light);

/// Wraps a screen in the real theme, an AppLayoutScope and optional large text
/// or reduced motion so component behaviour is exercised under app conditions.
Widget _app(
  Widget home, {
  AppLayout layout = AppLayout.compact,
  double textScale = 1,
  bool disableAnimations = false,
  EdgeInsets? padding,
}) {
  return AppLayoutScope(
    layout: layout,
    child: MaterialApp(
      theme: _theme(),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
            padding: padding ?? media.padding,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: home,
    ),
  );
}

Future<void> _narrow(WidgetTester tester) async {
  tester.view.physicalSize = const Size(320, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('platform', () {
    test('flags follow the target platform without dart:io', () {
      final original = debugDefaultTargetPlatformOverride;
      addTearDown(() => debugDefaultTargetPlatformOverride = original);
      for (final platform in <TargetPlatform>[
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        final mobile =
            platform == TargetPlatform.android ||
            platform == TargetPlatform.iOS;
        final desktop =
            platform == TargetPlatform.linux ||
            platform == TargetPlatform.macOS ||
            platform == TargetPlatform.windows;
        expect(AppPlatform.isWeb, kIsWeb, reason: '$platform web');
        expect(
          AppPlatform.isAndroid,
          platform == TargetPlatform.android,
          reason: '$platform android',
        );
        expect(
          AppPlatform.isIOS,
          platform == TargetPlatform.iOS,
          reason: '$platform ios',
        );
        expect(AppPlatform.isDesktopLike, desktop, reason: '$platform desktop');
        expect(
          AppPlatform.supportsHaptics,
          mobile,
          reason: '$platform haptics',
        );
        expect(
          AppPlatform.supportsKeyboardShortcuts,
          desktop,
          reason: '$platform shortcuts',
        );
        expect(
          AppPlatform.supportsLocalNotifications,
          mobile || desktop,
          reason: '$platform notifications',
        );
        expect(
          AppPlatform.canOpenSystemSettings,
          mobile || desktop,
          reason: '$platform settings',
        );
      }
    });
  });

  group('AppPage', () {
    testWidgets('caps and centers content on expanded layouts', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          AppPage(
            header: const AppPageHeader(title: Text('Today')),
            padding: EdgeInsets.zero,
            child: Container(key: const Key('page-child')),
          ),
          layout: AppLayout.expanded,
        ),
      );
      expect(tester.getSize(find.byKey(const Key('page-child'))).width, 1100);
      expect(find.text('Today'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders fab and bottom bar and works without a scope', (
      tester,
    ) async {
      var fabTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: _theme(),
          home: AppPage(
            fab: FloatingActionButton(
              onPressed: () => fabTaps++,
              child: const Icon(Icons.add),
            ),
            bottomBar: const SizedBox(height: 56, child: Text('bottom bar')),
            child: const Text('fallback content'),
          ),
        ),
      );
      expect(find.text('fallback content'), findsOneWidget);
      expect(find.text('bottom bar'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add));
      expect(fabTaps, 1);
      expect(tester.takeException(), isNull);
    });
  });

  group('AppSurface', () {
    testWidgets('is flat, bordered and tappable with a 48dp target', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Center(
              child: AppSurface(
                semanticLabel: 'Open project',
                onTap: () => taps++,
                child: const Text('Project'),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(AppSurface)).height,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester.getSemantics(find.byType(AppSurface)).label,
        contains('Open project'),
      );
      handle.dispose();
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(AppSurface),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.elevation, 0);
      expect(material.color, _theme().colorScheme.surfaceContainerLow);
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side.width, 1);
      await tester.tap(find.byType(AppSurface));
      expect(taps, 1);
    });

    testWidgets('supports a tonal borderless variant', (tester) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: AppSurface(
              tonal: true,
              border: false,
              child: const Text('Tonal'),
            ),
          ),
        ),
      );
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(AppSurface),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, _theme().colorScheme.surfaceContainerHigh);
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side, BorderSide.none);
    });
  });

  group('buttons', () {
    testWidgets('variants, icons and disabled state render', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  AppButton(label: 'Primary', onPressed: () => taps++),
                  AppButton(
                    label: 'Secondary',
                    variant: AppButtonVariant.secondary,
                    onPressed: () {},
                  ),
                  AppButton(
                    label: 'Ghost',
                    variant: AppButtonVariant.ghost,
                    onPressed: () {},
                  ),
                  AppButton(
                    label: 'Danger',
                    variant: AppButtonVariant.danger,
                    onPressed: () {},
                  ),
                  const AppButton(label: 'Disabled', onPressed: null),
                  AppButton(
                    label: 'With icon',
                    icon: Icons.add,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.byType(FilledButton), findsNWidgets(4));
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      final disabled = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Disabled'),
      );
      expect(disabled.onPressed, isNull);
      await tester.tap(find.text('Primary'));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('busy keeps size and blocks activation', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Column(
              children: <Widget>[
                AppButton(
                  key: const Key('idle'),
                  label: 'Submit',
                  onPressed: () => taps++,
                ),
                AppButton(
                  key: const Key('busy'),
                  label: 'Submit',
                  busy: true,
                  onPressed: () => taps++,
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('busy'))),
        tester.getSize(find.byKey(const Key('idle'))),
      );
      await tester.tap(find.byKey(const Key('busy')));
      expect(taps, 0);
      await tester.pump();
    });

    testWidgets('expand fills the available width', (tester) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: AppButton(label: 'Wide', expand: true, onPressed: () {}),
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(AppButton)).width, 200);
    });

    testWidgets('activates from the keyboard and has a focus ring', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Center(
              child: AppButton(label: 'Save', onPressed: () => taps++),
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focused = tester
          .widget<FilledButton>(find.byType(FilledButton))
          .style!
          .side!
          .resolve(<WidgetState>{WidgetState.focused})!;
      expect(focused.width, 1.5);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(taps, 1, reason: 'FilledButton should activate on Enter');
    });

    testWidgets('icon button exposes label, tooltip, badge and selection', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Center(
              child: AppIconButton(
                icon: Icons.notifications_outlined,
                tooltip: 'Notifications',
                semanticLabel: 'Notifications',
                badge: '3',
                selected: true,
                onPressed: () => taps++,
              ),
            ),
          ),
        ),
      );
      expect(find.byTooltip('Notifications'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(AppIconButton)).label,
        contains('Notifications'),
      );
      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.isSelected, isTrue);
      final size = tester.getSize(find.byType(AppIconButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      await tester.tap(find.byType(AppIconButton));
      expect(taps, 1);
      handle.dispose();
    });
  });

  group('fields', () {
    testWidgets('text field forwards editing, focus and disabled state', (
      tester,
    ) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);
      String? changed;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Column(
              children: <Widget>[
                AppTextField(
                  controller: controller,
                  focusNode: focusNode,
                  labelText: 'Title',
                  hintText: 'Untitled',
                  prefixIcon: const Icon(Icons.edit),
                  onChanged: (value) => changed = value,
                ),
                const AppTextField(enabled: false, hintText: 'Disabled'),
              ],
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField).first, 'Hello');
      expect(controller.text, 'Hello');
      expect(changed, 'Hello');
      expect(
        tester.widget<TextField>(find.byType(TextField).last).enabled,
        false,
      );
      expect(find.text('Disabled'), findsOneWidget);
    });

    testWidgets('autofocus moves focus to the field', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        _app(
          Scaffold(body: AppTextField(focusNode: focusNode, autofocus: true)),
        ),
      );
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);
    });

    testWidgets('search field shows and clears its clear button', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var clears = 0;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: AppSearchField(
              controller: controller,
              onClear: () => clears++,
            ),
          ),
        ),
      );
      expect(find.byTooltip('Clear search'), findsNothing);
      await tester.enterText(find.byType(TextField), 'milk');
      await tester.pump();
      expect(find.byTooltip('Clear search'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(clears, 1);
      expect(find.byTooltip('Clear search'), findsNothing);
    });
  });

  group('chips', () {
    testWidgets('shows selection, supports long press and filter toggling', (
      tester,
    ) async {
      var taps = 0;
      var longPresses = 0;
      bool? selectedValue;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Wrap(
              children: <Widget>[
                AppChip(
                  label: 'Tag',
                  tooltip: 'Tag filter',
                  onTap: () => taps++,
                  onLongPress: () => longPresses++,
                ),
                AppChip(label: 'Selected', selected: true, onTap: () {}),
                AppFilterChip(
                  label: 'Work',
                  selected: false,
                  count: 2,
                  color: Colors.blue,
                  onSelected: (value) => selectedValue = value,
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.byTooltip('Tag filter'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(
        tester.getSize(find.widgetWithText(AppChip, 'Tag')).height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.text('Tag'));
      await tester.longPress(find.text('Tag'));
      expect(taps, 1);
      expect(longPresses, 1);
      await tester.tap(find.text('Work (2)'));
      expect(selectedValue, isTrue);
    });
  });

  group('headers', () {
    testWidgets('page and section headers expose all slots', (tester) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Column(
              children: <Widget>[
                AppPageHeader(
                  title: const Text('Today'),
                  subtitle: const Text('3 tasks'),
                  leading: const Icon(Icons.today),
                  actions: <Widget>[
                    AppIconButton(
                      icon: Icons.search,
                      tooltip: 'Search',
                      onPressed: () {},
                    ),
                  ],
                ),
                SectionTitle(
                  title: 'Projects',
                  count: 4,
                  description: 'All open projects',
                  action: AppIconButton(
                    icon: Icons.more_horiz,
                    tooltip: 'More',
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('3 tasks'), findsOneWidget);
      expect(find.text('Projects'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('All open projects'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('default padding clears the status bar inset', (tester) async {
      await tester.pumpWidget(
        _app(
          const Scaffold(body: AppPageHeader(title: Text('Inset'))),
          padding: const EdgeInsets.only(top: 24),
        ),
      );
      expect(tester.getTopLeft(find.text('Inset')).dy, 24 + DsSpace.x12);
      expect(tester.takeException(), isNull);
    });

    testWidgets('explicit padding overrides the status bar inset', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: AppPageHeader(
              padding: const EdgeInsets.fromLTRB(
                DsSpace.x16,
                24 + DsSpace.x12,
                DsSpace.x16,
                DsSpace.x8,
              ),
              title: const Text('Explicit'),
            ),
          ),
          padding: const EdgeInsets.only(top: 24),
        ),
      );
      expect(tester.getTopLeft(find.text('Explicit')).dy, 24 + DsSpace.x12);
      expect(tester.takeException(), isNull);
    });
  });

  group('states', () {
    testWidgets('empty state paints art and runs both actions', (tester) async {
      var primary = 0;
      var secondary = 0;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: AppEmptyState(
              icon: Icons.inbox_outlined,
              title: 'Nothing here',
              message: 'Add your first task.',
              actionLabel: 'Add task',
              onAction: () => primary++,
              secondaryLabel: 'Learn more',
              onSecondary: () => secondary++,
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey<String>('empty-art')), findsOneWidget);
      expect(find.text('Nothing here'), findsOneWidget);
      await tester.tap(find.text('Add task'));
      await tester.tap(find.text('Learn more'));
      expect(primary, 1);
      expect(secondary, 1);
    });

    testWidgets('error state retries', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: AppErrorState(
              title: 'Could not load',
              message: 'Check your connection.',
              onRetry: () => retries++,
            ),
          ),
        ),
      );
      expect(find.text('Could not load'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retries, 1);
    });

    testWidgets('skeleton sizes and list render without endless motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Column(
              children: <Widget>[
                const AppSkeleton(width: 120, height: 20),
                AppSkeletonList(rows: 3, padding: const EdgeInsets.all(8)),
              ],
            ),
          ),
          disableAnimations: true,
        ),
      );
      expect(tester.getSize(find.byType(AppSkeleton)), const Size(120, 20));
      expect(find.byType(AppSkeletonList), findsOneWidget);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });
    testWidgets('skeleton pulse completes and honours reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const Scaffold(body: AppSkeletonList(rows: 2))),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _app(
          const Scaffold(body: AppSkeletonList(rows: 2)),
          disableAnimations: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });
  });

  group('overlays', () {
    testWidgets('sheet header and key hint render', (tester) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Column(
              children: <Widget>[
                AppSheetHeader(
                  title: 'New task',
                  subtitle: 'Fill in the details',
                  leading: const Icon(Icons.edit),
                  actions: <Widget>[
                    AppIconButton(
                      icon: Icons.close,
                      tooltip: 'Close',
                      onPressed: () {},
                    ),
                  ],
                ),
                const KeyHint(label: 'Ctrl+K'),
              ],
            ),
          ),
        ),
      );
      expect(find.text('New task'), findsOneWidget);
      expect(find.text('Fill in the details'), findsOneWidget);
      expect(find.text('Ctrl+K'), findsOneWidget);
    });

    testWidgets('showAppDialog opens and returns a value', (tester) async {
      late Future<String?> pending;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Builder(
              builder: (context) {
                return AppButton(
                  label: 'Open',
                  onPressed: () {
                    pending = showAppDialog<String>(
                      context: context,
                      builder: (dialogContext) {
                        return AlertDialog(
                          title: const Text('Dialog title'),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop('ok'),
                              child: const Text('OK'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Dialog title'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(await pending, 'ok');
    });
  });

  group('sync indicator', () {
    testWidgets('every state has a distinct label and semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      const labels = <AppSyncState, String>{
        AppSyncState.synced: 'Synced',
        AppSyncState.syncing: 'Syncing',
        AppSyncState.offline: 'Offline',
        AppSyncState.attention: 'Needs attention',
      };
      for (final entry in labels.entries) {
        await tester.pumpWidget(
          _app(
            Scaffold(
              body: Center(
                child: AppSyncIndicator(state: entry.key, compact: false),
              ),
            ),
          ),
        );
        expect(find.text(entry.value), findsOneWidget);
        expect(
          tester.getSemantics(find.byType(AppSyncIndicator)).label,
          contains(entry.value),
        );
      }
      handle.dispose();
    });

    testWidgets('syncing arc completes and compact mode stays quiet', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const Scaffold(
            body: Center(child: AppSyncIndicator(state: AppSyncState.syncing)),
          ),
        ),
      );
      expect(find.text('Syncing'), findsNothing);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('tap and tooltip are wired', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Center(
              child: AppSyncIndicator(
                state: AppSyncState.offline,
                tooltip: 'Sync now',
                label: 'Offline',
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      );
      expect(find.byTooltip('Sync now'), findsOneWidget);
      await tester.tap(find.byType(AppSyncIndicator));
      expect(taps, 1);
    });
  });

  testWidgets('320dp at 200% text does not overflow', (tester) async {
    await _narrow(tester);
    final controller = TextEditingController(text: 'a long search query');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        AppPage(
          header: AppPageHeader(
            title: const Text('A long page title that has to wrap'),
            subtitle: const Text('Subtitle with more context'),
            actions: <Widget>[
              AppIconButton(
                icon: Icons.search,
                tooltip: 'Search',
                onPressed: () {},
              ),
              AppIconButton(
                icon: Icons.more_vert,
                tooltip: 'More',
                onPressed: () {},
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AppSurface(
                  onTap: () {},
                  child: const Text(
                    'A surface with enough copy to wrap onto several lines.',
                  ),
                ),
                AppButton(
                  label: 'A very long primary action label',
                  icon: Icons.add,
                  onPressed: () {},
                ),
                AppButton(
                  label: 'Secondary',
                  variant: AppButtonVariant.secondary,
                  onPressed: null,
                ),
                AppTextField(labelText: 'Title', hintText: 'Untitled'),
                AppSearchField(controller: controller),
                Wrap(
                  spacing: DsSpace.x8,
                  runSpacing: DsSpace.x8,
                  children: <Widget>[
                    AppChip(
                      label: 'A very long chip label that should ellipsize',
                      selected: true,
                      onTap: () {},
                    ),
                    AppFilterChip(
                      label: 'A long filter',
                      count: 42,
                      selected: false,
                      onSelected: (_) {},
                    ),
                  ],
                ),
                SectionTitle(
                  title: 'A long section heading that should ellipsize',
                  count: 12,
                  action: AppIconButton(
                    icon: Icons.chevron_right,
                    tooltip: 'Open',
                    onPressed: () {},
                  ),
                  description: 'Section description',
                ),
                AppEmptyState(
                  title: 'A sizable empty title',
                  message: 'A message that explains what to do next.',
                  actionLabel: 'Add something',
                  onAction: () {},
                  secondaryLabel: 'Maybe later',
                  onSecondary: () {},
                ),
                const AppErrorState(
                  title: 'An error title',
                  message: 'A message with details about the failure.',
                ),
                AppSkeletonList(rows: 2),
                AppSheetHeader(
                  title: 'A sheet title with length',
                  subtitle: 'A subtitle that can wrap',
                  actions: <Widget>[
                    AppIconButton(
                      icon: Icons.close,
                      tooltip: 'Close',
                      onPressed: () {},
                    ),
                  ],
                ),
                const KeyHint(label: 'Ctrl+Shift+K'),
                const AppSyncIndicator(
                  state: AppSyncState.attention,
                  compact: false,
                ),
              ],
            ),
          ),
        ),
        textScale: 2,
        disableAnimations: true,
      ),
    );
    expect(tester.getSize(find.byType(AppPage)).width, 320);
    expect(tester.takeException(), isNull);
  });
}
