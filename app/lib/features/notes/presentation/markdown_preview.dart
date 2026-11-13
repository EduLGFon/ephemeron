// Lightweight Markdown renderer to widgets. Parses with the GitHub
// flavored set, builds each block once, renders blocks lazily in a
// ListView. Tappable task-list items call [onToggleTask] with the Nth
// task line index in the source.
//
// The renderer is a single Dart library split into `part` files under
// presentation/markdown_preview/ so source preprocessing and block rendering
// stay focused while private members remain shared within the library. The
// entry point and import path are unchanged for existing importers.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;

import '../../../core/platform/system_launcher.dart';

part 'markdown_preview/blocks.dart';
part 'markdown_preview/source.dart';

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

/// Word and character counts for the editor status line.
({int words, int chars}) countWords(String text) {
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  return (words: words, chars: text.length);
}
