/**
 * flbSync.mjs
 * Orchestrates daily schedule refresh and live-game polling for Lebanese
 * basketball games. Call startFlbJobs(pool) once from server.mjs after the
 * PG pool is ready.
 *
 * Environment variables:
 *   FLB_DISABLE_SYNC=1           Skip scheduling all cron jobs (CI / local dev).
 *   FLB_COMPETITION_IDS=a,b,c    Override the list of competitions to scrape.
 *   FLB_CHROMIUM_SINGLE_PROCESS=1  Pass --single-process to Chromium (Linux containers only).
 */

import cron from 'node-cron';
import {
  getSchedule,
  getBoxscore,
  getPlayByPlay,
} from './flbScraper.mjs';

const DEFAULT_COMPETITION_IDS = [42001, 39158, 39159, 48035];

function readCompetitionIds() {
  const raw = process.env.FLB_COMPETITION_IDS;
  if (!raw) return DEFAULT_COMPETITION_IDS;
  const ids = raw
    .split(',')
    .map((s) => Number(String(s).trim()))
    .filter((n) => Number.isFinite(n) && n > 0);
  return ids.length > 0 ? ids : DEFAULT_COMPETITION_IDS;
}

const COMPETITION_IDS = readCompetitionIds();

// Polling intervals (milliseconds)
const PBP_INTERVAL_MS   = 8_000;   // play-by-play while game is live
const BOX_INTERVAL_MS   = 30_000;  // boxscore while game is live
const LIVE_CHECK_CRON   = '* * * * *';  // every minute, check for games going live
const DAILY_REFRESH_CRON = '7 3 * * *'; // 03:07 Asia/Beirut (off-peak)

// ─────────────────────────────────────────────────────────────────────────────
// Active pollers registry (per matchId)
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @typedef {object} Poller
 * @property {NodeJS.Timeout} pbpTimer
 * @property {NodeJS.Timeout} boxTimer
 * @property {boolean} pbpRunning
 * @property {boolean} boxRunning
 * @property {boolean} stopping
 */

/** @type {Map<number, Poller>} */
const activePollers = new Map();

/** Flag to guard the once-per-minute live-check cron from overlapping runs. */
let liveCheckRunning = false;

/** Flag to guard the daily refresh from overlapping runs. */
let dailyRefreshRunning = false;

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
      game.rawStatus ?? null,
      game.dateTimeText ?? null,
      game.venue ?? null,
      game.venueId ?? null,
      game.homeTeam?.id ?? null,
      game.homeTeam?.name ?? null,
      game.homeTeam?.logoUrl ?? null,
      game.awayTeam?.id ?? null,
      game.awayTeam?.name ?? null,
      game.awayTeam?.logoUrl ?? null,
      game.homeTeam?.score ?? null,
      game.awayTeam?.score ?? null,
      game.summaryUrl ?? null,
      game.boxScoreUrl ?? null,
      game.playByPlayUrl ?? null,
      game.shotChartUrl ?? null,
    ],
  );
}

