part of '../settings_screen.dart';

List<Widget> _appearanceSection(
  _SettingsScreenState state,
  SettingsStrings strings,
) {
  final sections = <Widget>[
    SectionTitle(
      title: strings.appearanceTitle,
      description: strings.appearanceDescription,
    ),
    _SettingsGroup(
      children: <Widget>[
        _SettingsChoiceRow(
          key: const ValueKey('settings-brightness'),
          title: strings.brightnessTitle,
          help: strings.brightnessHelp,
          keyPrefix: 'brightness',
          selectedId: state._brightnessName,
          options: <({String id, String label})>[
            (id: 'light', label: strings.brightnessLight),
            (id: 'dark', label: strings.brightnessDark),
            (id: 'amoled', label: strings.brightnessAmoled),
            (id: 'system', label: strings.brightnessSystem),
          ],
          onSelected: state._setBrightness,
        ),
        _SettingsColorRow(
          key: const ValueKey('settings-accent-color'),
          title: strings.accentTitle,
          help: strings.accentHelp,
          presets: primaryPresets,
          selectedHex: state._primaryHex,
          keyPrefix: 'primary',
          onSelected: (hex) => state._selectColor(primary: true, hex: hex),
        ),
        _SettingsHexRow(
          key: const ValueKey('settings-custom-accent'),
          title: strings.customAccentTitle,
          help: strings.customHexHelp,
          value: state._primaryHex,
          fieldKey: const ValueKey('primary-hex-field'),
          invalidMessage: strings.invalidHex,
          onSubmitted: (hex) => state._selectColor(primary: true, hex: hex),
        ),
        _SettingsColorRow(
          key: const ValueKey('settings-background-color'),
          title: strings.backgroundTitle,
          help: strings.backgroundHelp,
          presets: backgroundPresets,
          selectedHex: state._backgroundHex,
          keyPrefix: 'background',
          onSelected: (hex) => state._selectColor(primary: false, hex: hex),
        ),
        _SettingsHexRow(
          key: const ValueKey('settings-custom-background'),
          title: strings.customBackgroundTitle,
          help: strings.customHexHelp,
          value: state._backgroundHex,
          fieldKey: const ValueKey('background-hex-field'),
          invalidMessage: strings.invalidHex,
          onSubmitted: (hex) => state._selectColor(primary: false, hex: hex),
        ),
        _SettingsSwitchRow(
          key: const ValueKey('settings-dynamic-color'),
          icon: Icons.palette_outlined,
          title: strings.dynamicColorTitle,
          subtitle: AppPlatform.isAndroid
              ? strings.dynamicColorSubtitle
              : strings.dynamicColorUnavailable,
          value: state._dynamicColor,
          onChanged: AppPlatform.isAndroid ? state._setDynamicColor : null,
          switchKey: const ValueKey('dynamic-color-switch'),
        ),
        _SettingsChoiceRow(
          key: const ValueKey('settings-density'),
          title: strings.densityTitle,
          help: strings.densityHelp,
          keyPrefix: 'density',
          selectedId: state._uiDensity,
          options: <({String id, String label})>[
            (id: 'comfortable', label: strings.densityComfortable),
            (id: 'compact', label: strings.densityCompact),
          ],
          onSelected: state._setDensity,
        ),
        _SettingsSwitchRow(
          key: const ValueKey('settings-reduce-motion'),
          icon: Icons.motion_photos_off_outlined,
          title: strings.reduceMotionTitle,
          subtitle: strings.reduceMotionSubtitle,
          value: state._reduceAnimations,
          onChanged: state._setReduceAnimations,
          switchKey: const ValueKey('reduce-motion-switch'),
        ),
        _SettingsSwitchRow(
          key: const ValueKey('settings-haptics'),
          icon: Icons.vibration,
          title: strings.hapticsTitle,
          subtitle: strings.hapticsSubtitle,
          value: state._haptics,
          onChanged: state._setHaptics,
          switchKey: const ValueKey('haptics-switch'),
        ),
        _SettingsPickerRow<PowerSavingMode>(
          key: const ValueKey('settings-power-saving'),
          title: strings.powerSavingTitle,
          help: strings.powerSavingHelp,
          value: state._powerSavingMode,
          items: <DropdownMenuItem<PowerSavingMode>>[
            DropdownMenuItem(
              value: PowerSavingMode.auto,
              child: Text(strings.powerAuto),
            ),
            DropdownMenuItem(
              value: PowerSavingMode.on,
              child: Text(strings.powerOn),
            ),
            DropdownMenuItem(
              value: PowerSavingMode.off,
              child: Text(strings.powerOff),
            ),
          ],
          onChanged: state._setPowerSaving,
        ),
        _SettingsPickerRow<String>(
          key: const ValueKey('settings-language'),
          title: strings.languageTitle,
          help: strings.languageHelp,
          value: state._localeCode,
          items: <DropdownMenuItem<String>>[
            DropdownMenuItem(
              value: 'system',
              child: Text(strings.languageSystem),
            ),
            DropdownMenuItem(value: 'en', child: Text(strings.languageEnglish)),
            DropdownMenuItem(
              value: 'pt',
              child: Text(strings.languagePortuguese),
            ),
          ],
          onChanged: state._setLocale,
        ),
      ],
    ),
  ];
  _sectionGap(sections);
  return sections;
}
