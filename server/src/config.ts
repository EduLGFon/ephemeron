const env = (k: string) => Deno.env.get(k);

export const config = {
  appEnv: env("APP_ENV") ?? "development",
  port: Number(env("PORT") ?? "8091"),
  host: env("HOST") ?? "0.0.0.0",
  databaseUrl: env("DATABASE_URL") ?? "",
  pgPoolMax: Number(env("PGPOOL_MAX") ?? "10"),
  corsOrigins: (env("CORS_ORIGINS") ?? "https://ephemeron.spotnik.space")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean),
  jwtSecret: env("JWT_SECRET") ?? "dev-secret-change-me",
  accessTtlSec: Number(env("ACCESS_TOKEN_TTL_SEC") ?? "900"),
  refreshTtlSec: Number(env("REFRESH_TOKEN_TTL_SEC") ?? "2592000"),
};

if (
  config.appEnv === "production" &&
  (!config.jwtSecret ||
    config.jwtSecret === "dev-secret-change-me" ||
    config.jwtSecret.length < 32)
) {
  throw new Error("JWT_SECRET must be set in production with length >= 32");
}
