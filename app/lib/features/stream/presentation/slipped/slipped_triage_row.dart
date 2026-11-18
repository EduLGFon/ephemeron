import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';
import 'slipped_action_labels.dart';
import 'slipped_item.dart';

class SlippedTriageRow extends StatelessWidget {
  const SlippedTriageRow({
    super.key,
    required this.item,
    required this.overdueText,
    required this.labels,
    required this.selected,
    required this.onDone,
    required this.onTomorrow,
    required this.onPickTime,
    required this.onDrop,
  });

  final SlippedItem item;
  final String overdueText;
  final SlippedActionLabels labels;
  final bool selected;
  final VoidCallback onDone;
  final VoidCallback onTomorrow;
  final VoidCallback onPickTime;
  final VoidCallback onDrop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final doneAction = CustomSemanticsAction(label: labels.done);
    final tomorrowAction = CustomSemanticsAction(label: labels.tomorrow);
    final pickAction = CustomSemanticsAction(label: labels.pickTime);
    final dropAction = CustomSemanticsAction(label: labels.drop);
    return Semantics(
      selected: selected,
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        doneAction: onDone,
        tomorrowAction: onTomorrow,
        pickAction: onPickTime,
        dropAction: onDrop,
      },
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: StreamSpacing.x6,
        ),
        child: Dismissible(
          key: ValueKey<String>('slipped-${item.id}'),
          direction: DismissDirection.horizontal,
          background: _buildBackground(
            scheme,
            Alignment.centerLeft,
            Icons.check,
          ),
          secondaryBackground: _buildBackground(
            scheme,
            Alignment.centerRight,
            Icons.schedule,
            tertiary: true,
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              onDone();
            } else {
              onTomorrow();
            }
            return false;
          },
          child: _buildContent(context, selected),
        ),
      ),
    );
  }

  Widget _buildBackground(
    ColorScheme scheme,
    Alignment alignment,
    IconData icon, {
    bool tertiary = false,
  }) {
    final color = tertiary ? scheme.tertiaryContainer : scheme.primaryContainer;
    final iconColor = tertiary
        ? scheme.onTertiaryContainer
        : scheme.onPrimaryContainer;
    final padding = tertiary
        ? const EdgeInsets.only(right: StreamSpacing.x4)
        : const EdgeInsets.only(left: StreamSpacing.x4);
    return Container(
      color: color,
      alignment: alignment,
      padding: padding,
      child: Icon(icon, color: iconColor),
    );
  }

  Widget _buildContent(BuildContext context, bool selected) {
    return Container(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
                .withValues(alpha: 0.35)
          : null,
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: StreamSpacing.x2,
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Color(item.listColorArgb),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: StreamSpacing.x2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                Text(overdueText, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: labels.done,
          icon: const Icon(Icons.check),
          onPressed: onDone,
        ),
        IconButton(
          tooltip: labels.tomorrow,
          icon: const Icon(Icons.schedule),
          onPressed: onTomorrow,
        ),
        IconButton(
          tooltip: labels.pickTime,
          icon: const Icon(Icons.access_time),
          onPressed: onPickTime,
        ),
        IconButton(
          tooltip: labels.drop,
          icon: const Icon(Icons.close),
          onPressed: onDrop,
        ),
      ],
    );
  }
}
