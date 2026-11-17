// Designed empty state: art, title, body and one primary action. Labels are
// caller-supplied so no hard-coded English lives in the widget.
import 'package:material_ui/material_ui.dart';

import 'stream_art.dart';

class StreamEmptyState extends StatelessWidget {
  const StreamEmptyState({
    super.key,
    required this.title,
    this.body,
    required this.actionLabel,
    required this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final String title;
  final String? body;
  final String actionLabel;
  final VoidCallback onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Semantics(
          container: true,
          label: title,
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const StreamEmptyArt(),
                  const SizedBox(height: 24),
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
                  const SizedBox(height: 24),
                  FilledButton(onPressed: onAction, child: Text(actionLabel)),
                  if (secondaryActionLabel != null &&
                      onSecondaryAction != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: onSecondaryAction,
                      child: Text(secondaryActionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
