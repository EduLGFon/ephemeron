import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';
import 'tray_item.dart';

class TrayPanelItem extends StatefulWidget {
  const TrayPanelItem({
    super.key,
    required this.item,
    required this.unnamedGroupLabel,
    this.onTap,
  });

  final TrayItem item;
  final String unnamedGroupLabel;
  final VoidCallback? onTap;

  @override
  State<TrayPanelItem> createState() => _TrayPanelItemState();
}

class _TrayPanelItemState extends State<TrayPanelItem> {
  final FocusNode _focusNode = FocusNode();
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(
      () => setState(() => _focused = _focusNode.hasFocus),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  String get _listName => widget.item.listName.isEmpty
      ? widget.unnamedGroupLabel
      : widget.item.listName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = Color(widget.item.colorArgb);
    final actionable = widget.onTap != null;
    return Semantics(
      button: actionable,
      excludeSemantics: true,
      label: '${widget.item.title}, $_listName',
      onTap: widget.onTap,
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space)) {
            widget.onTap?.call();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: () {
              _focusNode.requestFocus();
              widget.onTap?.call();
            },
            child: Container(
              height: 48,
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: StreamSpacing.x2,
              ),
              decoration: BoxDecoration(
                color: _pressed
                    ? scheme.surfaceContainerHighest
                    : (_hovered ? scheme.surfaceContainerHigh : null),
                border: _focused
                    ? Border.all(color: scheme.primary, width: 2)
                    : null,
              ),
              child: Row(
                children: [
                  Container(width: 3, height: 20, color: color),
                  const SizedBox(width: StreamSpacing.x2),
                  Expanded(
                    child: Text(
                      widget.item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
