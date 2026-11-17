// Platform capability flags for the Stream UI. Widgets read these instead of
// scattering platform checks. Detection uses only Flutter foundation constants.
import 'package:flutter/foundation.dart';

class PlatformCapabilities {
  factory PlatformCapabilities({bool? isWeb, TargetPlatform? platform}) {
    final web = isWeb ?? kIsWeb;
    final plat = platform ?? defaultTargetPlatform;
    return PlatformCapabilities._(isWeb: web, platform: plat);
  }

  const PlatformCapabilities._({
    required bool isWeb,
    required TargetPlatform platform,
  }) : isWeb = isWeb,
       isAndroid = !isWeb && platform == TargetPlatform.android,
       isIOS = !isWeb && platform == TargetPlatform.iOS,
       isDesktopLike =
           !isWeb &&
           (platform == TargetPlatform.linux ||
               platform == TargetPlatform.macOS ||
               platform == TargetPlatform.windows),
       supportsHaptics =
           !isWeb &&
           (platform == TargetPlatform.android ||
               platform == TargetPlatform.iOS),
       supportsKeyboardShortcuts =
           isWeb ||
           (!isWeb &&
               (platform == TargetPlatform.linux ||
                   platform == TargetPlatform.macOS ||
                   platform == TargetPlatform.windows)),
       canOpenSystemSettings =
           !isWeb &&
           (platform == TargetPlatform.android ||
               platform == TargetPlatform.iOS),
       edgeGestureMarginDp = 24,
       usesTouchPrimary =
           !isWeb &&
           (platform == TargetPlatform.android ||
               platform == TargetPlatform.iOS);

  final bool isWeb;
  final bool isAndroid;
  final bool isIOS;
  final bool isDesktopLike;
  final bool supportsHaptics;
  final bool supportsKeyboardShortcuts;
  final bool canOpenSystemSettings;
  final int edgeGestureMarginDp;
  final bool usesTouchPrimary;

  static const PlatformCapabilities defaults = PlatformCapabilities._(
    isWeb: false,
    platform: TargetPlatform.android,
  );
}
