import 'package:ephemeron/features/stream/presentation/stream_layout_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cases = <(double, StreamLayoutMode)>[
    (0, StreamLayoutMode.compact),
    (360, StreamLayoutMode.compact),
    (599.9, StreamLayoutMode.compact),
    (600, StreamLayoutMode.medium),
    (700, StreamLayoutMode.medium),
    (839.9, StreamLayoutMode.medium),
    (840, StreamLayoutMode.expanded),
    (1200, StreamLayoutMode.expanded),
  ];
  for (final c in cases) {
    test('width ${c.$1} -> ${c.$2}', () {
      expect(streamLayoutModeForWidth(c.$1), c.$2);
    });
  }
}
