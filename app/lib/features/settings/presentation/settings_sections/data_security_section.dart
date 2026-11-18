part of '../settings_screen.dart';

List<Widget> _dataSection(_SettingsScreenState state, SettingsStrings strings) {
  final sections = <Widget>[
    SectionTitle(
      title: strings.dataTitle,
      description: strings.dataDescription,
    ),
    _SettingsGroup(
      children: <Widget>[
        _SettingsRow(
          key: const ValueKey('settings-backup'),
          icon: Icons.backup_outlined,
          title: strings.backupTitle,
          subtitle: strings.backupSubtitle,
        ),
        const BackupSection(),
        _SettingsRow(
          key: const ValueKey('settings-home-widgets'),
          icon: Icons.widgets_outlined,
          title: strings.homeWidgetsTitle,
          subtitle: strings.homeWidgetsSubtitle,
          onTap: () => _push(state.context, const HomeWidgetsScreen()),
        ),
      ],
    ),
  ];
  _sectionGap(sections);
  return sections;
}

List<Widget> _securitySection(
  _SettingsScreenState state,
  SettingsStrings strings,
) {
  final sections = <Widget>[
    SectionTitle(
      title: strings.securityTitle,
      description: strings.securityDescription,
    ),
    _SettingsGroup(
      children: <Widget>[
        _SettingsSwitchRow(
          key: const ValueKey('settings-biometric'),
          icon: Icons.fingerprint,
          title: strings.biometricTitle,
          subtitle: state._biometricSupported
              ? strings.biometricSupported
              : strings.biometricUnsupported,
          value: state._biometricSupported && state._biometricLock,
          onChanged: state._biometricSupported ? state._setBiometricLock : null,
          switchKey: const ValueKey('biometric-switch'),
        ),
      ],
    ),
  ];
  _sectionGap(sections);
  return sections;
}
