part of '../note_editor_screen.dart';

// Word/char count plus the autosave status label under the body.

/// Relative label for the last successful autosave. Calm under a minute,
/// minute-precision up to an hour, then hour/day precision so the label stays
/// short for notes left open for a long time.
String savedAgeLabel(DateTime savedAt, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(savedAt);
  if (elapsed.inMinutes < 1) return 'Saved just now';
  if (elapsed.inHours < 1) return 'Saved ${elapsed.inMinutes}m ago';
  if (elapsed.inDays < 1) return 'Saved ${elapsed.inHours}h ago';
  return 'Saved ${elapsed.inDays}d ago';
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.controller,
    required this.status,
    required this.lastSavedAt,
    required this.onRetry,
  });

  final TextEditingController controller;
  final _SaveStatus status;
  final DateTime? lastSavedAt;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final counts = countWords(value.text);
        final last = lastSavedAt;
        final label = switch (status) {
          _SaveStatus.idle => 'Autosave on',
          _SaveStatus.saving => 'Saving...',
          _SaveStatus.saved => last == null ? 'Saved' : savedAgeLabel(last),
          _SaveStatus.failed => 'Save failed',
        };
        final failed = status == _SaveStatus.failed;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${counts.words} words, ${counts.chars} chars - $label',
                  key: const Key('note-save-status'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: failed ? Theme.of(context).colorScheme.error : null,
                  ),
                ),
              ),
              if (failed)
                TextButton(
                  key: const Key('note-save-retry'),
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
            ],
          ),
        );
      },
    );
  }
}
