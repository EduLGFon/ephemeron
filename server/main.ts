// deno-lint-ignore-file no-explicit-any
import { Hono } from "hono";
import { cors } from "hono/cors";
import * as argon2 from "argon2";
import { config } from "./src/config.ts";
import {
  type FocusRow,
  type HabitLogRow,
  type HabitRow,
  InMemoryStorage,
  type Storage,
} from "./src/storage.ts";
import { PostgresStorage } from "./src/pg_storage.ts";
import { signAccessToken, verifyAccessToken } from "./src/jwt.ts";

if (config.appEnv === "production" && !config.databaseUrl) {
  throw new Error("DATABASE_URL must be set in production");
}
const storage: Storage = config.databaseUrl
  ? new PostgresStorage()
  : new InMemoryStorage();
console.log(`storage backend: ${config.databaseUrl ? "postgres" : "memory"}`);

// rate limiter
const buckets = new Map<string, { count: number; reset: number }>();
function rateLimit(
  key: string,
  limit: number,
  windowSec: number,
): { ok: boolean; retryAfter: number } {
  const now = Math.floor(Date.now() / 1000);
  let b = buckets.get(key);
  if (!b || b.reset < now) {
    b = { count: 0, reset: now + windowSec };
    buckets.set(key, b);
  }
  b.count++;
  if (b.count > limit) return { ok: false, retryAfter: b.reset - now };
  return { ok: true, retryAfter: 0 };
}

function authRate(c: any) {
  const ip = c.req.header("x-forwarded-for") ?? "local";
  const r = rateLimit(`auth:${ip}`, 10, 60);
  if (!r.ok) {
    c.header("Retry-After", String(r.retryAfter));
    return c.json({ error: "rate_limited" }, 429);
  }
  return null;
}

const app = new Hono();
app.use("*", cors({ origin: config.corsOrigins }));

app.get("/health", (c: any) => c.json({ ok: true }));

// auth
app.post("/auth/register", async (c: any) => {
  const rl = authRate(c);
  if (rl) return rl;
  let body: any;
  try {
    body = await c.req.json();
  } catch {
    return c.json({ error: "bad_json" }, 400);
  }
  const email = String(body?.email ?? "").trim().toLowerCase();
  const password = String(body?.password ?? "");
  if (!email.includes("@") || email.length > 254) {
    return c.json({ error: "invalid_email" }, 400);
  }
  if (password.length < 8 || password.length > 128) {
    return c.json({ error: "invalid_password" }, 400);
  }
  const existing = await storage.findUserByEmail(email);
  if (existing) return c.json({ error: "email_taken" }, 409);
  const hash = await argon2.hash(password, {
    memoryCost: 19456,
    timeCost: 2,
    parallelism: 1,
  } as any);
  const user = await storage.createUser(email, hash);
  return await issueSession(c, user);
});

app.post("/auth/login", async (c: any) => {
  const rl = authRate(c);
  if (rl) return rl;
  let body: any;
  try {
    body = await c.req.json();
  } catch {
    return c.json({ error: "bad_json" }, 400);
  }
  const email = String(body?.email ?? "").trim().toLowerCase();
  const password = String(body?.password ?? "");
  const user = await storage.findUserByEmail(email);
  const dummyHash =
    "$argon2id$v=19$m=19456,t=2,p=1$1exYM1U1V+KGPSjdlQ$fYi8kd26UDahZZmZSKE2eQUVxJM+JSCCv1Lqlh4c9Qc";
  let ok = false;
  if (user) {
    ok = await argon2.verify(user.passwordHash, password);
  } else {
    await argon2.verify(dummyHash, password);
  }
  if (!user || !ok) {
    return c.json({
      error: "invalid_credentials",
      message: "Invalid credentials.",
    }, 401);
  }
  return await issueSession(c, user);
});

