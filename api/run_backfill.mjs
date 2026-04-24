/**
 * run_backfill.mjs — one-shot manual backfill trigger
 * Usage: node run_backfill.mjs
 * Delete after use.
 */
import pg from 'pg';
import dotenv from 'dotenv';

dotenv.config();

// Must be set before flbSync.mjs is imported — it reads COMPETITION_IDS at module load time.
process.env.FLB_COMPETITION_IDS = '42001';

const { _internals } = await import('./flbSync.mjs');

const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

console.log('[backfill] connecting…');
const t0 = Date.now();

try {
  await _internals.runScheduleRefresh(pool);
  console.log(`[backfill] done in ${((Date.now() - t0) / 1000).toFixed(1)}s`);
} catch (err) {
  console.error('[backfill] failed:', err?.message ?? err);
  process.exit(1);
} finally {
  await pool.end();
  process.exit(0);
}
