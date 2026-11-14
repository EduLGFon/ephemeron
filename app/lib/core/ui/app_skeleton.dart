// Loading placeholders. A single opacity pulse animates the whole block group;
// reduce-motion stops the controller so no frame work runs while loading.
import 'package:material_ui/material_ui.dart';

import '../theme/theme_tokens.dart';
import 'app_motion.dart';

abstract final class AppSkeleton {
  /// A list-shaped placeholder with an avatar and two text lines per row.
  static Widget list(BuildContext context, {int itemCount = 6}) {
    return _SkeletonList(itemCount: itemCount);
  }

  /// A single rounded placeholder block.
  static Widget box({
    double? width,
    double height = 16,
    BorderRadius? borderRadius,
  }) {
    return _SkeletonBlock(
      width: width,
      height: height,
      borderRadius: borderRadius,
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList({required this.itemCount});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return _Pulse(
      child: Padding(
        key: const ValueKey('app-skeleton-list'),
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < itemCount; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i == itemCount - 1 ? 0 : AppSpace.md,
                ),
                child: const Row(
                  children: [
                    _SkeletonBlock(
                      width: 40,
                      height: 40,
                      borderRadius: BorderRadius.all(
                        Radius.circular(AppRadius.pill),
                      ),
                    ),
                    SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SkeletonBlock(height: 12),
                          SizedBox(height: AppSpace.sm),
                          FractionallySizedBox(
                            widthFactor: 0.65,
                            alignment: Alignment.centerLeft,
                            child: _SkeletonBlock(height: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({this.width, required this.height, this.borderRadius});

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.7),
        borderRadius: borderRadius ?? BorderRadius.circular(AppRadius.sm),
      ),
    );
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.slow * 3,
  );

  bool? _reduced;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = AppMotion.reduced(context);
    if (_reduced == reduced) return;
    _reduced = reduced;
    if (reduced) {
      _controller.stop();
      _controller.value = 0.7;
    } else {
      _controller.repeat(reverse: true, min: 0.35, max: 0.9);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _controller, child: widget.child);
  }
}
