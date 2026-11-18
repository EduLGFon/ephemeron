// Platform capabilities without dart:io. Widgets and shell code use these
// flags to guard mobile-only affordances and desktop/web shortcuts instead of
// branching on runtime IO.
import 'package:flutter/foundation.dart';

abstract final class AppPlatform {
  static bool get isWeb => kIsWeb;

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get isDesktopLike =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  static bool get supportsHaptics => isAndroid || isIOS;

  static bool get supportsKeyboardShortcuts => isWeb || isDesktopLike;

  static bool get supportsLocalNotifications =>
      isAndroid || isIOS || isDesktopLike;

  static bool get canOpenSystemSettings => isAndroid || isIOS || isDesktopLike;
}
