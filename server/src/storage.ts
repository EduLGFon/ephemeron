// deno-lint-ignore-file require-await
// deno-lint-ignore-file no-explicit-any
export interface User {
  id: string;
  email: string;
  passwordHash: string;
  createdAt: number;
}
export interface RefreshToken {
  id: string;
  userId: string;
  tokenHash: string;
  familyId: string;
  expiresAt: number;
  revokedAt: number | null;
  createdAt: number;
}
export interface HabitRow {
  userId: string;
  id: string;
  sectionId: string | null;
  name: string;
  frequency: string;
  weekdaysMask: number;
  weeklyTarget: number | null;
  intervalDays: number | null;
  goalType: string | null;
  goalAmount: number | null;
  unit: string | null;
  increment: number | null;
  goalDurationDays: number | null;
  startDate: string | null;
  archived: boolean;
  reminderTime: string | null;
  alarmPreset: string | null;
  createdAt: number;
  updatedAt: number;
  deletedAt: number | null;
}
export interface HabitLogRow {
  userId: string;
  id: string;
  habitId: string;
  dayKey: string;
  amount: number;
  done: boolean;
  skipped: boolean;
  createdAt: number;
  updatedAt: number;
}
export interface FocusRow {
  userId: string;
  id: string;
  taskId: string | null;
  habitId: string | null;
  startUtc: number;
  endUtc: number | null;
  targetEndUtc: number | null;
  phase: string | null;
  note: string | null;
  createdAt: number;
  updatedAt: number;
}

export interface Storage {
  createUser(email: string, passwordHash: string): Promise<User>;
  findUserByEmail(email: string): Promise<User | null>;
  findUserById(id: string): Promise<User | null>;
  deleteUser(userId: string): Promise<void>;

  insertRefreshToken(t: RefreshToken): Promise<void>;
  findRefreshTokenByHash(hash: string): Promise<RefreshToken | null>;
  revokeRefreshToken(id: string, at: number): Promise<void>;
  revokeFamily(familyId: string, at: number): Promise<void>;

  upsertHabit(row: HabitRow): Promise<void>;
  habitsSince(userId: string, since: number): Promise<HabitRow[]>;
  upsertHabitLog(row: HabitLogRow): Promise<void>;
  habitLogsSince(userId: string, since: number): Promise<HabitLogRow[]>;
  upsertFocus(row: FocusRow): Promise<void>;
  focusSince(userId: string, since: number): Promise<FocusRow[]>;
  clearAll(): Promise<void>;
}

export class InMemoryStorage implements Storage {
  users = new Map<string, User>();
  usersByEmail = new Map<string, string>();
  refreshTokens = new Map<string, RefreshToken>();
  habits = new Map<string, HabitRow>(); // key userId:id
  habitLogs = new Map<string, HabitLogRow>(); // key userId:habitId:dayKey
  focus = new Map<string, FocusRow>(); // key userId:id

  async clearAll() {
    this.users.clear();
    this.usersByEmail.clear();
    this.refreshTokens.clear();
    this.habits.clear();
    this.habitLogs.clear();
    this.focus.clear();
  }

  async createUser(email: string, passwordHash: string) {
    const ne = email.toLowerCase().trim();
    if (this.usersByEmail.has(ne)) throw new Error("EMAIL_TAKEN");
    const u: User = {
      id: crypto.randomUUID(),
      email: ne,
      passwordHash,
      createdAt: Date.now(),
    };
    this.users.set(u.id, u);
    this.usersByEmail.set(ne, u.id);
    return u;
  }
  async findUserByEmail(email: string) {
    const ne = email.toLowerCase().trim();
    const id = this.usersByEmail.get(ne);
    return id ? this.users.get(id)! : null;
  }
  async findUserById(id: string) {
    return this.users.get(id) ?? null;
  }
  async deleteUser(userId: string) {
    this.users.delete(userId);
    for (const [e, id] of this.usersByEmail) {
      if (id === userId) this.usersByEmail.delete(e);
    }
    for (const [k, t] of this.refreshTokens) {
      if (t.userId === userId) this.refreshTokens.delete(k);
    }
    for (const [k, h] of this.habits) {
      if (h.userId === userId) this.habits.delete(k);
    }
    for (const [k, l] of this.habitLogs) {
      if (l.userId === userId) this.habitLogs.delete(k);
    }
    for (const [k, f] of this.focus) {
      if (f.userId === userId) this.focus.delete(k);
    }
  }

  async insertRefreshToken(t: RefreshToken) {
    this.refreshTokens.set(t.id, t);
  }
  async findRefreshTokenByHash(hash: string) {
    for (const t of this.refreshTokens.values()) {
      if (t.tokenHash === hash) return t;
    }
    return null;
  }
  async revokeRefreshToken(id: string, at: number) {
    const t = this.refreshTokens.get(id);
    if (t) t.revokedAt = at;
  }
  async revokeFamily(familyId: string, at: number) {
    for (const t of this.refreshTokens.values()) {
      if (t.familyId === familyId) t.revokedAt = at;
    }
  }

  async upsertHabit(row: HabitRow) {
    const key = row.userId + ":" + row.id;
    const existing = this.habits.get(key);
    if (existing && existing.updatedAt >= row.updatedAt) return;
    this.habits.set(key, row);
  }
  async habitsSince(userId: string, since: number) {
    const out: HabitRow[] = [];
    for (const h of this.habits.values()) {
      if (h.userId === userId && h.updatedAt > since) out.push(h);
    }
    out.sort((a, b) => a.updatedAt - b.updatedAt);
    return out.slice(0, 200);
  }
  async upsertHabitLog(row: HabitLogRow) {
    const key = row.userId + ":" + row.habitId + ":" + row.dayKey;
    const existing = this.habitLogs.get(key);
    if (existing && existing.updatedAt >= row.updatedAt) return;
    // keep id from incoming if present else existing
    this.habitLogs.set(key, { ...row, id: row.id || existing?.id || key });
  }
  async habitLogsSince(userId: string, since: number) {
    const out: HabitLogRow[] = [];
    for (const l of this.habitLogs.values()) {
      if (l.userId === userId && l.updatedAt > since) out.push(l);
    }
    out.sort((a, b) => a.updatedAt - b.updatedAt);
    return out.slice(0, 200);
  }
  async upsertFocus(row: FocusRow) {
    const key = row.userId + ":" + row.id;
    const existing = this.focus.get(key);
    if (existing && existing.updatedAt >= row.updatedAt) return;
    this.focus.set(key, row);
  }
  async focusSince(userId: string, since: number) {
    const out: FocusRow[] = [];
    for (const f of this.focus.values()) {
      if (f.userId === userId && f.updatedAt > since) out.push(f);
    }
    out.sort((a, b) => a.updatedAt - b.updatedAt);
    return out.slice(0, 200);
  }
}
