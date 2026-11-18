import 'package:material_ui/material_ui.dart';

/// Crossfade between two level widgets using [FadeTransition].
///
/// Both children must be pre-built and identically sized; no layout work is
/// performed during the fade. [onChanged] fires once at the midpoint with
/// [level]. Reduce motion collapses the duration to zero.
class LevelTransition extends StatefulWidget {
  const LevelTransition({
    super.key,
    required this.child,
    this.level,
    this.duration = const Duration(milliseconds: 180),
    this.onChanged,
    this.reduceMotion,
  });

  final Widget child;
  final Object? level;
  final Duration duration;
  final void Function(Object? level)? onChanged;
  final bool? reduceMotion;

  @override
  State<LevelTransition> createState() => _LevelTransitionState();
}

typedef StreamLevelTransition = LevelTransition;

class _LevelTransitionState extends State<LevelTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Widget? _outgoing;
  Widget? _incoming;
  Object? _currentLevel;
  bool _changedFired = false;
  bool _transitioning = false;

  bool get _reduced {
    if (widget.reduceMotion != null) return widget.reduceMotion!;
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void initState() {
    super.initState();
    _incoming = widget.child;
    _currentLevel = widget.level;
    _controller = AnimationController(
      vsync: this,
      duration: widget.reduceMotion == true ? Duration.zero : widget.duration,
    );
    _controller.addListener(_onTick);
    _controller.addStatusListener(_onStatus);
  }

  @override
  void didUpdateWidget(covariant LevelTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    final levelChanged = widget.level != oldWidget.level;
    final childChanged = !identical(widget.child, oldWidget.child);
    if ((levelChanged || childChanged) &&
        !(identical(widget.child, _incoming) &&
            widget.level == _currentLevel)) {
      _startTransition();
    }
  }

  void _startTransition() {
    if (identical(widget.child, _incoming) && widget.level == _currentLevel) {
      return;
    }
    _outgoing = _incoming;
    _incoming = widget.child;
    _currentLevel = widget.level;
    _changedFired = false;
    _transitioning = true;
    _controller.duration = _reduced ? Duration.zero : widget.duration;
    _controller.value = 0;
    _controller.forward();
  }

  void _onTick() {
    if (!_changedFired && _controller.value >= 0.5) {
      _changedFired = true;
      widget.onChanged?.call(_currentLevel);
    }
    if (_reduced && _transitioning && !_changedFired) {
      // ensure fire for zero-duration
      _changedFired = true;
      widget.onChanged?.call(_currentLevel);
    }
    setState(() {});
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _outgoing = null;
      _transitioning = false;
      _controller.value = 0;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_transitioning || _outgoing == null) {
      return _incoming ?? widget.child;
    }
    final incomingOpacity = _controller;
    final outgoingOpacity = Tween<double>(
      begin: 1,
      end: 0,
    ).animate(_controller);
    return Stack(
      fit: StackFit.expand,
      children: [
        FadeTransition(opacity: outgoingOpacity, child: _outgoing),
        FadeTransition(opacity: incomingOpacity, child: _incoming),
      ],
    );
  }
}
