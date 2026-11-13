FROM denoland/deno:2.9.8

WORKDIR /app

# Dependency layer: only manifests, so source edits do not invalidate it.
COPY deno.json deno.lock ./

# Bake the Deno cache into the image layer (no cache mount on DENO_DIR).
# Bare specifiers resolve through deno.json so versions cannot drift from the lockfile.
RUN printf 'import "hono";\nimport "hono/cors";\nimport "argon2";\nimport "@std/assert";\nimport "pg";\n' > /app/warmup.ts && \
    mkdir -p /deno-dir && \
    DENO_DIR=/deno-dir deno cache --lock=/app/deno.lock /app/warmup.ts && \
    rm -f /app/warmup.ts

# Warm the argon2 native .so at build time so it is baked into the image.
RUN DENO_DIR=/deno-dir deno eval --lock=/app/deno.lock \
    "import('argon2').then(async (m) => { await m.hash('warmup'); console.log('argon2 warmed'); })"

# Source (after deps). Owned by the non-root deno user.
COPY --chown=deno:deno . .

# Entrypoint handles DB readiness + migration, then execs the server.
RUN chmod +x /app/docker-entrypoint.sh

# Non-root runtime.
USER deno

ENV DENO_DIR=/deno-dir
EXPOSE 8091

ENTRYPOINT ["/app/docker-entrypoint.sh"]
