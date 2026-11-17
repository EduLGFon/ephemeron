/// Command palette widget. Presentation only, no providers.
library;

import 'package:flutter/foundation.dart' show ValueListenable, listEquals;
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:material_ui/material_ui.dart';

import 'command_palette_row.dart';
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
  });

  final String? query;
  final ValueListenable<String>? queryListenable;
  final List<CommandCandidate> candidates;
  final ValueChanged<CommandCandidate> onSelected;
  final VoidCallback? onDismiss;
  final int maxResults;
  final String emptyLabel;
  final String? listSemanticLabel;

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  late final FocusNode _focusNode;
  int _selectedIndex = 0;
  int _hovered = -1;
  String _lastQuery = '';
  List<String> _lastIds = const <String>[];

  String get _queryText => widget.queryListenable?.value ?? widget.query ?? '';

  List<CommandCandidate> get _filtered {
    final ranked = fuzzyRank<CommandCandidate>(
      _queryText,
      widget.candidates,
      (c) => c.label,
    );
    if (ranked.length <= widget.maxResults) return ranked;
    return ranked.sublist(0, widget.maxResults);
  }

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    widget.queryListenable?.addListener(_onQueryChanged);
  }

  @override
  void didUpdateWidget(CommandPalette oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.queryListenable != widget.queryListenable) {
      oldWidget.queryListenable?.removeListener(_onQueryChanged);
      widget.queryListenable?.addListener(_onQueryChanged);
    }
  }

  void _onQueryChanged() {
    if (mounted) setState(() => _selectedIndex = 0);
  }

  @override
  void dispose() {
    widget.queryListenable?.removeListener(_onQueryChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    final ids = list.map((c) => c.id).toList(growable: false);
    final queryChanged = _queryText != _lastQuery;
    final idsChanged = !listEquals(ids, _lastIds);
    if (queryChanged || idsChanged) {
      _lastQuery = _queryText;
      _lastIds = ids;
      _hovered = -1;
      if (_selectedIndex >= list.length && list.isNotEmpty) {
        _selectedIndex = list.length - 1;
      }
      if (list.isEmpty) _selectedIndex = 0;
    }

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
                itemBuilder: (context, i) {
                  final c = list[i];
                  return CommandPaletteRow(
                    candidate: c,
                    selected: i == _selectedIndex,
                    hovered: i == _hovered,
                    onHoverChanged: (h) =>
                        setState(() => _hovered = h ? i : -1),
                    onTap: () => widget.onSelected(c),
                  );
                },
              ),
      ),
    );
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
}
