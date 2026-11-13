# iOS home-screen widgets (owner/Xcode work)

Status: not implemented. Requires macOS + Xcode; cannot be completed/verified on Linux build env. Do not add WidgetKit targets/entitlements/project.pbxproj edits from Linux.

## Already exists
- Android widget providers/layouts: app/android/.../HomeWidgets.kt, WeekCalendarWidget.kt, CollectionWidgets.kt.
- Dart widget definitions/refresh binding: app/lib/data/services/home_widget_service.dart and related.
- home_widget treated supported on iOS in app/lib/data/services/home_widget_support.dart; no Dart-side platform guard change needed.

## Owner steps (Xcode/macOS)
1. Regenerate iOS scaffolding if needed (`flutter create .` in app/), open app/ios/Runner.xcworkspace.
2. Add WidgetKit extension target.
3. Enable App Groups for Runner and extension, one shared group id.
4. Publish group id to Dart and call HomeWidget.setAppGroupId(...) before widget data written (no such call yet).
5. Implement SwiftUI views reading shared keys (title/body/image per provider, matching Android key prefixes).
6. Register every widget kind in extension bundle + Info.plist.
7. Build/run on iOS simulator/device; verify rendering, refresh, deep links (ephemeron://...).

## Optional non-Xcode prep (owner-approved)
- Choose/document App Group identifier.
- Add Dart constant and call HomeWidget.setAppGroupId.
- Keep key prefixes aligned with home_widget_service.dart.
Left undone because group id and extension contract must settle in Xcode first.