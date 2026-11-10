CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  created_at BIGINT NOT NULL
);
CREATE TABLE IF NOT EXISTS refresh_tokens (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT UNIQUE NOT NULL,
  family_id UUID NOT NULL,
  expires_at BIGINT NOT NULL,
  revoked_at BIGINT,
  created_at BIGINT NOT NULL
);
CREATE TABLE IF NOT EXISTS habits (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  id TEXT NOT NULL,
  section_id TEXT,
  name TEXT NOT NULL,
  frequency TEXT NOT NULL,
  weekdays_mask INT NOT NULL DEFAULT 0,
  weekly_target INT,
  interval_days INT,
  goal_type TEXT,
  goal_amount DOUBLE PRECISION,
  unit TEXT,
  increment DOUBLE PRECISION,
  goal_duration_days INT,
  start_date TEXT,
  archived BOOLEAN NOT NULL DEFAULT FALSE,
  reminder_time TEXT,
  alarm_preset TEXT,
  created_at BIGINT NOT NULL,
  updated_at BIGINT NOT NULL,
  deleted_at BIGINT,
  PRIMARY KEY (user_id, id)
);
CREATE TABLE IF NOT EXISTS habit_logs (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  id TEXT NOT NULL,
  habit_id TEXT NOT NULL,
  day_key TEXT NOT NULL,
  amount DOUBLE PRECISION NOT NULL DEFAULT 0,
  done BOOLEAN NOT NULL DEFAULT FALSE,
  skipped BOOLEAN NOT NULL DEFAULT FALSE,
  created_at BIGINT NOT NULL,
  updated_at BIGINT NOT NULL,
  PRIMARY KEY (user_id, habit_id, day_key)
);
CREATE TABLE IF NOT EXISTS focus_sessions (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  id TEXT NOT NULL,
  task_id TEXT,
  habit_id TEXT,
  start_utc BIGINT NOT NULL,
  end_utc BIGINT,
  target_end_utc BIGINT,
  phase TEXT,
  note TEXT,
  created_at BIGINT NOT NULL,
  updated_at BIGINT NOT NULL,
  PRIMARY KEY (user_id, id)
);
CREATE INDEX IF NOT EXISTS idx_habits_updated ON habits(user_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_logs_updated ON habit_logs(user_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_focus_updated ON focus_sessions(user_id, updated_at);