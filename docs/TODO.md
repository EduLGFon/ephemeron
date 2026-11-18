# TODO

## Owner/device verification (open)

- Week calendar home widget: Android build/launcher behavior; warm/cold tap navigation; Motorola One Fusion 4x2 setup dialog.
- Alarm ring flow on device: audio/flashlight; cold/warm notification taps open /ring; Snooze/Dismiss/Open stop native audio; Android 14+ without full-screen intent permission; alarms with notifications disabled marked missed; locked-device full-screen ring over keyguard with biometric; minute repeats do not re-alert. Verify the 2026-11-16 changes: no multi-alarm ring after hibernation, overdue rows appear as missed, long audio starts only on the rendered RingScreen and a >2-minute active ring survives resume, leaving the screen auto-snoozes 10 min with a toast, and stale deliveries without a fire time do not ring.
- Native notification Dismiss does not run Dart; next habit occurrence scheduled on next app open.
- Google sign-in and runtime permissions on Android debug/release, decline path, device-calendar import/settings, first reminder/alarm prompts, exact-alarm/full-screen prompts. Google Cloud console: SHA-1 entries, Calendar/Tasks APIs, Web serverClientId match.
- Android multi-account silent restore on a real device: restart with two or more granted accounts and confirm no account picker appears, sync uses each account's token, and a revoked grant shows the reconnect banner instead of prompting.
- Microsoft web sign-in: Entra SPA redirect registration for http://localhost:8080/auth.html. Android primary target.
- Real-account checks: shared Google/Microsoft calendars, freeBusyReader, recurring exceptions moved/cancelled, Google single-occurrence edit/delete, multi-account restart + reconnect banner, device-calendar refresh, force-sync error paths.
- Visual/device checks: themes, More command center, onboarding, quick add, search, calendar, tasks, notes/auth, habits/focus/countdowns, alarm ring navigation, matrix density/peek at 2.5x/3x text, notes grid perf, 320dp large-text layouts.
- New UI (2026-11-18): Android profile run for Today/Tasks/Calendar frame build/raster on a mid-range 60Hz device and a 120Hz device; cold/warm start and idle RAM; battery while idle and while a focus session runs. No numbers are claimed before this run.
- New UI dynamic colour on Android 12+: system accent changes, light/dark/AMOLED, and the fallback when the platform channel returns null.
- New UI denied states on device: notifications denied, exact alarms denied, full-screen intent denied, and the Settings fix-it rows at 320dp/200%.
- New UI 320dp/200% visual pass: Today, Tasks and Settings plus the compact nav
  passed on the Android 11 device (icon-only nav, no wrapped or clipped labels).
  Remaining: Calendar, Habits, Focus, Countdowns, Notes, Matrix, Search and
  Quick Add, including focus rings and 48dp targets with a keyboard and touch.
- New UI Stream opt-in: done (2026-11-18) in the release web build - Stream
  enabled shows Stream and disabled shows Today. Widget tests cover the
  More/sidebar entry, direct `/stream` redirect and restore not reopening
  Stream; repeat the direct-link/restore check on device.
- New UI platform builds: iOS, macOS and Windows (not run on the Linux integration host); Linux desktop after installing webkit2gtk-4.0.

## Owner console, legal, store

- Security review code-level done (docs/SECURITY_REVIEW.md); Play declarations, backup rules, release-build verification are owner checks.
- Privacy policy draft done (docs/PRIVACY.md EN/PT); needs lawyer sign-off.
- Store assets and staged rollout: owner.
- iOS: home-screen widgets need WidgetKit extension, App Group entitlement, signing, SwiftUI views (docs/IOS_WIDGETS.md); Critical Alerts needs entitlement + App Store Connect request. Needs macOS + Xcode.

## Accepted limitations / decisions

