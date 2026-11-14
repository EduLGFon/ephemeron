# Ephemeron API

Deno + Hono + Postgres backend for habits and focus sessions.

Versions: Deno 2.9.8, Hono 4.13.18, Postgres 18.7.

## Env

See .env.example. PORT defaults to 8091.

## Run locally

```
cp .env.example .env
# edit DATABASE_URL etc
deno run --allow-all main.ts
```

## Production

Production (APP_ENV=production) requires DATABASE_URL and 32+ char JWT_SECRET;
process exits otherwise. argon2 native lib needs unscoped --allow-ffi
(path-scoped ffi breaks UnsafePointerView at hash time). Deployed systemd unit
on this host:

```
deno run --allow-net=127.0.0.1:5434,127.0.0.1:8091 --allow-env --allow-ffi --allow-read=/home/io/p/ephemeron-app/server,/home/io/.cache/deno main.ts
```

with HOST=127.0.0.1 PORT=8091; postgres on 127.0.0.1:5434 (own cluster; port
5433 belongs to system postgres).

## Docker

See docs/DOCKER.md at repo root. Quick start:

```
cd server
cp .env.example .env  # add POSTGRES_PASSWORD and JWT_SECRET
docker compose up -d --build
```

API listens on 127.0.0.1:8091. Postgres data persists in pgdata volume. No
database port published.

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

Set DATABASE_URL. Run migrations: psql $DATABASE_URL -f
server/migrations/001_init.sql. Pool size via PGPOOL_MAX (default 10). CORS via
CORS_ORIGINS (comma-separated). JWT_SECRET required in production
(APP_ENV=production).
