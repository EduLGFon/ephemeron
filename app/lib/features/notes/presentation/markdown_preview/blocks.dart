part of '../markdown_preview.dart';

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
            backgroundColor: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest,
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
