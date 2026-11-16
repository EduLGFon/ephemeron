// Reusable local countdown section for an event, task, or habit. The link and
// countdown rows are local-only; read-only remote sources can still add one.
import 'package:material_ui/material_ui.dart';
import 'package:ephemeron/core/theme/theme_tokens.dart';
import 'package:ephemeron/core/time/device_date_format.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/drift/app_database.dart';
import '../application/countdowns_providers.dart';
import 'countdown_editor_sheet.dart';
import 'countdown_formatters.dart';

class EntityCountdownSection extends ConsumerWidget {
  const EntityCountdownSection({
    super.key,
    required this.linkedType,
    required this.linkedId,
    required this.initialTitle,
    this.initialDate,
  });

  final String linkedType;
  final String linkedId;
  final String initialTitle;
  final DateTime? initialDate;

  void _openEditor(BuildContext context, {Countdown? countdown}) {
    showCountdownEditor(
      context,
      countdown: countdown,
      linkedType: linkedType,
      linkedId: linkedId,
      initialTitle: initialTitle,
      initialDate: initialDate,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items =
        ref
            .watch(linkedCountdownsProvider((type: linkedType, id: linkedId)))
            .value ??
        const <Countdown>[];
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.lg,
            AppSpace.sm,
            AppSpace.lg,
            0,
          ),
          child: Text(
            'Countdown',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (final countdown in items)
          _LinkedCountdownTile(
            countdown: countdown,
            onTap: () => _openEditor(context, countdown: countdown),
          ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.xs,
              AppSpace.lg,
              AppSpace.sm,
            ),
            child: OutlinedButton.icon(
              onPressed: () => _openEditor(context),
              icon: const Icon(Icons.hourglass_bottom_outlined),
              label: const Text('Add countdown'),
            ),
          )
        else
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
              child: TextButton.icon(
                onPressed: () => _openEditor(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add countdown'),
              ),
            ),
          ),
      ],
    );
  }
}

class _LinkedCountdownTile extends StatelessWidget {
  const _LinkedCountdownTile({required this.countdown, required this.onTap});

  final Countdown countdown;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final schedule = countdownSchedule(
      targetDate: countdown.targetDate,
      yearlyRepeat: countdown.yearlyRepeat,
    );
    final subtitle = schedule == null
        ? 'No date'
        : '${countdownRelativeLabel(schedule.days)} - '
              '${DeviceDateFormat.yMMMd(context).format(schedule.next)}';
    return ListTile(
      leading: const Icon(Icons.hourglass_bottom_outlined),
      title: Text(
        countdown.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.edit_outlined, size: 20),
      onTap: onTap,
    );
  }
}
