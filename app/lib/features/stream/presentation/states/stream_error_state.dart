// Calm error state: a small error icon, caller-supplied copy, retry and an
// optional secondary action. Never blames the user; no red flood.
import 'package:material_ui/material_ui.dart';

class StreamErrorState extends StatelessWidget {
  const StreamErrorState({
    super.key,
    required this.title,
    this.body,
    this.retryLabel,
    this.onRetry,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final String title;
  final String? body;
  final String? retryLabel;
  final VoidCallback? onRetry;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(child: _content(theme, scheme)),
      ),
    );
  }

  Widget _content(ThemeData theme, ColorScheme scheme) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: scheme.error, size: 32),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              color: scheme.onSurface,
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: 8),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (retryLabel != null && onRetry != null) ...[
            const SizedBox(height: 24),
            FilledButton.tonal(onPressed: onRetry, child: Text(retryLabel!)),
          ],
          if (secondaryActionLabel != null && onSecondaryAction != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onSecondaryAction,
              child: Text(secondaryActionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