- UI English-only by decision. intl formatting; only existing ARB keys localized; full localization is separate owner-approved effort.
- Google has no single-token cross-account move. Moving recurring Google series to local calendar supported; cross-account copy/delete requires both accounts synced at least once.
- Microsoft shared-primary calendars not in /me/calendars not enumerable without owner address.
- Initial unbounded Google full sync can be heavy on very large calendars.
- Google restore is silent per account: Android re-authorizes by email, iOS by stored Google user id, both with prompting disabled. A revoked grant still needs one interactive reconnect. Web cannot refresh after a reload, and legacy iOS accounts need one reconnect to capture their user id.
- Device calendars: manual refresh, fixed [now-30d, now+365d] window. Rows drifting outside soft-deleted; no background live device sync (battery/API cost).
- Microsoft deletion reconciliation skips recurring rows and rows with unprovable overlap; left untouched rather than guessed.
- Sync diagnostics show only non-personal allowlisted labels. Outbox payloads, tokens, emails, titles, raw bodies never rendered.
- Notes' relative "Saved Xm ago" refreshes on rebuild, not live timer, to avoid wakeups.
- Native notification Dismiss schedules next habit occurrence on next app open (no headless worker).
- wakelock_plus remains 1.8.0 because 1.8.2 requires dbus ^0.8.0 while battery_plus -> upower 0.7.0 pins dbus ^0.7.0. Revisit when either relaxes.
- Do not run release build while flutter run active; both rewrite GeneratedPluginRegistrant.java; debug registrant includes integration_test, breaks release Java compile.
- Docker image build unverified: docker.service failed to start here and sudo needs a password; Dockerfile cache layers and argon2 warm-up were simulated with Deno 2.9.8 in a fresh DENO_DIR.
- Linux build blocked by missing system package webkit2gtk-4.0 (required by desktop_webview_window), not app code.
- iOS/macOS/Windows builds not run (Linux host, no Xcode/Windows).
- Alarm missed history is retained for 24 h only; older settled rows are trimmed by the next window rebuild. There is no separate missed-at timestamp.
- Focus alarm `phase`/`body` are not stored in `alarms_index`; the foreground notification posted when the ring starts cannot carry the focus next-phase action. Ring/snooze/dismiss are unaffected.
- Full-screen alarm audio is confined to the visible RingScreen on Android and to the in-app fallback dialog on web/desktop/iOS. If the screen cannot open, the alarm becomes missed rather than ringing in the background.
- Linked countdowns are local-only; they are not sent to the backend. Event/task date changes update linked target dates, but a countdown can still be edited independently afterward.
- Habit statistics use local logs and existing streak rules; weekly-target stats show the current week only. No schema or backend change was added.
- `todo_coverage` long-press task reorder is timing-flaky in the combined 849-test suite: it passed alone and in subsequent full runs, but failed once during this pass. Follow-up: stabilize the gesture timing in that widget test.
- UI rebirth full-suite order dependence (2026-11-18): the first combined run failed `habits_timer 320dp trailing no overflow with timer` (32px RenderFlex overflow), `l10n search screen localizes titles` (drift stream-disposal pending timer) and `todo_coverage drag handle reorders tasks and persists sortOrder` (drag did not reorder). Each case file passes alone and later full runs passed (the third run 1832/1832), so they are recorded as flakes. Follow-up: isolate platform-channel/stream state so the first combined run is green.
- `app/lib/app/shell/app_sections.dart` has no imports after the adaptive shell and is dead code. Follow-up: delete it in a unit that owns the file.
- Web cold-boot hash deep links (`/#/tasks`) are overridden by the router's fixed `initialLocation` and by session restore calling `goBranch`; a reload lands on the restored tab. Follow-up only if bookmarks must survive reload.
- `app/web` has no tracked `manifest.json` or `favicon.png` (gitignored) while `index.html` references both, so release web logs 404s. Follow-up: add the assets or drop the tags.
- Three plugins still apply Kotlin Gradle Plugin (flutter_web_auth_2, home_widget, workmanager_android); Flutter warns this will fail in a future release. All are latest, so this is upstream.
- Generated l10n keeps a header ignore for deprecated_member_use because Flutter gen-l10n still emits legacy delegates; app code uses material_ui delegates. Revisit when the generator migrates.
- Release build warns the CupertinoIcons font is absent; no app code uses CupertinoIcons.
- AGP 9.5.1, Gradle 9.9.1, Kotlin 2.4.21 are above Flutter 3.50 max-known versions but latest stable; debug and arm64 release builds pass.

