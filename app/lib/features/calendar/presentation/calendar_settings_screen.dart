// Calendar settings: calendars (add/enable/default), device calendar import
// and refresh, week start, default duration.
import 'package:flutter/material.dart';
import 'package:ephemeron/core/time/device_date_format.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/application/settings_providers.dart';
import '../application/calendar_providers.dart';
import '../../../data/drift/app_database.dart';
import '../../../data/services/device_calendar_import_service.dart';
import '../../../core/platform/app_permissions.dart';
import '../../../core/platform/system_launcher.dart';

List<MapEntry<String, List<Calendar>>> _groupCalendars(List<Calendar> cals) {
  final map = <String, List<Calendar>>{};
  for (final c in cals) {
    final key = c.source == 'google'
        ? (c.googleAccount ?? 'Google')
        : c.source == 'microsoft'
        ? (c.microsoftAccount ?? 'Microsoft')
        : 'Device';
    map.putIfAbsent(key, () => []).add(c);
  }
  return map.entries.toList();
}

String _importCounts(DeviceImportResult result) =>
    '${result.inserted} new, ${result.updated} updated, '
    '${result.deleted} removed, ${result.skipped} skipped';

class CalendarSettingsScreen extends ConsumerStatefulWidget {
  const CalendarSettingsScreen({super.key});

  @override
  ConsumerState<CalendarSettingsScreen> createState() =>
      _CalendarSettingsScreenState();
}

class _CalendarSettingsScreenState
    extends ConsumerState<CalendarSettingsScreen> {
  late Future<bool> _hasMappings;

  @override
  void initState() {
    super.initState();
    _hasMappings = _service.hasMappings();
  }

  DeviceCalendarImportService get _service =>
      DeviceCalendarImportService(ref.read(eventRepositoryProvider));

  @override
  Widget build(BuildContext context) {
    final calsAsync = ref.watch(calendarsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Calendars')),
      body: ListView(
        children: [
          calsAsync.maybeWhen(
            data: (cals) => Column(
              children: [
                for (final group in _groupCalendars(cals)) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      group.key,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  for (final c in group.value)
                    SwitchListTile(
                      value: c.enabled,
                      onChanged: (v) => ref
                          .read(eventRepositoryProvider)
                          .setCalendarEnabled(c.id, v),
                      title: Text(c.name),
                      subtitle: Text(c.source),
                    ),
                ],
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Add local calendar'),
                  onTap: () => _addCalendar(),
                ),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('Import from device calendars'),
                  onTap: () => _importDeviceCalendars(),
                ),
                FutureBuilder<bool>(
                  future: _hasMappings,
                  builder: (ctx, snap) {
                    if (snap.data != true) return const SizedBox.shrink();
                    return ListTile(
                      leading: const Icon(Icons.refresh),
                      title: const Text('Refresh device calendars'),
                      onTap: () => _refreshDeviceCalendars(),
                    );
                  },
                ),
              ],
            ),
            orElse: () => const ListTile(title: Text('Loading…')),
          ),
          const Divider(),
          ListTile(
            title: const Text('Week starts on'),
            trailing: FutureBuilder<int>(
              future: _weekStart(),
              builder: (ctx, snap) => DropdownButton<int>(
                value: snap.data ?? DateTime.monday,
                items: [
                  DropdownMenuItem(
                    value: DateTime.monday,
                    child: Text(
                      DeviceDateFormat.eeee(ctx).format(DateTime(2024, 1, 1)),
                    ),
                  ),
                  DropdownMenuItem(
                    value: DateTime.sunday,
                    child: Text(
                      DeviceDateFormat.eeee(ctx).format(DateTime(2024, 1, 7)),
                    ),
                  ),
                  DropdownMenuItem(
                    value: DateTime.saturday,
                    child: Text(
                      DeviceDateFormat.eeee(ctx).format(DateTime(2024, 1, 6)),
                    ),
                  ),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  final repo = await ref.read(
                    settingsRepositoryProvider.future,
                  );
                  await repo.setWeekStart(v);
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Week start saved')),
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<int> _weekStart() async {
    final repo = await ref.read(settingsRepositoryProvider.future);
    return repo.weekStart;
  }

  Future<void> _importDeviceCalendars() async {
    final service = _service;
    if (!service.isSupported) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device calendars not supported here')),
        );
      }
      return;
    }
    // Moment of need with a reason first: the OS prompt follows.
    if (!await AppPermissions.explainCalendarImport(context)) return;
    final granted = await service.requestPermission();
    if (granted == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Calendar permission denied. The import needs read access.',
            ),
            duration: const Duration(seconds: 6),
            persist: false,
            action: SnackBarAction(
              label: 'Settings',
              onPressed: SystemLauncher.openAppSettings,
            ),
          ),
        );
      }
      return;
    }
    final deviceCals = await service.listCalendars();
    if (deviceCals.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No device calendars found')),
        );
      }
      return;
    }
    final appCals =
        (await ref.read(eventRepositoryProvider).watchCalendars().first)
            .where((c) => c.source == 'device')
            .toList();
    if (appCals.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Create a local calendar first')),
        );
      }
      return;
    }
    if (!mounted) return;
    String targetId = appCals.first.id;
    final selected = <String>{};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Import device calendars'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: targetId,
                    items: [
                      for (final c in appCals)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => targetId = v ?? targetId),
                    decoration: const InputDecoration(
                      labelText: 'Target calendar',
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final dc in deviceCals)
                    CheckboxListTile(
                      value: selected.contains(dc.id),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          selected.add(dc.id);
                        } else {
                          selected.remove(dc.id);
                        }
                      }),
                      title: Text(dc.name),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || selected.isEmpty) return;
    var result = const DeviceImportResult();
    final completed = <String>{};
    for (final id in selected) {
      final imported = await service.importCalendar(
        deviceCalendarId: id,
        targetCalendarId: targetId,
      );
      result += imported;
      if (imported.completed) completed.add(id);
    }
    if (completed.isNotEmpty) {
      await service.saveMappings({for (final id in completed) id: targetId});
    }
    if (!mounted) return;
    setState(() => _hasMappings = service.hasMappings());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Imported device calendars: ${_importCounts(result)}'),
      ),
    );
  }

  Future<void> _refreshDeviceCalendars() async {
    final service = _service;
    if (!service.isSupported) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device calendars not supported here')),
        );
      }
      return;
    }
    if (!await AppPermissions.explainCalendarImport(context)) return;
    final granted = await service.requestPermission();
    if (granted == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Calendar permission denied. The refresh needs read access.',
            ),
            duration: const Duration(seconds: 6),
            persist: false,
            action: SnackBarAction(
              label: 'Settings',
              onPressed: SystemLauncher.openAppSettings,
            ),
          ),
        );
      }
      return;
    }
    final result = await service.refreshMappedCalendars();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Refreshed device calendars: ${_importCounts(result)}'),
      ),
    );
  }

  Future<void> _addCalendar() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New calendar'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(eventRepositoryProvider).createCalendar(name);
    }
  }
}
