import 'package:flutter/services.dart'
    show LogicalKeyboardKey, KeyEvent, KeyDownEvent;
import 'package:material_ui/material_ui.dart';

import '../../capture/capture_parser.dart';

import 'capture_preview_chips.dart';

/// One-line capture bar with live preview chips above the input.
///
/// Caller positions this above keyboard insets (consume MediaQuery.viewInsets
/// in the parent); this widget adds no SafeArea or inset padding.
class CaptureBar extends StatefulWidget {
  const CaptureBar({
    super.key,
    required this.now,
    required this.locale,
    required this.hintText,
    required this.label,
    required this.chipsBuilder,
    this.semanticsLabel,
    this.submitLabel,
    this.clearLabel,
    this.closeLabel,
    this.onSubmitted,
    this.onDismiss,
    this.onChipTapped,
  });

  final DateTime now;
  final CaptureLocale locale;

  final String hintText;
  final String label;
  final String? semanticsLabel;

  final String? submitLabel;
  final String? clearLabel;
  final String? closeLabel;

  final List<CapturePreviewChip> Function(CaptureDraft) chipsBuilder;

  final ValueChanged<CaptureDraft>? onSubmitted;
  final VoidCallback? onDismiss;
  final ValueChanged<CaptureChipKind>? onChipTapped;

  @override
  State<CaptureBar> createState() => _CaptureBarState();
}

class _CaptureBarState extends State<CaptureBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final ValueNotifier<CaptureDraft?> _draft;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _draft = ValueNotifier<CaptureDraft?>(null);
    _controller.addListener(_parse);
  }

  @override
  void didUpdateWidget(covariant CaptureBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.now != widget.now || oldWidget.locale != widget.locale) {
      _parse();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_parse);
    _controller.dispose();
    _focusNode.dispose();
    _draft.dispose();
    super.dispose();
  }

  void _parse() {
    final text = _controller.text;
    if (text.isEmpty) {
      _draft.value = null;
      return;
    }
    _draft.value = parseCapture(text, locale: widget.locale, now: widget.now);
  }

  void _submit() {
    final text = _controller.text;
    final draft =
        _draft.value ??
        parseCapture(text, locale: widget.locale, now: widget.now);
    widget.onSubmitted?.call(draft);
    _controller.clear();
    _draft.value = null;
    _focusNode.requestFocus();
  }

  void _dismiss() {
    widget.onDismiss?.call();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _dismiss();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: _controller,
      focusNode: _focusNode,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        // When an explicit semantics label is supplied, keep it as the only
        // announced label to avoid "label\\nhint"-style duplicates.
        labelText: widget.semanticsLabel != null
            ? null
            : (widget.label.isEmpty ? null : widget.label),
        hintText: widget.hintText.isEmpty ? null : widget.hintText,
      ),
      minLines: 1,
      maxLines: 1,
    );

    final Widget fieldNode = widget.semanticsLabel == null
        ? field
        : Semantics(
            label: widget.semanticsLabel,
            container: true,
            child: field,
          );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Focus(
        onKeyEvent: _handleKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ValueListenableBuilder<CaptureDraft?>(
              valueListenable: _draft,
              builder: (context, draft, _) {
                if (draft == null) return const SizedBox.shrink();
                final chips = widget.chipsBuilder(draft);
                if (chips.isEmpty) return const SizedBox.shrink();
                return CapturePreviewChips(
                  chips: chips,
                  onChipTapped: widget.onChipTapped ?? (_) {},
                );
              },
            ),
            Row(
              children: <Widget>[
                Expanded(flex: 4, child: fieldNode),
                if (widget.clearLabel != null && widget.clearLabel!.isNotEmpty)
                  Flexible(
                    flex: 1,
                    child: TextButton(
                      onPressed: () => _controller.clear(),
                      child: Text(
                        widget.clearLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                if (widget.closeLabel != null && widget.closeLabel!.isNotEmpty)
                  Flexible(
                    flex: 1,
                    child: TextButton(
                      onPressed: _dismiss,
                      child: Text(
                        widget.closeLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                if (widget.submitLabel != null &&
                    widget.submitLabel!.isNotEmpty)
                  Flexible(
                    flex: 1,
                    child: TextButton(
                      onPressed: _submit,
                      child: Text(
                        widget.submitLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
