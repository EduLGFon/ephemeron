import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';

/// A thin vertical draggable track on the right edge reporting a
/// fractional position in [0, 1].
///
/// The hit target is at least 48 dp in both directions while the track
/// stays visually thin. [padding] lets the caller keep the widget inside
/// the 24 dp screen margin; this widget does not enforce that margin
/// itself.
class Scrubber extends StatefulWidget {
  const Scrubber({
    super.key,
    required this.onChanged,
    required this.semanticLabel,
    required this.valueFormatter,
    this.onChangeEnd,
    this.value,
    this.padding = EdgeInsetsDirectional.zero,
  });

  final ValueChanged<double> onChanged;
  final String semanticLabel;
  final ValueChanged<double>? onChangeEnd;

  /// Optional controlled position in [0, 1].
  final double? value;

  /// Caller-supplied formatter for the slider value string.
  final String Function(double) valueFormatter;

  final EdgeInsetsDirectional padding;

  @override
  State<Scrubber> createState() => _ScrubberState();
}

class _ScrubberState extends State<Scrubber> {
  double _value = 0;

  @override
  void initState() {
    super.initState();
    if (widget.value != null) _value = widget.value!.clamp(0.0, 1.0);
  }

  @override
  void didUpdateWidget(covariant Scrubber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != null) _value = widget.value!.clamp(0.0, 1.0);
  }

  void _setValue(double v) {
    final clamped = v.clamp(0.0, 1.0);
    setState(() => _value = clamped);
    widget.onChanged(clamped);
  }

  void _handleDrag(DragUpdateDetails details, double trackHeight) {
    if (trackHeight <= 0) return;
    final pos = details.localPosition.dy / trackHeight;
    _setValue(pos);
  }

  static const double _step = 0.05;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: widget.padding,
      child: Semantics(
        label: widget.semanticLabel,
        slider: true,
        value: widget.valueFormatter(_value),
        increasedValue: widget.valueFormatter((_value + _step).clamp(0.0, 1.0)),
        decreasedValue: widget.valueFormatter((_value - _step).clamp(0.0, 1.0)),
        onIncrease: () => _setValue(_value + _step),
        onDecrease: () => _setValue(_value - _step),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: SizedBox(
            width: 48,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trackHeight = constraints.maxHeight;
                return GestureDetector(
                  excludeFromSemantics: true,
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (d) => _handleDrag(d, trackHeight),
                  onVerticalDragEnd: (_) => widget.onChangeEnd?.call(_value),
                  child: Stack(
                    alignment: AlignmentDirectional.center,
                    children: [
                      Container(
                        width: 4,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(StreamRadii.full),
                        ),
                      ),
                      PositionedDirectional(
                        top:
                            _value * (trackHeight - 12).clamp(0.0, trackHeight),
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(
                              StreamRadii.full,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
