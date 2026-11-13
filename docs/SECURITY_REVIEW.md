# Security review (code-level, Phase 10)

Date: 2026-10-29. No Android SDK or devices here; device/store items are owner checks.

## Verified in code

- No hardcoded secrets: no API keys/passwords/keystores/tokens in source. OAuth client IDs are public identifiers via --dart-define, never committed.
- Tokens: Google OAuth and backend refresh token only in flutter_secure_storage via SafeSecureStorage. Access tokens in memory. Nothing token-like in SharedPreferences, Drift, logs, or backups (DB holds no tokens).
- Logging: AppLogger caps 500 lines; codebase logs no tokens/passwords/user ids/calendar/note content.
- Transport: no http:// URLs; Google and backend clients HTTPS only. Backend base URL empty by default (offline).
- SQL: all queries through Drift; no string-concatenated SQL. LIKE patterns bound; %/_ wildcards stripped by search methods.
- Backend isolation: backend_api_client.dart, backend_sync_api.dart, backend_sync_engine.dart, backend_auth.dart import no Google code and touch only habit/focus tables. Google outbox entities skipped by backend engine and vice versa.
- Dependencies: no analytics/crash-reporting/ads/telemetry SDKs. Deps first-party or narrowly scoped (http, google_sign_in, flutter_secure_storage, markdown, image, path_provider).
- Android manifest: receivers exported=false; only MainActivity exported. Permissions limited to alarms, boot/time recovery, vibration, notifications, and (fixed 2026-10-29) INTERNET for release.

## Fixed in this review

- INTERNET was debug/profile-only: release builds could not reach Google or backend. Added to main manifest.

## Owner checks (need SDK/device/store)

- Release build: flutter build appbundle, install, verify Google sync, backend sync, alarm fires after reboot.
- Rename com.example.ephemeron to real applicationId AND matching SNOOZE/DONE action strings in AlarmReceiver.kt together.
- Play Console: USE_EXACT_ALARM declaration (calendar/alarm use case).
- Auto-backup rules: exclude secure-storage prefs file so tokens never leave device via Google Drive backup; verify prefs file name for pinned flutter_secure_storage version.
- Confirm backend serves TLS 1.2+ with valid certs; rate limits on.
- Run flutter pub outdated + dependency audit before release.