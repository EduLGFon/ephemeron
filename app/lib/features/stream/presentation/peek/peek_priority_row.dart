import 'package:material_ui/material_ui.dart';

import 'peek_data.dart';

/// Priority segmented control for the Peek editor.
class PeekPriorityRow extends StatelessWidget {
  const PeekPriorityRow({
    super.key,
    required this.labels,
    required this.icons,
    required this.value,
    required this.onChanged,
  });

  final List<String> labels;
  final List<IconData> icons;
  final PeekPriority value;
  final ValueChanged<PeekPriority> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: [
        SegmentedButton<PeekPriority>(
          segments: [
            for (var i = 0; i < labels.length; i++)
              ButtonSegment<PeekPriority>(
                value: PeekPriority.values[i],
                label: Text(labels[i]),
                icon: Icon(icons[i]),
              ),
          ],
          selected: {value},
          onSelectionChanged: (s) => onChanged(s.single),
        ),
      ],
    );
  }
}
