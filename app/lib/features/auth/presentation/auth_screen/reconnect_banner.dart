part of '../auth_screen.dart';

/// Banner shown when a signed-in account needs its Google grant renewed
/// (expired token, revoked access, or a grant from before Tasks sync that
/// only covers Calendar). Queued rows are kept, so reconnecting resumes
/// sync without data loss.
class _ReconnectBanner extends ConsumerWidget {
  const _ReconnectBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(googleReconsentAccountsProvider);
    if (accounts.isEmpty) return const SizedBox.shrink();
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Google sync needs permission again. Your changes are kept on '
              'this device and will sync after reconnecting.',
            ),
            for (final email in accounts) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text(email)),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _reconnect(context, ref, email),
                    child: const Text('Reconnect'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _reconnect(
    BuildContext context,
    WidgetRef ref,
    String email,
  ) async {
    try {
      await ref.read(googleAccountProvider.notifier).setActive(email);
      await ref.read(googleAccountProvider.notifier).signIn(tasks: true);
      final active = ref.read(googleAccountProvider);
      if (!isSameAccountEmail(active ?? '', email)) {
        if (!context.mounted) return;
        showErrorSnackBar(
          context,
          'Signed in with a different account. '
          'Reconnect $email to continue syncing it.',
        );
        return;
      }
      ref.read(googleReconsentAccountsProvider.notifier).clear(email);
      await ref
          .read(googleReconnectNeededProvider.notifier)
          .set(ref.read(googleReconsentAccountsProvider).isNotEmpty);
      await ref.read(syncStatusProvider.notifier).syncNow();
      await ref.read(googleAutoSyncServiceProvider).start();
      if (!context.mounted) return;
      AppFeedback.success();
      showAppSnackBar(context, 'Google access renewed.', icon: Icons.check);
    } on GoogleAuthException catch (e) {
      if (!context.mounted) return;
      showErrorSnackBar(context, e.message);
    } catch (e) {
      if (!context.mounted) return;
      showErrorSnackBar(context, 'Google sign-in failed: $e');
    }
  }
}
