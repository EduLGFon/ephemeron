// Part of the habits screen library: section-grouped, lazily built rows.
part of '../habits_screen.dart';

sealed class _HabitListEntry {
  const _HabitListEntry();
}

class _SectionEntry extends _HabitListEntry {
  const _SectionEntry({required this.name, required this.count});

  final String name;
  final int count;
}

class _HabitEntry extends _HabitListEntry {
  const _HabitEntry(this.habit);

  final Habit habit;
}

class _HabitList extends StatelessWidget {
  const _HabitList({
    required this.habits,
    required this.sections,
    required this.selecting,
    required this.selectedIds,
    required this.strings,
    required this.onToggleSelection,
    required this.onStartSelection,
  });

  final List<Habit> habits;
  final List<HabitSection> sections;
  final bool selecting;
  final Set<String> selectedIds;
  final HabitsStrings strings;
  final void Function(String id) onToggleSelection;
  final void Function(String id) onStartSelection;

  @override
  Widget build(BuildContext context) {
    final grouped = <String?, List<Habit>>{};
    for (final habit in habits) {
      grouped.putIfAbsent(habit.sectionId, () => []).add(habit);
    }
    final knownSections = {for (final section in sections) section.id};
    final orderedIds = [
      ...sections.map((section) => section.id).where(grouped.containsKey),
      ...grouped.keys.where((id) => id != null && !knownSections.contains(id)),
    ];
    final hasNamedSections = orderedIds.isNotEmpty;
    final entries = <_HabitListEntry>[];
    void addSection(String? id, List<Habit> rows) {
      if (hasNamedSections) {
        entries.add(
          _SectionEntry(
            name: id == null ? strings.noSection : _sectionName(id),
            count: rows.length,
          ),
        );
      }
      entries.addAll(rows.map(_HabitEntry.new));
    }

    for (final id in orderedIds) {
      addSection(id, grouped[id]!);
    }
    if (grouped.containsKey(null)) {
      addSection(null, grouped[null]!);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: DsSpace.x48 + DsSpace.x48),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        switch (entry) {
          case _SectionEntry():
            return Padding(
              padding: const EdgeInsets.only(top: DsSpace.x8),
              child: SectionTitle(title: entry.name, count: entry.count),
            );
          case _HabitEntry():
            return _HabitTile(
              key: ValueKey(entry.habit.id),
              habit: entry.habit,
              selecting: selecting,
              selected: selectedIds.contains(entry.habit.id),
              strings: strings,
              onToggleSelection: () => onToggleSelection(entry.habit.id),
              onStartSelection: () => onStartSelection(entry.habit.id),
            );
        }
      },
    );
  }

  String _sectionName(String id) {
    for (final section in sections) {
      if (section.id == id) return section.name;
    }
    return strings.noSection;
  }
}
