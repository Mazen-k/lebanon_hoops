// One-time backfill: fetch boxscores for all final games that don't have them yet.
import pg from 'pg';
import dotenv from 'dotenv';
import { getBoxscore, shutdownBrowser } from './flbScraper.mjs';
import { _internals } from './flbSync.mjs';

dotenv.config();

const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

const BATCH_SIZE = 20;  // Fetch 20 per run to avoid hammering the site

(async () => {
  try {
    console.log('[backfill] finding final games without boxscores...');

    let offset = 0;
    let totalFilled = 0;

    while (true) {
      const { rows } = await pool.query(`
        SELECT DISTINCT g.match_id, g.competition_id
        FROM games g
        WHERE g.status = 'final'
          AND NOT EXISTS (
            SELECT 1 FROM player_boxscores pb WHERE pb.match_id = g.match_id LIMIT 1
          )
        ORDER BY g.match_id DESC
        LIMIT $1 OFFSET $2
      `, [BATCH_SIZE, offset]);

      if (rows.length === 0) break;

      console.log(`[backfill] batch starting at offset ${offset}…`);

      for (const { match_id, competition_id } of rows) {
        const matchId = Number(match_id);
        const compId = Number(competition_id);
        try {
          const box = await getBoxscore(compId, matchId);
          await _internals.upsertBoxscore(pool, matchId, box);
          totalFilled += 1;
          console.log(`  ✓ ${matchId}`);
        } catch (err) {
          console.warn(`  ✗ ${matchId}: ${err?.message ?? err}`);
        }
      }

      offset += BATCH_SIZE;
    }

    console.log(`\n[backfill] complete: ${totalFilled} games backfilled`);

    // Final report
    const counts = await pool.query(`
      SELECT
        (SELECT COUNT(*) FROM games WHERE status = 'final') AS total_final,
        (SELECT COUNT(DISTINCT match_id) FROM player_boxscores) AS games_with_boxes,
        (SELECT COUNT(*) FROM player_boxscores) AS total_player_rows
    `);
    console.log('\n=== FINAL STATE ===');
    console.log(counts.rows[0]);
  } catch (err) {
    console.error('[backfill] failed:', err);
    process.exitCode = 1;
  } finally {
    await shutdownBrowser();
    await pool.end();
  }
})();
