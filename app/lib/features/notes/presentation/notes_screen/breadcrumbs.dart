part of '../notes_screen.dart';

// Breadcrumb trail of folder chips from the root to the current folder.

class _Breadcrumbs extends ConsumerWidget {
  const _Breadcrumbs({required this.folderId, required this.onNavigate});

  final String? folderId;
  final ValueChanged<String?> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = NotesStrings.of(context);
    if (folderId == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: AppChip(
          label: strings.allNotes,
          icon: Icons.folder_outlined,
          selected: true,
          onTap: () => onNavigate(null),
        ),
      );
    }
    return FutureBuilder(
      future: ref.read(noteRepositoryProvider).breadcrumbs(folderId!),
      builder: (ctx, snap) {
        final crumbs = snap.data ?? const <Folder>[];
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              AppChip(
                label: strings.allNotes,
                icon: Icons.folder_outlined,
                onTap: () => onNavigate(null),
              ),
              for (final f in crumbs) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: DsSpace.x4),
                  child: Icon(Icons.chevron_right, size: DsIcon.sm),
                ),
                AppChip(
                  label: f.name,
                  selected: f.id == folderId,
                  onTap: () => onNavigate(f.id),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
