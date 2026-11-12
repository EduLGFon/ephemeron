// Shared inline failure state for calendar views that read the occurrence
// and habit streams of the materialized range.
import 'package:flutter/material.dart';

/// Compact banner shown above calendar content when a range stream fails.
///
/// [onRetry] invalidates the providers for the current range so the view
/// reloads instead of rendering the failure as empty data.
class CalendarErrorBanner extends StatelessWidget {
  const CalendarErrorBanner({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('calendar-error'),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 16,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          const Expanded(child: Text('Could not load calendar.')),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
