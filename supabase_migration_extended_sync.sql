-- Migration: Extended Cloud Sync Tables for NovaHealth
-- Run in Supabase SQL Editor

-- Period cycles
CREATE TABLE IF NOT EXISTS period_cycles (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  start_date TIMESTAMP WITH TIME ZONE NOT NULL,
  end_date TIMESTAMP WITH TIME ZONE,
  flow_intensity TEXT,
  symptoms JSONB,
  mood TEXT,
  notes TEXT,
  cycle_length INTEGER,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  synced_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Symptom records
CREATE TABLE IF NOT EXISTS symptom_data (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
  symptom_type TEXT NOT NULL,
  severity INTEGER,
  body_part TEXT,
  notes TEXT,
  triggers JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  synced_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Meditation and breathing sessions
CREATE TABLE IF NOT EXISTS meditation_sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
  type TEXT NOT NULL,
  duration_minutes INTEGER NOT NULL,
  exercise_name TEXT,
  notes TEXT,
  completed BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  synced_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Sugar logs
CREATE TABLE IF NOT EXISTS sugar_logs (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  logged_at TIMESTAMP WITH TIME ZONE NOT NULL,
  sugar_type TEXT NOT NULL,
  label TEXT,
  estimated_sugar_grams REAL,
  estimated_calories REAL,
  note TEXT,
  xp_earned INTEGER,
  synced_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Habit tracking (daily state)
CREATE TABLE IF NOT EXISTS habit_tracking (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  day_key TEXT NOT NULL,
  completed_habits JSONB,
  synced_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- SOS profile
CREATE TABLE IF NOT EXISTS sos_profiles (
  user_id TEXT PRIMARY KEY,
  primary_contact TEXT,
  medical_note TEXT,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_period_cycles_user_id ON period_cycles(user_id);
CREATE INDEX IF NOT EXISTS idx_symptom_data_user_id ON symptom_data(user_id);
CREATE INDEX IF NOT EXISTS idx_meditation_sessions_user_id ON meditation_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sugar_logs_user_id ON sugar_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_habit_tracking_user_id ON habit_tracking(user_id);

-- Keep parity with no-auth schema used by this project.
ALTER TABLE period_cycles DISABLE ROW LEVEL SECURITY;
ALTER TABLE symptom_data DISABLE ROW LEVEL SECURITY;
ALTER TABLE meditation_sessions DISABLE ROW LEVEL SECURITY;
ALTER TABLE sugar_logs DISABLE ROW LEVEL SECURITY;
ALTER TABLE habit_tracking DISABLE ROW LEVEL SECURITY;
ALTER TABLE sos_profiles DISABLE ROW LEVEL SECURITY;

GRANT ALL ON period_cycles TO anon;
GRANT ALL ON symptom_data TO anon;
GRANT ALL ON meditation_sessions TO anon;
GRANT ALL ON sugar_logs TO anon;
GRANT ALL ON habit_tracking TO anon;
GRANT ALL ON sos_profiles TO anon;
