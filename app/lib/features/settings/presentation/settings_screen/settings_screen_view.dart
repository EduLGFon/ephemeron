part of '../settings_screen.dart';

Widget _settingsHeader(_SettingsScreenState state, SettingsStrings strings) {
  return AppPageHeader(
    leading: AppIconButton(
      key: const ValueKey('settings-back'),
      icon: Icons.arrow_back,
      tooltip: strings.back,
      semanticLabel: strings.back,
      onPressed: () => Navigator.of(state.context).maybePop(),
    ),
    title: Text(strings.title),
    subtitle: Text(strings.subtitle),
    actions: <Widget>[
      AppIconButton(
        key: const ValueKey('settings-search-toggle'),
        icon: Icons.search,
        tooltip: strings.search,
        semanticLabel: strings.search,
        onPressed: () => state.context.push('/search'),
      ),
    ],
  );
}

Widget _settingsBody(
  _SettingsScreenState state,
  SettingsStrings strings, {
  required bool needsReconnect,
}) {
  final sections = <Widget>[
    if (state._sectionMatches(
      strings.accountSyncTitle,
      'account google microsoft sign in sync reconnect interval last sync '
      'issues calendar calendars lists tasks',
    ))
      ..._accountSyncSection(state, strings, needsReconnect: needsReconnect),
    if (state._sectionMatches(
      strings.notificationsTitle,
      'notifications permission alarm exact due tomorrow dnd do not disturb '
      'reminder web ios',
    ))
      ..._notificationsSection(state, strings),
    if (state._sectionMatches(
      strings.appearanceTitle,
      'appearance theme brightness dark light amoled true black system accent '
      'color background custom hex dynamic density compact reduce motion '
      'haptics power saving language english portuguese',
    ))
      ..._appearanceSection(state, strings),
    if (state._sectionMatches(
      strings.timeTitle,
      'time week start monday sunday clock 24 hour 12 hour format',
    ))
      ..._timeSection(state, strings),
    if (state._sectionMatches(
      strings.shortcutsTitle,
      'shortcuts keyboard keys desktop web search new escape arrows',
    ))
      _shortcutsSection(state, strings),
    if (state._sectionMatches(
      strings.streamTitle,
      'stream timeline opt in more sidebar',
    ))
      ..._streamSection(state, strings),
    if (state._sectionMatches(
      strings.dataTitle,
      'data backup export restore home widgets launcher',
    ))
      ..._dataSection(state, strings),
    if (state._sectionMatches(
      strings.securityTitle,
      'security biometric lock fingerprint face unlock',
    ))
      ..._securitySection(state, strings),
    if (state._sectionMatches(
      strings.navigationTitle,
      'navigation reorder order primary destinations today tasks calendar '
      'habits focus',
    ))
      ..._navigationSection(state, strings),
    if (state._sectionMatches(
      strings.aboutTitle,
      'about privacy licenses open source version local first',
    ))
      ..._aboutSection(state, strings),
  ];

  if (sections.isEmpty) {
    return ListView(
      padding: const EdgeInsets.only(top: DsSpace.x24),
      children: <Widget>[
        AppEmptyState(
          icon: Icons.search_off,
          title: strings.searchEmptyTitle,
          message: strings.searchEmptyMessage,
        ),
      ],
    );
  }

  return ListView(
    padding: const EdgeInsets.only(top: DsSpace.x4, bottom: DsSpace.x48),
    children: sections,
  );
}
