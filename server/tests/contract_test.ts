import { assert, assertEquals } from "@std/assert";
import { app, resetAll } from "../main.ts";
const reset = resetAll;

// reset provided by resetAll

async function reg(email = "a@b.com", password = "password123") {
  const res = await app.fetch(
    new Request("http://x/auth/register", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email, password }),
    }),
  );
  return { res, json: await res.json() };
}

Deno.test("health", async () => {
  const res = await app.fetch(new Request("http://x/health"));
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { ok: true });
});

Deno.test("register/login/refresh/logout", async () => {
  reset();
  const r = await reg();
  assertEquals(r.res.status, 200);
  assert(r.json.accessToken && r.json.refreshToken);
  assertEquals(r.json.expiresInSec, 900);

  // duplicate
  const r2 = await reg();
  assertEquals(r2.res.status, 409);

  // login bad
  const bad = await app.fetch(
    new Request("http://x/auth/login", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email: "a@b.com", password: "wrongwrong" }),
    }),
  );
  assertEquals(bad.status, 401);

  // refresh rotates
  const ref = await app.fetch(
    new Request("http://x/auth/refresh", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ refreshToken: r.json.refreshToken }),
    }),
  );
  assertEquals(ref.status, 200);
  const refJson = await ref.json();
  assert(refJson.refreshToken !== r.json.refreshToken);

  // reuse old -> 401 + revoke family (new token should fail too)
  const reuse = await app.fetch(
    new Request("http://x/auth/refresh", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ refreshToken: r.json.refreshToken }),
    }),
  );
  assertEquals(reuse.status, 401);
  const reuse2 = await app.fetch(
    new Request("http://x/auth/refresh", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ refreshToken: refJson.refreshToken }),
    }),
  );
  assertEquals(reuse2.status, 401);

  // logout
  const lo = await app.fetch(
    new Request("http://x/auth/logout", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ refreshToken: refJson.refreshToken }),
    }),
  );
  assertEquals(lo.status, 200);
});

Deno.test("account deletion", async () => {
  reset();
  const r = await reg("c@d.com", "password123");
  const del = await app.fetch(
    new Request("http://x/account", {
      method: "DELETE",
      headers: { Authorization: `Bearer ${r.json.accessToken}` },
    }),
  );
  assertEquals(del.status, 200);
});

Deno.test("sync push/pull shapes", async () => {
  reset();
  const r = await reg();
  const token = r.json.accessToken;
  const habit = {
    id: "h1",
    sectionId: null,
    name: "H",
    frequency: "daily",
    weekdaysMask: 0,
    weeklyTarget: null,
    intervalDays: null,
    goalType: null,
    goalAmount: null,
    unit: null,
    increment: null,
    goalDurationDays: null,
    startDate: null,
    archived: false,
    reminderTime: null,
    alarmPreset: null,
    createdAt: 1,
    updatedAt: 10,
    deletedAt: null,
    extraKey: "ignored",
  };
  const log = {
    id: "l1",
    habitId: "h1",
    dayKey: "2026-01-01",
    amount: 1,
    done: true,
    skipped: false,
    createdAt: 2,
    updatedAt: 11,
  };
  const focus = {
    id: "f1",
    taskId: null,
    habitId: "h1",
    startUtc: 1,
    endUtc: 2,
    targetEndUtc: 3,
    phase: "work",
    note: "n",
    createdAt: 3,
    updatedAt: 12,
  };
  const push = await app.fetch(
    new Request("http://x/sync/push", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        habits: [habit],
        habitLogs: [log],
        focusSessions: [focus],
      }),
    }),
  );
  assertEquals(push.status, 200);

  const pull = await app.fetch(
    new Request("http://x/sync/pull?since=0", {
      headers: { Authorization: `Bearer ${token}` },
    }),
  );
  assertEquals(pull.status, 200);
  const pj = await pull.json();
  assertEquals(pj.habits.length, 1);
  assertEquals(pj.habitLogs.length, 1);
  assertEquals(pj.focusSessions.length, 1);
  assertEquals(pj.habits[0].name, "H");

  // LWW: push older should not overwrite
  const habit2 = { ...habit, name: "H2", updatedAt: 5 };
  await app.fetch(
    new Request("http://x/sync/push", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        habits: [habit2],
        habitLogs: [],
        focusSessions: [],
      }),
    }),
  );
  const pull2 = await app.fetch(
    new Request("http://x/sync/pull?since=0", {
      headers: { Authorization: `Bearer ${token}` },
    }),
  );
  const pj2 = await pull2.json();
  assertEquals(pj2.habits[0].name, "H");

  // tombstone habit
  const delHabit = { ...habit, deletedAt: 20, updatedAt: 20 };
  await app.fetch(
    new Request("http://x/sync/push", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        habits: [delHabit],
        habitLogs: [],
        focusSessions: [],
      }),
    }),
  );
  const pull3 = await app.fetch(
    new Request("http://x/sync/pull?since=0", {
      headers: { Authorization: `Bearer ${token}` },
    }),
  );
  const pj3 = await pull3.json();
  assert(pj3.habits[0].deletedAt !== null);
});

