import 'package:material_ui/material_ui.dart';

/// Design tokens for the Stream UI. Plain const values; no codegen.
/// See SUPER_TASK.md "DESIGN LANGUAGE".
abstract final class StreamSpacing {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x6 = 24;
  static const double x8 = 32;
  static const double x12 = 48;
}

abstract final class StreamRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double full = 9999;
}

abstract final class StreamTypeScale {
  static const double xs = 12;
  static const double sm = 14;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double display = 48;
}

abstract final class StreamFontWeight {
  static const int regular = 400;
  static const int medium = 500;
  static const int semibold = 600;
  static const int light = 300;
}

abstract final class StreamLineHeight {
  static const double tight = 1.1;
  static const double normal = 1.4;
  static const double relaxed = 1.6;
}

abstract final class StreamMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 180);
  static const Duration slow = Duration(milliseconds: 250);

  static const Curve standard = Easing.standard;
  static const Curve standardAccelerate = Easing.standardAccelerate;
  static const Curve standardDecelerate = Easing.standardDecelerate;
  static const Curve emphasizedAccelerate = Easing.emphasizedAccelerate;
  static const Curve emphasizedDecelerate = Easing.emphasizedDecelerate;
}

abstract final class StreamBreakpoints {
  static const double compact = 600;
  static const double medium = 840;
}

abstract final class StreamIconSize {
  static const double sm = 16;
  static const double md = 20;
  static const double lg = 24;
}

const String streamFontFamily = 'Inter';
