import 'package:ephemeron/features/stream/presentation/states/stream_art.dart';
import 'package:ephemeron/features/stream/presentation/states/stream_empty_state.dart';
import 'package:ephemeron/features/stream/presentation/states/stream_error_state.dart';
import 'package:ephemeron/features/stream/presentation/states/stream_offline_banner.dart';
import 'package:ephemeron/features/stream/presentation/states/stream_skeleton.dart';
import 'package:ephemeron/features/stream/presentation/states/stream_status_view.dart';
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
    final fade = tester.widget<FadeTransition>(
      find.descendant(
        of: find.byType(StreamSkeleton),
        matching: find.byType(FadeTransition),
      ),
    );
    final first = fade.opacity.value;
    await tester.pump(const Duration(milliseconds: 100));
    final second = tester
        .widget<FadeTransition>(
          find.descendant(
            of: find.byType(StreamSkeleton),
            matching: find.byType(FadeTransition),
          ),
        )
        .opacity
        .value;
    expect(second, isNot(equals(first)));

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: Scaffold(body: StreamSkeleton())),
      ),
    );
    await tester.pump();
    final r1 = tester
        .widget<FadeTransition>(
          find.descendant(
            of: find.byType(StreamSkeleton),
            matching: find.byType(FadeTransition),
          ),
        )
        .opacity
        .value;
    await tester.pump(const Duration(milliseconds: 100));
    final r2 = tester
        .widget<FadeTransition>(
          find.descendant(
            of: find.byType(StreamSkeleton),
            matching: find.byType(FadeTransition),
          ),
        )
        .opacity
        .value;
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

  testWidgets('no overflow at 320dp 2.0 scale', (tester) async {
    final states = <Widget>[
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
    for (final w in states) {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2.0),
          ),
          child: MaterialApp(home: Scaffold(body: w)),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
}
