# Architecture

Design contract for Ephemeron. Feature specs live in `docs/`. Setup and version pins in `README.md`.

## 1. Principles

- Fast, light, low battery, offline-first, secure, LGPD-compliant.
- Budgets (mid-range Android): cold start <600ms, warm <200ms, frame <16ms, idle RAM <150MB, background CPU zero when idle, battery <1%/day, APK <15MB/ABI, web initial <2MB gzip, any screen query <10ms for 50k rows.

## 2. Stack

- Flutter stable, Dart 3, AOT release, Impeller on.
- State: flutter_riverpod, plain providers, no codegen. Use `select`/`family`.
- Routing: go_router, StatefulShellRoute.indexedStack.
- DB: drift on SQLite. Native: sqlite3 WAL, synchronous=NORMAL, foreign_keys=ON, background isolate. Web: Drift WASM, OPFS with IndexedDB fallback.
- Google: thin http REST client (events, calendarList, tasks, tasklists). Sign-in via google_sign_in v7 (mobile) and loopback OAuth PKCE (desktop). No googleapis.
- Backend (own VPS, habits/focus only): Deno + Hono + Postgres, JWT access (15 min) + rotating refresh, Argon2id. Never receives Google data. Client uses HttpBackendAuthRepository.
- Alarms: native Kotlin module via platform channel. No Dart isolate wakes to ring.
- Markdown: markdown parser + custom lightweight renderer to TextSpan. Preview lazy, cached per note version.
- Deps: every new package needs reason, size check, maintenance check. Pin versions; upgrade one at a time.

## 3. Architecture

Feature-first clean architecture.

```
lib/
  core/      time, ids, result types, logger, db, platform channels, theme
  data/      drift tables, DAOs, remote clients, mappers, repositories
  domain/    pure Dart: entities, recurrence, parsers, use cases
  features/  calendar, tasks, matrix, habits, countdowns, focus, notes, tags, settings, auth, sync, alarms
  app/       shell, router, session restore, quick add
```

Rules:
- `domain/` has no Flutter or Drift imports; heavily unit-tested.
- UI reads only from Drift streams (single source of truth). Network never feeds UI directly.
- Writes: optimistic local write, enqueue outbox row, sync engine pushes. User never waits for network.
- Dependency direction: features -> data -> core; features/data -> domain; domain imports nothing from Flutter/networking. Widgets hold no business logic.

## 4. Platform priority

Android (max), Linux and Web (medium), Windows (low); iOS and macOS supported. Platform-specific APIs guarded with stubs. Unsupported features degrade gracefully.

## 5. Security and privacy (summary)

- Google tokens and Calendar/Tasks data never touch backend. Backend only habits/focus/notes/countdowns via auth REST contract.
- Tokens in flutter_secure_storage via SafeSecureStorage only. Never SharedPreferences, logs, code.
- No analytics, crash-reporting, ads, telemetry SDKs.
- No second local DB beyond Drift, SharedPreferences, flutter_secure_storage.
- TLS only; never disable verification.
- Soft-delete tasks (`isDeleted`); never hard-delete user data without reason.

## 6. Status

See `docs/PROGRESS.md` for phase status and `docs/TODO.md` for open work.
ARCHITECTURE.md is the design contract; changes here require owner approval when they touch security, privacy, persisted data/schema, or public API contracts.