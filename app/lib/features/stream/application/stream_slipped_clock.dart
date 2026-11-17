// Injectable local clock for slipped-task derivation and triage actions.
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef StreamSlippedClock = DateTime Function();

final streamSlippedClockProvider = Provider<StreamSlippedClock>(
  (ref) => DateTime.now,
);
