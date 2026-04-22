-- ============================================================
-- flb_schema.sql
-- FLB basketball game data tables migration
-- Run once against your Supabase / PostgreSQL database.
-- All statements are idempotent (IF NOT EXISTS / ON CONFLICT).
-- ============================================================

-- 1) games — one row per match
CREATE TABLE IF NOT EXISTS games (
  match_id         BIGINT PRIMARY KEY,
  competition_id   BIGINT NOT NULL,
  status           TEXT,          -- 'scheduled' | 'live' | 'final' | 'postponed'
  raw_status       TEXT,          -- raw string from Genius Sports
  date_time_text   TEXT,
  venue            TEXT,
  venue_id         BIGINT,
  home_team_id     BIGINT,
  home_team_name   TEXT,
  home_team_logo   TEXT,
  away_team_id     BIGINT,
  away_team_name   TEXT,
  away_team_logo   TEXT,
  home_score       INT,
  away_score       INT,
  summary_url      TEXT,
  boxscore_url     TEXT,
  playbyplay_url   TEXT,
  shotchart_url    TEXT,
  week             INT,           -- league round / week number (fixtures swipe UI)
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast live-game queries
CREATE INDEX IF NOT EXISTS idx_games_status       ON games (status);
CREATE INDEX IF NOT EXISTS idx_games_competition  ON games (competition_id);
CREATE INDEX IF NOT EXISTS idx_games_updated      ON games (updated_at DESC);

-- 2) game_events — play-by-play rows
CREATE TABLE IF NOT EXISTS game_events (
  event_id         TEXT PRIMARY KEY,
  match_id         BIGINT NOT NULL REFERENCES games (match_id) ON DELETE CASCADE,
  period           TEXT,
  clock            TEXT,
  score            TEXT,
  team_side        TEXT,   -- 'home' | 'away' | NULL
  team_name        TEXT,
  player           TEXT,
  player_number    TEXT,
  action_text      TEXT,
  event_type       TEXT,   -- '2pt' | '3pt' | 'freethrow' | 'rebound' | ...
  is_scoring_event BOOLEAN DEFAULT FALSE,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_game_events_match ON game_events (match_id, created_at DESC);

-- 3) team_boxscores — aggregate team stats per game
CREATE TABLE IF NOT EXISTS team_boxscores (
  match_id   BIGINT NOT NULL REFERENCES games (match_id) ON DELETE CASCADE,
  side       TEXT   NOT NULL,   -- 'home' | 'away'
  team_id    BIGINT,
  team_name  TEXT,
  totals     JSONB  NOT NULL DEFAULT '{}',
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (match_id, side)
);

-- 4) player_boxscores — individual player stats per game
CREATE TABLE IF NOT EXISTS player_boxscores (
  match_id      BIGINT NOT NULL REFERENCES games (match_id) ON DELETE CASCADE,
  side          TEXT   NOT NULL,   -- 'home' | 'away'
  player_id     BIGINT,
  player_name   TEXT   NOT NULL,
  player_number TEXT,
  stats         JSONB  NOT NULL DEFAULT '{}',
  updated_at    TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (match_id, side, player_name)
);

CREATE INDEX IF NOT EXISTS idx_player_boxscores_match ON player_boxscores (match_id);

-- Older databases: add `week` if the table predates that column
ALTER TABLE games ADD COLUMN IF NOT EXISTS week INT;
CREATE INDEX IF NOT EXISTS idx_games_comp_week ON games (competition_id, week);
