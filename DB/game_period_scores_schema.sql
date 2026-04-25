-- ============================================================
-- game_period_scores_schema.sql
-- Quarter/period score breakdown derived from game_events.
-- Run once against your Supabase / PostgreSQL database.
-- Idempotent (IF NOT EXISTS / ON CONFLICT).
-- ============================================================

CREATE TABLE IF NOT EXISTS game_period_scores (
  match_id             BIGINT NOT NULL,
  period               TEXT   NOT NULL,
  period_index         INT    NOT NULL,
  home_score           INT    NOT NULL DEFAULT 0,
  away_score           INT    NOT NULL DEFAULT 0,
  home_running_total   INT    NOT NULL DEFAULT 0,
  away_running_total   INT    NOT NULL DEFAULT 0,
  created_at           TIMESTAMPTZ DEFAULT NOW(),
  updated_at           TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (match_id, period)
);

CREATE INDEX IF NOT EXISTS idx_game_period_scores_match
  ON game_period_scores (match_id, period_index ASC);
