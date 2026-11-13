part of '../../search_screen.dart';

class _Group<T> extends StatelessWidget {
  const _Group({
    required this.title,
    required this.async,
    required this.onRetry,
    required this.tile,
  });

  final String title;
  final AsyncValue<List<T>> async;
  final VoidCallback onRetry;
  final Widget Function(T item) tile;

  @override
  Widget build(BuildContext context) {
    return async.maybeWhen(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                '$title (${items.length})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            for (final item in items) tile(item),
          ],
        );
      },
      error: (_, _) => ListTile(
        leading: const Icon(Icons.error_outline),
        title: Text('$title failed to load'),
        trailing: TextButton(onPressed: onRetry, child: const Text('Retry')),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}
