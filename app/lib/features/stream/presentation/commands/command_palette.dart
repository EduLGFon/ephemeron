/// Command palette widget. Presentation only, no providers.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:material_ui/material_ui.dart';

import 'fuzzy.dart';

class CommandCandidate {
  const CommandCandidate({
    required this.id,
    required this.label,
    this.subtitle = '',
    this.kind = '',
  });

  final String id;
  final String label;
  final String subtitle;
  final String kind;
}

class CommandPalette extends StatefulWidget {
  const CommandPalette({
    super.key,
    this.query,
    this.queryListenable,
    required this.candidates,
    required this.onSelected,
    this.onDismiss,
    this.maxResults = 6,
    this.emptyLabel = '',
    this.listSemanticLabel,
    this.itemExtent = 56,
  });

  final Object? query;
  final ValueListenable<String>? queryListenable;
  final List<CommandCandidate> candidates;
  final ValueChanged<CommandCandidate> onSelected;
  final VoidCallback? onDismiss;
  final int maxResults;
  final String emptyLabel;
  final String? listSemanticLabel;
  final double itemExtent;

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  late final FocusNode _focusNode;
  int _selectedIndex = 0;
  int _hovered = -1;

  ValueListenable<String>? get _listenable {
    if (widget.queryListenable != null) return widget.queryListenable;
    final q = widget.query;
    if (q is ValueListenable<String>) return q;
    return null;
  }

  String get _queryText {
    final q = widget.query;
    if (q is String) return q;
    if (q is ValueListenable<String>) return q.value;
    return '';
  }

  List<CommandCandidate> get _filtered {
    final q = _queryText;
    final list = fuzzyRank<CommandCandidate>(
      q,
      widget.candidates,
      (c) => c.label,
    );
    if (list.length <= widget.maxResults) return list;
    return list.sublist(0, widget.maxResults);
  }

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    final l = _listenable;
    l?.addListener(_onQueryChanged);
  }

  @override
  void didUpdateWidget(CommandPalette oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.queryListenable != widget.queryListenable) {
      oldWidget.queryListenable?.removeListener(_onQueryChanged);
      widget.queryListenable?.addListener(_onQueryChanged);
    }
    if (oldWidget.query != widget.query &&
        oldWidget.query is ValueListenable<String> &&
        widget.query is ValueListenable<String> &&
        oldWidget.query != widget.query) {
      (oldWidget.query as ValueListenable<String>).removeListener(
        _onQueryChanged,
      );
      (widget.query as ValueListenable<String>).addListener(_onQueryChanged);
    }
  }

  void _onQueryChanged() {
    if (mounted) setState(() => _selectedIndex = 0);
  }

  @override
  void dispose() {
    _listenable?.removeListener(_onQueryChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _move(int delta) {
    final n = _filtered.length;
    if (n == 0) return;
    setState(() {
      _selectedIndex = (_selectedIndex + delta).clamp(0, n - 1);
    });
  }

  void _select() {
    final list = _filtered;
    if (list.isEmpty) return;
    if (_selectedIndex >= list.length) _selectedIndex = list.length - 1;
    widget.onSelected(list[_selectedIndex]);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _move(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _move(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter) {
      _select();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      widget.onDismiss?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    if (_selectedIndex >= list.length && list.isNotEmpty) {
      _selectedIndex = list.length - 1;
    }
    if (list.isEmpty) _selectedIndex = 0;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Semantics(
        container: true,
        label: widget.listSemanticLabel,
        child: list.isEmpty
            ? Center(child: Text(widget.emptyLabel))
            : ListView.builder(
                itemCount: list.length,
                itemExtent: widget.itemExtent,
                itemBuilder: (context, i) {
                  final c = list[i];
                  final selected = i == _selectedIndex;
                  final hovered = i == _hovered;
                  return MouseRegion(
                    onEnter: (_) => setState(() => _hovered = i),
                    onExit: (_) => setState(() => _hovered = -1),
                    child: Semantics(
                      button: true,
                      selected: selected,
                      label: c.label,
                      child: InkWell(
                        key: ValueKey(c.id),
                        onTap: () => widget.onSelected(c),
                        child: Container(
                          color: (selected || hovered)
                              ? Theme.of(context).highlightColor
                              : null,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (c.subtitle.isNotEmpty)
                                      Text(
                                        c.subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
