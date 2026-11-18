// Dynamic system accent colour.
//
// Android 12+ exposes the user's wallpaper palette through the platform
// resource `system_accent1_500`. Only Android implements the channel method;
// every other target resolves to null so the theme keeps the brand seed. The
// lookup never throws: an unavailable accent is a normal, unsupported state.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const MethodChannel _systemChannel = MethodChannel('ephemeron/system');

/// ARGB accent from the operating system, or null when unsupported.
final systemAccentProvider = FutureProvider<Color?>((ref) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  try {
    final argb = await _systemChannel.invokeMethod<int>('getSystemAccent');
    if (argb == null) return null;
    return Color(argb & 0xFFFFFFFF);
  } catch (_) {
    // Missing plugin, older Android, or a platform exception all mean the
    // brand accent remains in use.
    return null;
  }
});
