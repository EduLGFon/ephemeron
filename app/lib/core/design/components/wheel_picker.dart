// iOS-style wheel picker and its modal sheet frame.
//
// Unlike [WheelSelector] (a plain list that shows every option), [WheelPicker]
// keeps exactly three rows in view and snaps the centre one on scroll or tap.
// Selection is signalled by scale, a check glyph and semantics, never by
// colour alone. Motion follows the app-wide reduce-accessibility setting.
import 'package:material_ui/material_ui.dart';

import '../../ui/app_motion.dart';
import '../../ui/app_sheet.dart';
import '../tokens.dart';
import '../typography.dart';
import 'app_overlays.dart';
import 'app_wheel.dart';

/// Number of rows visible when the picker is at rest.
const int kWheelPickerVisibleRows = 3;

/// Scale applied to the centred row and to its neighbours.
const double kWheelPickerCenterScale = 1.2;
const double kWheelPickerAdjacentScale = 0.8;

/// Opacity of the rows above and below the centre.
const double kWheelPickerAdjacentOpacity = 0.55;

/// A snapping, three-row wheel over [WheelItem] options.
///
/// The wheel scrolls to [value] when the parent changes it externally without
/// echoing a second [onChanged]. Scrolling or tapping reports the new value.
class WheelPicker<T> extends StatefulWidget {
  const WheelPicker({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.itemExtent = 56,
    this.semanticsLabel,
    this.enabled = true,
  });

  final List<WheelItem<T>> items;
  final T? value;
  final ValueChanged<T> onChanged;
  final double itemExtent;
  final String? semanticsLabel;
  final bool enabled;

  @override
  State<WheelPicker<T>> createState() => _WheelPickerState<T>();
}

class _WheelPickerState<T> extends State<WheelPicker<T>> {
  late final FixedExtentScrollController _controller;
  late int _selectedIndex;

  /// True while a programmatic scroll is in flight. Such scrolls update the
  /// visuals but must not echo [WheelPicker.onChanged] to the parent.
  bool _programmatic = false;

  /// Identifies the current programmatic scroll. An interrupted animation can
  /// complete after a newer one has started, so only the matching completion
  /// may release [_programmatic].
  int _scrollGeneration = 0;

  int get _count => widget.items.length;

  int _indexOf(T? value) {
    for (var i = 0; i < _count; i++) {
      if (widget.items[i].value == value) return i;
    }
    return -1;
  }

  Duration get _motion => AppMotion.duration(context, DsMotion.normal);

  @override
  void initState() {
    super.initState();
    final found = _indexOf(widget.value);
    _selectedIndex = found < 0 ? 0 : found;
    _controller = FixedExtentScrollController(initialItem: _selectedIndex);
  }

