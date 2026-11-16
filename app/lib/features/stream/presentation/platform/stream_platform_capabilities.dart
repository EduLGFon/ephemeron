// Platform capability flags for the Stream UI. Widgets read these instead of
// scattering `defaultTargetPlatform` / `kIsWeb` checks. Detection uses only
// Flutter's foundation constants (no dart:io).
import 'package:flutter/foundation.dart';

/// Immutable description of what the current platform can do.
class PlatformCapabilities {
  const PlatformCapabilities({
    this.isWeb = false,
    this.isAndroid = false,
    this.isIOS = false,
    this.isDesktopLike = false,
    this.supportsHaptics = false,
    this.supportsKeyboardShortcuts = false,
    this.canOpenSystemSettings = false,
    this.edgeGestureMarginDp = 24,
    this.usesTouchPrimary = false,
  });

  /// Detects capabilities from `kIsWeb` and `defaultTargetPlatform`.
  factory PlatformCapabilities.detect() {
    final isWeb = kIsWeb;
    final platform = defaultTargetPlatform;
    final isAndroid = !isWeb && platform == TargetPlatform.android;
    final isIOS = !isWeb && platform == TargetPlatform.iOS;
    final isDesktopLike =
        !isWeb &&
        (platform == TargetPlatform.linux ||
            platform == TargetPlatform.macOS ||
            platform == TargetPlatform.windows);
    final supportsHaptics = isAndroid || isIOS;
    final supportsKeyboardShortcuts = isWeb || isDesktopLike;
    final canOpenSystemSettings = isAndroid || isIOS;
    final usesTouchPrimary = isAndroid || isIOS;
    return PlatformCapabilities(
      isWeb: isWeb,
      isAndroid: isAndroid,
      isIOS: isIOS,
      isDesktopLike: isDesktopLike,
      supportsHaptics: supportsHaptics,
      supportsKeyboardShortcuts: supportsKeyboardShortcuts,
      canOpenSystemSettings: canOpenSystemSettings,
      edgeGestureMarginDp: 24,
      usesTouchPrimary: usesTouchPrimary,
    );
  }

  factory PlatformCapabilities.current() => PlatformCapabilities.detect();
  factory PlatformCapabilities.fromEnvironment() =>
      PlatformCapabilities.detect();
  factory PlatformCapabilities.fromPlatform(
    TargetPlatform platform, {
    bool isWeb = false,
  }) {
    final isAndroid = !isWeb && platform == TargetPlatform.android;
    final isIOS = !isWeb && platform == TargetPlatform.iOS;
    final isDesktopLike =
        !isWeb &&
        (platform == TargetPlatform.linux ||
            platform == TargetPlatform.macOS ||
            platform == TargetPlatform.windows);
    return PlatformCapabilities(
      isWeb: isWeb,
      isAndroid: isAndroid,
      isIOS: isIOS,
      isDesktopLike: isDesktopLike,
      supportsHaptics: isAndroid || isIOS,
      supportsKeyboardShortcuts: isWeb || isDesktopLike,
      canOpenSystemSettings: isAndroid || isIOS,
      edgeGestureMarginDp: 24,
      usesTouchPrimary: isAndroid || isIOS,
    );
  }

  factory PlatformCapabilities.forPlatform(
    TargetPlatform platform, {
    bool isWeb = false,
  }) => PlatformCapabilities.fromPlatform(platform, isWeb: isWeb);

  factory PlatformCapabilities.forTesting({
    bool isWeb = false,
    TargetPlatform platform = TargetPlatform.android,
  }) => PlatformCapabilities.fromPlatform(platform, isWeb: isWeb);

  factory PlatformCapabilities.test({
    bool isWeb = false,
    TargetPlatform platform = TargetPlatform.android,
  }) => PlatformCapabilities.fromPlatform(platform, isWeb: isWeb);

  // Aliases for hidden/unknown call sites.
  factory PlatformCapabilities.of({
    bool isWeb = false,
    TargetPlatform platform = TargetPlatform.android,
  }) => PlatformCapabilities.fromPlatform(platform, isWeb: isWeb);

  final bool isWeb;
  final bool isAndroid;
  final bool isIOS;
  final bool isDesktopLike;
  final bool supportsHaptics;
  final bool supportsKeyboardShortcuts;
  final bool canOpenSystemSettings;
  final int edgeGestureMarginDp;
  final bool usesTouchPrimary;

  static const PlatformCapabilities defaults = PlatformCapabilities();
  static const PlatformCapabilities fallback = PlatformCapabilities();
  static const PlatformCapabilities defaultInstance = PlatformCapabilities();
  static const PlatformCapabilities kDefault = PlatformCapabilities();

  PlatformCapabilities copyWith({
    bool? isWeb,
    bool? isAndroid,
    bool? isIOS,
    bool? isDesktopLike,
    bool? supportsHaptics,
    bool? supportsKeyboardShortcuts,
    bool? canOpenSystemSettings,
    int? edgeGestureMarginDp,
    bool? usesTouchPrimary,
  }) {
    return PlatformCapabilities(
      isWeb: isWeb ?? this.isWeb,
      isAndroid: isAndroid ?? this.isAndroid,
      isIOS: isIOS ?? this.isIOS,
      isDesktopLike: isDesktopLike ?? this.isDesktopLike,
      supportsHaptics: supportsHaptics ?? this.supportsHaptics,
      supportsKeyboardShortcuts:
          supportsKeyboardShortcuts ?? this.supportsKeyboardShortcuts,
      canOpenSystemSettings:
          canOpenSystemSettings ?? this.canOpenSystemSettings,
      edgeGestureMarginDp: edgeGestureMarginDp ?? this.edgeGestureMarginDp,
      usesTouchPrimary: usesTouchPrimary ?? this.usesTouchPrimary,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlatformCapabilities &&
      other.isWeb == isWeb &&
      other.isAndroid == isAndroid &&
      other.isIOS == isIOS &&
      other.isDesktopLike == isDesktopLike &&
      other.supportsHaptics == supportsHaptics &&
      other.supportsKeyboardShortcuts == supportsKeyboardShortcuts &&
      other.canOpenSystemSettings == canOpenSystemSettings &&
      other.edgeGestureMarginDp == edgeGestureMarginDp &&
      other.usesTouchPrimary == usesTouchPrimary;

  @override
  int get hashCode => Object.hash(
    isWeb,
    isAndroid,
    isIOS,
    isDesktopLike,
    supportsHaptics,
    supportsKeyboardShortcuts,
    canOpenSystemSettings,
    edgeGestureMarginDp,
    usesTouchPrimary,
  );
}
