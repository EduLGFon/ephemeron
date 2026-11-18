part of '../notes_screen.dart';

// Trash screen: restore notes that were soft-deleted.

class _TrashScreen extends ConsumerWidget {
  const _TrashScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = NotesStrings.of(context);
    final trashAsync = ref.watch(noteTrashProvider);
    return AppPage(
      header: AppPageHeader(
        title: Text(strings.trash),
        leading: AppIconButton(
          icon: Icons.arrow_back,
          tooltip: strings.back,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      child: trashAsync.when(
        loading: () => const AppSkeletonList(rows: 5),
        error: (e, _) => _ErrorState(
          message: strings.errorTrash,
          onRetry: () => ref.invalidate(noteTrashProvider),
        ),
        data: (notes) {
          if (notes.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                child: AppEmptyState(
                  icon: Icons.delete_outline,
                  title: strings.trashEmptyTitle,
                  message: strings.trashEmptyMessage,
                ),
              ),
            );
          }
          return RepaintBoundary(
            child: ListView.builder(
              key: const Key('notes-trash-list'),
              padding: const EdgeInsets.only(bottom: DsSpace.x24),
              itemCount: notes.length,
              itemBuilder: (context, i) {
                final note = notes[i];
                final title = note.title.isEmpty
                    ? strings.untitled
                    : note.title;
                return Padding(
                  padding: const EdgeInsets.only(bottom: DsSpace.x8),
                  child: AppSurface(
                    padding: const EdgeInsets.fromLTRB(
                      DsSpace.x16,
                      DsSpace.x4,
                      DsSpace.x4,
                      DsSpace.x4,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        AppIconButton(
                          icon: Icons.restore,
                          tooltip: strings.restore,
                          semanticLabel: strings.restoreNote(title),
                          onPressed: () => ref
                              .read(noteRepositoryProvider)
                              .restoreNote(note.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