async function issueSession(c: any, user: { id: string; email: string }) {
  const accessToken = await signAccessToken(user.id, user.email);
  const refreshToken = crypto.randomUUID() + crypto.randomUUID();
  const familyId = crypto.randomUUID();
  const hash = await sha256(refreshToken);
  await storage.insertRefreshToken({
    id: crypto.randomUUID(),
    userId: user.id,
    tokenHash: hash,
    familyId,
    expiresAt: Date.now() + config.refreshTtlSec * 1000,
    revokedAt: null,
    createdAt: Date.now(),
  });
  return c.json({
    email: user.email,
    accessToken,
    refreshToken,
    expiresInSec: config.accessTtlSec,
  });
}

async function sha256(s: string): Promise<string> {
  const buf = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(s),
  );
  return Array.from(new Uint8Array(buf)).map((b) =>
    b.toString(16).padStart(2, "0")
  ).join("");
}

app.post("/auth/refresh", async (c: any) => {
  const rl = authRate(c);
  if (rl) return rl;
  let body: any;
  try {
    body = await c.req.json();
  } catch {
    return c.json({ error: "bad_json" }, 400);
  }
  const rt = String(body?.refreshToken ?? "");
  if (!rt) return c.json({ error: "missing_token" }, 400);
  const hash = await sha256(rt);
  const token = await storage.findRefreshTokenByHash(hash);
  if (!token) {
    return c.json({
      error: "invalid_refresh",
      message: "Invalid refresh token.",
    }, 401);
  }
  if (token.revokedAt !== null) {
    await storage.revokeFamily(token.familyId, Date.now());
    return c.json({
      error: "invalid_refresh",
      message: "Invalid refresh token.",
    }, 401);
  }
  if (token.expiresAt < Date.now()) {
    return c.json({
      error: "invalid_refresh",
      message: "Invalid refresh token.",
    }, 401);
  }
  // rotate: revoke current, issue new in same family
  await storage.revokeRefreshToken(token.id, Date.now());
  const user = await storage.findUserById(token.userId);
  if (!user) return c.json({ error: "invalid_refresh" }, 401);
  const accessToken = await signAccessToken(user.id, user.email);
  const newRt = crypto.randomUUID() + crypto.randomUUID();
  const newHash = await sha256(newRt);
  await storage.insertRefreshToken({
    id: crypto.randomUUID(),
    userId: user.id,
    tokenHash: newHash,
    familyId: token.familyId,
    expiresAt: Date.now() + config.refreshTtlSec * 1000,
    revokedAt: null,
    createdAt: Date.now(),
  });
  return c.json({
    email: user.email,
    accessToken,
    refreshToken: newRt,
    expiresInSec: config.accessTtlSec,
  });
});

app.post("/auth/logout", async (c: any) => {
  let body: any;
  try {
    body = await c.req.json();
  } catch {
    body = {};
  }
  const rt = String(body?.refreshToken ?? "");
  if (rt) {
    const hash = await sha256(rt);
    const token = await storage.findRefreshTokenByHash(hash);
    if (token) await storage.revokeRefreshToken(token.id, Date.now());
  }
  return c.json({}, 200);
});

async function requireUser(
  c: any,
): Promise<{ userId: string; email: string } | Response> {
  const auth = c.req.header("Authorization") ?? "";
  const m = auth.match(/^Bearer\s+(.+)$/i);
  if (!m) return c.json({ error: "unauthorized" }, 401);
  const v = await verifyAccessToken(m[1]);
  if (!v) return c.json({ error: "unauthorized" }, 401);
  return v;
}

app.delete("/account", async (c: any) => {
  const u = await requireUser(c);
  if (u instanceof Response) return u;
  await storage.deleteUser(u.userId);
  return c.json({}, 200);
});

