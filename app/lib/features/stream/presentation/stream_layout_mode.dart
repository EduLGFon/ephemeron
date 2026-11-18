import '../design/stream_tokens.dart';

enum StreamLayoutMode { compact, medium, expanded }

StreamLayoutMode streamLayoutModeForWidth(double widthDp) {
  if (widthDp < StreamBreakpoints.compact) {
    return StreamLayoutMode.compact;
  }
  if (widthDp < StreamBreakpoints.medium) {
    return StreamLayoutMode.medium;
  }
  return StreamLayoutMode.expanded;
}
