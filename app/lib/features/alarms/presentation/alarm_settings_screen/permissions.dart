part of '../alarm_settings_screen.dart';

/// Shared permission row: status chip always visible, settings deep link
/// only while the privilege is missing.
class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.status,
    required this.onOpenSettings,
  });

  final IconData icon;
  final String title;
  final String description;
  final Future<bool> status;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: status,
      builder: (context, snap) {
        final granted = snap.data ?? false;
        return ListTile(
          isThreeLine: true,
          leading: Icon(icon),
          title: Text(title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpace.xs),
              _PermissionStatusChip(granted: granted),
              const SizedBox(height: AppSpace.xs),
              Text(description),
            ],
          ),
          trailing: granted
              ? null
              : FilledButton(
                  onPressed: onOpenSettings,
                  child: const Text('Open settings'),
                ),
        );
      },
    );
  }
}

class _PermissionStatusChip extends StatelessWidget {
  const _PermissionStatusChip({required this.granted});

  final bool granted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = granted ? scheme.primary : scheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            granted ? Icons.check_circle_outline : Icons.error_outline,
            size: 14,
            color: color,
          ),
          const SizedBox(width: AppSpace.xs),
          Text(
            granted ? 'Granted' : 'Not granted',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
