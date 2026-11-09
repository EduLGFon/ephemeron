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
  });

  final String body;
  final ValueChanged<int>? onToggleTask;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final widgets = _blockWidgets(context, body, onToggleTask);
    if (widgets.isEmpty) {
      return const Text('Nothing to preview');
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

final _fencePattern = RegExp(r'^ {0,3}(`{3,}|~{3,})');

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
/// fenced code blocks are copied verbatim so their content is not corrupted.
String _hardBreakSoftNewlines(String markdown) {
  final lines = markdown.split('\n');
  final out = <String>[];
  String? openFence;
  for (final line in lines) {
    if (openFence != null) {
      out.add(line);
      final trimmed = line.trimLeft();
      if (trimmed.startsWith(openFence) &&
          trimmed.substring(openFence.length).trim().isEmpty) {
        openFence = null;
      }
      continue;
    }
    final fence = _fencePattern.firstMatch(line);
    if (fence != null) {
      openFence = fence.group(1);
      out.add(line);
      continue;
    }
    if (line.trim().isEmpty || line.endsWith('  ') || line.endsWith('\\')) {
      out.add(line);
    } else {
      out.add('$line  ');
    }
  }
  return out.join('\n');
}

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
  ValueChanged<int>? onToggleTask,
) {
  final prepared = _hardBreakSoftNewlines(_normalizeLineEndings(body));
  final doc = md.Document(
    blockSyntaxes: md.ExtensionSet.gitHubFlavored.blockSyntaxes,
    inlineSyntaxes: md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
  );
  final nodes = doc.parseLines(prepared.split('\n'));
  final blocks = _Blocks(context, onToggleTask: onToggleTask);
  for (final n in nodes) {
    n.accept(blocks);
  }
  return blocks.widgets;
}

class _Blocks implements md.NodeVisitor {
  _Blocks(this.context, {this.onToggleTask});

  final BuildContext context;
  final ValueChanged<int>? onToggleTask;
  final widgets = <Widget>[];
  int listDepth = 0;
  int taskIndex = 0;

  TextStyle get _base =>
      Theme.of(context).textTheme.bodyMedium ?? const TextStyle();

  @override
  bool visitElementBefore(md.Element element) {
    final tag = element.tag;
    if (tag.startsWith('h')) {
      final level = int.tryParse(tag.substring(1)) ?? 1;
      widgets.add(
        Padding(
          padding: EdgeInsets.only(top: level == 1 ? 16 : 12, bottom: 4),
          child: Text(
            element.textContent,
            style: _base.copyWith(
              fontSize: 22 - level * 2.0,
              fontWeight: FontWeight.bold,
            ),
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
        widgets.add(
          CheckboxListTile(
            value: checked,
            onChanged: onToggleTask == null ? null : (_) => onToggleTask!(idx),
            title: Text(label.isEmpty ? '(task)' : label),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        );
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
        if (href != null) {
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
        if (href != null) {
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