  @override
  void didUpdateWidget(covariant WheelPicker<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == oldWidget.value) return;
    final found = _indexOf(widget.value);
    if (found < 0 || found >= _count || found == _selectedIndex) return;
    _selectedIndex = found;
    setState(() {});
    _scrollTo(found, report: false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scrollTo(int index, {required bool report}) {
    // A tap reports once, immediately, rather than on every crossed row.
    if (report && widget.items[index].value != widget.value) {
      widget.onChanged(widget.items[index].value);
    }
    final generation = ++_scrollGeneration;
    if (!_controller.hasClients) {
      if (generation == _scrollGeneration) _programmatic = false;
      return;
    }
    final duration = _motion;
    _programmatic = true;
    if (duration == Duration.zero) {
      _controller.jumpToItem(index);
      if (generation == _scrollGeneration) _programmatic = false;
      return;
    }
    _controller
        .animateToItem(index, duration: duration, curve: DsMotion.standard)
        .whenComplete(() {
          if (mounted && generation == _scrollGeneration) {
            _programmatic = false;
          }
        });
  }

  void _select(int index) {
    if (!widget.enabled || index < 0 || index >= _count) return;
    if (index != _selectedIndex) {
      setState(() => _selectedIndex = index);
    }
    _scrollTo(index, report: true);
  }

  void _onSelectedItemChanged(int index) {
    if (index < 0 || index >= _count) return;
    if (index != _selectedIndex) {
      setState(() => _selectedIndex = index);
    }
    if (_programmatic) return;
    final next = widget.items[index].value;
    if (next == widget.value) return;
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    if (_count == 0) return const SizedBox.shrink();
    final extent = widget.itemExtent;
    return Semantics(
      label: widget.semanticsLabel,
      child: SizedBox(
        height: extent * kWheelPickerVisibleRows,
        child: ListWheelScrollView.useDelegate(
          controller: _controller,
          physics: widget.enabled
              ? const FixedExtentScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          itemExtent: extent,
          diameterRatio: 2,
          perspective: 0.01,
          overAndUnderCenterOpacity: 1,
          onSelectedItemChanged: _onSelectedItemChanged,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: _count,
            builder: (context, index) => _buildRow(context, index),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, int index) {
    final item = widget.items[index];
    final selected = index == _selectedIndex;
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? scheme.onSecondaryContainer
        : scheme.onSurface;
    final iconColor = selected ? scheme.primary : scheme.onSurfaceVariant;
    final duration = _motion;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (item.color != null) ...<Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: item.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: DsSpace.x8),
        ],
        if (item.icon != null) ...<Widget>[
          Icon(item.icon, size: DsIcon.sm, color: iconColor),
          if (item.showLabel) const SizedBox(width: DsSpace.x8),
        ],
        if (item.showLabel)
          Flexible(
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DsType.numeric(
                (Theme.of(context).textTheme.bodyLarge ?? const TextStyle())
                    .copyWith(color: foreground),
              ),
            ),
          ),
        if (selected) ...<Widget>[
          const SizedBox(width: DsSpace.x8),
          Icon(Icons.check, size: DsIcon.sm, color: foreground),
        ],
      ],
    );
    final tile = Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        key: item.key ?? ValueKey<T>(item.value),
        onTap: widget.enabled ? () => _select(index) : null,
        child: SizedBox(
          height: widget.itemExtent,
          child: AnimatedOpacity(
            opacity: selected ? 1 : kWheelPickerAdjacentOpacity,
            duration: duration,
            curve: DsMotion.standard,
            child: AnimatedScale(
              scale: selected
                  ? kWheelPickerCenterScale
                  : kWheelPickerAdjacentScale,
              duration: duration,
              curve: DsMotion.standard,
              child: Center(child: content),
            ),
          ),
        ),
      ),
    );
    final message = item.tooltip;
    return message == null ? tile : Tooltip(message: message, child: tile);
  }
}

/// Themed chrome for a modal wheel picker sheet.
///
/// [wheels] holds one or more [WheelPicker]s (for example hour and minute).
/// Done pops [result] through the navigator, so callers keep the pending
/// value in state and only apply it when Done is tapped.
class WheelPickerSheetFrame extends StatelessWidget {
  const WheelPickerSheetFrame({
    super.key,
    required this.title,
    required this.wheels,
    required this.result,
    this.subtitle,
    this.cancelLabel = 'Cancel',
    this.doneLabel = 'Done',
  });

  final String title;
  final String? subtitle;
  final List<Widget> wheels;
  final Object? result;
  final String cancelLabel;
  final String doneLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppSheetHeader(title: title, subtitle: subtitle),
          const SizedBox(height: DsSpace.x8),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: DsSpace.x16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(DsRadius.r12),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: wheels),
          ),
          const SizedBox(height: DsSpace.x8),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DsSpace.x16,
              0,
              DsSpace.x16,
              DsSpace.x16,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(cancelLabel),
                ),
                const SizedBox(width: DsSpace.x8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 48),
                  ),
                  onPressed: () => Navigator.of(context).pop(result),
                  child: Text(doneLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens a single-wheel sheet and returns the value tapped on Done.
///
/// Cancelling or dismissing the barrier returns null.
Future<T?> showWheelPickerSheet<T>(
  BuildContext context, {
  required String title,
  required List<WheelItem<T>> items,
  T? value,
  String? subtitle,
  String? semanticsLabel,
  String cancelLabel = 'Cancel',
  String doneLabel = 'Done',
}) {
  if (items.isEmpty) return Future<T?>.value(null);
  return showAppSheet<T>(
    context,
    builder: (sheetContext) {
      T pending = value != null && items.any((item) => item.value == value)
          ? value
          : items.first.value;
      return StatefulBuilder(
        builder: (context, setState) => WheelPickerSheetFrame(
          title: title,
          subtitle: subtitle,
          wheels: <Widget>[
            WheelPicker<T>(
              items: items,
              value: pending,
              onChanged: (next) => setState(() => pending = next),
              semanticsLabel: semanticsLabel,
            ),
          ],
          result: pending,
          cancelLabel: cancelLabel,
          doneLabel: doneLabel,
        ),
      );
    },
  );
}
