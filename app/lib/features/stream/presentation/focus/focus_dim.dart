// Pure helper mapping a mark's tone while focus mode is active.
// No Flutter imports: callers map the tier to colours.

enum FocusDimTier { none, dim, dimmer }

FocusDimTier focusDimTier({
  required bool focusActive,
  required bool isFocusedMark,
  int distanceSteps = 0,
}) {
  if (!focusActive || isFocusedMark) return FocusDimTier.none;
  return distanceSteps >= 2 ? FocusDimTier.dimmer : FocusDimTier.dim;
}
