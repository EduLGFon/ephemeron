import 'package:ephemeron/features/stream/application/stream_theme_provider.dart';
import 'package:ephemeron/features/stream/design/stream_theme_mode.dart';
import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';

const List<StreamThemeMode> _themeOrder = [
  StreamThemeMode.light,
  StreamThemeMode.dark,
  StreamThemeMode.trueBlack,
  StreamThemeMode.system,
];

String _themeLabel(StreamThemeMode mode, AppLocalizations l) => switch (mode) {
  StreamThemeMode.light => l.streamSettingsThemeLight,
  StreamThemeMode.dark => l.streamSettingsThemeDark,
  StreamThemeMode.trueBlack => l.streamSettingsThemeTrueBlack,
  StreamThemeMode.system => l.streamSettingsThemeSystem,
};

/// Modal sheet body for Stream settings.
///
/// Presentation only: theme mode is read from and written to
/// [streamThemeProvider]; navigation stays with the caller via callbacks.
class StreamSettingsSheet extends ConsumerWidget {
  const StreamSettingsSheet({
    super.key,
    required this.onClose,
    required this.onOpenAppSettings,
    this.onReplaySchool,
  });

  final VoidCallback onClose;
  final VoidCallback onOpenAppSettings;

  /// When null the replay row is omitted.
  final VoidCallback? onReplaySchool;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(context, l),
        const Divider(height: 1),
        Flexible(child: _list(context, ref, l)),
      ],
    );
  }

  Widget _header(BuildContext context, AppLocalizations l) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        StreamSpacing.x4,
        StreamSpacing.x1,
        StreamSpacing.x1,
        StreamSpacing.x1,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                l.streamSettingsSheetTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          IconButton(
            key: const Key('streamSettingsSheetClose'),
            onPressed: onClose,
            tooltip: l.streamSettingsSheetClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _list(BuildContext context, WidgetRef ref, AppLocalizations l) {
    final mode = ref.watch(streamThemeProvider);
    final replay = onReplaySchool;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: StreamSpacing.x1,
      ),
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            StreamSpacing.x4,
            StreamSpacing.x2,
            StreamSpacing.x4,
            StreamSpacing.x1,
          ),
          child: Text(
            l.streamSettingsThemeSection,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        for (final option in _themeOrder)
          _row(
            key: Key('streamSettingsTheme-${option.name}'),
            label: _themeLabel(option, l),
            selected: option == mode,
            onTap: () => ref.read(streamThemeProvider.notifier).setMode(option),
          ),
        const Divider(height: 1),
        _row(
          key: const Key('streamSettingsMore'),
          icon: Icons.settings_outlined,
          label: l.streamSettingsMore,
          onTap: onOpenAppSettings,
        ),
        if (replay != null)
          _row(
            key: const Key('streamSettingsReplaySchool'),
            icon: Icons.school_outlined,
            label: l.streamSettingsReplaySchool,
            onTap: replay,
          ),
      ],
    );
  }
}

Widget _row({
  Key? key,
  required String label,
  required VoidCallback onTap,
  IconData? icon,
  bool? selected,
}) {
  return Semantics(
    key: key,
    button: true,
    selected: selected,
    child: ListTile(
      minTileHeight: 48,
      leading: icon == null ? null : Icon(icon),
      title: Text(label),
      trailing: selected == true ? const Icon(Icons.check) : null,
      selected: selected ?? false,
      onTap: onTap,
    ),
  );
}
