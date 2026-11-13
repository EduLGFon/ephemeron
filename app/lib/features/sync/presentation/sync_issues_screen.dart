// User-facing sync diagnostics: exhausted/pending outbox rows and per-calendar
// or per-task-list errors. The screen only renders non-personal labels and
// counters; payloads, tokens, emails, titles and raw responses stay in storage.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_feedback.dart';
import '../application/sync_providers.dart';
import '../domain/sync_issue.dart';

class SyncIssuesScreen extends ConsumerWidget {
  const SyncIssuesScreen({super.key});

  static Key outboxRetryKey(String id) =>
      ValueKey('sync-issue-outbox-retry-$id');

  static Key outboxDiscardKey(String id) =>
      ValueKey('sync-issue-outbox-discard-$id');

  static Key stateRetryKey(String key) =>
      ValueKey('sync-issue-state-retry-$key');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outbox = ref.watch(syncOutboxIssuesProvider);
    final stateIssues = ref.watch(syncStateIssuesProvider);
    final loading = outbox.isLoading && stateIssues.isLoading;
    final failed = outbox.hasError && stateIssues.hasError;
    final changes = outbox.value ?? const <SyncOutboxIssue>[];
    final calendars = stateIssues.value ?? const <SyncStateIssue>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Sync issues')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : failed
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load sync issues.'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () {
                      ref.invalidate(syncOutboxIssuesProvider);
                      ref.invalidate(syncStateIssuesProvider);
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                const _SectionHeader(
                  title: 'Changes',
                  description:
                      'Queued changes retry automatically. Failed changes '
                      'stay on this device until retried or discarded.',
                ),
                if (changes.isEmpty)
                  const ListTile(
                    title: Text('No queued or failed changes.'),
                    leading: Icon(Icons.check_circle_outline),
                  ),
                for (final issue in changes) _OutboxIssueTile(issue: issue),
                const _SectionHeader(
                  title: 'Calendars and task lists',
                  description:
                      'A sync error on one calendar or task list does not '
                      'stop the rest.',
                ),
                if (calendars.isEmpty)
                  const ListTile(
                    title: Text('No calendar or task-list errors.'),
                    leading: Icon(Icons.check_circle_outline),
                  ),
                for (final issue in calendars) _StateIssueTile(issue: issue),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _OutboxIssueTile extends ConsumerWidget {
  const _OutboxIssueTile({required this.issue});

  final SyncOutboxIssue issue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final age = syncIssueAgeLabel(issue.createdAtUtc);
    final attempts = issue.attempts == 1
        ? '1 attempt'
        : '${issue.attempts} attempts';
    return ListTile(
      leading: Icon(issue.failed ? Icons.error_outline : Icons.sync_problem),
      title: Text('${issue.operationLabel} ${issue.entityLabel.toLowerCase()}'),
      subtitle: Text('${issue.errorLabel} - $attempts - $age', softWrap: true),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: SyncIssuesScreen.outboxRetryKey(issue.id),
            tooltip: 'Retry change',
            onPressed: () => _retry(context, ref),
            icon: const Icon(Icons.refresh),
          ),
          if (issue.failed)
            IconButton(
              key: SyncIssuesScreen.outboxDiscardKey(issue.id),
              tooltip: 'Discard change',
              onPressed: () => _discard(context, ref),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
    );
  }

  Future<void> _retry(BuildContext context, WidgetRef ref) async {
    AppFeedback.tap();
    try {
      await ref.read(syncEngineProvider).retryFailed(issue.id);
      if (!context.mounted) return;
      showAppSnackBar(context, 'Retrying change', icon: Icons.sync);
      await ref.read(syncAllProvider)();
    } catch (_) {
      if (!context.mounted) return;
      showErrorSnackBar(context, 'Could not retry this change.');
    }
  }

  Future<void> _discard(BuildContext context, WidgetRef ref) async {
    AppFeedback.tap();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard change?'),
        content: const Text(
          'This removes the queued sync change from this device. '
          'The local item is kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final removed = await ref.read(syncEngineProvider).discardFailed(issue.id);
    if (!context.mounted) return;
    if (removed) {
      showAppSnackBar(context, 'Change discarded', icon: Icons.delete_outline);
    } else {
      showErrorSnackBar(context, 'This change still has retries left.');
    }
  }
}

class _StateIssueTile extends ConsumerWidget {
  const _StateIssueTile({required this.issue});

  final SyncStateIssue issue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = issue.kind == SyncStateIssueKind.calendar
        ? 'Calendar sync'
        : 'Task-list sync';
    final age = syncIssueAgeLabel(issue.lastSyncAtUtc);
    return ListTile(
      leading: const Icon(Icons.event_busy),
      title: Text(title),
      subtitle: Text('${issue.errorLabel} - $age', softWrap: true),
      trailing: TextButton(
        key: SyncIssuesScreen.stateRetryKey(issue.key),
        onPressed: () => _retry(context, ref),
        child: const Text('Retry'),
      ),
    );
  }

  Future<void> _retry(BuildContext context, WidgetRef ref) async {
    AppFeedback.tap();
    try {
      await ref.read(syncEngineProvider).clearSyncStateError(issue.key);
      if (!context.mounted) return;
      showAppSnackBar(context, 'Retrying sync', icon: Icons.sync);
      await ref.read(syncAllProvider)();
    } catch (_) {
      if (!context.mounted) return;
      showErrorSnackBar(context, 'Could not retry sync.');
    }
  }
}
