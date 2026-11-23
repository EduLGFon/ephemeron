# TODO

## Device / owner verification (open)
- [ ] Week calendar home widget: Android build/launcher behavior, warm/cold tap navigation, Motorola One Fusion 4x2 setup dialog.
- [ ] Alarm ring flow on device: audio/flashlight, cold/warm notification taps open /ring, Snooze/Dismiss/Open stop native audio, Android 14+ without full-screen intent permission, alarms with notifications disabled marked missed, locked-device full-screen ring over keyguard with biometric, minute repeats do not re-alert.
- [ ] Verify 2026-11-16 alarm changes on device (no multi-alarm ring after hibernation, overdue rows missed, long audio starts only on rendered RingScreen, >2-min active ring survives resume auto-snooze 10 min with toast, stale deliveries without fire time do not ring).
- [ ] Native notification Dismiss does not run Dart; next habit occurrence scheduled on next app open.
- [ ] Google sign-in and runtime permissions on Android debug/release, decline path, device-calendar import/settings, first reminder/alarm prompts, exact-alarm/full-screen prompts. Google Cloud console: SHA-1 entries, Calendar/Tasks APIs, Web serverClientId match.
- [ ] Android multi-account silent restore on a real device (restart with two+ granted accounts; no picker; sync uses each token; revoked grant shows reconnect banner).
- [ ] Microsoft web sign-in: Entra SPA redirect registration for http://localhost:8080/auth.html (Android primary target).
- [ ] Real-account checks: shared Google/Microsoft calendars, freeBusyReader, recurring exceptions moved/cancelled, Google single-occurrence edit/delete, multi-account restart + reconnect banner, device-calendar refresh, force-sync error paths.
- [ ] Visual/device checks: themes, More command center, onboarding, quick add, search, calendar, tasks, notes/auth, habits/focus/countdowns, alarm ring navigation, matrix density/peek at 2.5x/3x text, notes grid perf, 320dp large-text layouts.
- [ ] New UI (2026-11-18): Android profile run for Today/Tasks/Calendar frame build/raster on mid-range 60Hz and 120Hz; cold/warm start and idle RAM; battery while idle and during focus session. No numbers claimed before run.
- [ ] New UI dynamic colour on Android 12+: system accent changes, light/dark/AMOLED, fallback when platform channel returns null.
- [ ] New UI denied states on device: notifications denied, exact alarms denied, full-screen intent denied, Settings fix-it rows at 320dp/200%.
- [ ] New UI 320dp/200% visual pass: Calendar, Habits, Focus, Countdowns, Notes, Matrix, Search, Quick Add, including focus rings and 48dp targets with keyboard and touch.
- [ ] New UI Stream opt-in: repeat direct-link/restore check on device (widget tests already cover).
- [ ] New UI platform builds: iOS, macOS, Windows (not run on Linux integration host); Linux desktop after installing webkit2gtk-4.0.

## Owner / legal / store (open)
- [ ] Security review code-level done (docs/SECURITY_REVIEW.md); Play declarations, backup rules, release-build verification are owner checks.
- [ ] Privacy policy draft done (docs/PRIVACY.md EN/PT); needs lawyer sign-off.
- [ ] Store assets and staged rollout: owner.
- [ ] iOS: home-screen widgets need WidgetKit extension, App Group entitlement, signing, SwiftUI views (docs/IOS_WIDGETS.md); Critical Alerts needs entitlement + App Store Connect request. Needs macOS + Xcode.

