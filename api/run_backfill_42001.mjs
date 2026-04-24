/**
 * run_backfill_42001.mjs — full backfill for competition 42001 (no row limit)
 * Usage: node run_backfill_42001.mjs
 *
 * Finds every final game in competition 42001 that is missing boxscore data
 * (player_boxscores) or play-by-play data (game_events) and fetches both.
 * Delete after use.
 */
import pg from 'pg';
import dotenv from 'dotenv';
import { getBoxscore, getPlayByPlay } from './flbScraper.mjs';
import { _internals } from './flbSync.mjs';

dotenv.config();

const COMPETITION_ID = 42001;
const SCRAPE_PBP = !['0', 'false', 'no', 'off'].includes(
  String(process.env.FLB_SCRAPE_PLAY_BY_PLAY ?? '').trim().toLowerCase(),
);

const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: false,
});

console.log(`[backfill-42001] connecting… (PBP scraping: ${SCRAPE_PBP})`);
const t0 = Date.now();

try {
  const backfillCols = SCRAPE_PBP
    ? `(NOT EXISTS (SELECT 1 FROM player_boxscores pb WHERE pb.match_id = g.match_id LIMIT 1)) AS needs_box,
       (NOT EXISTS (SELECT 1 FROM game_events      ge WHERE ge.match_id = g.match_id LIMIT 1)) AS needs_pbp`
    : `(NOT EXISTS (SELECT 1 FROM player_boxscores pb WHERE pb.match_id = g.match_id LIMIT 1)) AS needs_box,
       FALSE AS needs_pbp`;

  const backfillWhere = SCRAPE_PBP
    ? `g.status = 'final'
       AND g.competition_id = $1
       AND (
         NOT EXISTS (SELECT 1 FROM player_boxscores pb WHERE pb.match_id = g.match_id LIMIT 1)
         OR NOT EXISTS (SELECT 1 FROM game_events   ge WHERE ge.match_id = g.match_id LIMIT 1)
       )`
    : `g.status = 'final'
       AND g.competition_id = $1
       AND NOT EXISTS (SELECT 1 FROM player_boxscores pb WHERE pb.match_id = g.match_id LIMIT 1)`;

  const { rows: games } = await pool.query(
    `SELECT g.match_id, g.competition_id, ${backfillCols}
     FROM games g
     WHERE ${backfillWhere}
     ORDER BY g.match_id DESC`,
    [COMPETITION_ID],
  );

  const boxNeeded = games.filter(r => r.needs_box).length;
  const pbpNeeded = games.filter(r => r.needs_pbp).length;
  console.log(`[backfill-42001] ${games.length} games need work (box=${boxNeeded} pbp=${pbpNeeded})`);

  for (const row of games) {
    const matchId = Number(row.match_id);
    const compId  = Number(row.competition_id);

    if (row.needs_box) {
      try {
        const box = await getBoxscore(compId, matchId);
        await _internals.upsertBoxscore(pool, matchId, box);
        console.log(`[backfill-42001] boxscore OK matchId=${matchId}`);
      } catch (err) {
        console.warn(`[backfill-42001] boxscore FAILED matchId=${matchId}:`, err?.message ?? err);
      }
    }

    if (row.needs_pbp && SCRAPE_PBP) {
      try {
        const pbp = await getPlayByPlay(compId, matchId);
        await _internals.upsertEvents(pool, matchId, pbp);
        console.log(`[backfill-42001] PBP OK matchId=${matchId}`);
      } catch (err) {
        console.warn(`[backfill-42001] PBP FAILED matchId=${matchId}:`, err?.message ?? err);
      }
    }
  }

  console.log(`[backfill-42001] done in ${((Date.now() - t0) / 1000).toFixed(1)}s`);
} catch (err) {
  console.error('[backfill-42001] fatal:', err?.message ?? err);
  process.exit(1);
} finally {
  await pool.end();
  process.exit(0);
}
