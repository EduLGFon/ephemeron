// Root messenger for messages that must outlive the route that triggered
// them, such as the ring screen auto-snooze toast after it is replaced.
import 'package:material_ui/material_ui.dart';

final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

abstract final class AppMessenger {
  static void show(String message) {
    final messenger = appMessengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
