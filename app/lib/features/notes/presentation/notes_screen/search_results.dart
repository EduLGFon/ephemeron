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
    final scheme = Theme.of(context).colorScheme;
    final subtitleStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    return Scaffold(
      appBar: AppBar(title: Text('Results for "$query"')),
      body: hits.isEmpty
          ? EmptyState(
              icon: Icons.search_off,
              title: 'No matches',
              subtitle: 'Nothing matched "$query".',
            )
          : RepaintBoundary(
              child: ListView.builder(
                itemCount: hits.length,
                itemBuilder: (context, i) {
                  final hit = hits[i];
                  final note = hit.note;
                  return ListTile(
                    title: Text(note.title.isEmpty ? '(untitled)' : note.title),
                    subtitle: Text.rich(
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
                    trailing: Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    onTap: () => onOpen(note.id),
                  );
                },
              ),
            ),
    );
  }
}
