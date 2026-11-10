# Ephemeron API

Deno + Hono + Postgres backend for habits and focus sessions.

## Env

See `.env.example`. PORT defaults to 8091.

## Run locally

```
cp .env.example .env
# edit DATABASE_URL etc
deno run --allow-all main.ts
```

## Tests

```
deno test --allow-all
deno lint
deno fmt --check
```

## Endpoints

- GET /health -> {ok:true}
- POST /auth/register {email,password} ->
  {email,accessToken,refreshToken,expiresInSec}
- POST /auth/login ...
- POST /auth/refresh {refreshToken} -> rotated
- POST /auth/logout {refreshToken}
- DELETE /account (Bearer)
- POST /sync/push (Bearer) {habits,habitLogs,focusSessions}
- GET /sync/pull?since=<ms> (Bearer)

## Database

Set DATABASE_URL. Run migrations:
`psql $DATABASE_URL -f server/migrations/001_init.sql` Pool size via PGPOOL_MAX
(default 10). CORS via CORS_ORIGINS (comma-separated). JWT_SECRET required in
production (APP_ENV=production).
