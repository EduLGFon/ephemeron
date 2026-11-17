part of '../stream_slipped_sheet.dart';

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.closeLabel,
    required this.onClose,
  });

  final String title;
  final String closeLabel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        StreamSpacing.x4,
        StreamSpacing.x1,
        StreamSpacing.x1,
        StreamSpacing.x1,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            key: const Key('streamSlippedClose'),
            onPressed: onClose,
            tooltip: closeLabel,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _SheetMessage extends StatelessWidget {
  const _SheetMessage({required this.label, this.busy = false});

  final String label;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.all(StreamSpacing.x6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy) ...[
            const SizedBox(
              width: StreamIconSize.lg,
              height: StreamIconSize.lg,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: StreamSpacing.x3),
          ],
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
