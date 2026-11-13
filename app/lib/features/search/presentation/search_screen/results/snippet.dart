part of '../../search_screen.dart';

class _SnippetLine extends StatelessWidget {
  const _SnippetLine({required this.snippet, required this.query});

  final String snippet;
  final String query;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          for (final span in highlightSnippet(snippet, sanitizeSearch(query)))
            TextSpan(
              text: span.text,
              style: span.bold
                  ? const TextStyle(fontWeight: FontWeight.bold)
                  : null,
            ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
