import 'package:material_ui/material_ui.dart';

/// Notes field for the Peek editor.
/// Height is fixed at 120 dp (within the 72..160 dp range).
class PeekNotesField extends StatelessWidget {
  const PeekNotesField({super.key, required this.controller, this.label});

  final TextEditingController controller;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        maxLines: null,
        expands: true,
        keyboardType: TextInputType.multiline,
      ),
    );
  }
}
