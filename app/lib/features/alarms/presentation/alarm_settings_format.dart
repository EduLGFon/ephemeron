// Pure formatting helpers for the alarm settings lists. Kept free of widget
// code so upcoming and missed times can be tested without a widget tree.
import 'package:intl/intl.dart';

/// Converts the stored UTC milliseconds to local time and formats it with the
/// device-aware formatter supplied by the caller. Callers pass
/// `DeviceDateFormat.yMMMd(context).add_Hm()` (or any other device format).
String formatAlarmFireTime(int fireAtUtcMs, DateFormat formatter) {
  final local = DateTime.fromMillisecondsSinceEpoch(
    fireAtUtcMs,
    isUtc: true,
  ).toLocal();
  return formatter.format(local);
}
