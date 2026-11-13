# GitHub Pages deployment for https://ephemeron.spotnik.space

Automated workflow: .github/workflows/pages.yml (triggers on push to master and manual dispatch). Builds Flutter web release with BACKEND_BASE_URL=https://api-ephemeron.spotnik.space, deploys via actions/deploy-pages.

## Repo already provides
- app/web/CNAME contains ephemeron.spotnik.space (custom domain carried in artifact).
- app/web/index.html embeds Google web client id 927111009905-v93shl2b2g8oc71t2kamvlpu3ricvet7.apps.googleusercontent.com.
- Base href / (custom domain at root, no subpath).

## SPA routing (no 404.html)
App uses go_router without setUrlStrategy, so default hash URL strategy (/#/...). Deep links in fragment; GitHub Pages serves without server-side routing; no 404.html redirect needed. If switching to path strategy, add standard GitHub Pages 404.html redirect.

## Drift/WASM storage on Pages (COOP/COEP)
app/lib/data/drift/app_database.dart opens DB via driftDatabase with DriftWebOptions(sqlite3Wasm, driftWorker). drift_flutter prefers OPFS when cross-origin isolation available; on Pages (no COOP/COEP headers) OPFS unavailable, falls back to IndexedDB. Expect graceful degradation, no crash, data persists in IndexedDB. Do not add headers/wrappers that break Pages deploy (Pages cannot set COOP/COEP).

## Owner-side checklist
1. GitHub repo EduLGFon/ephemeron-app -> Settings -> Pages: Source GitHub Actions; Custom domain ephemeron.spotnik.space; Enforce HTTPS enabled (after DNS resolves).
2. DNS for ephemeron.spotnik.space: CNAME to edulgfon.github.io (or Pages target), or A/AAAA records GitHub documents. Wait for verification + HTTPS cert.
3. Google Cloud Console: Authorized JS origin https://ephemeron.spotnik.space; OAuth consent screen test users if in testing; Calendar API and Tasks API enabled.
4. Microsoft Entra: update SPA redirect URI from http://localhost:8080/auth.html to https://ephemeron.spotnik.space/auth.html. Note: app default microsoftWebRedirectUri is localhost value; for Pages builds pass --dart-define=MICROSOFT_WEB_REDIRECT_URI=https://ephemeron.spotnik.space/auth.html or update default later. app/web/auth.html must be present in build output (currently not in tree).
5. Backend API https://api-ephemeron.spotnik.space live with CORS from https://ephemeron.spotnik.space.

## Verification
- Workflow YAML parses: python3 -c "import yaml; yaml.safe_load(open('.github/workflows/pages.yml'))".
- flutter analyze and flutter test run in CI; no Dart changes in this task.
- After first successful deploy, open https://ephemeron.spotnik.space and confirm Google sign-in works and data persists across reloads (IndexedDB fallback).

Note: app/web is gitignored, so future app/web/* static files (like CNAME) need git add -f.