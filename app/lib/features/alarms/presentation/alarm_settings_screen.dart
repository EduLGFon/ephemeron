// Alarm settings: exact-alarm permission, per-preset test buttons,
// battery guidance, upcoming + missed alarms. Web/desktop show the
// simulation note instead of the unavailable banner.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/alarms/alarm_preset.dart';
import '../../../core/platform/app_permissions.dart';
import '../../../core/platform/system_launcher.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/time/device_date_format.dart';
import '../../../core/ui/app_section_header.dart';
import '../../../core/ui/empty_state.dart';
import '../../settings/application/settings_providers.dart';
import '../application/alarm_providers.dart';
import '../data/alarm_scheduler.dart';
import 'alarm_settings_format.dart';

class AlarmSettingsScreen extends ConsumerStatefulWidget {
  const AlarmSettingsScreen({super.key});

  @override
  ConsumerState<AlarmSettingsScreen> createState() =>
      _AlarmSettingsScreenState();
}

class _AlarmSettingsScreenState extends ConsumerState<AlarmSettingsScreen> {
  // Permission checks are platform-channel round trips. Resolve each once per
  // screen visit so stream/provider rebuilds cannot flash the status chip.
  Future<bool>? _exactAlarmStatus;
  Future<bool>? _fullScreenStatus;

  @override
  void initState() {
    super.initState();
    // Track the route so restarts return here.
    Future.microtask(() async {
      try {
        final repo = await ref.read(settingsRepositoryProvider.future);
        if (repo.lastRoute != '/alarm-settings') {
          await repo.setLastRoute('/alarm-settings');
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Alarms')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Web simulation',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text(
              'Browsers cannot fire alarms in the background. While this tab '
              'is open, reminders arrive as snackbars and full-screen alarms '
              'arrive as pop-up dialogs with sound. Keep the tab open for '
              'timely alerts, or export ICS to your system calendar.',
            ),
            const SizedBox(height: 12),
            _PresetCards(ref),
            const SizedBox(height: 12),
            _Upcoming(ref),
            _Missed(ref),
          ],
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows) {
      return Scaffold(
        appBar: AppBar(title: const Text('Alarms')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Desktop simulation. System notifications plus in-app pop-up '
              'alarms while the app is running. Configure sound paths per OS.',
            ),
            const SizedBox(height: 12),
            _PresetCards(ref),
            const SizedBox(height: 12),
            _Upcoming(ref),
            _Missed(ref),
          ],
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return Scaffold(
        appBar: AppBar(title: const Text('Alarms')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'iOS allows at most 64 pending notifications; the app keeps the '
              'same rolling window capped at 60. No full-screen ring screen '
              'is possible on iOS: alerts arrive as time-sensitive '
              'notifications.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Critical Alerts ring through silent mode and need Apple '
              'approval for the App Store build.',
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () async {
                final ok = await AlarmScheduler.requestCriticalAlerts();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'Critical Alerts granted.'
                            : 'Critical Alerts not granted. The native '
                                  'request needs an Xcode build with the '
                                  'entitlement (see docs/TODO.md).',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Request Critical Alerts'),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Alarms')),
      body: ListView(
        children: [
          _PermissionTile(
            icon: Icons.alarm,
            title: 'Exact alarms',
            description:
                'Needed to ring at the exact time, including in power saving.',
            status: _exactAlarmStatus ??= AlarmScheduler.canScheduleExact(),
            onOpenSettings: () => AppPermissions.ensureExactAlarm(context),
          ),
          _PermissionTile(
            icon: Icons.fullscreen,
            title: 'Full-screen alarms',
            description:
                'Needed on Android 14+ to show alarms over the lock screen.',
            status: _fullScreenStatus ??=
                SystemLauncher.canUseFullScreenIntent(),
            onOpenSettings: () =>
                AppPermissions.ensureFullScreenIntent(context, needed: true),
          ),
          const AppSectionHeader(
            'Alarm styles',
            description:
                'Reminders (early or at-time notifications) always fire '
                'separately and are set per item.',
          ),
          for (final p in AlarmPreset.values)
            ListTile(
              leading: Icon(
                p == AlarmPreset.notification
                    ? Icons.notifications_outlined
                    : p == AlarmPreset.fullScreenShort
                    ? Icons.fullscreen
                    : Icons.alarm_on,
              ),
              title: Text(p.title),
              subtitle: Text(p.description),
              trailing: TextButton(
                onPressed: () async {
                  // Moment of need: notifications, then exact alarms for
                  // clock presets, then full-screen for lock-screen presets.
                  // Each prompt explains why before the system dialog.
                  await AppPermissions.ensureAlarmPrereqs(
                    context,
                    exactAlarm: p.needsAlarmClock,
                    fullScreen: p.usesFullScreen,
                  );
                  if (!context.mounted) return;
                  AlarmScheduler.testAlarm(p);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Test ${p.title.toLowerCase()} set (10 s)'),
                    ),
                  );
                },
                child: const Text('Test'),
              ),
            ),
          ListTile(
            title: const Text('Battery optimization'),
            subtitle: const Text(
              'Xiaomi, Samsung, Huawei and Oppo may block alarms. Open system settings.',
            ),
            onTap: () => AlarmScheduler.openBatterySettings(),
          ),
          const Divider(),
          _Upcoming(ref),
          _Missed(ref),
        ],
      ),
    );
  }
}

/// Shared permission row: status chip always visible, settings deep link
/// only while the privilege is missing.
class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.status,
    required this.onOpenSettings,
  });

  final IconData icon;
  final String title;
  final String description;
  final Future<bool> status;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: status,
      builder: (context, snap) {
        final granted = snap.data ?? false;
        return ListTile(
          isThreeLine: true,
          leading: Icon(icon),
          title: Text(title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpace.xs),
              _PermissionStatusChip(granted: granted),
              const SizedBox(height: AppSpace.xs),
              Text(description),
            ],
          ),
          trailing: granted
              ? null
              : FilledButton(
                  onPressed: onOpenSettings,
                  child: const Text('Open settings'),
                ),
        );
      },
    );
  }
}