// sync push
app.post("/sync/push", async (c: any) => {
  const u = await requireUser(c);
  if (u instanceof Response) return u;
  let body: any;
  try {
    body = await c.req.json();
  } catch {
    return c.json({ error: "bad_json" }, 400);
  }
  const habits = Array.isArray(body?.habits) ? body.habits : [];
  const logs = Array.isArray(body?.habitLogs) ? body.habitLogs : [];
  const focus = Array.isArray(body?.focusSessions) ? body.focusSessions : [];
  const numFields = [
    "weekdaysMask",
    "weeklyTarget",
    "intervalDays",
    "goalAmount",
    "increment",
    "goalDurationDays",
    "createdAt",
    "updatedAt",
    "deletedAt",
    "amount",
    "startUtc",
    "endUtc",
    "targetEndUtc",
  ];
  function badNum(v: unknown): boolean {
    return v !== undefined && v !== null &&
      (typeof v !== "number" || !Number.isFinite(v));
  }
  for (const h of habits) {
    if (!h || typeof h !== "object") return c.json({ error: "bad_row" }, 400);
    if (typeof h.id !== "string" || h.id.trim() === "") {
      return c.json({ error: "bad_row" }, 400);
    }
    for (const f of numFields) {
      if (badNum((h as any)[f])) return c.json({ error: "bad_row" }, 400);
    }
  }
  for (const l of logs) {
    if (!l || typeof l !== "object") return c.json({ error: "bad_row" }, 400);
    if (typeof l.habitId !== "string" || l.habitId.trim() === "") {
      return c.json({ error: "bad_row" }, 400);
    }
    if (typeof l.dayKey !== "string" || l.dayKey.trim() === "") {
      return c.json({ error: "bad_row" }, 400);
    }
    if (badNum(l.amount) || badNum(l.createdAt) || badNum(l.updatedAt)) {
      return c.json({ error: "bad_row" }, 400);
    }
  }
  for (const f of focus) {
    if (!f || typeof f !== "object") return c.json({ error: "bad_row" }, 400);
    if (typeof f.id !== "string" || f.id.trim() === "") {
      return c.json({ error: "bad_row" }, 400);
    }
    for (
      const fld of [
        "startUtc",
        "endUtc",
        "targetEndUtc",
        "createdAt",
        "updatedAt",
      ]
    ) if (badNum((f as any)[fld])) return c.json({ error: "bad_row" }, 400);
  }
  if (habits.length > 200 || logs.length > 200 || focus.length > 200) {
    c.header("Retry-After", "60");
    return c.json({ error: "too_many_rows" }, 413);
  }
  // rate limit per user
  const r = rateLimit(`push:${u.userId}`, 60, 60);
  if (!r.ok) {
    c.header("Retry-After", String(r.retryAfter));
    return c.json({ error: "rate_limited" }, 429);
  }

  for (const h of habits) {
    const row: HabitRow = {
      userId: u.userId,
      id: String(h.id),
      sectionId: h.sectionId == null ? null : String(h.sectionId),
      name: String(h.name ?? "Habit"),
      frequency: String(h.frequency ?? "daily"),
      weekdaysMask: Number(h.weekdaysMask ?? 0),
      weeklyTarget: h.weeklyTarget == null ? null : Number(h.weeklyTarget),
      intervalDays: h.intervalDays == null ? null : Number(h.intervalDays),
      goalType: h.goalType == null ? null : String(h.goalType),
      goalAmount: h.goalAmount == null ? null : Number(h.goalAmount),
      unit: h.unit == null ? null : String(h.unit),
      increment: h.increment == null ? null : Number(h.increment),
      goalDurationDays: h.goalDurationDays == null
        ? null
        : Number(h.goalDurationDays),
      startDate: h.startDate == null ? null : String(h.startDate),
      archived: Boolean(h.archived ?? false),
      reminderTime: h.reminderTime == null ? null : String(h.reminderTime),
      alarmPreset: h.alarmPreset == null ? null : String(h.alarmPreset),
      createdAt: Number(h.createdAt ?? Date.now()),
      updatedAt: Number(h.updatedAt ?? Date.now()),
      deletedAt: h.deletedAt == null ? null : Number(h.deletedAt),
    };
    // sectionId validation: if provided but unknown? We don't have sections table; store as-is per client (client validates). Spec: unknown section -> NULL. We can't know; keep provided. Client merge validates. Server stores provided.
    await storage.upsertHabit(row);
  }
  for (const l of logs) {
    const row: HabitLogRow = {
      userId: u.userId,
      id: String(l.id ?? ""),
      habitId: String(l.habitId),
      dayKey: String(l.dayKey),
      amount: Number(l.amount ?? 0),
      done: Boolean(l.done ?? false),
      skipped: Boolean(l.skipped ?? false),
      createdAt: Number(l.createdAt ?? Date.now()),
      updatedAt: Number(l.updatedAt ?? Date.now()),
    };
    await storage.upsertHabitLog(row);
  }
  for (const f of focus) {
    const row: FocusRow = {
      userId: u.userId,
      id: String(f.id),
      taskId: f.taskId == null ? null : String(f.taskId),
      habitId: f.habitId == null ? null : String(f.habitId),
      startUtc: Number(f.startUtc ?? Date.now()),
      endUtc: f.endUtc == null ? null : Number(f.endUtc),
      targetEndUtc: f.targetEndUtc == null ? null : Number(f.targetEndUtc),
      phase: f.phase == null ? null : String(f.phase),
      note: f.note == null ? null : String(f.note),
      createdAt: Number(f.createdAt ?? Date.now()),
      updatedAt: Number(f.updatedAt ?? Date.now()),
    };
    await storage.upsertFocus(row);
  }
  return c.json({}, 200);
});

