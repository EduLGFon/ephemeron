import 'package:flutter/services.dart'
    show LogicalKeyboardKey, KeyEvent, KeyDownEvent;
import 'package:material_ui/material_ui.dart';

import '../../capture/capture_parser.dart';
import '../../capture/capture_priority.dart';

import 'capture_preview_chips.dart';

/// One-line capture bar with live preview chips above the input.
///
/// The caller positions this widget above the keyboard insets (consume
/// MediaQuery.viewInsets in the parent); this widget adds no SafeArea or
/// inset padding so nothing is doubled.
class CaptureBar extends StatefulWidget {
  const CaptureBar({
    super.key,
    this.now,
    this.locale,
    this.hintText,
    this.hint,
    this.label,
    this.textFieldLabel,
    this.fieldLabel,
    this.semanticsLabel,
    this.clearLabel,
    this.clearText,
    this.clearButtonLabel,
    this.closeLabel,
    this.closeButtonLabel,
    this.dismissLabel,
    this.onSubmitted,
    this.onSubmit,
    this.onSubmitCapture,
    this.onDismiss,
    this.onClose,
    this.onChipTapped,
    this.onChipTap,
    this.chipsBuilder,
    this.chipBuilder,
    this.previewChipsBuilder,
    this.chipLabelBuilder,
  });

  final DateTime? now;
  final CaptureLocale? locale;

  final String? hintText;
  final String? hint;

  final String? label;
  final String? textFieldLabel;
  final String? fieldLabel;
  final String? semanticsLabel;

  final String? clearLabel;
  final String? clearText;
  final String? clearButtonLabel;

  final String? closeLabel;
  final String? closeButtonLabel;
  final String? dismissLabel;

  final ValueChanged<CaptureDraft>? onSubmitted;
  final ValueChanged<CaptureDraft>? onSubmit;
  final ValueChanged<CaptureDraft>? onSubmitCapture;

  final VoidCallback? onDismiss;
  final VoidCallback? onClose;

  final ValueChanged<CaptureChipKind>? onChipTapped;
  final ValueChanged<CaptureChipKind>? onChipTap;

  final List<CapturePreviewChip> Function(CaptureDraft)? chipsBuilder;
  final List<CapturePreviewChip> Function(CaptureDraft)? chipBuilder;
  final List<CapturePreviewChip> Function(CaptureDraft)? previewChipsBuilder;
  final String? Function(CaptureDraft, CaptureChipKind)? chipLabelBuilder;

  @override
  State<CaptureBar> createState() => _CaptureBarState();
}

class _CaptureBarState extends State<CaptureBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final ValueNotifier<CaptureDraft?> _draft;

  DateTime get _now => widget.now ?? DateTime.now();
  CaptureLocale get _locale => widget.locale ?? CaptureLocale.en;

  String get _hint => widget.hintText ?? widget.hint ?? '';
  String get _label =>
      widget.label ??
      widget.textFieldLabel ??
      widget.fieldLabel ??
      widget.semanticsLabel ??
      '';
  String get _clear =>
      widget.clearLabel ?? widget.clearText ?? widget.clearButtonLabel ?? '';
  String get _close =>
      widget.closeLabel ?? widget.closeButtonLabel ?? widget.dismissLabel ?? '';

  ValueChanged<CaptureDraft>? get _submitCallback =>
      widget.onSubmitted ?? widget.onSubmit ?? widget.onSubmitCapture;

  ValueChanged<CaptureChipKind>? get _chipTapCallback =>
      widget.onChipTapped ?? widget.onChipTap;

  VoidCallback? get _dismissCallback => widget.onDismiss ?? widget.onClose;

  List<CapturePreviewChip> Function(CaptureDraft)? get _builder =>
      widget.chipsBuilder ?? widget.chipBuilder ?? widget.previewChipsBuilder;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _draft = ValueNotifier<CaptureDraft?>(null);
    _controller.addListener(_parse);
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
    _draft.value = parseCapture(text, locale: _locale, now: _now);
  }

  List<CapturePreviewChip> _chipsFor(CaptureDraft draft) {
    final builder = _builder;
    if (builder != null) return builder(draft);
    final labelBuilder = widget.chipLabelBuilder;
    if (labelBuilder != null) {
      final chips = <CapturePreviewChip>[];
      for (final kind in CaptureChipKind.values) {
        final value = labelBuilder(draft, kind);
        if (value != null && value.isNotEmpty) {
          chips.add(CapturePreviewChip(kind: kind, label: value));
        }
      }
      return chips;
    }
    final chips = <CapturePreviewChip>[
      CapturePreviewChip(kind: CaptureChipKind.kind, label: draft.kind.name),
    ];
    if (draft.date != null) {
      chips.add(
        const CapturePreviewChip(kind: CaptureChipKind.date, label: 'date'),
      );
    }
    if (draft.startTime != null) {
      chips.add(
        const CapturePreviewChip(kind: CaptureChipKind.time, label: 'time'),
      );
    }
    if (draft.repeat != null) {
      chips.add(
        const CapturePreviewChip(kind: CaptureChipKind.repeat, label: 'repeat'),
      );
    }
    if (draft.listTag != null) {
      chips.add(
        CapturePreviewChip(kind: CaptureChipKind.list, label: draft.listTag!),
      );
    }
    if (draft.priority != CapturePriority.none) {
      chips.add(
        CapturePreviewChip(
          kind: CaptureChipKind.priority,
          label: draft.priority.name,
        ),
      );
    }
    return chips;
  }

  void _submit() {
    final text = _controller.text;
    final draft =
        _draft.value ?? parseCapture(text, locale: _locale, now: _now);
    _submitCallback?.call(draft);
    _controller.clear();
    _draft.value = null;
    _focusNode.requestFocus();
  }

  void _dismiss() {
    _dismissCallback?.call();
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
                final chips = _chipsFor(draft);
                if (chips.isEmpty) return const SizedBox.shrink();
                return CapturePreviewChips(
                  chips: chips,
                  onChipTapped: _chipTapCallback ?? (_) {},
                );
              },
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: Semantics(
                    label: _label,
                    textField: true,
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: _label.isEmpty ? null : _label,
                        hintText: _hint.isEmpty ? null : _hint,
                      ),
                      minLines: 1,
                      maxLines: 1,
                    ),
                  ),
                ),
                if (_clear.isNotEmpty || _close.isNotEmpty) ...<Widget>[
                  if (_clear.isNotEmpty)
                    TextButton(
                      onPressed: () => _controller.clear(),
                      child: Text(_clear),
                    ),
                  if (_close.isNotEmpty)
                    TextButton(onPressed: _dismiss, child: Text(_close)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
