---
description: Verify the Ephemeron Flutter app in a real browser via the in-app browser
---

Serve the Ephemeron app for web and verify flow in a real Chromium tab, reporting console errors and screenshots: $ARGUMENTS

If $ARGUMENTS empty, default pass: boot with no console errors, complete onboarding, open every bottom-nav tab (Calendar, Tasks, Matrix, Habits, Countdowns, Focus via More, Notes via More), push Search route, run one search query, open Settings > Account, tap Google sign-in (expect "not configured" snackbar, not crash).

Procedure (in-app browser tools run inside execute Code Mode; call as tools.browser.* after search({namespace:"browser"})):
1. Start server in background from app/: flutter run -d web-server --web-port 8099. For release verification: flutter build web --release, then serve app/build/web on 8099 with python3 -m http.server. Confirm port listens before continuing.
2. Open tab to http://localhost:8099/, wait for load, read console at level error. Zero errors is bar.
3. App renders to canvas, so snapshot shows almost no text. Verify visually with screenshot; drive input:
   - Clicks: dispatch synthetic PointerEvents on canvas inside flt-glass-pane shadow root (pointerover, pointerdown, pointerup with pointerId:1, pointerType:'mouse'). Tapping nav destinations and sheet rows works; buttons opening modal sheets sometimes ignore synthetic events.
   - Modal sheets, text fields, stubborn buttons: use keyboard (Tab traverse, Enter activate). Focused Flutter text field exposes DOM textbox ref you can fill.
   - evaluate scripts run once and return JSON; no timers. Chain small steps across calls and re-screenshot after each.
4. Cover flow end to end, checking console errors after every screen change. Known-good reference: onboarding (3 pages) -> Calendar grid from WASM DB -> Habits day strip -> Countdowns create round-trip -> Search push + query -> Settings/Backup web note -> Account Google guard snackbar -> Focus/Notes/Matrix/Tasks render.
5. Report: exercised, every console error verbatim (or "zero console errors"), screenshot paths. Do not fix failures unprompted; list as findings unless asked.

Notes: first load compiles Dart to JS and can take minutes - wait via repeated short wait calls, never fixed sleeps. flutter test -d chrome cannot drive integration_test/ ("Web devices are not supported for integration tests yet"); this command is the web driver. Kill server when done; leave git status clean of scratch files.