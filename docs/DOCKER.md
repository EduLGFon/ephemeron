# Docker

Run the Ephemeron sync API and Postgres with Docker Compose.

## Images

- API: denoland/deno:2.9.8.
- DB: postgres:18.7-alpine. 18.7 is a patch within the existing 18.x data format, so no volume migration is needed for this refresh.

## Build
```
cd server
docker compose build
```

## Run
```
cd server
cp .env.example .env
# set POSTGRES_PASSWORD and JWT_SECRET (32+ chars)
docker compose up -d
```
API published on 127.0.0.1:8091. Postgres not published; API reaches it over compose network as db.

## Environment
- POSTGRES_PASSWORD (required)
- JWT_SECRET (required, 32+ chars)
- API_PORT (optional, default 8091)
- APP_ENV, HOST, PORT, PGPOOL_MAX, CORS_ORIGINS, ACCESS_TOKEN_TTL_SEC, REFRESH_TOKEN_TTL_SEC forwarded if set.

## Data
Postgres data in named volume pgdata. Remove with docker compose down -v.

## Logs
docker compose logs -f api / db

## Update
```
git pull
docker compose up -d --build
```
Migrations run automatically at API startup.