## Ephemeron domains rollout (u10d, 2026-11-10)

- Owner DNS + hosting steps pending (Cloudflare records, Pages custom domain, tunnel/route for api, OAuth console origins).
- Backend hardening deferred to deploy: reverse-proxy client_max_body_size (~1MB), strip/overwrite X-Forwarded-For at proxy, run API as non-root with least-privilege deno flags.
- Code follow-ups: wrap server/src/jwt.ts atob in try/catch (500-vs-401); bound or TTL-sweep server/main.ts rate-limit buckets; 400 on since=NaN in pull; rename weak expired-refresh test and add real-expiry case; app/web gitignored so future app/web/* static files need git add -f (like CNAME); add that note to docs/PAGES_DEPLOY.md as one line.

## Stream UI (v3, opt-in)

Stream is opt-in via `settings.streamEnabled` (default off) and is reachable
from the secondary More/sidebar entries only when enabled. Direct `/stream/...`
redirects to `/today` when off and session restore never opens it. All Stream
components and features are retained; no Stream feature was removed.

- [x] Wire capture bar into the day surface.
- [x] Wire command palette into the day surface.
- [ ] Wire tray drag-to-schedule.
- [ ] Wire peek inline editor.
- [ ] Wire slipped triage.
- [x] Wire agenda toggle.
- [x] Wire gesture school overlay.
- [ ] Wire focus mode controls.
- [ ] Wire habit gutter.
- [ ] Wire countdown landmarks.
- [x] Wire week/month level switching.
- [x] Implement year level view.
- [x] Implement settings sheet.
- [ ] Implement progressive hints.
- [ ] Wire permission banners.
- [x] Wire sync/offline states into the surface.
- [x] Remove the legacy tab shell and old screen chrome; the adaptive shell and
      `core/design` components replaced them. Stream remains an optional
      secondary surface.
- [ ] Run Phase 0 perf gate (frame build/raster, cold start, memory, 2000-mark scroll) after the spike fix.
- [ ] Review follow-up: week/month painters over 300 lines.
- [ ] Review follow-up: palette duplication in the emitter.
- [ ] Review follow-up: `_mapRow` length.
- [ ] Review follow-up: cluster layout complexity.

## Verification record (2026-11-13)

Dependency refresh run (Flutter 3.50.0, Dart 3.14.0):

- flutter pub get, flutter gen-l10n, dart run tools/gen_test_runner.dart (116 case files) succeeded.
- dart format --output=none --set-exit-if-changed . clean (526 files, 0 changed).
- flutter analyze --fatal-infos: no issues.
- Full flutter test passed: 773 tests.
- flutter build web --release passed, main.dart.js gzip 1,761,101 B (under 2 MB budget).
- Arm64 release APK: 28,346,708 bytes, SHA-256 afc2409ee0c48bf79d6ff2cf012730a5bb438e153a9ba58d3817359d22629acd. Baseline was 27,831,621 bytes, delta +515,087 bytes (+1.85%). Built with flutter build apk --release --target-platform android-arm64 and temporary non-committed dart-defines for platform OAuth client IDs.
- Server: deno install --frozen, deno check main.ts, deno lint pass; deno test --allow-all 10 passed, 0 failed, 1 pg-gated ignored; changed-file deno fmt passes; compose config resolves postgres:18.7-alpine.
- Pre-existing Drift multiple-database debug warnings appear in test run and do not affect results.
