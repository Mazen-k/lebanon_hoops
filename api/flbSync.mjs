/**
 * flbSync.mjs
 * Orchestrates daily schedule refresh and live-game polling for Lebanese basketball.
 * Call startFlbJobs(pool) once from server.mjs after the pool is ready.
 */

import cron from 'node-cron';
import { getSchedule, getBoxscore, getPlayByPlay } from './flbScraper.mjs';

// Competition IDs for the Lebanese leagues
const COMPETITION_IDS = [42001, 39158, 39159, 48035];

// Polling intervals (milliseconds)
const PBP_INTERVAL_MS   = 8_000;
const BOX_INTERVAL_MS   = 30_000;
const CHECK_INTERVAL_MS = 60_000; // fallback safety net

// How far ahead of game start we begin checking (minutes)
const PRE_GAME_WINDOW_MIN = 30;

/** Active polling handles keyed by matchId */
const activePollers = new Map(); // matchId → { pbp: NodeJS.Timeout, box: NodeJS.Timeout }

// ─────────────────────────────────────────────────────────────────────────────
// DB bootstrap — create tables if they don't exist
// ─────────────────────────────────────────────────────────────────────────────

async function ensureTables(pool) {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS games (
      match_id         BIGINT PRIMARY KEY,
      competition_id   BIGINT NOT NULL,
      status           TEXT,
      raw_status       TEXT,
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
      updated_at       TIMESTAMPTZ DEFAULT NOW()
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS game_events (
      event_id        TEXT PRIMARY KEY,
      match_id        BIGINT NOT NULL,
      period          TEXT,
      clock           TEXT,
      score           TEXT,
      team_side       TEXT,
      team_name       TEXT,
      player          TEXT,
      player_number   TEXT,
      action_text     TEXT,
      event_type      TEXT,
      is_scoring_event BOOLEAN DEFAULT FALSE,
      created_at      TIMESTAMPTZ DEFAULT NOW()
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS team_boxscores (
      match_id   BIGINT NOT NULL,
      side       TEXT   NOT NULL,
      team_id    BIGINT,
      team_name  TEXT,
      totals     JSONB  NOT NULL,
      updated_at TIMESTAMPTZ DEFAULT NOW(),
      PRIMARY KEY (match_id, side)
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS player_boxscores (
      match_id      BIGINT NOT NULL,
      side          TEXT   NOT NULL,
      player_id     BIGINT,
      player_name   TEXT   NOT NULL,
      player_number TEXT,
      stats         JSONB  NOT NULL,
      updated_at    TIMESTAMPTZ DEFAULT NOW(),
      PRIMARY KEY (match_id, side, player_name)
    )
  `);
}

// ─────────────────────────────────────────────────────────────────────────────
// Upsert helpers
// ─────────────────────────────────────────────────────────────────────────────

async function upsertGame(pool, game) {
  await pool.query(
    `INSERT INTO games (
       match_id, competition_id, status, raw_status, date_time_text,
       venue, venue_id,
       home_team_id, home_team_name, home_team_logo,
       away_team_id, away_team_name, away_team_logo,
       home_score, away_score,
       summary_url, boxscore_url, playbyplay_url, shotchart_url,
       updated_at
     )
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,NOW())
     ON CONFLICT (match_id) DO UPDATE SET
       competition_id  = EXCLUDED.competition_id,
       status          = EXCLUDED.status,
       raw_status      = EXCLUDED.raw_status,
       date_time_text  = EXCLUDED.date_time_text,
       venue           = EXCLUDED.venue,
       venue_id        = EXCLUDED.venue_id,
       home_team_id    = EXCLUDED.home_team_id,
       home_team_name  = EXCLUDED.home_team_name,
       home_team_logo  = EXCLUDED.home_team_logo,
       away_team_id    = EXCLUDED.away_team_id,
       away_team_name  = EXCLUDED.away_team_name,
       away_team_logo  = EXCLUDED.away_team_logo,
       home_score      = COALESCE(EXCLUDED.home_score, games.home_score),
       away_score      = COALESCE(EXCLUDED.away_score, games.away_score),
       summary_url     = EXCLUDED.summary_url,
       boxscore_url    = EXCLUDED.boxscore_url,
       playbyplay_url  = EXCLUDED.playbyplay_url,
       shotchart_url   = EXCLUDED.shotchart_url,
       updated_at      = NOW()`,
    [
      game.matchId,
      game.competitionId,
      game.status,
      game.rawStatus,
      game.dateTimeText,
      game.venue,
      game.venueId,
      game.homeTeam?.id,
      game.homeTeam?.name,
      game.homeTeam?.logoUrl,
      game.awayTeam?.id,
      game.awayTeam?.name,
      game.awayTeam?.logoUrl,
      game.homeScore ?? null,
      game.awayScore ?? null,
      game.summaryUrl,
      game.boxScoreUrl,
      game.playByPlayUrl,
      game.shotChartUrl,
    ],
  );
}

async function upsertBoxscore(pool, matchId, boxscore) {
  for (const team of boxscore.teams ?? []) {
    // team_boxscores
    await pool.query(
      `INSERT INTO team_boxscores (match_id, side, team_id, team_name, totals, updated_at)
       VALUES ($1, $2, $3, $4, $5, NOW())
       ON CONFLICT (match_id, side) DO UPDATE SET
         team_id   = EXCLUDED.team_id,
         team_name = EXCLUDED.team_name,
         totals    = EXCLUDED.totals,
         updated_at = NOW()`,
      [matchId, team.side, team.teamId, team.teamName, JSON.stringify(team.totals ?? {})],
    );

    // player_boxscores
    for (const player of team.players ?? []) {
      if (!player.playerName) continue;
      await pool.query(
        `INSERT INTO player_boxscores
           (match_id, side, player_id, player_name, player_number, stats, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, NOW())
         ON CONFLICT (match_id, side, player_name) DO UPDATE SET
           player_id     = COALESCE(EXCLUDED.player_id, player_boxscores.player_id),
           player_number = EXCLUDED.player_number,
           stats         = EXCLUDED.stats,
           updated_at    = NOW()`,
        [
          matchId,
          team.side,
          player.playerId ?? null,
          player.playerName,
          player.playerNumber ?? null,
          JSON.stringify(player.stats ?? {}),
        ],
      );
    }
  }

  // Also update score in games table from header
  const hdr = boxscore.header;
  if (hdr) {
    await pool.query(
      `UPDATE games SET
         home_score = COALESCE($2, home_score),
         away_score = COALESCE($3, away_score),
         status     = COALESCE($4, status),
         updated_at = NOW()
       WHERE match_id = $1`,
      [
        matchId,
        hdr.homeTeam?.score ?? null,
        hdr.awayTeam?.score ?? null,
        hdr.status ?? null,
      ],
    );
  }
}

async function upsertEvents(pool, matchId, playByPlay) {
  for (const ev of playByPlay.events ?? []) {
    if (!ev.eventId) continue;
    await pool.query(
      `INSERT INTO game_events
         (event_id, match_id, period, clock, score, team_side, team_name,
          player, player_number, action_text, event_type, is_scoring_event)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
       ON CONFLICT (event_id) DO NOTHING`,
      [
        ev.eventId,
        matchId,
        ev.period ?? null,
        ev.clock ?? null,
        ev.score ?? null,
        ev.teamSide ?? null,
        ev.teamName ?? null,
        ev.player ?? null,
        ev.playerNumber ?? null,
        ev.actionText ?? null,
        ev.eventType ?? null,
        ev.isScoringEvent ?? false,
      ],
    );
  }

  // Update status from header
  const hdr = playByPlay.header;
  if (hdr?.status) {
    await pool.query(
      `UPDATE games SET status = $2, updated_at = NOW() WHERE match_id = $1`,
      [matchId, hdr.status],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live polling
// ─────────────────────────────────────────────────────────────────────────────

function stopPolling(matchId) {
  const handles = activePollers.get(matchId);
  if (!handles) return;
  clearInterval(handles.pbp);
  clearInterval(handles.box);
  activePollers.delete(matchId);
  console.log(`[flbSync] stopped polling matchId=${matchId}`);
}

/**
 * Start live polling for a match.
 * @param {import('pg').Pool} pool
 * @param {number} competitionId
 * @param {number} matchId
 */
function startPolling(pool, competitionId, matchId) {
  if (activePollers.has(matchId)) return; // already polling

  console.log(`[flbSync] starting live polling matchId=${matchId} compId=${competitionId}`);

  async function pollPbp() {
    try {
      const pbp = await getPlayByPlay(competitionId, matchId);
      await upsertEvents(pool, matchId, pbp);
      // If game is final, do final boxscore sync then stop
      if (pbp.header?.status === 'final') {
        console.log(`[flbSync] matchId=${matchId} is final — running final boxscore sync`);
        try {
          const box = await getBoxscore(competitionId, matchId);
          await upsertBoxscore(pool, matchId, box);
        } catch (e) {
          console.error(`[flbSync] final boxscore error matchId=${matchId}:`, e.message ?? e);
        }
        stopPolling(matchId);
      }
    } catch (err) {
      console.error(`[flbSync] PBP poll error matchId=${matchId}:`, err.message ?? err);
    }
  }

  async function pollBox() {
    if (!activePollers.has(matchId)) return;
    try {
      const box = await getBoxscore(competitionId, matchId);
      await upsertBoxscore(pool, matchId, box);
    } catch (err) {
      console.error(`[flbSync] boxscore poll error matchId=${matchId}:`, err.message ?? err);
    }
  }

  // Kick off immediately, then on interval
  pollPbp();
  pollBox();

  const pbpTimer = setInterval(pollPbp, PBP_INTERVAL_MS);
  const boxTimer = setInterval(pollBox, BOX_INTERVAL_MS);

  activePollers.set(matchId, { pbp: pbpTimer, box: boxTimer });
}

// ─────────────────────────────────────────────────────────────────────────────
// Job 1 — Daily schedule refresh
// ─────────────────────────────────────────────────────────────────────────────

async function runScheduleRefresh(pool) {
  console.log('[flbSync] running daily schedule refresh');
  for (const competitionId of COMPETITION_IDS) {
    try {
      const games = await getSchedule(competitionId);
      for (const game of games) {
        try {
          await upsertGame(pool, game);
        } catch (err) {
          console.error(
            `[flbSync] upsertGame error matchId=${game.matchId}:`,
            err.message ?? err,
          );
        }
      }
      console.log(
        `[flbSync] schedule refresh done compId=${competitionId} — ${games.length} games`,
      );
    } catch (err) {
      console.error(
        `[flbSync] schedule refresh error compId=${competitionId}:`,
        err.message ?? err,
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Job 2 — Live game detector
// ─────────────────────────────────────────────────────────────────────────────

async function runLiveCheck(pool) {
  try {
    // Find games that are live, or about to start within the pre-game window, and not final
    const { rows } = await pool.query(`
      SELECT match_id, competition_id, status
      FROM games
      WHERE
        status = 'live'
        OR (
          status NOT IN ('final', 'postponed')
          AND date_time_text IS NOT NULL
        )
      ORDER BY match_id ASC
    `);

    for (const row of rows) {
      const matchId = Number(row.match_id);
      const competitionId = Number(row.competition_id);
      const status = row.status;

      if (status === 'live') {
        startPolling(pool, competitionId, matchId);
        continue;
      }

      // For non-live games: quick-check the web to see if they've gone live
      // We throttle to avoid hammering the site — only check if not already polling
      if (!activePollers.has(matchId)) {
        try {
          const pbp = await getPlayByPlay(competitionId, matchId);
          if (pbp.header?.status === 'live') {
            // Update DB and start polling
            await pool.query(
              `UPDATE games SET status = 'live', updated_at = NOW() WHERE match_id = $1`,
              [matchId],
            );
            startPolling(pool, competitionId, matchId);
          }
        } catch (_) {
          // silently ignore — we'll try again next minute
        }
      }
    }
  } catch (err) {
    console.error('[flbSync] live check error:', err.message ?? err);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Bootstrap all FLB cron jobs.
 * Call once from server.mjs: `startFlbJobs(pool)`
 * @param {import('pg').Pool} pool
 */
export async function startFlbJobs(pool) {
  try {
    await ensureTables(pool);
    console.log('[flbSync] DB tables verified');
  } catch (err) {
    console.error('[flbSync] ensureTables error:', err.message ?? err);
    // Non-fatal — server continues even if tables already exist or there's a minor issue.
  }

  // ── Job 1: daily refresh at midnight ───────────────────────────
  cron.schedule('0 0 * * *', () => runScheduleRefresh(pool), { timezone: 'Asia/Beirut' });
  console.log('[flbSync] scheduled daily refresh at 00:00 Asia/Beirut');

  // ── Job 2: live-game check every minute ────────────────────────
  cron.schedule('* * * * *', () => runLiveCheck(pool));
  console.log('[flbSync] scheduled live-game check every minute');

  // Run an initial schedule refresh immediately on start so data is fresh
  runScheduleRefresh(pool).catch((err) =>
    console.error('[flbSync] initial refresh failed:', err.message ?? err),
  );
}
