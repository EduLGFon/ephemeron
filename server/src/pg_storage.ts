// deno-lint-ignore-file no-explicit-any
// deno-lint-ignore-file require-await
import pg from "pg";
import { config } from "./config.ts";
import type {
  FocusRow,
  HabitLogRow,
  HabitRow,
  RefreshToken,
  Storage,
  User,
} from "./storage.ts";

let pool: pg.Pool | null = null;
function getPool(): pg.Pool {
  if (!pool) {
    pool = new pg.Pool({
      connectionString: config.databaseUrl,
      max: config.pgPoolMax,
    });
  }
  return pool;
}

export class PostgresStorage implements Storage {
  async createUser(email: string, passwordHash: string): Promise<User> {
    const id = crypto.randomUUID();
    const createdAt = Date.now();
    const ne = email.toLowerCase().trim();
    await getPool().query(
      "INSERT INTO users (id, email, password_hash, created_at) VALUES ($1,$2,$3,$4)",
      [id, ne, passwordHash, createdAt],
    );
    return { id, email: ne, passwordHash, createdAt };
  }
  async findUserByEmail(email: string): Promise<User | null> {
    const ne = email.toLowerCase().trim();
    const r = await getPool().query(
      "SELECT id, email, password_hash, created_at FROM users WHERE email = $1",
      [ne],
    );
    if (r.rows.length === 0) return null;
    const row = r.rows[0];
    return {
      id: row.id,
      email: row.email,
      passwordHash: row.password_hash,
      createdAt: Number(row.created_at),
    };
  }
  async findUserById(id: string): Promise<User | null> {
    const r = await getPool().query(
      "SELECT id, email, password_hash, created_at FROM users WHERE id = $1",
      [id],
    );
    if (r.rows.length === 0) return null;
    const row = r.rows[0];
    return {
      id: row.id,
      email: row.email,
      passwordHash: row.password_hash,
      createdAt: Number(row.created_at),
    };
  }
  async deleteUser(userId: string): Promise<void> {
    await getPool().query("DELETE FROM users WHERE id = $1", [userId]);
  }

  async insertRefreshToken(t: RefreshToken): Promise<void> {
    await getPool().query(
      "INSERT INTO refresh_tokens (id, user_id, token_hash, family_id, expires_at, revoked_at, created_at) VALUES ($1,$2,$3,$4,$5,$6,$7)",
      [
        t.id,
        t.userId,
        t.tokenHash,
        t.familyId,
        t.expiresAt,
        t.revokedAt,
        t.createdAt,
      ],
    );
  }
  async findRefreshTokenByHash(hash: string): Promise<RefreshToken | null> {
    const r = await getPool().query(
      "SELECT id, user_id, token_hash, family_id, expires_at, revoked_at, created_at FROM refresh_tokens WHERE token_hash = $1",
      [hash],
    );
    if (r.rows.length === 0) return null;
    const row = r.rows[0];
    return {
      id: row.id,
      userId: row.user_id,
      tokenHash: row.token_hash,
      familyId: row.family_id,
      expiresAt: Number(row.expires_at),
      revokedAt: row.revoked_at === null ? null : Number(row.revoked_at),
      createdAt: Number(row.created_at),
    };
  }
  async revokeRefreshToken(id: string, at: number): Promise<void> {
    await getPool().query(
      "UPDATE refresh_tokens SET revoked_at = $1 WHERE id = $2",
      [at, id],
    );
  }
  async revokeFamily(familyId: string, at: number): Promise<void> {
    await getPool().query(
      "UPDATE refresh_tokens SET revoked_at = $1 WHERE family_id = $2",
      [at, familyId],
    );
  }

