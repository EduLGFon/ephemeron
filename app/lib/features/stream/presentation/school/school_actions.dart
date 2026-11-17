import 'package:material_ui/material_ui.dart';

class SchoolActions extends StatelessWidget {
  const SchoolActions({
    super.key,
    required this.skipLabel,
    required this.nextLabel,
    required this.onSkip,
    required this.onNext,
  }) : assert(skipLabel != ''),
       assert(nextLabel != '');

  final String skipLabel;
  final String nextLabel;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 8,
      runSpacing: 8,
      children: [
        Semantics(
          button: true,
          label: skipLabel,
          child: TextButton(onPressed: onSkip, child: Text(skipLabel)),
        ),
        Semantics(
          button: true,
          label: nextLabel,
          child: FilledButton(onPressed: onNext, child: Text(nextLabel)),
        ),
      ],
    );
  }
}
