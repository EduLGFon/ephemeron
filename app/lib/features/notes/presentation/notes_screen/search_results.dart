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
