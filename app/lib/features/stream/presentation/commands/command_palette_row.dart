/// Row widget for the command palette.
library;

import 'package:material_ui/material_ui.dart';

import 'command_palette.dart' show CommandCandidate;

class CommandPaletteRow extends StatelessWidget {
  const CommandPaletteRow({
    super.key,
    required this.candidate,
    required this.selected,
    required this.hovered,
    required this.onHoverChanged,
    required this.onTap,
  });

  final CommandCandidate candidate;
  final bool selected;
  final bool hovered;
  final ValueChanged<bool> onHoverChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: Semantics(
        button: true,
        selected: selected,
        label: candidate.label,
        child: InkWell(
          key: ValueKey(candidate.id),
          onTap: onTap,
          child: Container(
            color: (selected || hovered)
                ? Theme.of(context).highlightColor
                : null,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidate.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (candidate.subtitle.isNotEmpty)
                        Text(
                          candidate.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
