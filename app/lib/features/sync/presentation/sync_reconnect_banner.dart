// Global banner shown above the shell when Google sync needs renewed
// permission. The persisted flag survives restarts; the in-memory reconsent
// list adds account names for the current session.
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_screen.dart';
import '../application/sync_providers.dart';

class SyncReconnectBanner extends ConsumerWidget {
  const SyncReconnectBanner({super.key});

  static const Key bannerKey = Key('sync-reconnect-banner');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(googleReconsentAccountsProvider);
    final needsReconnect = ref.watch(googleReconnectNeededProvider);
    // Null means the persisted flag has not loaded yet: do not render a false
    // state, which would flash the banner off on cold start.
    if (accounts.isEmpty && needsReconnect != true) {
      return const SizedBox.shrink();
    }
    final message = accounts.isEmpty
        ? 'Google sync needs permission. Reconnect your Google account.'
        : 'Google sync needs permission again for: ${accounts.join(', ')}. '
              'Your changes are kept on this device.';
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      key: bannerKey,
      bottom: false,
      child: Card(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        color: scheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: TextStyle(color: scheme.onErrorContainer)),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
                  ),
                  child: Text(
                    'Review accounts',
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
