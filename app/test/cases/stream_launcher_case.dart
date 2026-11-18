import 'package:ephemeron/features/stream/presentation/surface/stream_launcher.dart';
import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _launcherApp({
  required ValueChanged<StreamLauncherDestination> onSelected,
  VoidCallback? onClose,
  Widget Function(Widget child)? wrap,
}) {
  final content = Scaffold(
    body: StreamLauncher(onSelected: onSelected, onClose: onClose ?? () {}),
  );
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: wrap == null ? content : wrap(content),
  );
}

void main() {
  testWidgets('lists every destination with its localized label', (
    tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    final labels = <StreamLauncherDestination, String>{
      StreamLauncherDestination.calendar: l.streamLauncherCalendar,
      StreamLauncherDestination.tasks: l.searchTasks,
      StreamLauncherDestination.matrix: l.streamLauncherMatrix,
      StreamLauncherDestination.habits: l.searchHabits,
      StreamLauncherDestination.countdowns: l.searchCountdowns,
      StreamLauncherDestination.focus: l.streamLauncherFocus,
      StreamLauncherDestination.notes: l.searchNotes,
      StreamLauncherDestination.search: l.searchTitle,
      StreamLauncherDestination.settings: l.streamSettings,
    };

    await tester.pumpWidget(_launcherApp(onSelected: (_) {}));

    expect(find.text(l.streamLauncherTitle), findsOneWidget);
    expect(labels, hasLength(StreamLauncherDestination.values.length));
    for (final entry in labels.entries) {
      final key = Key('streamLauncherDestination-${entry.key.name}');
      expect(find.byKey(key), findsOneWidget);
      expect(find.text(entry.value), findsOneWidget);
      expect(find.bySemanticsLabel(entry.value), findsOneWidget);
    }
  });

  testWidgets('tapping a destination reports it once', (tester) async {
    StreamLauncherDestination? selected;
    await tester.pumpWidget(
      _launcherApp(onSelected: (destination) => selected = destination),
    );

    await tester.tap(find.byKey(const Key('streamLauncherDestination-tasks')));
    await tester.pump();

    expect(selected, StreamLauncherDestination.tasks);
  });

  testWidgets('close button reports close', (tester) async {
    var closed = 0;
    await tester.pumpWidget(
      _launcherApp(onSelected: (_) {}, onClose: () => closed++),
    );

    await tester.tap(find.byKey(const Key('streamLauncherClose')));
    await tester.pump();

    expect(closed, 1);
  });

  testWidgets('320 dp at 2.0 text scale does not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _launcherApp(
        onSelected: (_) {},
        wrap: (child) => MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: child,
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('rows are at least 48 dp tall', (tester) async {
    await tester.pumpWidget(_launcherApp(onSelected: (_) {}));

    for (final destination in StreamLauncherDestination.values) {
      final size = tester.getSize(
        find.byKey(Key('streamLauncherDestination-${destination.name}')),
      );
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });
}
