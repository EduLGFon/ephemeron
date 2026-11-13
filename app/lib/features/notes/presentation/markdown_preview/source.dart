part of '../markdown_preview.dart';

/// Normalizes every line ending an editor or clipboard can produce to `\n`.
///
/// CRLF, bare CR, and the Unicode line/paragraph separators all render as
/// newlines to the user, so the renderer treats them the same way.
String _normalizeLineEndings(String body) => body
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .replaceAll('\u2028', '\n')
    .replaceAll('\u2029', '\n');

final _fencePattern = RegExp(r'^ {0,3}(`{3,}|~{3,})(.*)$');
final _fenceClosePattern = RegExp(r'^ {0,3}(`{3,}|~{3,})[ \t]*$');
final _indentedCodePattern = RegExp(r'^(?: {4,}|\t)');

/// Render-only preprocessing: turns soft newlines into Markdown hard breaks.
///
/// Flutter's Markdown AST represents a soft break as a `"\n"` text run in
/// paragraphs, but block widgets that read `element.textContent` drop `<br>`
/// nodes entirely. Users expect Enter to always start a visible new line, so
/// append the two trailing spaces that Markdown treats as a hard break before
/// parsing. The parsed `<br>` is then rendered explicitly by [_Blocks._spans]
/// and [_textWithBreaks].
///
/// This never touches the stored note body. Lines that already end in two
/// spaces or a backslash are hard breaks already, blank lines stay blank, and
/// both fenced and indented code blocks are copied verbatim so their content
/// is not corrupted. Fence tracking stores the marker character and length, so
/// longer closing fences close the block and different or shorter fences stay
/// literal content.
String _hardBreakSoftNewlines(String markdown) {
  final lines = markdown.split('\n');
  final out = <String>[];
  String? fenceChar;
  var fenceLength = 0;
  var inIndentedCode = false;
  var previousBlank = true;
  for (final line in lines) {
    if (fenceChar != null) {
      out.add(line);
      final close = _fenceClosePattern.firstMatch(line);
      if (close != null) {
        final marker = close.group(1)!;
        if (marker[0] == fenceChar && marker.length >= fenceLength) {
          fenceChar = null;
          fenceLength = 0;
        }
      }
      previousBlank = false;
      continue;
    }
    if (inIndentedCode) {
      if (line.trim().isEmpty || _indentedCodePattern.hasMatch(line)) {
        out.add(line);
        previousBlank = line.trim().isEmpty;
        continue;
      }
      inIndentedCode = false;
    }
    final fence = _fencePattern.firstMatch(line);
    if (fence != null) {
      final marker = fence.group(1)!;
      final info = fence.group(2)!;
      // Backtick info strings may not contain backticks; such a line is inline
      // code or ordinary text, not a fence opener.
      if (!(marker[0] == '`' && info.contains('`'))) {
        fenceChar = marker[0];
        fenceLength = marker.length;
        out.add(line);
        previousBlank = false;
        continue;
      }
    }
    // An indented code block may start only after a blank line (or at the
    // document start); otherwise the indentation continues a paragraph or list.
    if (previousBlank && _indentedCodePattern.hasMatch(line)) {
      inIndentedCode = true;
      out.add(line);
      previousBlank = false;
      continue;
    }
    if (line.trim().isEmpty || line.endsWith('  ') || line.endsWith('\\')) {
      out.add(line);
    } else {
      out.add('$line  ');
    }
    previousBlank = line.trim().isEmpty;
  }
  return out.join('\n');
}

/// Normalizes line endings and applies render-only hard-break preprocessing.
///
/// Exposed for tests so fence and indented-code tracking can be asserted
/// without depending on widget layout.
@visibleForTesting
String prepareMarkdownForRender(String markdown) =>
    _hardBreakSoftNewlines(_normalizeLineEndings(markdown));
