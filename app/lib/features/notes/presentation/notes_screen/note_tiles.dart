part of '../notes_screen.dart';

// Note rows and grid cards shared by both notes list layouts.

abstract final class _NoteTiles {
  static Widget row(
    BuildContext context,
    WidgetRef ref,
    Note note,
    ValueChanged<Note> onTap,
  ) {
    final theme = Theme.of(context);
    final strings = NotesStrings.of(context);
    final title = note.title.isEmpty ? strings.untitled : note.title;
    final subtitle = _subtitle(note, strings);
    return Dismissible(
      key: ValueKey('note-${note.id}'),
      direction: DismissDirection.endToStart,
      background: _trashBackground(context),
      confirmDismiss: (_) => _trash(context, ref, note, title, strings),
      child: AppSurface(
        onTap: () => onTap(note),
        tonal: note.pinned,
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpace.x12,
          vertical: DsSpace.x8,
        ),
        child: Row(
          children: [
            Icon(
              Icons.description_outlined,
              size: DsIcon.md,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: DsSpace.x12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (note.pinned) ...[
                        Semantics(
                          label: strings.pinned,
                          child: Icon(
                            Icons.push_pin,
                            size: DsIcon.sm,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: DsSpace.x4),
                      ],
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: DsSpace.x4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: DsSpace.x4),
                  Text(
                    _updatedLabel(context, note),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: DsIcon.sm,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  static Widget card(
    BuildContext context,
    WidgetRef ref,
    Note note,
    ValueChanged<Note> onTap,
  ) {
    final theme = Theme.of(context);
    final strings = NotesStrings.of(context);
    final title = note.title.isEmpty ? strings.untitled : note.title;
    final body = (note.body ?? '').trim();
    final sliced = body.length > 500 ? body.substring(0, 500) : body;
    return RepaintBoundary(
      child: Dismissible(
        key: ValueKey('card-${note.id}'),
        direction: DismissDirection.endToStart,
        background: _trashBackground(context),
        confirmDismiss: (_) => _trash(context, ref, note, title, strings),
        child: AppSurface(
          onTap: () => onTap(note),
          tonal: note.pinned,
          padding: const EdgeInsets.all(DsSpace.x12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (note.pinned) ...[
                    Semantics(
                      label: strings.pinned,
                      child: Icon(
                        Icons.push_pin,
                        size: DsIcon.sm,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: DsSpace.x4),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DsSpace.x4),
              Expanded(
                child: ClipRect(
                  child: IgnorePointer(
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: MarkdownBody(
                        body: sliced,
                        compact: true,
                        interactive: false,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: DsSpace.x4),
              Text(
                _updatedLabel(context, note),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _trashBackground(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.error,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: DsSpace.x16),
      child: Icon(Icons.delete, color: scheme.onError),
    );
  }

  static Future<bool> _trash(
    BuildContext context,
    WidgetRef ref,
    Note note,
    String title,
    NotesStrings strings,
  ) async {
    final pending = ref.read(pendingOperationsProvider);
    final opId = await pending.scheduleNoteTrash(note.id);
    if (context.mounted) {
      showUndoSnackBar(
        context,
        strings.trashed(title),
        onUndo: () => pending.cancel(opId),
      );
    }
    return false;
  }

  static String _updatedLabel(BuildContext context, Note note) {
    return DeviceDateFormat.date(
      context,
      DateTime.fromMillisecondsSinceEpoch(note.updatedAt).toLocal(),
    );
  }

  static String? _subtitle(Note note, NotesStrings strings) {
    final body = (note.body ?? '').trim();
    if (body.isEmpty && note.linkedEventId == null) return null;
    final first = body
        .split('\n')
        .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    final text = note.linkedEventId != null
        ? '${strings.linkedEventPrefix} $first'
        : first;
    if (text.isEmpty) return null;
    return text;
  }
}
