// Lightweight Markdown renderer to widgets. Parses with the GitHub
// flavored set, builds each block once, renders blocks lazily in a
// ListView. Tappable task-list items call [onToggleTask] with the Nth
// task line index in the source.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;

import '../../../core/platform/system_launcher.dart';

class MarkdownPreview extends StatelessWidget {
  const MarkdownPreview({super.key, required this.body, this.onToggleTask});

  final String body;
  final ValueChanged<int>? onToggleTask;

  @override
  Widget build(BuildContext context) {
    final widgets = _blockWidgets(context, body, onToggleTask);
    if (widgets.isEmpty) {
      return const Text('Nothing to preview');
    }
    return RepaintBoundary(
      child: ListView(padding: const EdgeInsets.all(16), children: widgets),
    );
  }
}

/// Non-scrollable Markdown body for embedding inside an existing scroll view
/// (for example event details). Uses the same blocks as [MarkdownPreview].
class MarkdownBody extends StatelessWidget {
  const MarkdownBody({
    super.key,
    required this.body,
    this.onToggleTask,
    this.padding = EdgeInsets.zero,
    this.compact = false,
    this.interactive = true,
  });

  final String body;
  final ValueChanged<int>? onToggleTask;
  final EdgeInsetsGeometry padding;
  final bool compact;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    if (compact && body.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final widgets = _blockWidgets(
      context,
      body,
      onToggleTask,
      compact: compact,
      interactive: interactive,
    );
    if (widgets.isEmpty) {
      return compact
          ? const SizedBox.shrink()
          : const Text('Nothing to preview');
    }
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widgets,
      ),
    );
  }
}

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

/// Text of [node] with `<br>` elements rendered as newlines.
///
/// `md.Element.textContent` returns an empty string for `<br>`, so block
/// widgets that use it would collapse the hard breaks added by
/// [_hardBreakSoftNewlines]. Paragraphs use [_Blocks._spans] instead.
String _textWithBreaks(md.Node node) {
  if (node is md.Text) return node.text;
  if (node is md.Element) {
    if (node.tag == 'br') return '\n';
    final children = node.children;
    if (children == null) return '';
    return children.map(_textWithBreaks).join();
  }
  return node.textContent;
}

List<Widget> _blockWidgets(
  BuildContext context,
  String body,
  ValueChanged<int>? onToggleTask, {
  bool compact = false,
  bool interactive = true,
}) {
  final prepared = prepareMarkdownForRender(body);
  final doc = md.Document(
    blockSyntaxes: md.ExtensionSet.gitHubFlavored.blockSyntaxes,
    inlineSyntaxes: md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
  );
  final nodes = doc.parseLines(prepared.split('\n'));
  final blocks = _Blocks(
    context,
    onToggleTask: onToggleTask,
    compact: compact,
    interactive: interactive,
  );
  for (final n in nodes) {
    n.accept(blocks);
  }
  return blocks.widgets;
}

class _Blocks implements md.NodeVisitor {
  _Blocks(
    this.context, {
    this.onToggleTask,
    this.compact = false,
    this.interactive = true,
  });

  final BuildContext context;
  final ValueChanged<int>? onToggleTask;
  final bool compact;
  final bool interactive;
  final widgets = <Widget>[];
  int listDepth = 0;
  int taskIndex = 0;

  TextStyle get _base {
    final s = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    return compact ? s.copyWith(fontSize: 11) : s;
  }

