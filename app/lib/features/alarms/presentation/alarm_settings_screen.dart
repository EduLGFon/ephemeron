// Alarm settings: exact-alarm permission, per-preset test buttons,
// battery guidance, upcoming + missed alarms. Web/desktop show the
// simulation note instead of the unavailable banner.
//
// The screen is a single Dart library split into `part` files under
// presentation/alarm_settings_screen/ so permission rows and alarm lists stay
// focused while private members remain shared within the library. The entry
// point and import path are unchanged for existing importers.
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
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

part 'alarm_settings_screen/alarm_lists.dart';
part 'alarm_settings_screen/permissions.dart';

class AlarmSettingsScreen extends ConsumerStatefulWidget {
  const AlarmSettingsScreen({super.key});

  @override
  ConsumerState<AlarmSettingsScreen> createState() =>
      _AlarmSettingsScreenState();
}

class _AlarmSettingsScreenState extends ConsumerState<AlarmSettingsScreen>
    with WidgetsBindingObserver {
  // Permission checks are platform-channel round trips. Resolve each once per
  // build so stream/provider rebuilds cannot flash the status chip, then
  // invalidate when the user returns from system settings.
  Future<bool>? _exactAlarmStatus;
  Future<bool>? _fullScreenStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Permission prompts leave the app. Re-check both tiles on return so a
    // grant in system Settings is reflected without a manual screen reload.
    if (state == AppLifecycleState.resumed) _refreshPermissionStatus();
  }

  void _refreshPermissionStatus() {
    if (!mounted) return;
    setState(() {
      _exactAlarmStatus = null;
      _fullScreenStatus = null;
    });
  }

  Future<void> _openPermissionSettings(Future<bool> Function() open) async {
    await open();
    _refreshPermissionStatus();
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
                                  'entitlement (see TODO.md).',
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
            onOpenSettings: () => _openPermissionSettings(
              () => AppPermissions.ensureExactAlarm(context),
            ),
          ),
          _PermissionTile(
            icon: Icons.fullscreen,
            title: 'Full-screen alarms',
            description:
                'Needed on Android 14+ to show alarms over the lock screen.',
            status: _fullScreenStatus ??=
                SystemLauncher.canUseFullScreenIntent(),
            onOpenSettings: () => _openPermissionSettings(
              () =>
                  AppPermissions.ensureFullScreenIntent(context, needed: true),
            ),
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