class _PermissionStatusChip extends StatelessWidget {
  const _PermissionStatusChip({required this.granted});

  final bool granted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = granted ? scheme.primary : scheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            granted ? Icons.check_circle_outline : Icons.error_outline,
            size: 14,
            color: color,
          ),
          const SizedBox(width: AppSpace.xs),
          Text(
            granted ? 'Granted' : 'Not granted',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetCards extends StatelessWidget {
  const _PresetCards(this.ref);
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final p in AlarmPreset.values)
          Card(
            child: ListTile(
              title: Text(p.title),
              subtitle: Text(p.description),
            ),
          ),
      ],
    );
  }
}

class _Upcoming extends ConsumerWidget {
  const _Upcoming(this.ref);
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef innerRef) {
    final upcoming = ref.watch(upcomingAlarmsProvider);
    final count = upcoming.value?.length ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader('Upcoming', count: count > 0 ? count : null),
        upcoming.maybeWhen(
          data: (list) => Column(
            children: [
              if (list.isEmpty)
                const EmptyState(
                  compact: true,
                  icon: Icons.schedule,
                  title: 'No upcoming alarms',
                  subtitle: 'Alarms you set will appear here.',
                )
              else
                for (final a in list.take(20))
                  ListTile(
                    title: Text(a.title ?? a.sourceId),
                    subtitle: Text(
                      '${a.kind} - ${a.preset ?? ''} - '
                      '${formatAlarmFireTime(a.fireAtUtc, DeviceDateFormat.yMMMd(context).add_Hm())}',
                    ),
                  ),
            ],
          ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _Missed extends ConsumerWidget {
  const _Missed(this.ref);
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef innerRef) {
    final missedAsync = ref.watch(missedAlarmsProvider);
    final count = missedAsync.value?.length ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader('Missed alarms', count: count > 0 ? count : null),
        missedAsync.maybeWhen(
          data: (missed) => Column(
            children: [
              if (missed.isEmpty)
                const EmptyState(
                  compact: true,
                  icon: Icons.alarm_off,
                  title: 'No missed alarms',
                  subtitle: 'Alarms you miss will appear here.',
                )
              else
                for (final m in missed)
                  ListTile(
                    title: Text(m.title ?? m.sourceId),
                    subtitle: Text(
                      formatAlarmFireTime(
                        m.fireAtUtc,
                        DeviceDateFormat.yMMMd(context).add_Hm(),
                      ),
                    ),
                  ),
            ],
          ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
