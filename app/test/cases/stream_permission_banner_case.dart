import 'dart:async';

import 'package:ephemeron/features/stream/application/stream_tray.dart';
import 'package:ephemeron/features/stream/capture/capture_parser.dart';
import 'package:ephemeron/features/stream/presentation/surface/stream_capture_dock.dart';
import 'package:ephemeron/features/stream/presentation/surface/stream_permission_banner_host.dart';
import 'package:ephemeron/features/stream/presentation/tray/tray_item.dart';
import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _bannerKey = Key('streamPermissionBanner');
const _notificationsMissing = StreamPermissionStatus(
  notificationsGranted: false,
  exactAlarmGranted: true,
);
const _exactMissing = StreamPermissionStatus(
  notificationsGranted: true,
  exactAlarmGranted: false,
);
const _granted = StreamPermissionStatus.granted();

Widget _home({
  StreamPermissionStatus? status,
  Future<void> Function(StreamPermissionStatus status)? onOpenSettings,
  double width = 400,
  double textScale = 1.0,
}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: width,
          child: StreamPermissionBannerHost(
            statusOverride: status,
            openSettingsOverride: onOpenSettings,
          ),
        ),
      ),
    ),
  );
}

Widget _app({
  StreamPermissionStatus? status,
  Future<void> Function(StreamPermissionStatus status)? onOpenSettings,
  double width = 400,
  double textScale = 1.0,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: _home(
      status: status,
      onOpenSettings: onOpenSettings,
      width: width,
      textScale: textScale,
    ),
  );
}

AppLocalizations _labels(WidgetTester tester) => AppLocalizations.of(
  tester.element(find.byType(StreamPermissionBannerHost)),
);

void main() {
  testWidgets('missing notifications shows the banner', (tester) async {
    await tester.pumpWidget(_app(status: _notificationsMissing));
    await tester.pump();

    expect(find.byKey(_bannerKey), findsOneWidget);
    final l = _labels(tester);
    expect(find.text(l.onboardingP2Body), findsOneWidget);
    expect(find.text(l.streamSettings), findsOneWidget);
  });

  testWidgets('missing exact alarm shows the banner', (tester) async {
    await tester.pumpWidget(_app(status: _exactMissing));
    await tester.pump();

    expect(find.byKey(_bannerKey), findsOneWidget);
  });

  testWidgets('both permissions granted renders nothing', (tester) async {
    await tester.pumpWidget(_app(status: _granted));
    await tester.pump();

    expect(find.byKey(_bannerKey), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('tapping settings passes the missing state to the opener', (
    tester,
  ) async {
    StreamPermissionStatus? opened;
    await tester.pumpWidget(
      _app(
        status: _exactMissing,
        onOpenSettings: (status) async => opened = status,
      ),
    );
    await tester.pump();

    await tester.tap(find.text(_labels(tester).streamSettings));
    await tester.pump();

    expect(opened, same(_exactMissing));
  });

  testWidgets('notification tap opens the app settings page', (tester) async {
    final calls = <String>[];
    const channel = MethodChannel('ephemeron/system');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return true;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await tester.pumpWidget(_app(status: _notificationsMissing));
    await tester.pump();
    await tester.tap(find.text(_labels(tester).streamSettings));
    await tester.pump();

    expect(calls, contains('openAppSettings'));
  });

  testWidgets('exact alarm tap opens the exact-alarm settings page', (
    tester,
  ) async {
    final calls = <String>[];
    const channel = MethodChannel('ephemeron/alarms');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return true;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await tester.pumpWidget(_app(status: _exactMissing));
    await tester.pump();
    await tester.tap(find.text(_labels(tester).streamSettings));
    await tester.pump();

    expect(calls, contains('openExactAlarmSettings'));
  });

  testWidgets('dismiss is session-only and never persisted', (tester) async {
    await tester.pumpWidget(_app(status: _notificationsMissing));
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(StreamPermissionBannerHost)),
    );

    await tester.tap(find.byTooltip(_labels(tester).streamCaptureClose));
    await tester.pump();

    expect(find.byKey(_bannerKey), findsNothing);
    expect(container.read(streamPermissionBannerDismissedProvider), isTrue);

    // A rebuild in the same session must not bring the banner back.
    await tester.pumpWidget(_app(status: _notificationsMissing));
    await tester.pump();
    expect(find.byKey(_bannerKey), findsNothing);
  });

  testWidgets('320 dp at 2.0 text scale does not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(status: _notificationsMissing, width: 320, textScale: 2.0),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final size = tester.getSize(find.byKey(_bannerKey));
    expect(size.width, lessThanOrEqualTo(320.5));
    expect(size.height, greaterThan(0));
  });

  testWidgets('dock mounts the banner host above the capture dock', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          streamTrayItemsProvider.overrideWith(
            (ref) => Stream<List<TrayItem>>.value(const <TrayItem>[]),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StreamDockHost(
              now: DateTime(2026, 11, 17, 9),
              locale: CaptureLocale.en,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(StreamPermissionBannerHost), findsOneWidget);
    expect(find.byType(StreamCaptureDock), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(StreamPermissionBannerHost),
        matching: find.byType(StreamCaptureDock),
      ),
      findsNothing,
    );
  });
}
