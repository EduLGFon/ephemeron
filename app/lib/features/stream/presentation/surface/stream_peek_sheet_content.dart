part of 'stream_peek_sheet.dart';

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.title, this.closeLabel, this.onClose});

  final String title;
  final String? closeLabel;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (onClose != null)
          IconButton(
            key: const ValueKey('peek_sheet_close'),
            onPressed: onClose,
            tooltip: closeLabel,
            icon: const Icon(Icons.close),
          ),
      ],
    );
  }
}

class _StatusBody extends StatelessWidget {
  const _StatusBody({
    required this.title,
    required this.closeLabel,
    required this.onClose,
    required this.child,
  });

  final String title;
  final String closeLabel;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetTitle(title: title, closeLabel: closeLabel, onClose: onClose),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: Text(retryLabel)),
      ],
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, textAlign: TextAlign.center);
  }
}

class _ReadOnlySummary extends StatelessWidget {
  const _ReadOnlySummary({
    required this.data,
    required this.formatTime,
    required this.readOnlyLabel,
    required this.startLabel,
    required this.endLabel,
  });

  final PeekData data;
  final String Function(int ms) formatTime;
  final String readOnlyLabel;
  final String startLabel;
  final String endLabel;

  @override
  Widget build(BuildContext context) {
    final endMs = data.endMs;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(data.title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        _SummaryLine(label: startLabel, value: formatTime(data.startMs)),
        if (endMs != null) ...[
          const SizedBox(height: 8),
          _SummaryLine(label: endLabel, value: formatTime(endMs)),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              Icons.lock_outline,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(readOnlyLabel, style: theme.textTheme.labelMedium),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        Text(value, style: theme.textTheme.bodyLarge),
      ],
    );
  }
}

Future<bool> _showDiscardDialog(BuildContext context) async {
  final choice = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final l = AppLocalizations.of(dialogContext);
      return AlertDialog(
        title: Text(l.streamPeekDiscardTitle),
        content: Text(l.streamPeekDiscardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.streamPeekDiscardConfirm),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.streamPeekKeepEditing),
          ),
        ],
      );
    },
  );
  return choice ?? false;
}

String _formatTime(BuildContext context, int ms) {
  return formatStreamTimeOfDay(
    context,
    DateTime.fromMillisecondsSinceEpoch(ms),
  );
}
