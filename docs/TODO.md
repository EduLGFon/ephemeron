# TODO

## Owner/device verification (no devices or SDK here)

- Week calendar home widget: Android build/launcher behavior; warm/cold tap navigation; Motorola One Fusion 4x2 setup dialog.
- Alarm ring flow on device: audio/flashlight; cold/warm notification taps open /ring; Snooze/Dismiss/Open stop native audio; Android 14+ without full-screen intent permission; alarms with notifications disabled marked missed; locked-device full-screen ring over keyguard with biometric; minute repeats do not re-alert.
- Native notification Dismiss does not run Dart; next habit occurrence scheduled on next app open.
- Google sign-in and runtime permissions on Android debug/release, decline path, device-calendar import/settings, first reminder/alarm prompts, exact-alarm/full-screen prompts. Google Cloud console: SHA-1 entries, Calendar/Tasks APIs, Web serverClientId match.
- Microsoft web sign-in: Entra SPA redirect registration for http://localhost:8080/auth.html. Android primary target.
- Real-account checks: shared Google/Microsoft calendars, freeBusyReader, recurring exceptions moved/cancelled, Google single-occurrence edit/delete, multi-account restart + reconnect banner, device-calendar refresh, force-sync error paths.
- Visual/device checks: themes, More command center, onboarding, quick add, search, calendar, tasks, notes/auth, habits/focus/countdowns, alarm ring navigation, matrix density/peek at 2.5x/3x text, notes grid perf, 320dp large-text layouts.
- Device profile run for startup and calendar rebuild timings.

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
- Expired Google tokens require interactive reconnect. Plugin may restore only one lightweight account at a time.
- Device calendars: manual refresh, fixed [now-30d, now+365d] window. Rows drifting outside soft-deleted; no background live device sync (battery/API cost).
- Microsoft deletion reconciliation skips recurring rows and rows with unprovable overlap; left untouched rather than guessed.
- Sync diagnostics show only non-personal allowlisted labels. Outbox payloads, tokens, emails, titles, raw bodies never rendered.
- Notes' relative "Saved Xm ago" refreshes on rebuild, not live timer, to avoid wakeups.
- Native notification Dismiss schedules next habit occurrence on next app open (no headless worker).
- wakelock_plus stays at 1.8.0: 1.8.2 conflicts with battery_plus 7.1.2 via dbus. Revisit when either relaxes.
- Deferred: AGP 9.3 + Gradle 9.5 upgrade (needs migration + build size/behavior comparison).
- Do not run release build while flutter run active; both rewrite GeneratedPluginRegistrant.java; debug registrant includes integration_test, breaks release Java compile.

## Ephemeron domains rollout (u10d, 2026-11-10)

- Owner DNS + hosting steps pending (Cloudflare records, Pages custom domain, tunnel/route for api, OAuth console origins).
- Backend hardening deferred to deploy: reverse-proxy client_max_body_size (~1MB), strip/overwrite X-Forwarded-For at proxy, run API as non-root with least-privilege deno flags.
- Code follow-ups: wrap server/src/jwt.ts atob in try/catch (500-vs-401); bound or TTL-sweep server/main.ts rate-limit buckets; 400 on since=NaN in pull; rename weak expired-refresh test and add real-expiry case; app/web gitignored so future app/web/* static files need git add -f (like CNAME); add that note to docs/PAGES_DEPLOY.md as one line.
- flutter analyze/test not run locally (no SDK) - CI covers.

## Verification record (2026-11-13)

- flutter pub get, flutter gen-l10n, dart run tools/gen_test_runner.dart (116 case files) succeeded.
- dart format --set-exit-if-changed . clean (526 files, 0 changed).
- flutter analyze clean, no issues.
- Full flutter test passed: 773 tests.
- Arm64 release APK: app/build/app/outputs/flutter-apk/app-release.apk, 27,831,621 bytes (27.8 MB), libapp.so only under lib/arm64-v8a, SHA-256 f52ce3b62f08a140cf16110ab6c0f65cd20f7eb48f74c36c6ab45b9c77abb92d. Built with flutter build apk --release --target-platform android-arm64 and temporary non-committed dart-defines for platform OAuth client IDs.
- Pre-existing Drift multiple-database debug warnings appear in test run and do not affect results.