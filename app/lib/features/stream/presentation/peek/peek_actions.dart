import 'package:material_ui/material_ui.dart';

/// Save/cancel actions for the Peek editor.
class PeekActions extends StatelessWidget {
  const PeekActions({
    super.key,
    required this.saveLabel,
    required this.cancelLabel,
    required this.onSave,
    required this.onCancel,
  });

  final String saveLabel;
  final String cancelLabel;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      children: [
        TextButton(onPressed: onCancel, child: Text(cancelLabel)),
        FilledButton(onPressed: onSave, child: Text(saveLabel)),
      ],
    );
  }
}