## Accepted limitations / follow-ups (open)
- [ ] UI English-only by decision; full localization is separate owner-approved effort.
- [ ] Google has no single-token cross-account move; cross-account copy/delete requires both accounts synced at least once.
- [ ] Microsoft shared-primary calendars not in /me/calendars not enumerable without owner address.
- [ ] Initial unbounded Google full sync can be heavy on very large calendars.
- [ ] Google restore silent per account; revoked grant needs one interactive reconnect; web cannot refresh after reload; legacy iOS accounts need one reconnect.
- [ ] Device calendars: manual refresh, fixed [now-30d, now+365d] window; rows drifting outside soft-deleted; no background live device sync.
- [ ] Microsoft deletion reconciliation skips recurring rows and rows with unprovable overlap.
- [ ] Sync diagnostics show only non-personal allowlisted labels.
- [ ] Notes' relative "Saved Xm ago" refreshes on rebuild, not live timer.
- [ ] Native notification Dismiss schedules next habit occurrence on next app open (no headless worker).
- [ ] wakelock_plus held at 1.8.0 due to dbus pin; revisit when either relaxes.
- [ ] Do not run release build while flutter run active (both rewrite GeneratedPluginRegistrant.java).
- [ ] Docker image build unverified (docker.service failed to start; sudo needs password).
- [ ] Linux build blocked by missing webkit2gtk-4.0.
- [ ] iOS/macOS/Windows builds not run (Linux host).
- [ ] Alarm missed history retained 24 h only.
- [ ] Focus alarm phase/body not stored in alarms_index; foreground notification cannot carry focus next-phase action.
- [ ] Full-screen alarm audio confined to visible RingScreen; if screen cannot open, alarm becomes missed.
- [ ] Linked countdowns local-only; not sent to backend.
- [ ] Habit statistics use local logs; weekly-target stats show current week only.
- [ ] Stabilize `todo_coverage` long-press task reorder gesture timing (flaky in combined suite).
- [ ] Isolate platform-channel/stream state so first combined test run is green (habits_timer 320dp, l10n search screen, todo_coverage drag).
- [ ] Delete dead code `app/lib/app/shell/app_sections.dart` in a unit that owns the file.
- [ ] Web cold-boot hash deep links (`/#/tasks`) overridden by router initialLocation and session restore; follow up only if bookmarks must survive reload.
- [ ] Add tracked `manifest.json`/`favicon.png` under `app/web` or drop tags (release web 404s).
- [ ] Three plugins still apply Kotlin Gradle Plugin (flutter_web_auth_2, home_widget, workmanager_android); upstream.
- [ ] Generated l10n header ignore for deprecated_member_use; revisit when generator migrates.
- [ ] Release build warns CupertinoIcons font absent; no app code uses it.
- [ ] AGP/Gradle/Kotlin above Flutter 3.50 max-known but build-verified.
- [ ] Google Calendar incremental sync primary calendar receives HTTP 410 each run; falls back to full resync. Find why stored v2 token rejected.
- [ ] Serialize background and foreground sync or isolate DB connection (WorkManager overlap).
- [ ] Ephemeron domains rollout (u10d): owner DNS/hosting steps pending (Cloudflare records, Pages custom domain, tunnel/route for api, OAuth console origins).
- [ ] Backend hardening deferred to deploy: reverse-proxy client_max_body_size (~1MB), strip/overwrite X-Forwarded-For, run API as non-root with least-privilege deno flags.
- [ ] Code follow-ups: wrap server/src/jwt.ts atob in try/catch; bound or TTL-sweep server/main.ts rate-limit buckets; 400 on since=NaN in pull; rename weak expired-refresh test and add real-expiry case; note app/web gitignored in docs/PAGES_DEPLOY.md.

## Stream UI (v3, opt-in) (open)
- [ ] Wire tray drag-to-schedule.
- [ ] Wire peek inline editor.
- [ ] Wire slipped triage.
- [ ] Wire focus mode controls.
- [ ] Wire habit gutter.
- [ ] Wire countdown landmarks.
- [ ] Implement progressive hints.
- [ ] Wire permission banners.
- [ ] Run Phase 0 perf gate (frame build/raster, cold start, memory, 2000-mark scroll) after spike fix.
- [ ] Review follow-up: week/month painters over 300 lines.
- [ ] Review follow-up: palette duplication in the emitter.
- [ ] Review follow-up: `_mapRow` length.
- [ ] Review follow-up: cluster layout complexity.
