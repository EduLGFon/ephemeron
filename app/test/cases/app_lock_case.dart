import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

import 'package:ephemeron/core/security/app_lock.dart';
import 'package:ephemeron/core/security/app_lock_screen.dart';
import 'package:ephemeron/core/theme/app_theme.dart';
import 'package:ephemeron/core/theme/theme_tokens.dart';

ThemeData _theme(AppBrightness brightness) => buildTheme(
  primary: primaryPresets.first,
  background: backgroundPresets.first,
  brightness: brightness,
);

void main() {
  test('describeError maps lockout to PIN fallback message', () {
    expect(
      AppLock.describeError(
        const LocalAuthException(code: LocalAuthExceptionCode.biometricLockout),
      ),
      contains('PIN'),
    );
    expect(
      AppLock.describeError(
        const LocalAuthException(code: LocalAuthExceptionCode.temporaryLockout),
      ),
      contains('PIN'),
    );
  });

  test('describeError maps missing enrollment to setup message', () {
    expect(
      AppLock.describeError(
        const LocalAuthException(
          code: LocalAuthExceptionCode.noBiometricsEnrolled,
        ),
      ),
      contains('No screen lock'),
    );
    expect(
      AppLock.describeError(
        const LocalAuthException(code: LocalAuthExceptionCode.noCredentialsSet),
      ),
      contains('No screen lock'),
    );
  });

  test('describeError maps unavailable UI instead of empty failure', () {
    expect(
      AppLock.describeError(
        const LocalAuthException(code: LocalAuthExceptionCode.uiUnavailable),
      ),
      isNot('Unlock failed. Try again.'),
    );
  });

  for (final brightness in [AppBrightness.light, AppBrightness.dark]) {
    testWidgets('lock screen builds with the ${brightness.name} app theme', (
      tester,
    ) async {
      final theme = _theme(brightness);
      await tester.pumpWidget(
        BiometricLockScreen(
          theme: theme,
          busy: false,
          error: null,
          onUnlock: () {},
        ),
      );

      expect(find.text('Ephemeron is locked'), findsOneWidget);
      expect(find.text('Unlock'), findsOneWidget);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.theme, same(theme));
      expect(app.theme?.brightness, theme.brightness);
      expect(tester.takeException(), isNull);
    });
  }
}
