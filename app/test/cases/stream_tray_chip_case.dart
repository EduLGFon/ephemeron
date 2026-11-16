import 'package:ephemeron/features/stream/presentation/tray/tray_item.dart';
import 'package:ephemeron/features/stream/presentation/tray/tray_chip.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('chip min touch target 48', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrayChip(
            item: TrayItem(
              id: 't',
              title: 'Task',
              listId: 'l',
              listName: 'List',
              colorArgb: 0xFF000000,
            ),
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    final size = tester.getSize(find.byType(TrayChip));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(size.width, greaterThanOrEqualTo(48));
  });
}
