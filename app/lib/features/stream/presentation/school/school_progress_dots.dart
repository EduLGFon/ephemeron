import 'package:material_ui/material_ui.dart';

class SchoolProgressDots extends StatelessWidget {
  const SchoolProgressDots({
    super.key,
    required this.count,
    required this.currentIndex,
    required this.progressLabel,
    required this.currentStepIdName,
  });

  final int count;
  final int currentIndex;
  final String Function(String stepId, int current, int total) progressLabel;
  final String currentStepIdName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = progressLabel(currentStepIdName, currentIndex + 1, count);
    return Semantics(
      liveRegion: true,
      label: label,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Semantics(
                label: label,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == currentIndex
                        ? scheme.primary
                        : scheme.outlineVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
