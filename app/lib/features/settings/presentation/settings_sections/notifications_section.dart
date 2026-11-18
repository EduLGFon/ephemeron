part of '../settings_screen.dart';

List<Widget> _notificationsSection(
  _SettingsScreenState state,
  SettingsStrings strings,
) {
  final sections = <Widget>[
    SectionTitle(
      title: strings.notificationsTitle,
      description: strings.notificationsDescription,
    ),
    _SettingsGroup(
      children: <Widget>[
        _NotificationsPermissionTile(strings: strings),
        if (AppPlatform.isWeb)
          _SettingsNotice(
            icon: Icons.public_off,
            title: strings.webNoticeTitle,
            message: strings.webNoticeBody,
          ),
        if (AppPlatform.isIOS)
          _SettingsNotice(
            icon: Icons.phone_iphone,
            title: strings.iosNoticeTitle,
            message: strings.iosNoticeBody,
          ),
        _ExactAlarmTile(strings: strings),
        _SettingsSwitchRow(
          key: const ValueKey('settings-due-tomorrow'),
          icon: Icons.notification_add_outlined,
          title: strings.dueTomorrowTitle,
          subtitle: strings.dueTomorrowSubtitle,
          value: state._taskDueTomorrowReminder,
          onChanged: state._setTaskDueTomorrowReminder,
          switchKey: const ValueKey('due-tomorrow-switch'),
        ),
        _SettingsSwitchRow(
          key: const ValueKey('settings-dnd'),
          icon: Icons.do_not_disturb_on_outlined,
          title: strings.dndTitle,
          subtitle: AppPlatform.isAndroid
              ? strings.dndSubtitle
              : strings.dndAndroidOnly,
          value: state._focusDnd,
          onChanged: AppPlatform.isAndroid ? state._setFocusDnd : null,
          switchKey: const ValueKey('dnd-switch'),
        ),
      ],
    ),
  ];
  _sectionGap(sections);
  return sections;
}

class _NotificationsPermissionTile extends StatefulWidget {
  const _NotificationsPermissionTile({required this.strings});

  final SettingsStrings strings;

  @override
  State<_NotificationsPermissionTile> createState() =>
      _NotificationsPermissionTileState();
}

class _NotificationsPermissionTileState
    extends State<_NotificationsPermissionTile> {
  late Future<bool> _status = _load();

  Future<bool> _load() async {
    if (!AppPlatform.isAndroid) return true;
    try {
      return await SystemLauncher.canPostNotifications();
    } catch (_) {
      return false;
    }
  }

  void _refresh() {
    setState(() {
      _status = _load();
    });
  }

  Future<void> _request(BuildContext context) async {
    await AppPermissions.ensureNotifications(
      context,
      reason: widget.strings.notificationsReason,
    );
    if (mounted) _refresh();
  }

  Future<void> _openSettings(BuildContext context) async {
    final opened = await SystemLauncher.openAppSettings();
    if (!context.mounted) return;
    if (!opened) {
      showAppSnackBar(
        context,
        widget.strings.appSettings,
        icon: Icons.settings_outlined,
      );
    }
    if (mounted) _refresh();
  }

  String _subtitle(bool granted) {
    if (AppPlatform.isWeb) return widget.strings.permissionWeb;
    if (!AppPlatform.isAndroid) {
      return widget.strings.permissionSystemManaged;
    }
    return granted
        ? widget.strings.permissionGranted
        : widget.strings.permissionDenied;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _status,
      builder: (context, snapshot) {
        final done = snapshot.connectionState == ConnectionState.done;
        final granted = snapshot.data ?? false;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _SettingsRow(
              key: const ValueKey('settings-notification-permission'),
              icon: Icons.notifications_outlined,
              title: widget.strings.permissionTitle,
              subtitle: done
                  ? _subtitle(granted)
                  : widget.strings.permissionChecking,
            ),
            if (done && !granted && AppPlatform.isAndroid)
              _SettingsNotice(
                emphasis: true,
                icon: Icons.notifications_off_outlined,
                title: widget.strings.notificationsDeniedTitle,
                message: widget.strings.notificationsDeniedBody,
                actionLabel: widget.strings.allowNotifications,
                onAction: () => _request(context),
                secondaryLabel: widget.strings.appSettings,
                onSecondary: () => _openSettings(context),
              ),
          ],
        );
      },
    );
  }
}

class _ExactAlarmTile extends StatefulWidget {
  const _ExactAlarmTile({required this.strings});

  final SettingsStrings strings;

  @override
  State<_ExactAlarmTile> createState() => _ExactAlarmTileState();
}

class _ExactAlarmTileState extends State<_ExactAlarmTile> {
  late Future<bool?> _status = _load();

  Future<bool?> _load() async {
    if (!AppPlatform.isAndroid) return null;
    try {
      return await AlarmScheduler.canScheduleExact();
    } catch (_) {
      return false;
    }
  }

  void _refresh() {
    setState(() {
      _status = _load();
    });
  }

  Future<void> _openSettings(BuildContext context) async {
    await AppPermissions.ensureExactAlarm(context);
    if (mounted) _refresh();
  }

  String _subtitle(bool? granted) {
    if (granted == null) {
      return AppPlatform.isWeb
          ? widget.strings.exactAlarmWeb
          : widget.strings.exactAlarmSystemManaged;
    }
    return granted
        ? widget.strings.exactAlarmGranted
        : widget.strings.exactAlarmDenied;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool?>(
      future: _status,
      builder: (context, snapshot) {
        final done = snapshot.connectionState == ConnectionState.done;
        final granted =
            snapshot.data ?? (done && AppPlatform.isAndroid ? false : null);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _SettingsRow(
              key: const ValueKey('settings-exact-alarm'),
              icon: Icons.alarm_outlined,
              title: widget.strings.exactAlarmTitle,
              subtitle: done
                  ? _subtitle(granted)
                  : widget.strings.permissionChecking,
              trailing: done && granted == false && AppPlatform.isAndroid
                  ? AppButton(
                      label: widget.strings.openSettings,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => _openSettings(context),
                    )
                  : null,
            ),
            if (!AppPlatform.isAndroid && !AppPlatform.isWeb)
              _SettingsNotice(
                icon: Icons.info_outline,
                title: widget.strings.exactAlarmTitle,
                message: widget.strings.exactAlarmAndroidOnly,
              ),
          ],
        );
      },
    );
  }
}
