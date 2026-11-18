part of '../notes_screen.dart';

// Search results screen.

/// Splits [snippet] into spans, bolding every case-insensitive occurrence of
/// [query] with [highlightColor]. Text is preserved exactly, including literal
/// `<b>` sequences, because the repository returns plain snippet text.
List<TextSpan> highlightSnippetSpans(
  String snippet, {
  required String query,
  TextStyle? baseStyle,
  required Color highlightColor,
}) {
  final needle = query.trim();
  final boldStyle = (baseStyle ?? const TextStyle()).copyWith(
    fontWeight: FontWeight.bold,
    color: highlightColor,
  );
  if (needle.isEmpty || snippet.isEmpty) {
    return [TextSpan(text: snippet, style: baseStyle)];
  }
  final pattern = RegExp(RegExp.escape(needle), caseSensitive: false);
  final spans = <TextSpan>[];
  var index = 0;
  for (final match in pattern.allMatches(snippet)) {
    if (match.start > index) {
      spans.add(
        TextSpan(text: snippet.substring(index, match.start), style: baseStyle),
      );
    }
    spans.add(TextSpan(text: match.group(0), style: boldStyle));
    index = match.end;
  }
  if (index < snippet.length) {
    spans.add(TextSpan(text: snippet.substring(index), style: baseStyle));
  }
  return spans;
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.query,
    required this.hits,
    required this.onOpen,
  });

  final String query;
  final List<NoteSearchHit> hits;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final strings = NotesStrings.of(context);
    return AppPage(
      header: AppPageHeader(
        title: Text(strings.resultsFor(query)),
        leading: AppIconButton(
          icon: Icons.arrow_back,
          tooltip: strings.back,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      child: hits.isEmpty
          ? Center(
              child: SingleChildScrollView(
                child: AppEmptyState(
                  icon: Icons.search_off,
                  title: strings.noMatchesTitle,
                  message: strings.nothingMatched(query),
                ),
              ),
            )
          : _resultList(context, strings),
    );
  }

  Widget _resultList(BuildContext context, NotesStrings strings) {
    final scheme = Theme.of(context).colorScheme;
    final subtitleStyle = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: scheme.onSurfaceVariant);
    return RepaintBoundary(
      child: ListView.builder(
        key: const Key('notes-search-results'),
        padding: const EdgeInsets.only(bottom: DsSpace.x24),
        itemCount: hits.length,
        itemBuilder: (context, i) {
          final hit = hits[i];
          final note = hit.note;
          return Padding(
            padding: const EdgeInsets.only(bottom: DsSpace.x8),
            child: AppSurface(
              onTap: () => onOpen(note.id),
              padding: const EdgeInsets.symmetric(
                horizontal: DsSpace.x16,
                vertical: DsSpace.x12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          note.title.isEmpty ? strings.untitled : note.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: DsSpace.x4),
                        Text.rich(
                          TextSpan(
                            style: subtitleStyle,
                            children: highlightSnippetSpans(
                              hit.snippet,
                              query: query,
                              baseStyle: subtitleStyle,
                              highlightColor: scheme.primary,
                            ),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: DsSpace.x8),
                  Icon(
                    Icons.chevron_right,
                    size: DsIcon.sm,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
