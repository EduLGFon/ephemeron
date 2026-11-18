part of '../settings_screen.dart';

List<Widget> _timeSection(_SettingsScreenState state, SettingsStrings strings) {
  final sections = <Widget>[
    SectionTitle(
      title: strings.timeTitle,
      description: strings.timeDescription,
    ),
    _SettingsGroup(
      children: <Widget>[
        _SettingsPickerRow<int>(
          key: const ValueKey('settings-week-start'),
          title: strings.weekStartTitle,
          help: strings.weekStartHelp,
          value: state._weekStart,
          items: <DropdownMenuItem<int>>[
            DropdownMenuItem(
              value: DateTime.monday,
              child: Text(strings.weekdayMonday),
            ),
            DropdownMenuItem(
              value: DateTime.tuesday,
              child: Text(strings.weekdayTuesday),
            ),
            DropdownMenuItem(
              value: DateTime.wednesday,
              child: Text(strings.weekdayWednesday),
            ),
            DropdownMenuItem(
              value: DateTime.thursday,
              child: Text(strings.weekdayThursday),
            ),
            DropdownMenuItem(
              value: DateTime.friday,
              child: Text(strings.weekdayFriday),
            ),
            DropdownMenuItem(
              value: DateTime.saturday,
              child: Text(strings.weekdaySaturday),
            ),
            DropdownMenuItem(
              value: DateTime.sunday,
              child: Text(strings.weekdaySunday),
            ),
          ],
          onChanged: state._setWeekStart,
        ),
        _SettingsSwitchRow(
          key: const ValueKey('settings-time-format'),
          icon: Icons.schedule,
          title: state._time24h ? strings.clockTitle : strings.clock12Title,
          subtitle: state._time24h
              ? strings.clockSubtitle
              : strings.clock12Subtitle,
          value: state._time24h,
          onChanged: state._setTime24h,
          switchKey: const ValueKey('time-24h-switch'),
        ),
      ],
    ),
  ];
  _sectionGap(sections);
  return sections;
}

Widget _shortcutsSection(_SettingsScreenState state, SettingsStrings strings) {
  final rows = <Widget>[];
  if (AppPlatform.supportsKeyboardShortcuts) {
    rows.addAll(<Widget>[
      _SettingsRow(
        title: strings.shortcutNew,
        trailing: const KeyHint(label: 'N'),
      ),
      _SettingsRow(
        title: strings.shortcutSearch,
        trailing: const KeyHint(label: '/'),
      ),
      _SettingsRow(
        title: strings.shortcutCommandSearch,
        trailing: const KeyHint(label: 'Ctrl K'),
      ),
      _SettingsRow(
        title: strings.shortcutEscape,
        trailing: const KeyHint(label: 'Esc'),
      ),
      _SettingsRow(
        title: strings.shortcutTabs,
        trailing: const KeyHint(label: '1-5'),
      ),
      _SettingsRow(
        title: strings.shortcutToday,
        trailing: const KeyHint(label: 'T'),
      ),
      _SettingsRow(
        title: strings.shortcutArrows,
        trailing: const KeyHint(label: 'Left Right'),
      ),
    ]);
  } else {
    rows.add(
      _SettingsRow(
        icon: Icons.keyboard_outlined,
        title: strings.shortcutsTitle,
        subtitle: strings.shortcutsUnavailable,
      ),
    );
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      SectionTitle(
        title: strings.shortcutsTitle,
        description: strings.shortcutsDescription,
      ),
      _SettingsGroup(children: rows),
      const SizedBox(height: DsSpace.x16),
    ],
  );
}

List<Widget> _streamSection(
  _SettingsScreenState state,
  SettingsStrings strings,
) {
  final sections = <Widget>[
    SectionTitle(
      title: strings.streamTitle,
      description: strings.streamDescription,
    ),
    _SettingsGroup(
      children: <Widget>[
        _SettingsSwitchRow(
          key: const ValueKey('settings-stream'),
          icon: Icons.stream_outlined,
          title: strings.streamToggleTitle,
          subtitle: strings.streamToggleSubtitle,
          value: state._streamEnabled,
          onChanged: state._setStreamEnabled,
          switchKey: const ValueKey('stream-toggle'),
        ),
      ],
    ),
  ];
  _sectionGap(sections);
  return sections;
}