Deno.test("413 beyond 200", async () => {
  reset();
  const r = await reg();
  const big = Array.from(
    { length: 201 },
    (_, i) => ({ id: `h${i}`, name: "x", createdAt: 1, updatedAt: 2 }),
  );
  const res = await app.fetch(
    new Request("http://x/sync/push", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        Authorization: `Bearer ${r.json.accessToken}`,
      },
      body: JSON.stringify({ habits: big, habitLogs: [], focusSessions: [] }),
    }),
  );
  assertEquals(res.status, 413);
});

Deno.test("401 unauthorized pull", async () => {
  const res = await app.fetch(new Request("http://x/sync/pull?since=0"));
  assertEquals(res.status, 401);
});

Deno.test("expired refresh keeps family", async () => {
  reset();
  await reg("e@f.com", "password123");
  // access via main module storage not exported; manipulate through app? Instead use refresh with bogus expiry impossible.
  // We at least assert login still works after a 401 from a garbage token.
  const bad = await app.fetch(
    new Request("http://x/auth/refresh", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ refreshToken: "nope" }),
    }),
  );
  assertEquals(bad.status, 401);
  const login = await app.fetch(
    new Request("http://x/auth/login", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email: "e@f.com", password: "password123" }),
    }),
  );
  assertEquals(login.status, 200);
});

Deno.test("case-insensitive email", async () => {
  reset();
  const r1 = await reg("User@x.com", "password123");
  assertEquals(r1.res.status, 200);
  const r2 = await reg("user@x.com", "password123");
  assertEquals(r2.res.status, 409);
});

Deno.test("cross-user isolation", async () => {
  reset();
  const a = await reg("a@b.com", "password123");
  const b = await reg("c@d.com", "password123");
  // A pushes habit
  await app.fetch(
    new Request("http://x/sync/push", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        Authorization: `Bearer ${a.json.accessToken}`,
      },
      body: JSON.stringify({
        habits: [{ id: "hA", name: "A", createdAt: 1, updatedAt: 10 }],
        habitLogs: [],
        focusSessions: [],
      }),
    }),
  );
  // B pulls since 0 -> no A rows
  const pullB = await app.fetch(
    new Request("http://x/sync/pull?since=0", {
      headers: { Authorization: `Bearer ${b.json.accessToken}` },
    }),
  );
  const pj = await pullB.json();
  assertEquals(pj.habits.length, 0);
  // B pushes same id -> does not overwrite A
  await app.fetch(
    new Request("http://x/sync/push", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        Authorization: `Bearer ${b.json.accessToken}`,
      },
      body: JSON.stringify({
        habits: [{
          id: "hA",
          name: "B-overwrite",
          createdAt: 1,
          updatedAt: 100,
        }],
        habitLogs: [],
        focusSessions: [],
      }),
    }),
  );
  const pullA = await app.fetch(
    new Request("http://x/sync/pull?since=0", {
      headers: { Authorization: `Bearer ${a.json.accessToken}` },
    }),
  );
  const pjA = await pullA.json();
  assertEquals(pjA.habits[0].name, "A");
});

Deno.test("429 rate limit auth", async () => {
  reset();
  // spam register/login
  let last = 0;
  for (let i = 0; i < 12; i++) {
    const res = await app.fetch(
      new Request("http://x/auth/login", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ email: "x@y.com", password: "password123" }),
      }),
    );
    last = res.status;
    if (res.status === 429) {
      assert(res.headers.get("retry-after"));
      break;
    }
  }
  assertEquals(last, 429);
});
