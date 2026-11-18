part of '../../search_screen.dart';

class _SnippetLine extends StatelessWidget {
  const _SnippetLine({required this.snippet, required this.query});

  final String snippet;
  final String query;

  @override
  Widget build(BuildContext context) {
    final emphasis = Theme.of(context).textTheme.bodySmall
        ?.copyWith(fontWeight: FontWeight.w700);
    return Text.rich(
      TextSpan(
        children: [
          for (final span in highlightSnippet(snippet, sanitizeSearch(query)))
            TextSpan(text: span.text, style: span.bold ? emphasis : null),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