  @override
  bool visitElementBefore(md.Element element) {
    final tag = element.tag;
    if (tag.startsWith('h')) {
      final level = int.tryParse(tag.substring(1)) ?? 1;
      final size = compact
          ? (14 - (level - 1).clamp(0, 3) * 1.0)
          : (22 - level * 2.0);
      widgets.add(
        Padding(
          padding: EdgeInsets.only(
            top: compact ? 4 : (level == 1 ? 16 : 12),
            bottom: 2,
          ),
          child: Text(
            element.textContent,
            style: _base.copyWith(fontSize: size, fontWeight: FontWeight.bold),
            maxLines: compact ? 2 : null,
            overflow: compact ? TextOverflow.ellipsis : TextOverflow.clip,
          ),
        ),
      );
      return false;
    }
    if (tag == 'p') {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RichText(text: _spans(element, _base)),
        ),
      );
      return false;
    }
    if (tag == 'ul' || tag == 'ol') {
      listDepth++;
      return true;
    }
    if (tag == 'li') {
      // GitHub-flavored task lists parse to <li class="task-list-item">
      // with an <input type="checkbox"> child; textContent no longer
      // contains the "[ ]" marker, so detect via the input element.
      final children = element.children ?? const <md.Node>[];
      md.Element? checkbox;
      for (final c in children) {
        if (c is md.Element &&
            c.tag == 'input' &&
            c.attributes['type'] == 'checkbox') {
          checkbox = c;
          break;
        }
      }
      final isTask =
          checkbox != null || element.attributes['class'] == 'task-list-item';
      if (isTask) {
        final idx = taskIndex++;
        final checked = checkbox?.attributes.containsKey('checked') ?? false;
        final label = _textWithBreaks(element).trim();
        if (compact) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '${checked ? '[x]' : '[ ]'} ${label.isEmpty ? '(task)' : label}',
                style: _base,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        } else {
          widgets.add(
            CheckboxListTile(
              value: checked,
              onChanged: onToggleTask == null
                  ? null
                  : (_) => onToggleTask!(idx),
              title: Text(label.isEmpty ? '(task)' : label),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          );
        }
      } else {
        final text = _textWithBreaks(element).trim();
        widgets.add(
          Padding(
            padding: EdgeInsets.only(left: listDepth * 16.0, bottom: 2),
            child: Text('- $text', style: _base),
          ),
        );
      }
      return false;
    }
    if (tag == 'pre') {
      widgets.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.only(bottom: 8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Text(
            element.textContent,
            style: _base.copyWith(fontFamily: 'monospace', fontSize: 13),
          ),
        ),
      );
      return false;
    }
    if (tag == 'blockquote') {
      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 3,
              ),
            ),
          ),
          child: Text(_textWithBreaks(element), style: _base),
        ),
      );
      return false;
    }
    return true;
  }

  @override
  void visitText(md.Text text) {}

  @override
  void visitElementAfter(md.Element element) {
    if (element.tag == 'ul' || element.tag == 'ol') listDepth--;
  }

  TextSpan _spans(md.Element element, TextStyle base) {
    final spans = <InlineSpan>[];
    for (final child in element.children ?? const <md.Node>[]) {
      if (child is md.Text) {
        // Markdown soft breaks stay as "\n" in the AST; Flutter lays them out
        // as line breaks, so plain single newlines stay visible.
        spans.add(TextSpan(text: child.text, style: base));
      } else if (child is md.Element) {
        if (child.tag == 'br') {
          // Hard breaks (`  \n` or `\\\n`) parse to <br>; keep the break.
          spans.add(TextSpan(text: '\n', style: base));
          continue;
        }
        final href = child.tag == 'a' ? child.attributes['href'] : null;
        TapGestureRecognizer? linkTap;
        if (href != null && interactive) {
          final url = href;
          linkTap = TapGestureRecognizer()
            ..onTap = () {
              SystemLauncher.openUrl(url);
            };
        }
        final inner = _spans(child, base).children ?? [];
        final style = switch (child.tag) {
          'strong' || 'b' => base.copyWith(fontWeight: FontWeight.bold),
          'em' || 'i' => base.copyWith(fontStyle: FontStyle.italic),
          'code' => base.copyWith(
            fontFamily: 'monospace',
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
          ),
          'a' => base.copyWith(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
          'del' => base.copyWith(decoration: TextDecoration.lineThrough),
          _ => base,
        };
        if (inner.isEmpty) {
          spans.add(
            TextSpan(
              text: child.textContent,
              style: style,
              recognizer: linkTap,
            ),
          );
        } else {
          for (final s in inner) {
            if (s is TextSpan) {
              spans.add(
                TextSpan(
                  text: s.text,
                  style: (s.style ?? base).merge(style),
                  recognizer: s.recognizer ?? linkTap,
                ),
              );
            } else {
              spans.add(s);
            }
          }
        }
        if (href != null && interactive) {
          spans.add(
            TextSpan(
              text: ' ($href)',
              style: base.copyWith(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
              recognizer: linkTap,
            ),
          );
        }
      }
    }
    return TextSpan(children: spans, style: base);
  }
}

/// Word and character counts for the editor status line.
({int words, int chars}) countWords(String text) {
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  return (words: words, chars: text.length);
}
