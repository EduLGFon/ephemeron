// Reusable empty-state placeholder for screens with no data.
import 'package:flutter/material.dart';

import '../theme/theme_tokens.dart';
import 'app_motion.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.compact = false,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  /// Tighter spacing and a smaller icon for dense areas such as sheets.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final iconBox = compact ? 48.0 : 72.0;
    final gap = compact ? AppSpace.md : AppSpace.lg;

    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Container(
              width: iconBox,
              height: iconBox,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: compact ? 24 : 32,
                color: scheme.onPrimaryContainer,
              ),
            ),
            SizedBox(height: gap),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontFamily: 'Fraunces',
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
              fontSize: compact ? 22 : null,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if ((actionLabel != null && onAction != null) ||
              (secondaryActionLabel != null && onSecondaryAction != null)) ...[
            SizedBox(height: gap),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpace.sm,
              runSpacing: AppSpace.xs,
              children: [
                if (actionLabel != null && onAction != null)
                  FilledButton(onPressed: onAction, child: Text(actionLabel!)),
                if (secondaryActionLabel != null && onSecondaryAction != null)
                  TextButton(
                    onPressed: onSecondaryAction,
                    child: Text(secondaryActionLabel!),
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpace.lg : AppSpace.xl,
          vertical: compact ? AppSpace.md : AppSpace.xl,
        ),
        child: _FadeIn(child: content),
      ),
    );
  }
}

class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduced ? 1 : 0, end: 1),
      duration: AppMotion.duration(context, AppDurations.normal),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 6),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
