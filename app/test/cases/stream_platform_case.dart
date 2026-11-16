import 'package:ephemeron/core/ui/app_feedback.dart';
import 'package:ephemeron/features/stream/presentation/platform/stream_feedback.dart';
import 'package:ephemeron/features/stream/presentation/platform/stream_platform_capabilities.dart';
import 'package:ephemeron/features/stream/presentation/platform/stream_undo.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    AppFeedback.hapticsEnabled = true;
  });

  group('PlatformCapabilities', () {
    test('android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final c = PlatformCapabilities.detect();
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
      final c = PlatformCapabilities.detect();
      expect(c.isIOS, true);
      expect(c.supportsHaptics, true);
      expect(c.supportsKeyboardShortcuts, false);
      expect(c.canOpenSystemSettings, true);
      expect(c.usesTouchPrimary, true);
    });
    test('linux', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final c = PlatformCapabilities.detect();
      expect(c.isDesktopLike, true);
      expect(c.supportsHaptics, false);
      expect(c.supportsKeyboardShortcuts, true);
      expect(c.canOpenSystemSettings, false);
      expect(c.usesTouchPrimary, false);
    });
    test('macOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final c = PlatformCapabilities.detect();
      expect(c.isDesktopLike, true);
      expect(c.supportsKeyboardShortcuts, true);
      expect(c.supportsHaptics, false);
    });
    test('windows', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final c = PlatformCapabilities.detect();
      expect(c.isDesktopLike, true);
      expect(c.supportsKeyboardShortcuts, true);
      expect(c.supportsHaptics, false);
    });
    test('web branch via test constructor', () {
      final c = PlatformCapabilities.forTesting(
        isWeb: true,
        platform: TargetPlatform.linux,
      );
      expect(c.isWeb, true);
      expect(
        c.isDesktopLike,
        false,
      ); // web is its own branch for keyboard shortcuts
      expect(c.supportsKeyboardShortcuts, true);
      expect(c.supportsHaptics, false);
      // isWeb true but platform linux should not mark desktopLike? spec: isDesktopLike Linux/macOS/Windows (native). Keep false on web.
    });
    test('web keyboard shortcuts true, haptics false', () {
      final c = PlatformCapabilities.fromPlatform(
        TargetPlatform.android,
        isWeb: true,
      );
      expect(c.isWeb, true);
      expect(c.isAndroid, false);
      expect(c.supportsKeyboardShortcuts, true);
      expect(c.supportsHaptics, false);
      expect(c.canOpenSystemSettings, false);
    });
    test('edge margin constant', () {
      expect(PlatformCapabilities.defaults.edgeGestureMarginDp, 24);
    });
  });

  group('StreamFeedback', () {
    test('does not throw when haptics disabled', () {
      AppFeedback.hapticsEnabled = false;
      expect(() {
        StreamFeedback.complete();
        StreamFeedback.push();
        StreamFeedback.levelChange();
        StreamFeedback.streak();
        StreamFeedback.timerEnd();
        StreamFeedback.undoAvailable();
        StreamFeedback.haptic(StreamHaptic.tap);
        StreamFeedback.haptic(StreamHaptic.selection);
        StreamFeedback.haptic(StreamHaptic.success);
        StreamFeedback.haptic(StreamHaptic.warning);
      }, returnsNormally);
    });
    test('does not throw when haptics enabled', () {
      AppFeedback.hapticsEnabled = true;
      expect(() {
        StreamFeedback.complete();
        StreamFeedback.push();
        StreamFeedback.levelChange();
        StreamFeedback.streak();
        StreamFeedback.timerEnd();
        StreamFeedback.undoAvailable();
      }, returnsNormally);
    });
  });

  group('stream undo', () {
    test('no-ops without messenger', () {
      expect(
        () => showStreamUndo(_FakeContext(), 'msg', () {}),
        returnsNormally,
      );
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

class _FakeContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
