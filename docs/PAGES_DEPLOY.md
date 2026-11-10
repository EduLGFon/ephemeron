# GitHub Pages deployment for `https://ephemeron.spotnik.space`

This document covers the owner-side setup that cannot be done from the repo.
The automated workflow is `.github/workflows/pages.yml` (triggers on pushes to
`master` and via manual dispatch). It builds Flutter web release with
`BACKEND_BASE_URL=https://api-ephemeron.spotnik.space` and deploys with
`actions/deploy-pages`.

## What the repo already provides

- `app/web/CNAME` contains `ephemeron.spotnik.space`, so the deployed artifact
  carries the custom domain (compatible with `actions/deploy-pages`).
- `app/web/index.html` already embeds the Google web client id
  `927111009905-v93shl2b2g8oc71t2kamvlpu3ricvet7.apps.googleusercontent.com`.
- Base href is `/` (custom domain at root; no subpath).

## SPA routing (no 404.html added)

The app uses go_router without a `setUrlStrategy` call, so it runs on Flutter's
default hash URL strategy (`/#/...`). Deep links are encoded in the fragment,
which GitHub Pages serves without server-side routing, so no `404.html`
redirect-back-to-index fallback is required. If the app later switches to
path strategy, add the standard GitHub Pages `404.html` redirect.

## Drift / WASM storage on GitHub Pages (COOP/COEP)

`app/lib/data/drift/app_database.dart` opens the DB via `driftDatabase` with
`DriftWebOptions(sqlite3Wasm, driftWorker)`. `drift_flutter` prefers OPFS when
the browser offers cross-origin isolation; on GitHub Pages (no COOP/COEP
headers) OPFS is unavailable and it falls back to IndexedDB. Expectation:
graceful degradation, no crash, data persists in IndexedDB. Do not add headers
or wrappers that would break the Pages deploy (Pages cannot set COOP/COEP).

## Owner-side checklist (only the owner can do)

1. GitHub repo `EduLGFon/ephemeron-app` -> Settings -> Pages:
   - Source: GitHub Actions.
   - Custom domain: `ephemeron.spotnik.space`.
   - Enforce HTTPS: enabled (after DNS resolves).
2. DNS for `ephemeron.spotnik.space`:
   - CNAME record to `edulgfon.github.io` (or the Pages target shown by
     GitHub), OR the A/AAAA records GitHub documents for apex-style setups.
   - Wait for verification and HTTPS certificate issuance.
3. Google Cloud Console:
   - Authorized JavaScript origin: `https://ephemeron.spotnik.space`.
   - OAuth consent screen: add test users if the app stays in testing.
   - Calendar API and Tasks API enabled (already required for other platforms).
4. Microsoft Entra (Azure AD):
   - Update the SPA redirect URI from `http://localhost:8080/auth.html` to
     `https://ephemeron.spotnik.space/auth.html`.
   - Note: the app's default `microsoftWebRedirectUri` is the localhost value;
     for Pages builds either pass
     `--dart-define=MICROSOFT_WEB_REDIRECT_URI=https://ephemeron.spotnik.space/auth.html`
     or update the default in a later change. `app/web/auth.html` must also be
     present in the build output for this flow (currently not in the tree).
5. Backend API `https://api-ephemeron.spotnik.space` must be live and allow
   CORS from `https://ephemeron.spotnik.space` (built in parallel; not this
   repo).

## Verification

- Workflow YAML parses: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/pages.yml'))"`.
- `flutter analyze` and `flutter test` run in CI; no Dart changes in this task.
- After first successful deploy, open `https://ephemeron.spotnik.space` and
  confirm Google sign-in works and data persists across reloads (IndexedDB
  fallback).
Note: `app/web` is gitignored, so any future `app/web/*` static file (like `CNAME`) must be added with `git add -f`.
