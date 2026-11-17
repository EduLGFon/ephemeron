import 'package:ephemeron/features/stream/application/stream_sync_status.dart';
import 'package:ephemeron/features/stream/presentation/states/stream_offline_banner.dart';
import 'package:ephemeron/features/stream/presentation/stream_header.dart'
    show StreamSyncStatus;
import 'package:ephemeron/features/stream/presentation/surface/stream_offline_banner_host.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _message = 'Offline: changes will sync when back online';
const _retry = 'Retry';

Widget _app({
  StreamSyncStatus? statusOverride,
  List<Override> overrides = const [],
  VoidCallback? onRetry,
  double width = 400,
  double textScale = 1.0,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: StreamOfflineBannerHost(
              message: _message,
              retryLabel: _retry,
              onRetry: onRetry ?? () {},
              statusOverride: statusOverride,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('offline status shows the message and retry', (tester) async {
    await tester.pumpWidget(
      _app(
        overrides: [
          streamSyncStatusProvider.overrideWithValue(StreamSyncStatus.offline),
        ],
      ),
    );
    await tester.pump();

    expect(find.text(_message), findsOneWidget);
    expect(find.text(_retry), findsOneWidget);
  });

  testWidgets('synced, syncing and attention hide the banner', (tester) async {
    for (final status in [
      StreamSyncStatus.synced,
      StreamSyncStatus.syncing,
      StreamSyncStatus.attention,
    ]) {
      await tester.pumpWidget(
        _app(overrides: [streamSyncStatusProvider.overrideWithValue(status)]),
      );
      await tester.pump();

      expect(find.text(_message), findsNothing);
      expect(find.text(_retry), findsNothing);
      expect(find.byType(StreamOfflineBanner), findsNothing);
    }
  });

  testWidgets('tapping retry calls onRetry once', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(statusOverride: StreamSyncStatus.offline, onRetry: () => taps++),
    );
    await tester.pump();

    await tester.tap(find.text(_retry));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('status override renders without reading the provider', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        statusOverride: StreamSyncStatus.offline,
        overrides: [
          streamSyncStatusProvider.overrideWith(
            (ref) => throw StateError('status provider must not be read'),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text(_message), findsOneWidget);
  });

  testWidgets('320 dp at 2.0 text scale does not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        statusOverride: StreamSyncStatus.offline,
        width: 320,
        textScale: 2.0,
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(StreamOfflineBannerHost)).width,
      lessThanOrEqualTo(320.5),
    );
  });

  testWidgets('retry action is a 48 dp button with a tap action', (
    tester,
  ) async {
    await tester.pumpWidget(_app(statusOverride: StreamSyncStatus.offline));
    await tester.pump();

    expect(tester.getSize(find.byType(TextButton)).height, 48);
    final node = tester
        .getSemantics(find.byType(TextButton))
        .getSemanticsData();
    expect(node.label, _retry);
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.hasAction(SemanticsAction.tap), isTrue);
  });
}
