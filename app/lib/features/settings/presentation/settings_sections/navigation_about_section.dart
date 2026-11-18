part of '../settings_screen.dart';

List<Widget> _navigationSection(
  _SettingsScreenState state,
  SettingsStrings strings,
) {
  final order =
      (state._repo?.navOrderV2 ?? SettingsRepository.defaultNavOrderV2)
          .map((id) => AppDestination.byId(id).title)
          .join(' > ');
  final sections = <Widget>[
    SectionTitle(
      title: strings.navigationTitle,
      description: strings.navigationDescription,
    ),
    _SettingsGroup(
      children: <Widget>[
        _SettingsRow(
          key: const ValueKey('settings-nav-order'),
          icon: Icons.swap_vert,
          title: strings.reorderTitle,
          subtitle: strings.navigationOrder(order),
          onTap: state._openNavOrder,
        ),
      ],
    ),
  ];
  _sectionGap(sections);
  return sections;
}

List<Widget> _aboutSection(
  _SettingsScreenState state,
  SettingsStrings strings,
) {
  final sections = <Widget>[
    SectionTitle(
      title: strings.aboutTitle,
      description: strings.aboutDescription,
    ),
    _SettingsGroup(
      children: <Widget>[
        _SettingsRow(
          key: const ValueKey('settings-about-privacy'),
          icon: Icons.lock_outline,
          title: strings.aboutPrivacyTitle,
          subtitle: strings.aboutPrivacyBody,
        ),
        _SettingsRow(
          key: const ValueKey('settings-about-licenses'),
          icon: Icons.description_outlined,
          title: strings.aboutLicensesTitle,
          subtitle: strings.aboutLicensesSubtitle,
          onTap: () => showLicensePage(
            context: state.context,
            applicationName: strings.appName,
            applicationLegalese: strings.aboutPrivacyBody,
          ),
        ),
        _SettingsRow(
          key: const ValueKey('settings-about-version'),
          icon: Icons.info_outline,
          title: strings.appName,
          subtitle: strings.aboutVersion,
        ),
      ],
    ),
  ];
  _sectionGap(sections);
  return sections;
}
