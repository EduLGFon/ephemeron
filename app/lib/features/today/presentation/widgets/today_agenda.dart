// Unified agenda: all-day items first, then one thin time-sorted timeline of
// timed events and tasks due today. Overdue tasks stay collapsed at the top so
// a bad day is visible without becoming a red wall.
import 'package:material_ui/material_ui.dart';

import '../../../../core/design/components/app_headers.dart';
import '../../../../core/design/components/rows.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/time/device_date_format.dart';
import '../../../../core/time/time.dart';
import '../../../../data/drift/app_database.dart';
import '../../application/today_providers.dart';
import '../today_strings.dart';

class TodayAgenda extends StatelessWidget {
  const TodayAgenda({
    super.key,
    required this.events,
    required this.tasks,
    required this.taskLists,
    required this.todayDate,
    required this.onEventTap,
    required this.onTaskTap,
    required this.onToggleTask,
  });

  final List<OccurrenceCacheData> events;
  final TodayTaskBuckets tasks;
  final Map<String, TaskList> taskLists;
  final DateTime todayDate;
  final ValueChanged<OccurrenceCacheData> onEventTap;
  final ValueChanged<Task> onTaskTap;
  final ValueChanged<Task> onToggleTask;

  bool _isAllDay(OccurrenceCacheData event) =>
      event.endUtc - event.startUtc >= msPerDay;

  @override
  Widget build(BuildContext context) {
    final strings = TodayStrings.of(context);
    final allDay = events.where(_isAllDay).toList()
      ..sort((a, b) => a.startUtc.compareTo(b.startUtc));
    final timed = events.where((event) => !_isAllDay(event)).toList();
    final entries = <_AgendaEntry>[
      for (final event in timed) _EventEntry(event),
      for (final task in tasks.today) _TaskEntry(task),
    ]..sort((a, b) => a.minute.compareTo(b.minute));

    return Column(
      key: const ValueKey<String>('today-agenda'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionTitle(
          title: strings.today,
          count: allDay.length + entries.length,
        ),
        if (tasks.overdue.isNotEmpty)
          _OverdueSection(
            tasks: tasks.overdue,
            taskLists: taskLists,
            todayDate: todayDate,
            onTaskTap: onTaskTap,
            onToggleTask: onToggleTask,
          ),
        for (final event in allDay)
          Padding(
            padding: const EdgeInsets.only(bottom: DsSpace.x4),
            child: AppEventRow(
              key: ValueKey<String>('today-event-${event.id}'),
              title: event.title ?? 'Event',
              timeLabel: strings.allDay,
              color: Theme.of(context).colorScheme.primary,
              onTap: () => onEventTap(event),
            ),
          ),
        for (final entry in entries)
          switch (entry) {
            _EventEntry(:final event) => Padding(
              padding: const EdgeInsets.only(bottom: DsSpace.x4),
              child: AppEventRow(
                key: ValueKey<String>('today-event-${event.id}'),
                title: event.title ?? 'Event',
                timeLabel: DeviceDateFormat.time(
                  context,
                  DateTime.fromMillisecondsSinceEpoch(event.startUtc).toLocal(),
                ),
                color: Theme.of(context).colorScheme.primary,
                onTap: () => onEventTap(event),
              ),
            ),
            _TaskEntry(:final task) => _TimelineTask(
              task: task,
              timeLabel: _taskTimeLabel(context, task),
              list: task.listId == null ? null : taskLists[task.listId],
              onTap: () => onTaskTap(task),
              onToggle: () => onToggleTask(task),
            ),
          },
      ],
    );
  }

  String _taskTimeLabel(BuildContext context, Task task) {
    final minute = taskMinuteOfDay(task);
    if (minute >= 24 * 60) return TodayStrings.of(context).anytime;
    return DeviceDateFormat.time(
      context,
      DateTime(
        todayDate.year,
        todayDate.month,
        todayDate.day,
        minute ~/ 60,
      ).add(Duration(minutes: minute % 60)),
    );
  }
}

sealed class _AgendaEntry {
  int get minute;
}

class _EventEntry implements _AgendaEntry {
  _EventEntry(this.event);
  final OccurrenceCacheData event;

  @override
  int get minute {
    final local = DateTime.fromMillisecondsSinceEpoch(event.startUtc).toLocal();
    return local.hour * 60 + local.minute;
  }
}

class _TaskEntry implements _AgendaEntry {
  _TaskEntry(this.task);
  final Task task;

  @override
  int get minute => taskMinuteOfDay(task);
}

class _TimelineTask extends StatelessWidget {
  const _TimelineTask({
    required this.task,
    required this.timeLabel,
    required this.list,
    required this.onTap,
    required this.onToggle,
  });

  final Task task;
  final String timeLabel;
  final TaskList? list;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final timeWidth = 60.0 * scale.clamp(1.0, 2.0);
    return Row(
      key: ValueKey<String>('today-task-${task.id}'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        SizedBox(
          width: timeWidth,
          child: Text(
            timeLabel,
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: DsSpace.x8),
        Expanded(
          child: AppTaskRow(
            title: task.title,
            subtitle: list?.name,
            listColor: list?.color == null ? null : parseColor(list!.color!),
            priority: visualTaskPriority(task),
            onTap: onTap,
            onToggle: onToggle,
          ),
        ),
      ],
    );
  }
}

class _OverdueSection extends StatefulWidget {
  const _OverdueSection({
    required this.tasks,
    required this.taskLists,
    required this.todayDate,
    required this.onTaskTap,
    required this.onToggleTask,
  });

  final List<Task> tasks;
  final Map<String, TaskList> taskLists;
  final DateTime todayDate;
  final ValueChanged<Task> onTaskTap;
  final ValueChanged<Task> onToggleTask;

  @override
  State<_OverdueSection> createState() => _OverdueSectionState();
}

class _OverdueSectionState extends State<_OverdueSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final strings = TodayStrings.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          button: true,
          expanded: _open,
          label: '${strings.overdue}, ${widget.tasks.length}',
          child: Material(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(DsRadius.r12),
            child: InkWell(
              key: const ValueKey<String>('today-overdue-toggle'),
              borderRadius: BorderRadius.circular(DsRadius.r12),
              onTap: () => setState(() => _open = !_open),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.x12),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.warning_amber_rounded,
                        size: DsIcon.sm,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: DsSpace.x8),
                      Expanded(
                        child: Text(
                          strings.overdue,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        '${widget.tasks.length}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: DsSpace.x4),
                      Icon(
                        _open ? Icons.expand_less : Icons.expand_more,
                        size: DsIcon.sm,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_open)
          for (final task in widget.tasks)
            Padding(
              padding: const EdgeInsets.only(top: DsSpace.x4),
              child: AppTaskRow(
                title: task.title,
                subtitle: widget.taskLists[task.listId]?.name,
                priority: visualTaskPriority(task),
                overdue: true,
                dense: true,
                onTap: () => widget.onTaskTap(task),
                onToggle: () => widget.onToggleTask(task),
              ),
            ),
      ],
    );
  }
}

Color? parseColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  var value = hex.trim();
  if (value.startsWith('#')) value = value.substring(1);
  if (value.length == 6) value = 'FF$value';
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? null : Color(parsed);
}
