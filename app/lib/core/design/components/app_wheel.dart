// Shared vertical wheel selector and priority-flag visuals.
//
// [WheelSelector] replaces horizontal chip rows in editors: it is a compact,
// discrete vertical list whose current value is marked by fill, a check icon
// and selected semantics, so status never depends on colour alone.
//
// The colour/icon mapping for priority flags lives here (the design layer),
// while flag identity stays pure data in domain/tasks/eisenhower.dart. Both
// are intentionally public so feature code can render flags consistently.
import 'package:material_ui/material_ui.dart';

import '../../../domain/tasks/eisenhower.dart';
import '../tokens.dart';
import '../typography.dart';

/// One option in a [WheelSelector].
class WheelItem<T> {
  const WheelItem({
    required this.value,
    required this.label,
    this.icon,
    this.color,
    this.key,
    this.tooltip,
  });

  final T value;
  final String label;
  final IconData? icon;
  final Color? color;

  /// Optional stable key for tests. Defaults to [ValueKey] of [value].
  final Key? key;
  final String? tooltip;
}

/// A compact, scrollable vertical selector of discrete options.
///
/// Tapping a row reports [onChanged]; the matching row is highlighted. The
/// wheel scrolls to keep the selected value in view when the parent rebuilds
/// with a new [value], and every row exposes button/selected semantics.
class WheelSelector<T> extends StatefulWidget {
  const WheelSelector({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.itemExtent = 44,
    this.height,
    this.semanticsLabel,
  });

  final List<WheelItem<T>> items;
  final T? value;
  final ValueChanged<T> onChanged;
  final double itemExtent;
  final double? height;
  final String? semanticsLabel;

  @override
  State<WheelSelector<T>> createState() => _WheelSelectorState<T>();
}

class _WheelSelectorState<T> extends State<WheelSelector<T>> {
  late final ScrollController _controller;

  int get _count => widget.items.length;

  int _index(T? value) {
    for (var i = 0; i < _count; i++) {
      if (widget.items[i].value == value) return i;
    }
    return -1;
  }

  @override
  void initState() {
    super.initState();
    final found = _index(widget.value);
    final initial = found < 0 ? 0 : found;
    _controller = ScrollController(
      initialScrollOffset: initial * widget.itemExtent,
    );
  }

  @override
  void didUpdateWidget(covariant WheelSelector<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == oldWidget.value) return;
    final found = _index(widget.value);
    if (found < 0 || found >= _count || !_controller.hasClients) return;
    _controller.animateTo(
      found * widget.itemExtent,
      duration: DsMotion.fast,
      curve: DsMotion.standard,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_count == 0) return const SizedBox.shrink();
    final extent = widget.itemExtent;
    final height =
        widget.height ?? (_count * extent).clamp(extent, 264.0).toDouble();
    return Semantics(
      label: widget.semanticsLabel,
      child: SizedBox(
        height: height,
        child: ListView.builder(
          controller: _controller,
          itemExtent: extent,
          itemCount: _count,
          itemBuilder: (context, index) =>
              _buildRow(context, widget.items[index]),
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, WheelItem<T> item) {
    final scheme = Theme.of(context).colorScheme;
    final selected = item.value == widget.value;
    final foreground = selected
        ? scheme.onSecondaryContainer
        : scheme.onSurface;
    final iconColor = selected ? scheme.primary : scheme.onSurfaceVariant;
    final row = Row(
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
          const SizedBox(width: DsSpace.x8),
        ],
        Expanded(
          child: Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DsType.numeric(
              (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
                  .copyWith(color: foreground),
            ),
          ),
        ),
        if (selected) Icon(Icons.check, size: DsIcon.sm, color: foreground),
      ],
    );
    final tile = Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        key: item.key ?? ValueKey<T?>(item.value),
        onTap: () => widget.onChanged(item.value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.x12),
          decoration: BoxDecoration(
            color: selected ? scheme.secondaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(DsRadius.r8),
          ),
          child: Center(child: row),
        ),
      ),
    );
    final message = item.tooltip;
    return message == null ? tile : Tooltip(message: message, child: tile);
  }
}

/// Visual identity of a priority flag: colour + icon + short label.
@immutable
class PriorityFlagStyle {
  const PriorityFlagStyle({
    required this.flag,
    required this.label,
    required this.color,
    required this.icon,
  });

  final PriorityFlag flag;
  final String label;
  final Color color;
  final IconData icon;
}

/// Fixed palette shared by every flag rendering. P1 is the most urgent (red)
/// through P4 (green); the P label is always shown beside the icon so colour
/// is never the only signal.
const Map<PriorityFlag, PriorityFlagStyle> priorityFlagStyles =
    <PriorityFlag, PriorityFlagStyle>{
      PriorityFlag.none: PriorityFlagStyle(
        flag: PriorityFlag.none,
        label: 'None',
        color: Color(0xFF9E9E9E),
        icon: Icons.flag_outlined,
      ),
      PriorityFlag.p4: PriorityFlagStyle(
        flag: PriorityFlag.p4,
        label: 'P4',
        color: Color(0xFF388E3C),
        icon: Icons.flag,
      ),
      PriorityFlag.p3: PriorityFlagStyle(
        flag: PriorityFlag.p3,
        label: 'P3',
        color: Color(0xFFFBC02D),
        icon: Icons.flag,
      ),
      PriorityFlag.p2: PriorityFlagStyle(
        flag: PriorityFlag.p2,
        label: 'P2',
        color: Color(0xFFF57C00),
        icon: Icons.flag,
      ),
      PriorityFlag.p1: PriorityFlagStyle(
        flag: PriorityFlag.p1,
        label: 'P1',
        color: Color(0xFFD32F2F),
        icon: Icons.flag,
      ),
    };

/// Visual style for [flag].
PriorityFlagStyle priorityFlagStyle(PriorityFlag flag) =>
    priorityFlagStyles[flag] ?? priorityFlagStyles[PriorityFlag.none]!;

/// Style for a stored priority (0 none, 1 low .. 4 high).
PriorityFlagStyle styleForStoredPriority(int priority) =>
    priorityFlagStyle(priorityFlag(priority));

/// Style for a visual priority (0 none, 1 = P1 .. 4 = P4).
PriorityFlagStyle styleForVisualPriority(int visual) =>
    styleForStoredPriority(storedPriority(visual));

/// A coloured flag plus its P label. [none] renders nothing.
class AppPriorityFlag extends StatelessWidget {
  const AppPriorityFlag({
    super.key,
    required this.flag,
    this.label,
    this.dense = false,
    this.showLabel = true,
  });

  final PriorityFlag flag;
  final String? label;
  final bool dense;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    if (flag == PriorityFlag.none) return const SizedBox.shrink();
    final style = priorityFlagStyle(flag);
    final text = label ?? style.label;
    final size = dense ? 14.0 : DsIcon.sm;
    return Semantics(
      label: 'Priority $text',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(style.icon, size: size, color: style.color),
          if (showLabel && text.isNotEmpty) ...<Widget>[
            const SizedBox(width: DsSpace.x4),
            Text(
              text,
              style:
                  (Theme.of(context).textTheme.labelSmall ?? const TextStyle())
                      .copyWith(color: style.color),
            ),
          ],
        ],
      ),
    );
  }
}
