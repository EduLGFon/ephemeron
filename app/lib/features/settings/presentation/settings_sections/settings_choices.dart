part of '../settings_screen.dart';

class _SettingsChoiceRow extends StatelessWidget {
  const _SettingsChoiceRow({
    super.key,
    required this.title,
    required this.options,
    required this.selectedId,
    required this.onSelected,
    required this.keyPrefix,
    this.help,
  });

  final String title;
  final String? help;
  final List<({String id, String label})> options;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpace.x16,
        vertical: DsSpace.x12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          if (help != null) ...<Widget>[
            const SizedBox(height: DsSpace.x4),
            Text(
              help!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: DsSpace.x8),
          Wrap(
            spacing: DsSpace.x8,
            runSpacing: DsSpace.x8,
            children: <Widget>[
              for (final option in options)
                AppChip(
                  key: ValueKey('$keyPrefix-${option.id}'),
                  label: option.label,
                  selected: selectedId == option.id,
                  onTap: () => onSelected(option.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsColorRow extends StatelessWidget {
  const _SettingsColorRow({
    super.key,
    required this.title,
    required this.help,
    required this.presets,
    required this.selectedHex,
    required this.keyPrefix,
    required this.onSelected,
  });

  final String title;
  final String help;
  final List<Color> presets;
  final String selectedHex;
  final String keyPrefix;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalized = isValidHex(selectedHex)
        ? colorToHex(parseHex(selectedHex))
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpace.x16,
        vertical: DsSpace.x12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: DsSpace.x4),
          Text(
            help,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: DsSpace.x12),
          Wrap(
            spacing: DsSpace.x8,
            runSpacing: DsSpace.x8,
            children: <Widget>[
              for (final color in presets)
                _ColorSwatch(
                  color: color,
                  selected: normalized == colorToHex(color),
                  keyPrefix: keyPrefix,
                  onSelected: onSelected,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.keyPrefix,
    required this.onSelected,
  });

  final Color color;
  final bool selected;
  final String keyPrefix;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hex = colorToHex(color);
    final checkColor = color.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;
    return Semantics(
      selected: selected,
      button: true,
      label: hex,
      child: Tooltip(
        message: hex,
        child: InkWell(
          key: ValueKey('$keyPrefix-color-$hex'),
          customBorder: const CircleBorder(),
          onTap: () => onSelected(hex),
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 3 : 1,
              ),
            ),
            child: selected
                ? Icon(
                    Icons.check,
                    key: ValueKey('$keyPrefix-selected-$hex'),
                    size: DsIcon.sm,
                    color: checkColor,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _HexColorField extends StatefulWidget {
  const _HexColorField({
    required this.value,
    required this.fieldKey,
    required this.errorMessage,
    required this.onSubmitted,
  });

  final String value;
  final Key fieldKey;
  final String errorMessage;
  final ValueChanged<String> onSubmitted;

  @override
  State<_HexColorField> createState() => _HexColorFieldState();
}

class _HexColorFieldState extends State<_HexColorField> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_HexColorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _controller.text.trim();
    if (!isValidHex(raw)) {
      setState(() => _error = widget.errorMessage);
      return;
    }
    setState(() => _error = null);
    final normalized = raw.startsWith('#') ? raw : '#$raw';
    _controller.text = normalized;
    widget.onSubmitted(normalized);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: widget.fieldKey,
      controller: _controller,
      autocorrect: false,
      textCapitalization: TextCapitalization.characters,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        hintText: '#RRGGBB',
        errorText: _error,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onSubmitted: (_) => _submit(),
    );
  }
}

class _SettingsHexRow extends StatelessWidget {
  const _SettingsHexRow({
    super.key,
    required this.title,
    required this.help,
    required this.value,
    required this.fieldKey,
    required this.invalidMessage,
    required this.onSubmitted,
  });

  final String title;
  final String help;
  final String value;
  final Key fieldKey;
  final String invalidMessage;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpace.x16,
        vertical: DsSpace.x12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: DsSpace.x4),
          Text(
            help,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: DsSpace.x8),
          _HexColorField(
            value: value,
            fieldKey: fieldKey,
            errorMessage: invalidMessage,
            onSubmitted: onSubmitted,
          ),
        ],
      ),
    );
  }
}
