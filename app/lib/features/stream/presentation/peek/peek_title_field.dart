import 'package:material_ui/material_ui.dart';

/// Title field for the Peek editor.
class PeekTitleField extends StatelessWidget {
  const PeekTitleField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.label,
    this.errorText,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? label;
  final String? errorText;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: key,
      controller: controller,
      focusNode: focusNode,
      autofocus: true,
      decoration: InputDecoration(labelText: label, errorText: errorText),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => onSubmitted(),
    );
  }
}
