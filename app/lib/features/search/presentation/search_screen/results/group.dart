part of '../../search_screen.dart';

class _Group<T> extends StatelessWidget {
  const _Group({
    required this.title,
    required this.async,
    required this.strings,
    required this.onRetry,
    required this.row,
  });

  final String title;
  final AsyncValue<List<T>> async;
  final SearchStrings strings;
  final VoidCallback onRetry;
  final Widget Function(T item) row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return async.maybeWhen(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: DsSpace.x8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(title: title, count: items.length),
              AppSurface(
                padding: EdgeInsets.zero,
                radius: DsRadius.r12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: theme.colorScheme.outlineVariant,
                        ),
                      row(items[i]),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
      error: (_, _) => Padding(
        padding: const EdgeInsets.only(bottom: DsSpace.x8),
        child: AppSurface(
          padding: EdgeInsets.zero,
          radius: DsRadius.r12,
          child: _ResultRow(
            icon: Icons.error_outline,
            title: strings.groupFailed(title),
            trailing: AppButton(
              label: strings.retry,
              variant: AppButtonVariant.ghost,
              onPressed: onRetry,
            ),
          ),
        ),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}
