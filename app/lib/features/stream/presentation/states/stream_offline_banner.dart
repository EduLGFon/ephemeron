// Slim inline offline banner (not a snackbar). Does not overlay content.
import 'package:material_ui/material_ui.dart';

class StreamOfflineBanner extends StatelessWidget {
  const StreamOfflineBanner({
    super.key,
    required this.message,
    this.retryLabel,
    this.onRetry,
    this.liveRegion = false,
  });

  final String message;
  final String? retryLabel;
  final VoidCallback? onRetry;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      liveRegion: liveRegion,
      child: Container(
        width: double.infinity,
        color: scheme.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
            if (retryLabel != null && onRetry != null)
              SizedBox(
                height: 48,
                child: TextButton(onPressed: onRetry, child: Text(retryLabel!)),
              ),
          ],
        ),
      ),
    );
  }
}
