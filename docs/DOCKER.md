# Docker

Run the Ephemeron sync API and its Postgres database with Docker Compose.

## Build

```
cd server
docker compose build
```

Cold builds take about 7s on this host; rebuilds that only change source
reuse the dependency layer and finish in under 1s.

## Run

```
cd server
cp .env.example .env
# set POSTGRES_PASSWORD and JWT_SECRET (32+ chars)
docker compose up -d
```

The API is published on `127.0.0.1:8091`. Postgres is not published; the API
reaches it over the compose network as `db`.

## Environment

- `POSTGRES_PASSWORD` (required): database password.
- `JWT_SECRET` (required, 32+ chars): JWT signing secret.
- `API_PORT` (optional, default 8091): host port for the API.
- `APP_ENV`, `HOST`, `PORT`, `PGPOOL_MAX`, `CORS_ORIGINS`,
  `ACCESS_TOKEN_TTL_SEC`, `REFRESH_TOKEN_TTL_SEC`: forwarded to the API if set.

## Data

Postgres data lives in the named volume `pgdata`. Remove it with
`docker compose down -v`.

## Logs

```
docker compose logs -f api
docker compose logs -f db
```

## Update flow

```
git pull
docker compose up -d --build
```

Migrations run automatically at API startup.
