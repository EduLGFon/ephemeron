// Empty, error and loading placeholders. The empty artwork is a cheap custom
// painter, and the skeleton pulse is a single colour sweep rather than an
// endless opacity animation.
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../ui/app_motion.dart';
import '../tokens.dart';
import '../typography.dart';
import 'app_buttons.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData? icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                RepaintBoundary(
                  child: CustomPaint(
                    key: const ValueKey<String>('empty-art'),
                    size: const Size.square(96),
                    painter: _EmptyArtPainter(
                      tint: scheme.primary,
                      fill: scheme.primaryContainer,
                      line: scheme.outlineVariant,
                    ),
                  ),
                ),
                if (icon != null)
                  Icon(icon, size: DsIcon.lg, color: scheme.primary),
              ],
            ),
          ),
          const SizedBox(height: DsSpace.x16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontFamily: DsType.fraunces,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          if (message != null) ...<Widget>[
            const SizedBox(height: DsSpace.x8),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (actionLabel != null || secondaryLabel != null) ...<Widget>[
            const SizedBox(height: DsSpace.x24),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: DsSpace.x8,
              runSpacing: DsSpace.x8,
              children: <Widget>[
                if (actionLabel != null && onAction != null)
                  AppButton(label: actionLabel!, onPressed: onAction),
                if (secondaryLabel != null && onSecondary != null)
                  AppButton(
                    label: secondaryLabel!,
                    onPressed: onSecondary,
                    variant: AppButtonVariant.ghost,
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpace.x24,
          vertical: DsSpace.x24,
        ),
        child: content,
      ),
    );
  }
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.title,
    this.message,
    this.onRetry,
  });

  final String title;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.error_outline,
      title: title,
      message: message,
      actionLabel: onRetry == null ? null : 'Try again',
      onAction: onRetry,
    );
  }
}

class AppSkeleton extends StatelessWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = DsRadius.r8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return _SkeletonPulse(
      builder: (context, color) => _skeletonBlock(
        color: color,
        width: width,
        height: height,
        radius: radius,
      ),
    );
  }
}

class AppSkeletonList extends StatelessWidget {
  const AppSkeletonList({super.key, this.rows = 5, this.padding});

  final int rows;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return _SkeletonPulse(
      builder: (context, color) {
        return Padding(
          padding: padding ?? const EdgeInsets.all(DsSpace.x16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (var i = 0; i < rows; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == rows - 1 ? 0 : DsSpace.x12,
                  ),
                  child: Row(
                    children: <Widget>[
                      _skeletonBlock(
                        color: color,
                        width: 40,
                        height: 40,
                        radius: DsRadius.pill,
                      ),
                      const SizedBox(width: DsSpace.x12),
                      Expanded(
                        child: _skeletonBlock(
                          color: color,
                          height: 12,
                          radius: DsRadius.r8,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

Widget _skeletonBlock({
  required Color color,
  required double height,
  required double radius,
  double? width,
}) {
  return SizedBox(
    width: width,
    height: height,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    ),
  );
}

class _SkeletonPulse extends StatefulWidget {
  const _SkeletonPulse({required this.builder});

  final Widget Function(BuildContext context, Color color) builder;

  @override
  State<_SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<_SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = AppMotion.reduced(context);
    if (reduced == _reduced && (reduced || _controller.isAnimating)) return;
    _reduced = reduced;
    if (reduced) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isCompleted) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final low = scheme.surfaceContainerHigh;
    final high = scheme.surfaceContainerHighest;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final pulse = math.sin(_controller.value * math.pi);
            return widget.builder(context, Color.lerp(low, high, pulse)!);
          },
        ),
      ),
    );
  }
}

class _EmptyArtPainter extends CustomPainter {
  const _EmptyArtPainter({
    required this.tint,
    required this.fill,
    required this.line,
  });

  final Color tint;
  final Color fill;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    canvas.drawCircle(
      center,
      radius * 0.82,
      Paint()..color = fill.withValues(alpha: 0.45),
    );
    canvas.drawCircle(
      center,
      radius * 0.66,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = line,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.44),
      -math.pi / 2,
      math.pi * 1.25,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = tint,
    );
    canvas.drawCircle(
      center + Offset(radius * 0.48, -radius * 0.34),
      3,
      Paint()..color = tint,
    );
  }

  @override
  bool shouldRepaint(covariant _EmptyArtPainter oldDelegate) {
    return oldDelegate.tint != tint ||
        oldDelegate.fill != fill ||
        oldDelegate.line != line;
  }
}
