/// Full-screen command palette overlay for the Stream surface. Owns only its
/// query state so opening or typing never rebuilds the canvas or dock.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:material_ui/material_ui.dart';

import '../../application/stream_command_actions.dart';
import '../../design/stream_tokens.dart';
import '../commands/command_palette.dart';
import 'stream_command_candidates.dart';

export 'stream_command_candidates.dart'
    show StreamCommandOverlayLabels, buildStreamCommandEntries;

/// Static-scrim palette above the Stream layout. [open] is a listenable so the
/// parent never rebuilds when the overlay opens, closes or filters.
class StreamCommandOverlay extends StatefulWidget {
  const StreamCommandOverlay({
    super.key,
    required this.open,
    required this.now,
    required this.labels,
    required this.onClose,
    required this.onSelected,
  });

  final ValueListenable<bool> open;
  final DateTime now;
  final StreamCommandOverlayLabels labels;
  final VoidCallback onClose;
  final ValueChanged<StreamCommandIntent> onSelected;

  @override
  State<StreamCommandOverlay> createState() => _StreamCommandOverlayState();
}

class _StreamCommandOverlayState extends State<StreamCommandOverlay> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _fieldFocus = FocusNode(debugLabel: 'streamCommandField');
  final ValueNotifier<String> _query = ValueNotifier<String>('');

  @override
  void initState() {
    super.initState();
    widget.open.addListener(_onOpenChanged);
  }

  @override
  void didUpdateWidget(StreamCommandOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.open != widget.open) {
      oldWidget.open.removeListener(_onOpenChanged);
      widget.open.addListener(_onOpenChanged);
    }
  }

  @override
  void dispose() {
    widget.open.removeListener(_onOpenChanged);
    _controller.dispose();
    _fieldFocus.dispose();
    _query.dispose();
    super.dispose();
  }

  void _onOpenChanged() {
    if (!widget.open.value) return;
    _controller.clear();
    _query.value = '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.open.value) _fieldFocus.requestFocus();
    });
  }

  /// The query field keeps focus while typing, so navigation keys bubble to
  /// this ancestor instead of the palette's own focus node. Forward them to
  /// the first descendant handler (the palette) so arrows and Enter keep
  /// working without stealing focus from the field.
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.arrowDown &&
        key != LogicalKeyboardKey.arrowUp &&
        key != LogicalKeyboardKey.enter &&
        key != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    for (final child in node.traversalDescendants) {
      final handler = child.onKeyEvent;
      if (handler == null) continue;
      final result = handler(child, event);
      if (result != KeyEventResult.ignored) return result;
    }
    return KeyEventResult.ignored;
  }

  void _select(StreamCommandIntent? intent) {
    if (intent == null) return;
    widget.onSelected(intent);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.open,
      builder: (context, open, _) {
        if (!open) return const SizedBox.shrink();
        final entries = buildStreamCommandEntries(
          now: widget.now,
          labels: widget.labels,
        );
        final intents = <String, StreamCommandIntent>{
          for (final entry in entries) entry.candidate.id: entry.intent,
        };
        final theme = Theme.of(context);
        return Stack(
          children: [
            Positioned.fill(
              child: ModalBarrier(
                key: const Key('streamCommandScrim'),
                dismissible: true,
                onDismiss: widget.onClose,
                semanticsLabel: widget.labels.close,
                color: Colors.black54,
              ),
            ),
            Positioned.fill(
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(StreamSpacing.x4),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 560,
                        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
                      ),
                      child: Material(
                        color: theme.colorScheme.surface,
                        elevation: 8,
                        borderRadius: BorderRadius.circular(StreamRadii.md),
                        clipBehavior: Clip.antiAlias,
                        child: Focus(
                          canRequestFocus: false,
                          skipTraversal: true,
                          onKeyEvent: _handleKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _Header(
                                title: widget.labels.title,
                                closeLabel: widget.labels.close,
                                onClose: widget.onClose,
                              ),
                              Padding(
                                padding: const EdgeInsetsDirectional.fromSTEB(
                                  StreamSpacing.x4,
                                  0,
                                  StreamSpacing.x4,
                                  StreamSpacing.x2,
                                ),
                                child: TextField(
                                  key: const Key('streamCommandField'),
                                  controller: _controller,
                                  focusNode: _fieldFocus,
                                  autofocus: true,
                                  textInputAction: TextInputAction.search,
                                  decoration: InputDecoration(
                                    hintText: widget.labels.hint,
                                    prefixIcon: const Icon(Icons.search),
                                  ),
                                  onChanged: (value) => _query.value = value,
                                ),
                              ),
                              Flexible(
                                child: CommandPalette(
                                  queryListenable: _query,
                                  candidates: [
                                    for (final entry in entries)
                                      entry.candidate,
                                  ],
                                  onSelected: (candidate) =>
                                      _select(intents[candidate.id]),
                                  onDismiss: widget.onClose,
                                  emptyLabel: widget.labels.empty,
                                  listSemanticLabel: widget.labels.title,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.closeLabel,
    required this.onClose,
  });

  final String title;
  final String closeLabel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        StreamSpacing.x4,
        StreamSpacing.x1,
        StreamSpacing.x1,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Semantics(
            button: true,
            label: closeLabel,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: IconButton(
                key: const Key('streamCommandClose'),
                onPressed: onClose,
                tooltip: closeLabel,
                icon: const Icon(Icons.close),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
