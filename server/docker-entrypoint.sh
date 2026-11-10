#!/bin/sh
set -e

# Wait for Postgres to accept connections.
until deno eval --allow-net=db --allow-env --allow-read=/app,/deno-dir "const {Client}=await import('pg');const c=new Client({connectionString:Deno.env.get('DATABASE_URL')});await c.connect();await c.end();" >/dev/null 2>&1; do
  echo "waiting for database..."
  sleep 2
done

# Apply idempotent migration.
deno eval --allow-net=db --allow-env --allow-read=/app,/deno-dir "const sql=Deno.readTextFileSync('/app/migrations/001_init.sql');const {Client}=await import('pg');const c=new Client({connectionString:Deno.env.get('DATABASE_URL')});await c.connect();await c.query(sql);await c.end();console.log('migration applied');"

exec deno run --frozen --allow-net=0.0.0.0,db --allow-env --allow-ffi --allow-read=/app,/deno-dir main.ts