app.get("/sync/pull", async (c: any) => {
  const u = await requireUser(c);
  if (u instanceof Response) return u;
  const since = Number(c.req.query("since") ?? "0");
  const habits = await storage.habitsSince(u.userId, since);
  const logs = await storage.habitLogsSince(u.userId, since);
  const focus = await storage.focusSince(u.userId, since);
  return c.json({
    habits: habits.map((h) => ({
      id: h.id,
      sectionId: h.sectionId,
      name: h.name,
      frequency: h.frequency,
      weekdaysMask: h.weekdaysMask,
      weeklyTarget: h.weeklyTarget,
      intervalDays: h.intervalDays,
      goalType: h.goalType,
      goalAmount: h.goalAmount,
      unit: h.unit,
      increment: h.increment,
      goalDurationDays: h.goalDurationDays,
      startDate: h.startDate,
      archived: h.archived,
      reminderTime: h.reminderTime,
      alarmPreset: h.alarmPreset,
      createdAt: h.createdAt,
      updatedAt: h.updatedAt,
      deletedAt: h.deletedAt,
    })),
    habitLogs: logs.map((l) => ({
      id: l.id,
      habitId: l.habitId,
      dayKey: l.dayKey,
      amount: l.amount,
      done: l.done,
      skipped: l.skipped,
      createdAt: l.createdAt,
      updatedAt: l.updatedAt,
    })),
    focusSessions: focus.map((f) => ({
      id: f.id,
      taskId: f.taskId,
      habitId: f.habitId,
      startUtc: f.startUtc,
      endUtc: f.endUtc,
      targetEndUtc: f.targetEndUtc,
      phase: f.phase,
      note: f.note,
      createdAt: f.createdAt,
      updatedAt: f.updatedAt,
    })),
  });
});

export { app, storage };
export function resetAll() {
  (storage as any).users?.clear?.();
  (storage as any).usersByEmail?.clear?.();
  (storage as any).refreshTokens?.clear?.();
  (storage as any).habits?.clear?.();
  (storage as any).habitLogs?.clear?.();
  (storage as any).focus?.clear?.();
  buckets.clear();
}

if (import.meta.main) {
  Deno.serve({ port: config.port, hostname: config.host }, app.fetch);
  console.log(`listening on ${config.host}:${config.port}`);
}
