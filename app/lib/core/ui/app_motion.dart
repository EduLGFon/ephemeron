// Motion primitives shared by screens. Every animation goes through
// [AppMotion.duration] so the user's reduce-motion setting collapses it to
// zero consistently instead of each widget re-checking accessibility flags.
import 'package:material_ui/material_ui.dart';

import '../theme/theme_tokens.dart';

abstract final class AppMotion {
  /// True when the platform or app asks for reduced motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [base] unless reduced motion is on, in which case duration is zero.
  static Duration duration(BuildContext context, Duration base) =>
      reduced(context) ? Duration.zero : base;
}

/// Fade plus a small upward slide when the child changes. Callers must key
/// [child] so the switcher can tell updates apart.
class AppAnimatedSwitcher extends StatelessWidget {
  const AppAnimatedSwitcher({
    super.key,
    required this.child,
    this.duration = AppDurations.normal,
    this.curve = Curves.easeOutCubic,
  });

  final Widget child;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final resolved = AppMotion.duration(context, duration);
    return AnimatedSwitcher(
      duration: resolved,
      switchInCurve: curve,
      switchOutCurve: curve,
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(parent: animation, curve: curve);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Shrinks [child] slightly while pressed and shows ink feedback when it owns
/// the gesture. Pass [onTap] only when the child is not already tappable:
/// wrapping an existing InkWell with a second tap handler would double-fire.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
    this.borderRadius,
    this.semanticsLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final BorderRadius? borderRadius;
  final String? semanticsLabel;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.duration(context, AppDurations.fast);
    final scaled = AnimatedScale(
      scale: _pressed ? widget.scale : 1,
      duration: duration,
      curve: Curves.easeOut,
      child: widget.child,
    );
    final onTap = widget.onTap;
    if (onTap == null) {
      // Scale-only wrapping around child-owned gestures (for example an
      // existing InkWell). Listener does not join the gesture arena, so it
      // observes the press without stealing taps.
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: scaled,
      );
    }

    final radius = widget.borderRadius;
    final content = Material(
      type: MaterialType.transparency,
      shape: radius == null
          ? null
          : RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: radius == null ? Clip.none : Clip.antiAlias,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        onHighlightChanged: _setPressed,
        child: scaled,
      ),
    );
    final label = widget.semanticsLabel;
    if (label == null) return content;
    return Semantics(
      container: true,
      button: true,
      label: label,
      child: content,
    );
  }
}
