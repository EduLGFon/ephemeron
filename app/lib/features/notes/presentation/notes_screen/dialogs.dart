part of '../notes_screen.dart';

// New-note template sheet rows and the FTS search dialog.

/// One selectable template row in the new-note sheet.
class _TemplateOption extends StatelessWidget {
  const _TemplateOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpace.x16,
        vertical: DsSpace.x4,
      ),
      child: AppSurface(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpace.x16,
          vertical: DsSpace.x12,
        ),
        child: Row(
          children: [
            Icon(icon, size: DsIcon.md),
            const SizedBox(width: DsSpace.x12),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
