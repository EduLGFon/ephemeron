// Lock gate UI shown while biometric app lock is enabled and unauthenticated.
// It is presentation only: the gate in main.dart owns authentication state and
// SECURITY: this widget must never unlock on its own.
import 'package:flutter/material.dart';

class BiometricLockScreen extends StatelessWidget {
  const BiometricLockScreen({
    super.key,
    required this.theme,
    required this.busy,
    required this.error,
    required this.onUnlock,
  });

  final ThemeData theme;
  final bool busy;
  final String? error;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: theme,
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 12),
                const Text('Ephemeron is locked'),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      error!,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.red),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: busy ? null : onUnlock,
                  icon: const Icon(Icons.fingerprint),
                  label: Text(busy ? 'Waiting...' : 'Unlock'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
