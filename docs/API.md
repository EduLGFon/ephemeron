# Ephemeron Backend API Contract

Base URL: https://api-ephemeron.spotnik.space

## Health
GET /health -> {"ok":true}

## Auth
POST /auth/register {email,password} -> {email,accessToken,refreshToken,expiresInSec} (409 if taken)
POST /auth/login {email,password} -> same (401 on bad)
POST /auth/refresh {refreshToken} -> same with rotated refresh token (401 + family revoke on reuse)
POST /auth/logout {refreshToken} -> 200
DELETE /account (Bearer) -> 200 (deletes all user data)

## Sync
POST /sync/push (Bearer) {habits:[],habitLogs:[],focusSessions:[]} up to 200 each. LWW by updatedAt.
GET /sync/pull?since=<ms> (Bearer) -> {habits,habitLogs,focusSessions}

Errors JSON {error|message}. 429 includes Retry-After.
## Env
DATABASE_URL, PGPOOL_MAX (default 10), CORS_ORIGINS (default https://ephemeron.spotnik.space), JWT_SECRET (required in production), APP_ENV.

## Migrations
psql $DATABASE_URL -f server/migrations/001_init.sql

## Errors
JSON envelope: {"error": "...", "message": "..."} (message optional). 413/429 include Retry-After header.

## Sync cursors
GET /sync/pull?since=<ms> returns rows with updatedAt > since, ascending, capped 200 per type. Client keeps per-type cursors (max updatedAt). Tombstones: habits with deletedAt set are included; keep for pull.

## Data scope
This API stores only account email/password hash, habits, habit logs, focus sessions. Google Calendar/Tasks data never touches this API.
