// Self-contained sections of the event editor form. Each takes its
// current value plus mutation callbacks so the editor state keeps the
// single source of truth.
part of '../event_editor_sheet.dart';

// All-day toggle plus start and end date/time rows.
class _EventWhenSection extends StatelessWidget {
  const _EventWhenSection({
    required this.allDay,
    required this.start,
    required this.end,
    required this.onToggleAllDay,
    required this.onPickDate,
    required this.onPickTime,
  });

  final bool allDay;
  final DateTime start;
  final DateTime end;
  final ValueChanged<bool> onToggleAllDay;
  final void Function(bool isStart) onPickDate;
  final void Function(bool isStart) onPickTime;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          value: allDay,
          onChanged: onToggleAllDay,
          title: const Text('All day'),
          contentPadding: EdgeInsets.zero,
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => onPickDate(true),
                child: Text(DeviceDateFormat.yMMMd(context).format(start)),
              ),
            ),
            const SizedBox(width: 8),
            if (!allDay)
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onPickTime(true),
                  child: Text(DeviceDateFormat.time(context, start)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => onPickDate(false),
                child: Text(DeviceDateFormat.yMMMd(context).format(end)),
              ),
            ),
            const SizedBox(width: 8),
            if (!allDay)
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onPickTime(false),
                  child: Text(DeviceDateFormat.time(context, end)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// Google Calendar color wheel; null color uses the theme primary and
// shows a check on the selected row. The swatch is paired with a text label so
// the choice is not conveyed by colour alone. Dart part files cannot add
// imports and the parent library is outside this unit's ownership, so this
// wheel uses only widgets already in scope.
class _EventColorSection extends StatefulWidget {
  const _EventColorSection({required this.colorId, required this.onChanged});

  static const _colorIds = <String?>[
    null,
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    '11',
  ];

  final String? colorId;
  final ValueChanged<String?> onChanged;

  @override
  State<_EventColorSection> createState() => _EventColorSectionState();
}

class _EventColorSectionState extends State<_EventColorSection> {
  static const double _itemExtent = 48;
  late final ScrollController _controller;

  int _index(String? colorId) {
    final index = _EventColorSection._colorIds.indexOf(colorId);
    return index < 0 ? 0 : index;
  }

  @override
  void initState() {
    super.initState();
    _controller = ScrollController(
      initialScrollOffset: _index(widget.colorId) * _itemExtent,
    );
  }

  @override
  void didUpdateWidget(covariant _EventColorSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.colorId == oldWidget.colorId || !_controller.hasClients) return;
    _controller.animateTo(
      _index(widget.colorId) * _itemExtent,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 192,
      child: ListView.builder(
        controller: _controller,
        itemExtent: _itemExtent,
        itemCount: _EventColorSection._colorIds.length,
        itemBuilder: (context, index) {
          final c = _EventColorSection._colorIds[index];
          final selected = widget.colorId == c;
          final swatch = c == null ? scheme.primary : googleCalendarColor(c);
          return Semantics(
            button: true,
            selected: selected,
            label: c == null ? 'Default' : 'Color $c',
            child: InkWell(
              key: ValueKey('event-color-${c ?? 'default'}'),
              onTap: () => widget.onChanged(c),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    CircleAvatar(radius: 12, backgroundColor: swatch),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        c == null ? 'Default' : 'Color $c',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: selected ? scheme.primary : scheme.onSurface,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check, size: 18, color: scheme.primary),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
