import 'package:material_ui/material_ui.dart';

/// Start/end time row for the Peek editor.
class PeekTimeRow extends StatelessWidget {
  const PeekTimeRow({
    super.key,
    required this.formatTime,
    required this.startMs,
    required this.endMs,
    this.startLabel,
    this.endLabel,
    this.addEndLabel,
    this.clearEndLabel,
    this.endErrorText,
    required this.onPickStart,
    required this.onPickEnd,
    this.onClearEnd,
  });

  final String Function(int ms) formatTime;
  final int startMs;
  final int? endMs;
  final String? startLabel;
  final String? endLabel;
  final String? addEndLabel;
  final String? clearEndLabel;
  final String? endErrorText;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback? onClearEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _TimeField(
                label: startLabel,
                value: formatTime(startMs),
                onTap: onPickStart,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TimeField(
                label: endLabel,
                value: endMs == null ? (addEndLabel ?? '') : formatTime(endMs!),
                onTap: onPickEnd,
              ),
            ),
          ],
        ),
        if (endErrorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              endErrorText!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (clearEndLabel != null && endMs != null && onClearEnd != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onClearEnd,
              child: Text(clearEndLabel!),
            ),
          ),
      ],
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({this.label, required this.value, this.onTap});
  final String? label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value),
      ),
    );
  }
}