async function upsertBoxscore(pool, matchId, boxscore) {
  if (!boxscore) return;

  for (const team of boxscore.teams ?? []) {
    if (!team?.side) continue;

    await pool.query(
      `INSERT INTO team_boxscores (match_id, side, team_id, team_name, totals, updated_at)
       VALUES ($1, $2, $3, $4, $5, NOW())
       ON CONFLICT (match_id, side) DO UPDATE SET
         team_id   = COALESCE(EXCLUDED.team_id, team_boxscores.team_id),
         team_name = COALESCE(EXCLUDED.team_name, team_boxscores.team_name),
         totals    = EXCLUDED.totals,
         updated_at = NOW()`,
      [
        matchId,
        team.side,
        team.teamId ?? null,
        team.teamName ?? null,
        JSON.stringify(team.totals ?? {}),
      ],
    );

    for (const player of team.players ?? []) {
      if (!player?.playerName) continue;
      await pool.query(
        `INSERT INTO player_boxscores
           (match_id, side, player_id, player_name, player_number, stats, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, NOW())
         ON CONFLICT (match_id, side, player_name) DO UPDATE SET
           player_id     = COALESCE(EXCLUDED.player_id, player_boxscores.player_id),
           player_number = COALESCE(EXCLUDED.player_number, player_boxscores.player_number),
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

  // Also update header-level fields on the games row (score + status)
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
  if (!playByPlay) return;
  for (const ev of playByPlay.events ?? []) {
    if (!ev?.eventId) continue;
    try {
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
    } catch (err) {
      console.error(
        `[flbSync] insert event failed matchId=${matchId} id=${ev.eventId}:`,
        err?.message ?? err,
      );
    }
  }

  // Mirror status from header, if present
  const hdr = playByPlay.header;
  if (hdr?.status) {
    await pool.query(
      `UPDATE games SET status = $2, updated_at = NOW() WHERE match_id = $1`,
      [matchId, hdr.status],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-match polling
// ─────────────────────────────────────────────────────────────────────────────

function stopPolling(matchId) {
  const p = activePollers.get(matchId);
  if (!p) return;
  p.stopping = true;
  clearInterval(p.pbpTimer);
  clearInterval(p.boxTimer);
  activePollers.delete(matchId);
  console.log(`[flbSync] stopped polling matchId=${matchId}`);
}

function startPolling(pool, competitionId, matchId) {
  if (activePollers.has(matchId)) return;

  console.log(`[flbSync] starting live poll matchId=${matchId} compId=${competitionId}`);

  /** @type {Poller} */
  const poller = {
    pbpTimer:   null,
    boxTimer:   null,
    pbpRunning: false,
    boxRunning: false,
    stopping:   false,
  };

  async function pbpTick() {
    if (poller.pbpRunning || poller.stopping) return;
    poller.pbpRunning = true;
    try {
      const pbp = await getPlayByPlay(competitionId, matchId);
      await upsertEvents(pool, matchId, pbp);

      if (pbp.header?.status === 'final') {
        console.log(`[flbSync] matchId=${matchId} reached final — running final boxscore sync`);
        try {
          const box = await getBoxscore(competitionId, matchId);
          await upsertBoxscore(pool, matchId, box);
        } catch (e) {
          console.error(
            `[flbSync] final boxscore error matchId=${matchId}:`,
            e?.message ?? e,
          );
        }
        stopPolling(matchId);
      }
    } catch (err) {
      console.error(`[flbSync] pbp tick error matchId=${matchId}:`, err?.message ?? err);
    } finally {
      poller.pbpRunning = false;
    }
  }

  async function boxTick() {
    if (poller.boxRunning || poller.stopping) return;
    poller.boxRunning = true;
    try {
      const box = await getBoxscore(competitionId, matchId);
      await upsertBoxscore(pool, matchId, box);
    } catch (err) {
      console.error(`[flbSync] box tick error matchId=${matchId}:`, err?.message ?? err);
    } finally {
      poller.boxRunning = false;
    }
  }

  // Kick off immediately (in background), then on interval
  pbpTick();
  boxTick();
  poller.pbpTimer = setInterval(pbpTick, PBP_INTERVAL_MS);
  poller.boxTimer = setInterval(boxTick, BOX_INTERVAL_MS);
  activePollers.set(matchId, poller);
}

// ─────────────────────────────────────────────────────────────────────────────
// Job 1 — Daily schedule refresh
// ─────────────────────────────────────────────────────────────────────────────

async function runScheduleRefresh(pool) {
  if (dailyRefreshRunning) {
    console.log('[flbSync] schedule refresh already in progress — skipping');
    return;
  }
  dailyRefreshRunning = true;
  const t0 = Date.now();
  let totalGames = 0;
  let okComps = 0;

  try {
    console.log('[flbSync] schedule refresh starting');
    for (const competitionId of COMPETITION_IDS) {
      try {
        const games = await getSchedule(competitionId);
        let inserted = 0;
        for (const game of games) {
          try {
            await upsertGame(pool, game);
            inserted += 1;
          } catch (err) {
            console.error(
              `[flbSync] upsertGame failed matchId=${game.matchId}:`,
              err?.message ?? err,
            );
          }
        }
        totalGames += inserted;
        okComps += 1;
        console.log(
          `[flbSync] schedule refresh compId=${competitionId}: ${inserted}/${games.length} upserted`,
        );
      } catch (err) {
        console.error(
          `[flbSync] schedule refresh failed compId=${competitionId}:`,
          err?.message ?? err,
        );
      }
    }
    console.log(
      `[flbSync] schedule refresh done: ${totalGames} rows across ${okComps}/${COMPETITION_IDS.length} comps in ${Date.now() - t0}ms`,
    );

    // After schedule refresh, backfill boxscores for final games that don't have them yet
    console.log('[flbSync] backfilling boxscores for final games...');
    const { rows: finalGamesWithoutBoxes } = await pool.query(`
      SELECT DISTINCT g.match_id, g.competition_id, g.updated_at
      FROM games g
      WHERE g.status = 'final'
        AND NOT EXISTS (
          SELECT 1 FROM player_boxscores pb WHERE pb.match_id = g.match_id LIMIT 1
        )
      ORDER BY g.updated_at DESC
      LIMIT 10
    `);
    console.log(`[flbSync] found ${finalGamesWithoutBoxes.length} final games needing boxscores`);

    for (const row of finalGamesWithoutBoxes) {
      const matchId = Number(row.match_id);
      const compId = Number(row.competition_id);
      try {
        const box = await getBoxscore(compId, matchId);
        await upsertBoxscore(pool, matchId, box);
        console.log(`[flbSync] backfilled boxscore matchId=${matchId}`);
      } catch (err) {
        console.warn(`[flbSync] backfill boxscore failed matchId=${matchId}:`, err?.message ?? err);
      }
    }
  } finally {
    dailyRefreshRunning = false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Job 2 — Live-game detector
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Every minute: find games that may be live and make sure a poller is running
 * for each. Kicks off a lightweight schedule re-scrape per competition to pick
 * up status transitions (scheduled → live → final) without waiting for the
 * next daily refresh. We only do this if there is at least one scheduled game
 * today for that competition, to avoid hammering the site when nothing is on.
 */
async function runLiveCheck(pool) {
  if (liveCheckRunning) return;
  liveCheckRunning = true;

  try {
    // 1. Pollers for games already marked live in the DB
    const { rows: liveRows } = await pool.query(
      `SELECT match_id, competition_id FROM games WHERE status = 'live'`,
    );
    for (const row of liveRows) {
      startPolling(pool, Number(row.competition_id), Number(row.match_id));
    }

    // 2. Ask each competition "is anything happening today?" by re-running the
    //    schedule scraper. We only do this for competitions that have at least
    //    one non-final / non-postponed game still in the DB — otherwise skip
    //    to save load.
    const { rows: activeComps } = await pool.query(
      `SELECT DISTINCT competition_id
       FROM games
       WHERE status NOT IN ('final', 'postponed')`,
    );

    for (const { competition_id } of activeComps) {
      const compId = Number(competition_id);
      try {
        const games = await getSchedule(compId);
        for (const g of games) {
          try {
            await upsertGame(pool, g);
          } catch (err) {
            console.error(
              `[flbSync] live-check upsertGame failed matchId=${g.matchId}:`,
              err?.message ?? err,
            );
          }
          if (g.status === 'live') {
            startPolling(pool, compId, g.matchId);
          } else if (g.status === 'final' && activePollers.has(g.matchId)) {
            // Game finished between ticks — flush a final boxscore, then stop
            try {
              const box = await getBoxscore(compId, g.matchId);
              await upsertBoxscore(pool, g.matchId, box);
            } catch (e) {
              console.error(
                `[flbSync] final flush boxscore error matchId=${g.matchId}:`,
                e?.message ?? e,
              );
            }
            stopPolling(g.matchId);
          }
        }
      } catch (err) {
        console.error(
          `[flbSync] live-check schedule failed compId=${compId}:`,
          err?.message ?? err,
        );
      }
    }
  } catch (err) {
    console.error('[flbSync] live-check failed:', err?.message ?? err);
  } finally {
    liveCheckRunning = false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Bootstrap all FLB cron jobs.
 * Call once from server.mjs:  startFlbJobs(pool)
 * Set FLB_DISABLE_SYNC=1 to skip scheduling (e.g. CI / local dev).
 *
 * @param {import('pg').Pool} pool
 */
export function startFlbJobs(pool) {
  if (process.env.FLB_DISABLE_SYNC === '1') {
    console.log('[flbSync] FLB_DISABLE_SYNC=1 — not scheduling jobs');
    return;
  }
  if (!pool) {
    console.warn('[flbSync] startFlbJobs called without a pool — aborting');
    return;
  }

  console.log(`[flbSync] competitions: ${COMPETITION_IDS.join(', ')}`);

  // Job 1 — daily schedule refresh
  cron.schedule(
    DAILY_REFRESH_CRON,
    () => {
      runScheduleRefresh(pool).catch((err) =>
        console.error('[flbSync] daily refresh crashed:', err?.message ?? err),
      );
    },
    { timezone: 'Asia/Beirut' },
  );
  console.log(`[flbSync] scheduled daily refresh at ${DAILY_REFRESH_CRON} Asia/Beirut`);

  // Job 2 — live game check every minute
  cron.schedule(LIVE_CHECK_CRON, () => {
    runLiveCheck(pool).catch((err) =>
      console.error('[flbSync] live check crashed:', err?.message ?? err),
    );
  });
  console.log(`[flbSync] scheduled live-game check at ${LIVE_CHECK_CRON}`);

  // Kick an initial refresh immediately so data is fresh on deploy
  runScheduleRefresh(pool).catch((err) =>
    console.error('[flbSync] initial refresh failed:', err?.message ?? err),
  );
}

// Exposed for admin / debugging routes if ever needed
export const _internals = {
  runScheduleRefresh,
  runLiveCheck,
  startPolling,
  stopPolling,
  activePollers,
  upsertGame,
  upsertBoxscore,
  upsertEvents,
};
