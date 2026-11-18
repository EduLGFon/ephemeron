import 'dart:async';

import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:material_ui/material_ui.dart';

import 'app/router/app_router.dart';
import 'core/design/theme.dart';
import 'core/platform/system_accent.dart';
import 'core/platform/system_launcher.dart';
import 'core/security/app_lock.dart';
import 'core/security/app_lock_screen.dart';
import 'core/theme/theme_tokens.dart';
import 'core/ui/app_feedback.dart';
import 'core/ui/app_messenger.dart';
import 'data/services/home_widget_callback.dart';
import 'data/services/home_widget_refresh_service.dart';
import 'features/alarms/application/alarm_providers.dart';
import 'features/settings/application/settings_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Do not block the first frame on a platform-channel round trip.
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  final container = ProviderContainer();
  await _primeColdRingRequest(container);
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const EphemeronApp(),
    ),
  );
  try {
    await HomeWidget.registerInteractivityCallback(
      homeWidgetBackgroundCallback,
    );
  } catch (_) {}
  // Best-effort: keep home-screen widgets from being blank. Deferred so it
  // does not compete with the first frames of the app.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Future<void>.delayed(const Duration(seconds: 2), () {
      container.read(homeWidgetRefreshServiceProvider).refreshDefaults();
    });
  });
}

/// Cold-start full-screen intent: consume the pending native ring request
/// before the router is created, but only trust a row that is actually
/// firing. Best effort and short; a missed request still arrives through the
/// warm system-channel path. The DB is opened only when a request exists.
Future<void> _primeColdRingRequest(ProviderContainer container) async {
  try {
    final code = await SystemLauncher.consumeRingRequest().timeout(
      const Duration(milliseconds: 750),
    );
    if (code == null) return;
    final row = await container
        .read(alarmRepositoryProvider)
        .byRequestCode(code)
        .timeout(const Duration(milliseconds: 1500));
    if (canOpenRingScreen(row?.state)) {
      container.read(activeRingRequestProvider.notifier).set(code);
    }
  } catch (_) {
    // Fail safe: the app opens normally and the lock gate stays in place.
  }
}

class EphemeronApp extends ConsumerStatefulWidget {
  const EphemeronApp({super.key});

  @override
  ConsumerState<EphemeronApp> createState() => _EphemeronAppState();
}

class _EphemeronAppState extends ConsumerState<EphemeronApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    // `system` brightness follows the platform live; rebuilding the app is
    // cheap (theme + router config are cached providers).
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsRepositoryProvider);
    final repo = settings.maybeWhen(data: (r) => r, orElse: () => null);

    final primary = repo?.primaryColorHex != null
        ? parseHex(repo!.primaryColorHex!)
        : EphemeronTheme.brandAccent;
    final background = repo?.backgroundColorHex != null
        ? parseHex(repo!.backgroundColorHex!)
        : null;
    final brightnessName = repo?.brightness ?? 'light';
    final dynamicColor = repo?.dynamicColor ?? false;
    // The platform accent is only requested when dynamic color is enabled; on
    // web, desktop and iOS the provider resolves to null.
    final dynamicAccent = dynamicColor
        ? ref.watch(systemAccentProvider).value
        : null;

    final router = ref.watch(appRouterProvider);
    final localeCode = repo?.localeCode ?? 'system';
    final locked = repo?.biometricLock ?? false;
    // A verified firing alarm may show its ring screen over the lock screen.
    // The provider is only set after the fired-row check, so an arbitrary
    // intent can never bypass the gate.
    final ringActive = ref.watch(activeRingRequestProvider) != null;

    ref.listen(settingsRepositoryProvider, (previous, next) {
      next.whenData(
        (repo) => AppFeedback.configure(hapticsEnabled: repo.haptics),
      );
    });

    final theme = EphemeronTheme.build(
      mode: brightnessName,
      platformBrightness: View.of(context)
          .platformDispatcher
          .platformBrightness,
      accent: primary,
      background: background,
      dynamicColor: dynamicColor,
      dynamicAccent: dynamicAccent,
      compact: repo?.uiDensity == 'compact',
    );

    final app = MaterialApp.router(
      title: 'Ephemeron',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: appMessengerKey,
      theme: theme,
      locale: localeCode == 'system' ? null : Locale(localeCode),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) {
        final data = MediaQuery.of(context);
        return MediaQuery(
          data: data.copyWith(
            alwaysUse24HourFormat: repo?.time24h ?? true,
            disableAnimations:
                data.disableAnimations || (repo?.reduceAnimations ?? false),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (!locked || ringActive) return app;
    return _LockGate(ref: ref, theme: theme, child: app);
  }
}

/// Full-screen gate shown when biometric app lock is on. Stays locked
/// until authentication succeeds; unsupported devices pass through.
class _LockGate extends StatefulWidget {
  const _LockGate({
    required this.ref,
    required this.child,
    required this.theme,
  });

  final Widget child;
  final WidgetRef ref;
  final ThemeData theme;

  @override
  State<_LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<_LockGate> {
  bool _unlocked = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryUnlock());
  }

  Future<void> _tryUnlock() async {
    if (_busy || _unlocked || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    // On devices without biometric/device-credential support, the lock cannot
    // be used: clear the stale setting and pass through.
    if (!await AppLock.isSupported()) {
      try {
        final repo = await widget.ref.read(settingsRepositoryProvider.future);
        await repo.setBiometricLock(false);
        widget.ref.invalidate(settingsRepositoryProvider);
      } catch (_) {
        // Best-effort cleanup; never block unlock.
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _unlocked = true;
      });
      return;
    }
    try {
      final ok = await AppLock.authenticate();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _unlocked = ok;
        // User cancel stays locked quietly; other false results also retry.
        if (!ok) _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _unlocked = false;
        _error = AppLock.describeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return widget.child;
    return BiometricLockScreen(
      theme: widget.theme,
      busy: _busy,
      error: _error,
      onUnlock: _tryUnlock,
    );
  }
}
