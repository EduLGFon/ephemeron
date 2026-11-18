// Exact-alarm / notification permission banner for the Stream dock.
//
// Presentation only: the current OS permission state is read through the
// existing [SystemLauncher] and [AlarmScheduler] seams. The dock mounts this
// host directly above the capture bar, so no screen or day body needs to know
// about permissions. Tests inject [StreamPermissionBannerHost.statusOverride]
// and [StreamPermissionBannerHost.openSettingsOverride]; the real host never
// asks for permission itself, it only points at system settings.
//
// Dismissal is session-only (never persisted): the user can silence the
// banner until the app process ends, so it never nags on every rebuild. A
// fresh launch re-checks the OS state and shows the banner again if the
// permission is still missing.
//
// PRIVACY: permission state is sensitive; it stays on the device, is never
// logged, and is never sent anywhere.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:ephemeron/l10n/src/app_localizations.dart';

import '../../../../core/platform/system_launcher.dart';
import '../../../alarms/data/alarm_scheduler.dart';

/// Session-only dismissal. Deliberately in memory: persisting it would hide a
/// missing permission forever, while rebuilding must not bring the banner
/// back after the user closes it.
final streamPermissionBannerDismissedProvider =
    NotifierProvider<StreamPermissionBannerDismissal, bool>(
      StreamPermissionBannerDismissal.new,
    );

class StreamPermissionBannerDismissal extends Notifier<bool> {
  @override
  bool build() => false;

  void dismiss() => state = true;
}

/// Android permissions that alarm delivery depends on. Off Android everything
/// is considered granted, so the banner only exists where it is actionable.
@immutable
class StreamPermissionStatus {
  const StreamPermissionStatus({
    required this.notificationsGranted,
    required this.exactAlarmGranted,
  });

  const StreamPermissionStatus.granted()
    : notificationsGranted = true,
      exactAlarmGranted = true;

  final bool notificationsGranted;
  final bool exactAlarmGranted;

  /// True when at least one permission still has to be turned on.
  bool get needsAttention => !notificationsGranted || !exactAlarmGranted;
}

/// Opens the relevant system settings page for [status].
typedef StreamPermissionSettingsOpener = Future<void> Function(
  StreamPermissionStatus status,
);

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Reads the existing permission seams. Exact alarms only exist on Android;
/// `AlarmScheduler.canScheduleExact` is false elsewhere by design, so the
/// platform gate keeps desktop and web from showing a banner forever.
Future<StreamPermissionStatus> loadStreamPermissionStatus() async {
  if (!_isAndroid) return const StreamPermissionStatus.granted();
  final notifications = await SystemLauncher.canPostNotifications();
  final exact = await AlarmScheduler.canScheduleExact();
  return StreamPermissionStatus(
    notificationsGranted: notifications,
    exactAlarmGranted: exact,
  );
}

/// Inline banner above the Stream capture dock. Renders nothing while the
/// permission state is loading, when both permissions are granted, or after
/// the user dismissed it for this session.
class StreamPermissionBannerHost extends ConsumerStatefulWidget {
  const StreamPermissionBannerHost({
    super.key,
    this.statusOverride,
    this.openSettingsOverride,
  });

  /// Test-only status; when set no platform channel is read.
  final StreamPermissionStatus? statusOverride;

  /// Test-only settings opener; production uses the system intents below.
  final StreamPermissionSettingsOpener? openSettingsOverride;

  @override
  ConsumerState<StreamPermissionBannerHost> createState() =>
      _StreamPermissionBannerHostState();
}

class _StreamPermissionBannerHostState
    extends ConsumerState<StreamPermissionBannerHost>
    with WidgetsBindingObserver {
  Future<StreamPermissionStatus>? _pending;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pending = _loadIfNeeded();
  }

  @override
  void didUpdateWidget(covariant StreamPermissionBannerHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.statusOverride == null && oldWidget.statusOverride != null) {
      _pending = loadStreamPermissionStatus();
    } else if (widget.statusOverride != null) {
      _pending = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user may have changed the permission in system settings.
    if (state == AppLifecycleState.resumed && widget.statusOverride == null) {
      setState(() => _pending = loadStreamPermissionStatus());
    }
  }

  Future<StreamPermissionStatus>? _loadIfNeeded() =>
      widget.statusOverride == null ? loadStreamPermissionStatus() : null;

  @override
  Widget build(BuildContext context) {
    final dismissed = ref.watch(streamPermissionBannerDismissedProvider);
    final override = widget.statusOverride;
    if (override != null) return _buildBanner(context, override, dismissed);
    final pending = _pending;
    if (pending == null) return const SizedBox.shrink();
    return FutureBuilder<StreamPermissionStatus>(
      future: pending,
      builder: (context, snapshot) =>
          _buildBanner(context, snapshot.data, dismissed),
    );
  }

  Widget _buildBanner(
    BuildContext context,
    StreamPermissionStatus? status,
    bool dismissed,
  ) {
    if (dismissed || status == null || !status.needsAttention) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l = AppLocalizations.of(context);
    // The explainer is the existing localized onboarding permission text;
    // ARB keys are not owned here, so no new label is introduced.
    return Material(
      key: const Key('streamPermissionBanner'),
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Row(
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 20,
              color: scheme.onSecondaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l.onboardingP2Body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ),
            Flexible(
              child: TextButton(
                onPressed: () => unawaited(_openSettings(status)),
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSecondaryContainer,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  l.streamSettings,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            IconButton(
              onPressed: _dismiss,
              tooltip: l.streamCaptureClose,
              iconSize: 20,
              color: scheme.onSecondaryContainer,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }

  void _dismiss() {
    ref.read(streamPermissionBannerDismissedProvider.notifier).dismiss();
  }

  Future<void> _openSettings(StreamPermissionStatus status) async {
    final override = widget.openSettingsOverride;
    if (override != null) {
      await override(status);
      return;
    }
    // Notifications live in the app's own settings page; exact alarms are a
    // separate special-access page. Both already exist in the app.
    if (!status.notificationsGranted) {
      await SystemLauncher.openAppSettings();
      return;
    }
    await AlarmScheduler.openExactAlarmSettings();
  }
}
