part of '../notes_screen.dart';

// New-note template sheet rows and the FTS search dialog.

/// One selectable template row in the new-note sheet.
class _TemplateOption extends StatelessWidget {
  const _TemplateOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpace.x16,
        vertical: DsSpace.x4,
      ),
      child: AppSurface(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpace.x16,
          vertical: DsSpace.x12,
        ),
        child: Row(
          children: [
            Icon(icon, size: DsIcon.md),
            const SizedBox(width: DsSpace.x12),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Owns the search field controller so it outlives the dialog route's exit
/// animation and is disposed with the route state.
class _SearchDialog extends StatefulWidget {
  const _SearchDialog({required this.initialQuery, required this.strings});

  final String initialQuery;
  final NotesStrings strings;

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    return AlertDialog(
      title: Text(strings.searchNotes),
      content: AppSearchField(
        key: const Key('notes-search-field'),
        controller: _controller,
        hintText: strings.searchNotes,
        autofocus: true,
        onSubmitted: _submit,
      ),
      actions: [
        AppButton(
          label: strings.cancel,
          variant: AppButtonVariant.ghost,
          onPressed: () {
            AppFeedback.tap();
            Navigator.of(context).pop();
          },
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) {
            return AppButton(
              label: strings.search,
              onPressed: value.text.trim().isEmpty
                  ? null
                  : () => _submit(value.text),
            );
          },
        ),
      ],
    );
  }

  void _submit(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    AppFeedback.selection();
    Navigator.of(context).pop(query);
  }
}