  async upsertHabit(row: HabitRow): Promise<void> {
    await getPool().query(
      `INSERT INTO habits (user_id,id,section_id,name,frequency,weekdays_mask,weekly_target,interval_days,goal_type,goal_amount,unit,increment,goal_duration_days,start_date,archived,reminder_time,alarm_preset,created_at,updated_at,deleted_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20)
       ON CONFLICT (user_id,id) DO UPDATE SET
         section_id=excluded.section_id,name=excluded.name,frequency=excluded.frequency,weekdays_mask=excluded.weekdays_mask,
         weekly_target=excluded.weekly_target,interval_days=excluded.interval_days,goal_type=excluded.goal_type,
         goal_amount=excluded.goal_amount,unit=excluded.unit,increment=excluded.increment,
         goal_duration_days=excluded.goal_duration_days,start_date=excluded.start_date,archived=excluded.archived,
         reminder_time=excluded.reminder_time,alarm_preset=excluded.alarm_preset,
         created_at=excluded.created_at,updated_at=excluded.updated_at,deleted_at=excluded.deleted_at
       WHERE excluded.updated_at > habits.updated_at`,
      [
        row.userId,
        row.id,
        row.sectionId,
        row.name,
        row.frequency,
        row.weekdaysMask,
        row.weeklyTarget,
        row.intervalDays,
        row.goalType,
        row.goalAmount,
        row.unit,
        row.increment,
        row.goalDurationDays,
        row.startDate,
        row.archived,
        row.reminderTime,
        row.alarmPreset,
        row.createdAt,
        row.updatedAt,
        row.deletedAt,
      ],
    );
  }
  async habitsSince(userId: string, since: number): Promise<HabitRow[]> {
    const r = await getPool().query(
      "SELECT * FROM habits WHERE user_id = $1 AND updated_at > $2 ORDER BY updated_at ASC LIMIT 200",
      [userId, since],
    );
    return r.rows.map((row: any) => ({
      userId: row.user_id,
      id: row.id,
      sectionId: row.section_id,
      name: row.name,
      frequency: row.frequency,
      weekdaysMask: Number(row.weekdays_mask),
      weeklyTarget: row.weekly_target === null
        ? null
        : Number(row.weekly_target),
      intervalDays: row.interval_days === null
        ? null
        : Number(row.interval_days),
      goalType: row.goal_type,
      goalAmount: row.goal_amount === null ? null : Number(row.goal_amount),
      unit: row.unit,
      increment: row.increment === null ? null : Number(row.increment),
      goalDurationDays: row.goal_duration_days === null
        ? null
        : Number(row.goal_duration_days),
      startDate: row.start_date,
      archived: Boolean(row.archived),
      reminderTime: row.reminder_time,
      alarmPreset: row.alarm_preset,
      createdAt: Number(row.created_at),
      updatedAt: Number(row.updated_at),
      deletedAt: row.deleted_at === null ? null : Number(row.deleted_at),
    }));
  }

  async upsertHabitLog(row: HabitLogRow): Promise<void> {
    await getPool().query(
      `INSERT INTO habit_logs (user_id,id,habit_id,day_key,amount,done,skipped,created_at,updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
       ON CONFLICT (user_id,habit_id,day_key) DO UPDATE SET
         id=excluded.id,amount=excluded.amount,done=excluded.done,skipped=excluded.skipped,
         created_at=excluded.created_at,updated_at=excluded.updated_at
       WHERE excluded.updated_at > habit_logs.updated_at`,
      [
        row.userId,
        row.id,
        row.habitId,
        row.dayKey,
        row.amount,
        row.done,
        row.skipped,
        row.createdAt,
        row.updatedAt,
      ],
    );
  }
  async habitLogsSince(userId: string, since: number): Promise<HabitLogRow[]> {
    const r = await getPool().query(
      "SELECT * FROM habit_logs WHERE user_id = $1 AND updated_at > $2 ORDER BY updated_at ASC LIMIT 200",
      [userId, since],
    );
    return r.rows.map((row: any) => ({
      userId: row.user_id,
      id: row.id,
      habitId: row.habit_id,
      dayKey: row.day_key,
      amount: Number(row.amount),
      done: Boolean(row.done),
      skipped: Boolean(row.skipped),
      createdAt: Number(row.created_at),
      updatedAt: Number(row.updated_at),
    }));
  }

  async upsertFocus(row: FocusRow): Promise<void> {
    await getPool().query(
      `INSERT INTO focus_sessions (user_id,id,task_id,habit_id,start_utc,end_utc,target_end_utc,phase,note,created_at,updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
       ON CONFLICT (user_id,id) DO UPDATE SET
         task_id=excluded.task_id,habit_id=excluded.habit_id,start_utc=excluded.start_utc,
         end_utc=excluded.end_utc,target_end_utc=excluded.target_end_utc,phase=excluded.phase,
         note=excluded.note,created_at=excluded.created_at,updated_at=excluded.updated_at
       WHERE excluded.updated_at > focus_sessions.updated_at`,
      [
        row.userId,
        row.id,
        row.taskId,
        row.habitId,
        row.startUtc,
        row.endUtc,
        row.targetEndUtc,
        row.phase,
        row.note,
        row.createdAt,
        row.updatedAt,
      ],
    );
  }
  async focusSince(userId: string, since: number): Promise<FocusRow[]> {
    const r = await getPool().query(
      "SELECT * FROM focus_sessions WHERE user_id = $1 AND updated_at > $2 ORDER BY updated_at ASC LIMIT 200",
      [userId, since],
    );
    return r.rows.map((row: any) => ({
      userId: row.user_id,
      id: row.id,
      taskId: row.task_id,
      habitId: row.habit_id,
      startUtc: Number(row.start_utc),
      endUtc: row.end_utc === null ? null : Number(row.end_utc),
      targetEndUtc: row.target_end_utc === null
        ? null
        : Number(row.target_end_utc),
      phase: row.phase,
      note: row.note,
      createdAt: Number(row.created_at),
      updatedAt: Number(row.updated_at),
    }));
  }

  async clearAll() {
    await getPool().query(
      "TRUNCATE users, refresh_tokens, habits, habit_logs, focus_sessions;",
    );
  }
}
