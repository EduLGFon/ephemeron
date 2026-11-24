import 'package:ephemeron/features/stream/presentation/states/stream_art.dart';
import 'package:ephemeron/features/stream/presentation/states/stream_empty_state.dart';
import 'package:ephemeron/features/stream/presentation/states/stream_error_state.dart';
import 'package:ephemeron/features/stream/presentation/states/stream_offline_banner.dart';
import 'package:ephemeron/features/stream/presentation/states/stream_skeleton.dart';
import 'package:ephemeron/features/stream/presentation/states/stream_status_view.dart';
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('empty state renders labels and one primary action', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreamEmptyState(
            title: 'Empty title',
            body: 'Empty body',
            actionLabel: 'Do thing',
            onAction: () => taps++,
          ),
        ),
      ),
    );
    expect(find.text('Empty title'), findsOneWidget);
    expect(find.text('Empty body'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('empty state omits action when label missing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StreamEmptyState(title: 'Empty title')),
      ),
    );
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('empty state renders secondary action', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreamEmptyState(
            title: 'Empty title',
            actionLabel: 'Primary',
            onAction: () {},
            secondaryActionLabel: 'Secondary',
            onSecondaryAction: () => taps++,
          ),
        ),
      ),
    );
    expect(find.text('Secondary'), findsOneWidget);
    await tester.tap(find.text('Secondary'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('empty state title appears once in semantics', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreamEmptyState(
            title: 'Empty title',
            actionLabel: 'Do thing',
            onAction: () {},
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Empty title'), findsOneWidget);
    final node = tester.getSemantics(find.byType(FilledButton));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
  });

  testWidgets('error state renders labels and retry action', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreamErrorState(
            title: 'Error title',
            body: 'Error body',
            retryLabel: 'Retry now',
            onRetry: () => taps++,
          ),
        ),
      ),
    );
    expect(find.text('Error title'), findsOneWidget);
    expect(find.text('Error body'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('error state omits retry when missing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StreamErrorState(title: 'Error title')),
      ),
    );
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('error state renders secondary action', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreamErrorState(
            title: 'Error title',
            retryLabel: 'Retry',
            onRetry: () {},
            secondaryActionLabel: 'Settings',
            onSecondaryAction: () => taps++,
          ),
        ),
      ),
    );
    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('offline banner renders message and retry', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreamOfflineBanner(
            message: 'Offline msg',
            retryLabel: 'Retry',
            onRetry: () => taps++,
          ),
        ),
      ),
    );
    expect(find.text('Offline msg'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('skeleton animates and is static under reduce motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: StreamSkeleton())),
    );
    await tester.pump();
    final fadeFinder = find.descendant(
      of: find.byType(StreamSkeleton),
      matching: find.byType(FadeTransition),
    );
    final first = tester.widget<FadeTransition>(fadeFinder).opacity.value;
    await tester.pump(const Duration(milliseconds: 100));
    final second = tester.widget<FadeTransition>(fadeFinder).opacity.value;
    expect(second, isNot(equals(first)));

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: Scaffold(body: StreamSkeleton())),
      ),
    );
    await tester.pump();
    final r1 = tester.widget<FadeTransition>(fadeFinder).opacity.value;
    await tester.pump(const Duration(milliseconds: 100));
    final r2 = tester.widget<FadeTransition>(fadeFinder).opacity.value;
    expect(r2, equals(r1));
  });

  testWidgets('art painter paints at several sizes', (tester) async {
    for (final s in [24.0, 64.0, 120.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: s,
              height: s,
              child: CustomPaint(
                painter: StreamEmptyArtPainter(color: Colors.blue),
                size: Size(s, s),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('status selector maps each value', (tester) async {
    for (final status in StreamStatus.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamStatusView(
              status: status,
              emptyTitle: 'ET',
              emptyActionLabel: 'EA',
              onEmptyAction: () {},
              errorTitle: 'RT',
              retryLabel: 'RL',
              onRetry: () {},
              offlineMessage: 'OM',
            ),
          ),
        ),
      );
      await tester.pump();
      if (status == StreamStatus.ready) {
        expect(find.byType(StreamSkeleton), findsNothing);
        expect(find.text('ET'), findsNothing);
      } else if (status == StreamStatus.empty) {
        expect(find.text('ET'), findsOneWidget);
      } else if (status == StreamStatus.loadingRemote) {
        expect(find.byType(StreamSkeleton), findsOneWidget);
      } else if (status == StreamStatus.error) {
        expect(find.text('RT'), findsOneWidget);
      } else if (status == StreamStatus.offline) {
        expect(find.text('OM'), findsOneWidget);
      }
    }
  });

  testWidgets('states layout at 320dp and 2.0 scale', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final cases = <Widget>[
      StreamEmptyState(
        title: 'Empty title long text that wraps around',
        body: 'Body text that may wrap at small widths',
        actionLabel: 'Primary action',
        onAction: () {},
      ),
      StreamErrorState(
        title: 'Error title long text',
        body: 'Error body long text',
        retryLabel: 'Retry',
        onRetry: () {},
      ),
      StreamOfflineBanner(
        message: 'Offline message long text',
        retryLabel: 'Retry',
        onRetry: () {},
      ),
      const StreamSkeleton(),
    ];

    for (final w in cases) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final mq = MediaQuery.of(context);
                return MediaQuery(
                  data: mq.copyWith(textScaler: const TextScaler.linear(2.0)),
                  child: SizedBox(width: 320, child: w),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final finder = w is StreamEmptyState
          ? find.byType(StreamEmptyState)
          : w is StreamErrorState
          ? find.byType(StreamErrorState)
          : w is StreamOfflineBanner
          ? find.byType(StreamOfflineBanner)
          : find.byType(StreamSkeleton);
      expect(tester.getSize(finder).width, lessThanOrEqualTo(320.5));
    }
  });
}
