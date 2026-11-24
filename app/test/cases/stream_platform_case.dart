import 'package:ephemeron/core/ui/app_feedback.dart';
import 'package:ephemeron/features/stream/presentation/platform/stream_feedback.dart';
import 'package:ephemeron/features/stream/presentation/platform/stream_platform_capabilities.dart';
import 'package:ephemeron/features/stream/presentation/platform/stream_undo.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    AppFeedback.hapticsEnabled = true;
  });

  group('PlatformCapabilities', () {
    test('android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final c = PlatformCapabilities();
      expect(c.isWeb, false);
      expect(c.isAndroid, true);
      expect(c.isIOS, false);
      expect(c.isDesktopLike, false);
      expect(c.supportsHaptics, true);
      expect(c.supportsKeyboardShortcuts, false);
      expect(c.canOpenSystemSettings, true);
      expect(c.usesTouchPrimary, true);
      expect(c.edgeGestureMarginDp, 24);
    });
    test('iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final c = PlatformCapabilities();
      expect(c.isIOS, true);
      expect(c.supportsHaptics, true);
      expect(c.supportsKeyboardShortcuts, false);
      expect(c.canOpenSystemSettings, true);
      expect(c.usesTouchPrimary, true);
    });
    test('linux', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final c = PlatformCapabilities();
      expect(c.isDesktopLike, true);
      expect(c.supportsHaptics, false);
      expect(c.supportsKeyboardShortcuts, true);
      expect(c.canOpenSystemSettings, false);
      expect(c.usesTouchPrimary, false);
    });
    test('macOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final c = PlatformCapabilities();
      expect(c.isDesktopLike, true);
      expect(c.supportsKeyboardShortcuts, true);
      expect(c.supportsHaptics, false);
    });
    test('windows', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final c = PlatformCapabilities();
      expect(c.isDesktopLike, true);
      expect(c.supportsKeyboardShortcuts, true);
      expect(c.supportsHaptics, false);
    });
    test('web branch', () {
      final c = PlatformCapabilities(
        isWeb: true,
        platform: TargetPlatform.linux,
      );
      expect(c.isWeb, true);
      expect(c.isAndroid, false);
      expect(c.isDesktopLike, false);
      expect(c.supportsKeyboardShortcuts, true);
      expect(c.supportsHaptics, false);
      expect(c.canOpenSystemSettings, false);
    });
    test('edge margin constant', () {
      expect(PlatformCapabilities.defaults.edgeGestureMarginDp, 24);
    });
  });

  group('StreamFeedback', () {
    late List<MethodCall> hapticCalls;
    setUp(() {
      hapticCalls = <MethodCall>[];
      TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              hapticCalls.add(call);
            }
            return null;
          });
    });
    tearDown(() {
      TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('does not invoke platform haptics when disabled', () async {
      AppFeedback.hapticsEnabled = false;
      StreamFeedback.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(hapticCalls, isEmpty);
    });

    test('invokes platform haptics when enabled', () async {
      AppFeedback.hapticsEnabled = true;
      StreamFeedback.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(hapticCalls, isNotEmpty);
    });
  });

  group('stream undo', () {
    testWidgets('no-ops without a messenger', (tester) async {
      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));
      expect(() => showStreamUndo(context, 'msg', () {}), returnsNormally);
    });

    testWidgets('shows snackbar with Undo action', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => showStreamUndo(context, 'done', () {}),
                  child: const Text('go'),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      expect(find.text('Undo'), findsOneWidget);
    });
  });
}
