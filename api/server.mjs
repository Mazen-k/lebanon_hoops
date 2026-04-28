import bcrypt from 'bcryptjs';
import crypto from 'crypto';
import cors from 'cors';
import express from 'express';
import pg from 'pg';
import dotenv from 'dotenv';
import { startFlbJobs } from './flbSync.mjs';

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

// Start FLB basketball data sync jobs (schedule refresh + live polling)
startFlbJobs(pool);

async function listTeams(req, res) {
  try {
    const rawCid = req.query.competition_id ?? req.query.competitionId;
    const competitionId =
      rawCid == null || rawCid === '' ? null : Number(rawCid);
    if (competitionId != null && Number.isNaN(competitionId)) {
      return res.status(400).json({ error: 'competition_id must be an integer.' });
    }

    const { rows } = competitionId == null
      ? await pool.query(
          'SELECT t.team_id, t.team_name, t.team_logo FROM teams t ORDER BY t.team_name ASC',
        )
      : await pool.query(
          `SELECT t.team_id, t.team_name, t.team_logo
           FROM teams t
           INNER JOIN competition_teams ct ON ct.team_id = t.team_id
           WHERE ct.competition_id = $1::int
           ORDER BY t.team_name ASC`,
          [competitionId],
        );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

// Flutter default: GET {base}/teams
app.get('/teams', listTeams);
// Common alternate layout
app.get('/api/teams', listTeams);

/** Full list of competitions (seasons + gender) from the `competitions` table. */
async function listCompetitions(_req, res) {
  try {
    const { rows } = await pool.query(
      `SELECT competition_id, competition_name, gender, start_year, end_year
       FROM competitions
       ORDER BY start_year DESC, end_year DESC, gender ASC, competition_id ASC`,
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

app.get('/competitions', listCompetitions);
app.get('/api/competitions', listCompetitions);

/** GET /competitions/:competitionId/champion — top team by win record from final games */
async function getCompetitionChampionHandler(req, res) {
  const compId = Number(req.params.competitionId);
  if (Number.isNaN(compId)) {
    return res.status(400).json({ error: 'competitionId must be an integer' });
  }
  try {
    const { rows } = await pool.query(
      `WITH win_records AS (
        SELECT team_name, SUM(wins) AS wins, SUM(losses) AS losses
        FROM (
          SELECT home_team_name AS team_name,
                 CASE WHEN home_score > away_score THEN 1 ELSE 0 END AS wins,
                 CASE WHEN home_score < away_score THEN 1 ELSE 0 END AS losses
          FROM games
          WHERE competition_id = $1 AND status = 'final'
            AND home_score IS NOT NULL AND away_score IS NOT NULL
          UNION ALL
          SELECT away_team_name,
                 CASE WHEN away_score > home_score THEN 1 ELSE 0 END,
                 CASE WHEN away_score < home_score THEN 1 ELSE 0 END
          FROM games
          WHERE competition_id = $1 AND status = 'final'
            AND home_score IS NOT NULL AND away_score IS NOT NULL
        ) sub
        GROUP BY team_name
        ORDER BY wins DESC LIMIT 1
      )
      SELECT
        w.team_name,
        w.wins::int AS wins,
        w.losses::int AS losses,
        c.competition_id,
        c.competition_name,
        c.gender,
        c.start_year,
        c.end_year,
        (
          SELECT CASE
            WHEN g.home_team_name = w.team_name THEN g.home_team_logo
            ELSE g.away_team_logo
          END
          FROM games g
          WHERE g.competition_id = $1
            AND (g.home_team_name = w.team_name OR g.away_team_name = w.team_name)
            AND CASE
              WHEN g.home_team_name = w.team_name THEN g.home_team_logo
              ELSE g.away_team_logo
            END IS NOT NULL
            AND CASE
              WHEN g.home_team_name = w.team_name THEN g.home_team_logo
              ELSE g.away_team_logo
            END != ''
          LIMIT 1
        ) AS logo_url
      FROM win_records w
      CROSS JOIN competitions c
      WHERE c.competition_id = $1`,
      [compId],
    );
    if (rows.length === 0) {
      return res.status(404).json({ error: 'No champion found for this competition' });
    }
    res.json(rows[0]);
  } catch (err) {
    console.error('[GET /competitions/:id/champion]', err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

app.get('/competitions/:competitionId/champion', getCompetitionChampionHandler);
app.get('/api/competitions/:competitionId/champion', getCompetitionChampionHandler);

async function getTeamDetails(req, res) {
  const teamId = Number(req.params.id);
  if (Number.isNaN(teamId)) {
    return res.status(400).json({ error: 'team id must be an integer.' });
  }
  try {
    const { rows: teamRows } = await pool.query(
      'SELECT team_id, team_name, team_logo FROM teams WHERE team_id = $1',
      [teamId]
    );
    if (teamRows.length === 0) {
      return res.status(404).json({ error: 'Team not found' });
    }
    const team = teamRows[0];

    let playerRows;
    try {
      const q = await pool.query(
        `SELECT player_id, jersey_number, first_name, last_name, nationality, position, dominant_hand, dob, picture_url
         FROM players WHERE team_id = $1 ORDER BY jersey_number ASC`,
        [teamId],
      );
      playerRows = q.rows;
    } catch (playerColErr) {
      const q = await pool.query(
        `SELECT player_id, jersey_number, first_name, last_name, nationality, position, dominant_hand, dob
         FROM players WHERE team_id = $1 ORDER BY jersey_number ASC`,
        [teamId],
      );
      playerRows = q.rows.map((r) => ({ ...r, picture_url: null }));
    }

    let staff = [];
    try {
      const { rows: staffRows } = await pool.query(
        `SELECT staff_id, team_id, first_name, last_name, role, picture_url
         FROM team_staff WHERE team_id = $1 ORDER BY staff_id ASC`,
        [teamId],
      );
      staff = staffRows;
    } catch (staffErr) {
      console.warn('getTeamDetails team_staff skipped:', staffErr?.message ?? staffErr);
    }

    let trophies = [];
    try {
      const { rows: instRows } = await pool.query(
        `SELECT t.trophy_id, t.trophy_name, t.trophy_description, t.trophy_image_url,
                ti.season_start_year, ti.season_end_year
         FROM trophy_instances ti
         INNER JOIN trophy t ON t.trophy_id = ti.trophy_id
         WHERE ti.team_id = $1
         ORDER BY t.trophy_name ASC, ti.season_start_year DESC`,
        [teamId]
      );
      const byTrophy = new Map();
      for (const r of instRows) {
        const id = r.trophy_id;
        if (!byTrophy.has(id)) {
          byTrophy.set(id, {
            trophy_id: id,
            trophy_name: r.trophy_name,
            trophy_description: r.trophy_description,
            trophy_image_url: r.trophy_image_url,
            seasons: [],
          });
        }
        byTrophy.get(id).seasons.push({
          season_start_year: r.season_start_year,
          season_end_year: r.season_end_year,
        });
      }
      trophies = [...byTrophy.values()]
        .map((t) => ({
          ...t,
          win_count: t.seasons.length,
        }))
        .sort((a, b) => b.win_count - a.win_count || String(a.trophy_name).localeCompare(String(b.trophy_name)));
    } catch (trophyErr) {
      console.warn('getTeamDetails trophies skipped:', trophyErr?.message ?? trophyErr);
    }

    let stadium = null;
    try {
      const { rows: stRows } = await pool.query(
        `SELECT stadium_id, stadium_name, location, capacity
         FROM stadiums WHERE team_id = $1 ORDER BY stadium_id ASC LIMIT 1`,
        [teamId],
      );
      if (stRows.length > 0) stadium = stRows[0];
    } catch (stadiumErr) {
      console.warn('getTeamDetails stadium skipped:', stadiumErr?.message ?? stadiumErr);
    }

    res.json({ team, players: playerRows, trophies, stadium, staff });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

app.get('/teams/:id', getTeamDetails);
app.get('/api/teams/:id', getTeamDetails);

function collectionDuplicatesOnly(query) {
  const v = query.duplicates_only ?? query.duplicatesOnly;
  return v === '1' || v === 'true' || v === true;
}

/** Distinct play_cards owned by user. Use ?duplicates_only=1 for 2+ copies (includes instance_count). */
async function collectionHandler(req, res) {
  const raw = req.query.user_id ?? req.query.userId;
  if (raw == null || raw === '' || Number.isNaN(Number(raw))) {
    return res.status(400).json({ error: 'user_id query parameter is required (integer).' });
  }
  const userId = Number(raw);
  const duplicatesOnly = collectionDuplicatesOnly(req.query);
  try {
    const sql = duplicatesOnly
      ? `
      WITH dup AS (
        SELECT card_id, COUNT(*)::int AS instance_count
        FROM card_instances
        WHERE user_id = $1::int
        GROUP BY card_id
        HAVING COUNT(*) > 1
      )
      SELECT
        pc.card_id,
        pc.card_type,
        pc.player_id,
        pc.attack,
        pc.defend,
        pc.card_image,
        COALESCE(NULLIF(TRIM(p.position), ''), '?') AS position,
        COALESCE(NULLIF(TRIM(p.nationality), ''), '') AS nationality,
        COALESCE(NULLIF(TRIM(p.first_name), ''), '') AS first_name,
        COALESCE(NULLIF(TRIM(p.last_name), ''), '') AS last_name,
        t.team_id,
        t.team_name,
        ROUND((pc.attack + pc.defend) / 2.0)::int AS overall,
        d.instance_count
      FROM dup d
      INNER JOIN play_cards pc ON pc.card_id = d.card_id
      LEFT JOIN players p ON p.player_id = pc.player_id
      LEFT JOIN teams t ON t.team_id = p.team_id
      ORDER BY d.instance_count DESC, ROUND((pc.attack + pc.defend) / 2.0)::int DESC, pc.card_id ASC
      `
      : `
      SELECT * FROM (
        SELECT DISTINCT ON (pc.card_id)
          pc.card_id,
          pc.card_type,
          pc.player_id,
          pc.attack,
          pc.defend,
          pc.card_image,
          COALESCE(NULLIF(TRIM(p.position), ''), '?') AS position,
          COALESCE(NULLIF(TRIM(p.nationality), ''), '') AS nationality,
          COALESCE(NULLIF(TRIM(p.first_name), ''), '') AS first_name,
          COALESCE(NULLIF(TRIM(p.last_name), ''), '') AS last_name,
          t.team_id,
          t.team_name,
          ROUND((pc.attack + pc.defend) / 2.0)::int AS overall
        FROM card_instances ci
        INNER JOIN play_cards pc ON pc.card_id = ci.card_id
        LEFT JOIN players p ON p.player_id = pc.player_id
        LEFT JOIN teams t ON t.team_id = p.team_id
        WHERE ci.user_id = $1::int
        ORDER BY pc.card_id
      ) x
      ORDER BY x.overall DESC, x.card_id ASC
      `;
    const { rows } = await pool.query(sql, [userId]);
    res.json({ cards: rows });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

app.get('/collection', collectionHandler);
app.get('/api/collection', collectionHandler);

/** Legacy alias — same as GET /collection?duplicates_only=1 */
function collectionDuplicatesAliasHandler(req, res) {
  req.query = { ...req.query, duplicates_only: '1' };
  return collectionHandler(req, res);
}

app.get('/collection-duplicates', collectionDuplicatesAliasHandler);
app.get('/api/collection-duplicates', collectionDuplicatesAliasHandler);

async function registerHandler(req, res) {
  const username = req.body?.username?.trim();
  const email = (req.body?.email ?? '').trim().toLowerCase();
  const password = req.body?.password;
  const phone_number = req.body?.phone_number?.trim() || req.body?.phoneNumber?.trim() || null;
  const favorite_team_id =
    req.body?.favorite_team_id ?? req.body?.favoriteTeamId ?? null;

  if (!username || !email || !password) {
    return res.status(400).json({ error: 'username, email, and password are required' });
  }
  if (password.length < 8) {
    return res.status(400).json({ error: 'Password must be at least 8 characters' });
  }
  try {
    const hash = await bcrypt.hash(password, 10);
    const { rows } = await pool.query(
      `INSERT INTO users (username, email, password_hash, phone_number, favorite_team_id)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING user_id, username, email`,
      [username, email, hash, phone_number, favorite_team_id],
    );
    res.status(201).json({
      user_id: rows[0].user_id,
      username: rows[0].username,
      email: rows[0].email,
    });
  } catch (err) {
    if (err.code === '23505') {
      return res.status(409).json({ error: 'Username or email already registered' });
    }
    if (err.code === '23503') {
      return res.status(400).json({ error: 'Invalid favorite_team_id' });
    }
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

async function loginHandler(req, res) {
  const usernameOrEmail =
    req.body?.usernameOrEmail?.trim() ||
    req.body?.username_or_email?.trim() ||
    req.body?.email?.trim();
  const password = req.body?.password;
  if (!usernameOrEmail || !password) {
    return res.status(400).json({ error: 'usernameOrEmail and password required' });
  }
  try {
    const { rows } = await pool.query(
      `SELECT user_id, username, email, password_hash
       FROM users
       WHERE username = $1 OR LOWER(email) = LOWER($1)
       LIMIT 1`,
      [usernameOrEmail],
    );
    if (rows.length === 0) {
      return res.status(401).json({ error: 'Invalid username or password' });
    }
    const ok = await bcrypt.compare(password, rows[0].password_hash);
    if (!ok) {
      return res.status(401).json({ error: 'Invalid username or password' });
    }
    res.json({
      user_id: rows[0].user_id,
      username: rows[0].username,
      email: rows[0].email,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

app.post('/auth/register', registerHandler);
app.post('/api/auth/register', registerHandler);
app.post('/auth/login', loginHandler);
app.post('/api/auth/login', loginHandler);

/** --- Court vendor (owner) sessions: in-memory Bearer tokens --- */
const vendorSessions = new Map();
const VENDOR_SESSION_MS = 72 * 60 * 60 * 1000;

function getVendorCourtId(req) {
  const h = req.headers.authorization ?? '';
  if (!h.startsWith('Bearer ')) return null;
  const token = h.slice(7).trim();
  if (!token) return null;
  const s = vendorSessions.get(token);
  if (!s || s.expMs < Date.now()) {
    if (token) vendorSessions.delete(token);
    return null;
  }
  return s.courtId;
}

async function courtVendorLoginHandler(req, res) {
  const username = req.body?.username?.trim();
  const password = req.body?.password;
  if (!username || !password) {
    return res.status(400).json({ error: 'username and password required' });
  }
  try {
    const { rows } = await pool.query(
      `SELECT court_id, court_name, location, username, password_hash
       FROM courts WHERE username = $1 LIMIT 1`,
      [username],
    );
    if (rows.length === 0) {
      return res.status(401).json({ error: 'Invalid court username or password' });
    }
    const ok = await bcrypt.compare(password, rows[0].password_hash);
    if (!ok) {
      return res.status(401).json({ error: 'Invalid court username or password' });
    }
    const token = crypto.randomBytes(32).toString('hex');
    vendorSessions.set(token, { courtId: rows[0].court_id, expMs: Date.now() + VENDOR_SESSION_MS });
    res.json({
      token,
      court_id: rows[0].court_id,
      court_name: rows[0].court_name,
      location: rows[0].location,
      username: rows[0].username,
    });
  } catch (err) {
    if (err.code === '42P01') {
      return res.status(503).json({ error: 'Courts table missing. Run DB/court_reservation_schema.sql' });
    }
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

async function vendorListPlaygroundsHandler(req, res) {
  const courtId = getVendorCourtId(req);
  if (!courtId) return res.status(401).json({ error: 'Vendor session required' });
  try {
    const { rows: pgRows } = await pool.query(
      `
      SELECT
        p.playground_id,
        p.court_id,
        p.playground_name,
        p.price_per_hour::float8 AS price_per_hour,
        p.is_active,
        p.can_half_court,
        COALESCE(
          json_agg(
            json_build_object('photo_id', pp.photo_id, 'photo_url', pp.photo_url)
            ORDER BY pp.photo_id
          ) FILTER (WHERE pp.photo_id IS NOT NULL),
          '[]'::json
        ) AS photos
      FROM playgrounds p
      LEFT JOIN playground_photos pp ON pp.playground_id = p.playground_id
      WHERE p.court_id = $1::int
      GROUP BY p.playground_id, p.court_id, p.playground_name, p.price_per_hour, p.is_active, p.can_half_court
      ORDER BY p.playground_name ASC
      `,
      [courtId],
    );
    const playgrounds = pgRows.map((r) => ({
      ...r,
      photos: Array.isArray(r.photos) ? r.photos : JSON.parse(String(r.photos ?? '[]')),
    }));
    res.json({ playgrounds });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

async function vendorCreatePlaygroundHandler(req, res) {
  const courtId = getVendorCourtId(req);
  if (!courtId) return res.status(401).json({ error: 'Vendor session required' });
  const name = (req.body?.playground_name ?? req.body?.playgroundName ?? '').trim();
  const price = req.body?.price_per_hour ?? req.body?.pricePerHour;
  if (!name || price == null || price === '') {
    return res.status(400).json({ error: 'playground_name and price_per_hour required' });
  }
  const canHalf = req.body?.can_half_court === true || req.body?.canHalfCourt === true;
  const isActive = req.body?.is_active !== false && req.body?.isActive !== false;
  try {
    const { rows } = await pool.query(
      `INSERT INTO playgrounds (court_id, playground_name, price_per_hour, is_active, can_half_court)
       VALUES ($1::int, $2, $3::decimal, $4::bool, $5::bool)
       RETURNING playground_id, court_id, playground_name, price_per_hour::float8 AS price_per_hour, is_active, can_half_court`,
      [courtId, name, Number(price), isActive, canHalf],
    );
    res.status(201).json({ playground: { ...rows[0], photo_urls: [] } });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

async function vendorPatchPlaygroundHandler(req, res) {
  const courtId = getVendorCourtId(req);
  if (!courtId) return res.status(401).json({ error: 'Vendor session required' });
  const pid = Number(req.params.id);
  if (Number.isNaN(pid)) return res.status(400).json({ error: 'invalid playground id' });
  const name = req.body?.playground_name ?? req.body?.playgroundName;
  const price = req.body?.price_per_hour ?? req.body?.pricePerHour;
  const canHalf = req.body?.can_half_court ?? req.body?.canHalfCourt;
  const isActive = req.body?.is_active ?? req.body?.isActive;
  try {
    const { rows } = await pool.query(
      `
      UPDATE playgrounds SET
        playground_name = COALESCE($3::varchar, playground_name),
        price_per_hour = COALESCE($4::decimal, price_per_hour),
        can_half_court = COALESCE($5::bool, can_half_court),
        is_active = COALESCE($6::bool, is_active)
      WHERE playground_id = $2::int AND court_id = $1::int
      RETURNING playground_id, court_id, playground_name, price_per_hour::float8 AS price_per_hour, is_active, can_half_court
      `,
      [
        courtId,
        pid,
        name != null ? String(name).trim() || null : null,
        price != null ? Number(price) : null,
        canHalf != null ? Boolean(canHalf) : null,
        isActive != null ? Boolean(isActive) : null,
      ],
    );
    if (rows.length === 0) return res.status(404).json({ error: 'Playground not found' });
    res.json({ playground: rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

async function vendorAddPlaygroundPhotoHandler(req, res) {
  const courtId = getVendorCourtId(req);
  if (!courtId) return res.status(401).json({ error: 'Vendor session required' });
  const pid = Number(req.params.id);
  const url = (req.body?.photo_url ?? req.body?.photoUrl ?? '').trim();
  if (Number.isNaN(pid) || !url) {
    return res.status(400).json({ error: 'photo_url required' });
  }
  try {
    const ins = await pool.query(
      `
      INSERT INTO playground_photos (playground_id, photo_url)
      SELECT p.playground_id, $3
      FROM playgrounds p
      WHERE p.playground_id = $2::int AND p.court_id = $1::int
      RETURNING photo_id, playground_id, photo_url
      `,
      [courtId, pid, url],
    );
    if (ins.rows.length === 0) return res.status(404).json({ error: 'Playground not found' });
    res.status(201).json({ photo: ins.rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

async function vendorDeletePhotoHandler(req, res) {
  const courtId = getVendorCourtId(req);
  if (!courtId) return res.status(401).json({ error: 'Vendor session required' });
  const photoId = Number(req.params.photoId);
  if (Number.isNaN(photoId)) return res.status(400).json({ error: 'invalid photo id' });
  try {
    const { rowCount } = await pool.query(
      `
      DELETE FROM playground_photos pp
      USING playgrounds p
      WHERE pp.photo_id = $2::int
        AND pp.playground_id = p.playground_id
        AND p.court_id = $1::int
      `,
      [courtId, photoId],
    );
    if (!rowCount) return res.status(404).json({ error: 'Photo not found' });
    res.status(204).end();
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

async function vendorListAvailabilityHandler(req, res) {
  const courtId = getVendorCourtId(req);
  if (!courtId) return res.status(401).json({ error: 'Vendor session required' });
  const pgId = Number(req.query.playground_id ?? req.query.playgroundId);
  if (Number.isNaN(pgId)) {
    return res.status(400).json({ error: 'playground_id query required' });
  }
  try {
    const { rows: ok } = await pool.query(
      'SELECT 1 FROM playgrounds WHERE playground_id = $1::int AND court_id = $2::int',
      [pgId, courtId],
    );
    if (ok.length === 0) return res.status(404).json({ error: 'Playground not found' });
    const { rows } = await pool.query(
      `
      SELECT
        a.availability_id,
        a.playground_id,
        a.available_date::text AS available_date,
        to_char(a.start_time, 'HH24:MI') AS start_time,
        to_char(a.end_time, 'HH24:MI') AS end_time,
        a.is_available,
        (r.reservation_id IS NOT NULL) AS is_booked
      FROM playground_availability a
      LEFT JOIN reservations r ON r.availability_id = a.availability_id
      WHERE a.playground_id = $1::int
      ORDER BY a.available_date ASC, a.start_time ASC
      `,
      [pgId],
    );
    res.json({ slots: rows });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

async function vendorCreateAvailabilityHandler(req, res) {
  const courtId = getVendorCourtId(req);
  if (!courtId) return res.status(401).json({ error: 'Vendor session required' });
  const pgId = Number(req.body?.playground_id ?? req.body?.playgroundId);
  const dateStr = String(req.body?.available_date ?? req.body?.availableDate ?? '').trim();
  const st = String(req.body?.start_time ?? req.body?.startTime ?? '').trim();
  const et = String(req.body?.end_time ?? req.body?.endTime ?? '').trim();
  if (Number.isNaN(pgId) || !/^\d{4}-\d{2}-\d{2}$/.test(dateStr) || !st || !et) {
    return res.status(400).json({ error: 'playground_id, available_date (YYYY-MM-DD), start_time, end_time required' });
  }
  try {
    const { rows: ok } = await pool.query(
      'SELECT 1 FROM playgrounds WHERE playground_id = $1::int AND court_id = $2::int',
      [pgId, courtId],
    );
    if (ok.length === 0) return res.status(404).json({ error: 'Playground not found' });
    const { rows } = await pool.query(
      `
      INSERT INTO playground_availability (playground_id, available_date, start_time, end_time, is_available)
      VALUES ($1::int, $2::date, $3::time, $4::time, COALESCE($5::bool, TRUE))
      RETURNING availability_id, playground_id, available_date::text AS available_date,
        to_char(start_time, 'HH24:MI') AS start_time, to_char(end_time, 'HH24:MI') AS end_time, is_available
      `,
      [pgId, dateStr, st.length === 5 ? `${st}:00` : st, et.length === 5 ? `${et}:00` : et, req.body?.is_available ?? req.body?.isAvailable],
    );
    res.status(201).json({ slot: rows[0] });
  } catch (err) {
    if (err.code === '23514') {
      return res.status(400).json({ error: 'end_time must be after start_time' });
    }
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

async function vendorDeleteAvailabilityHandler(req, res) {
  const courtId = getVendorCourtId(req);
  if (!courtId) return res.status(401).json({ error: 'Vendor session required' });
  const aid = Number(req.params.id);
  if (Number.isNaN(aid)) return res.status(400).json({ error: 'invalid availability id' });
  try {
    const { rowCount } = await pool.query(
      `
      DELETE FROM playground_availability a
      USING playgrounds p
      WHERE a.availability_id = $2::int
        AND a.playground_id = p.playground_id
        AND p.court_id = $1::int
      `,
      [courtId, aid],
    );
    if (!rowCount) return res.status(404).json({ error: 'Slot not found' });
    res.status(204).end();
  } catch (err) {
    if (err.code === '23503') {
      return res.status(409).json({ error: 'Cannot delete: slot has a reservation' });
    }
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

app.post('/auth/court-login', courtVendorLoginHandler);
app.post('/api/auth/court-login', courtVendorLoginHandler);
app.get('/vendor/playgrounds', vendorListPlaygroundsHandler);
app.get('/api/vendor/playgrounds', vendorListPlaygroundsHandler);
app.post('/vendor/playgrounds', vendorCreatePlaygroundHandler);
app.post('/api/vendor/playgrounds', vendorCreatePlaygroundHandler);
app.patch('/vendor/playgrounds/:id', vendorPatchPlaygroundHandler);
app.patch('/api/vendor/playgrounds/:id', vendorPatchPlaygroundHandler);
app.post('/vendor/playgrounds/:id/photos', vendorAddPlaygroundPhotoHandler);
app.post('/api/vendor/playgrounds/:id/photos', vendorAddPlaygroundPhotoHandler);
app.delete('/vendor/photos/:photoId', vendorDeletePhotoHandler);
app.delete('/api/vendor/photos/:photoId', vendorDeletePhotoHandler);
app.get('/vendor/availability', vendorListAvailabilityHandler);
app.get('/api/vendor/availability', vendorListAvailabilityHandler);
app.post('/vendor/availability', vendorCreateAvailabilityHandler);
app.post('/api/vendor/availability', vendorCreateAvailabilityHandler);
app.delete('/vendor/availability/:id', vendorDeleteAvailabilityHandler);
app.delete('/api/vendor/availability/:id', vendorDeleteAvailabilityHandler);

/** GET ?user_id= — username + card_coins for cards hub header. */
async function userWalletHandler(req, res) {
  const raw = req.query.user_id ?? req.query.userId;
  if (raw == null || raw === '' || Number.isNaN(Number(raw))) {
    return res.status(400).json({ error: 'user_id query parameter is required (integer).' });
  }
  const userId = Number(raw);
  try {
    const { rows } = await pool.query(
      `SELECT username, COALESCE(card_coins, 0)::int AS card_coins
       FROM users WHERE user_id = $1::int`,
      [userId],
    );
    if (rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.json({
      username: rows[0].username,
      card_coins: rows[0].card_coins,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

app.get('/user/wallet', userWalletHandler);
app.get('/api/user/wallet', userWalletHandler);

/** Instantly credits card coins to user wallet (no payment provider). */
async function buyCoinsHandler(req, res) {
  const rawUserId = req.query.user_id ?? req.query.userId ?? req.body?.userId ?? req.body?.user_id;
  if (rawUserId == null || rawUserId === '' || Number.isNaN(Number(rawUserId))) {
    return res.status(400).json({ error: 'user_id is required (integer).' });
  }
  const rawCoins = req.body?.coins;
  if (rawCoins == null || Number.isNaN(Number(rawCoins))) {
    return res.status(400).json({ error: 'coins is required (integer).' });
  }

  const userId = Number(rawUserId);
  const coins = Math.floor(Number(rawCoins));
  if (!Number.isFinite(coins) || coins <= 0) {
    return res.status(400).json({ error: 'coins must be greater than 0.' });
  }

  try {
    const { rows } = await pool.query(
      `
      UPDATE users
      SET card_coins = COALESCE(card_coins, 0) + $1::int
      WHERE user_id = $2::int
      RETURNING username, COALESCE(card_coins, 0)::int AS card_coins
      `,
      [coins, userId],
    );
    if (rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    return res.json({
      username: rows[0].username,
      card_coins: rows[0].card_coins,
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: err.message ?? String(err) });
  }
}

app.post('/user/wallet/buy-coins', buyCoinsHandler);
app.post('/api/user/wallet/buy-coins', buyCoinsHandler);

const LEBANESE_BASE_PACK_ID = 'lebanese_base';
const LEBANESE_BASE_PACK_COST = 5;
const IMPORT_CHANCE_PACK_ID = 'import_chance';
const IMPORT_CHANCE_PACK_COST = 7;

function packOpenCost(packId) {
  if (packId === IMPORT_CHANCE_PACK_ID) return IMPORT_CHANCE_PACK_COST;
  return LEBANESE_BASE_PACK_COST;
}

function isKnownOpenPack(packId) {
  return (
    packId === LEBANESE_BASE_PACK_ID ||
    packId === 'standard' ||
    packId === IMPORT_CHANCE_PACK_ID
  );
}

/**
 * Picks 4 card_ids for this pack. Lebanese base = 4× base. Standard = 4× any.
 * Import chance = slot1: 25% import (else base); if import pool empty on 25% roll, slot1 is base.
 * Slots 2–4 always base, distinct from slot1.
 */
async function pickCardIdsForOpenPack(client, packId) {
  if (packId === LEBANESE_BASE_PACK_ID) {
    const { rows } = await client.query(`
      SELECT card_id FROM play_cards
      WHERE LOWER(TRIM(COALESCE(card_type::text, ''))) = 'base'
      ORDER BY RANDOM() LIMIT 4
    `);
    if (rows.length < 4) {
      return {
        ok: false,
        error:
          'Not enough base cards in the pool (need 4). Add at least four play_cards rows with card_type = base.',
      };
    }
    return { ok: true, cardIds: rows.map((r) => r.card_id) };
  }

  if (packId === IMPORT_CHANCE_PACK_ID) {
    const firstIds = [];
    const rollImport = Math.random() < 0.25;

    if (rollImport) {
      const { rows: imp } = await client.query(`
        SELECT card_id FROM play_cards
        WHERE LOWER(TRIM(COALESCE(card_type::text, ''))) = 'import'
        ORDER BY RANDOM() LIMIT 1
      `);
      if (imp.length > 0) {
        firstIds.push(imp[0].card_id);
      } else {
        const { rows: b0 } = await client.query(`
          SELECT card_id FROM play_cards
          WHERE LOWER(TRIM(COALESCE(card_type::text, ''))) = 'base'
          ORDER BY RANDOM() LIMIT 1
        `);
        if (b0.length < 1) {
          return {
            ok: false,
            error:
              'Import Chance pack needs at least one base card (import pool was empty on this roll).',
          };
        }
        firstIds.push(b0[0].card_id);
      }
    } else {
      const { rows: b1 } = await client.query(`
        SELECT card_id FROM play_cards
        WHERE LOWER(TRIM(COALESCE(card_type::text, ''))) = 'base'
        ORDER BY RANDOM() LIMIT 1
      `);
      if (b1.length < 1) {
        return {
          ok: false,
          error: 'Not enough base cards for Import Chance pack (need at least 1 for the first slot).',
        };
      }
      firstIds.push(b1[0].card_id);
    }

    const { rows: rest } = await client.query(
      `
      SELECT card_id FROM play_cards
      WHERE LOWER(TRIM(COALESCE(card_type::text, ''))) = 'base'
        AND card_id <> ALL($1::int[])
      ORDER BY RANDOM() LIMIT 3
      `,
      [firstIds],
    );
    if (rest.length < 3) {
      return {
        ok: false,
        error:
          'Not enough distinct base cards for slots 2–4 (need 3 base cards besides the first pick). Add more base play_cards.',
      };
    }
    return { ok: true, cardIds: [...firstIds, ...rest.map((r) => r.card_id)] };
  }

  const { rows } = await client.query(`
    SELECT card_id FROM play_cards ORDER BY RANDOM() LIMIT 4
  `);
  if (rows.length < 4) {
    return {
      ok: false,
      error: 'Not enough cards in the pool (need 4). Add at least four rows to play_cards.',
    };
  }
  return { ok: true, cardIds: rows.map((r) => r.card_id) };
}

/** Canonical pack id from JSON (trim + lowercase aliases). */
function normalizeOpenPackId(body) {
  const raw = body?.packId ?? body?.pack_id;
  if (raw == null) return LEBANESE_BASE_PACK_ID;
  const s = String(raw).trim();
  if (s === '') return LEBANESE_BASE_PACK_ID;
  const lower = s.toLowerCase();
  if (lower === 'standard') return 'standard';
  if (lower === LEBANESE_BASE_PACK_ID) return LEBANESE_BASE_PACK_ID;
  if (lower === IMPORT_CHANCE_PACK_ID || lower === 'importchance' || lower === 'import_chance_pick') {
    return IMPORT_CHANCE_PACK_ID;
  }
  return s;
}

/** Open a pack: deduct card_coins, insert 4 random play_cards as card_instances. */
async function openPackHandler(req, res) {
  const userId = req.body?.userId ?? req.body?.user_id;
  const packId = normalizeOpenPackId(req.body);
  if (userId == null || Number.isNaN(Number(userId))) {
    return res.status(400).json({ error: 'userId (integer) is required in JSON body.' });
  }
  const uid = Number(userId);
  if (!isKnownOpenPack(packId)) {
    return res.status(400).json({ error: `Unknown pack: ${packId}` });
  }

  const cost = packOpenCost(packId);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const { rows: balRows } = await client.query(
      `SELECT COALESCE(card_coins, 0)::int AS c FROM users WHERE user_id = $1::int FOR UPDATE`,
      [uid],
    );
    if (balRows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'User not found.' });
    }
    const balance = balRows[0].c;
    if (balance < cost) {
      await client.query('ROLLBACK');
      return res.status(400).json({
        error: `Not enough card coins (need ${cost}, you have ${balance}).`,
      });
    }

    const picked = await pickCardIdsForOpenPack(client, packId);
    if (!picked.ok) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: picked.error });
    }
    const cardIds = picked.cardIds;

    if (packId === LEBANESE_BASE_PACK_ID) {
      const { rows: leak } = await client.query(
        `
        SELECT card_id, card_type
        FROM play_cards
        WHERE card_id = ANY($1::int[])
          AND LOWER(TRIM(COALESCE(card_type::text, ''))) <> 'base'
        `,
        [cardIds],
      );
      if (leak.length > 0) {
        await client.query('ROLLBACK');
        console.error('[open-pack] Lebanese base pool returned non-base rows', leak);
        return res.status(500).json({
          error: 'Pack pool misconfigured: non-base cards matched base filter. Check play_cards.card_type in the database.',
        });
      }
    }

    if (packId === IMPORT_CHANCE_PACK_ID) {
      const tail = cardIds.slice(1);
      const { rows: badTail } = await client.query(
        `
        SELECT card_id, card_type FROM play_cards
        WHERE card_id = ANY($1::int[])
          AND LOWER(TRIM(COALESCE(card_type::text, ''))) <> 'base'
        `,
        [tail],
      );
      if (badTail.length > 0) {
        await client.query('ROLLBACK');
        console.error('[open-pack] Import chance slots 2–4 must be base', badTail);
        return res.status(500).json({
          error: 'Pack pool misconfigured: non-base card in base-only slots.',
        });
      }
    }

    await client.query(
      `UPDATE users SET card_coins = card_coins - $1::int WHERE user_id = $2::int`,
      [cost, uid],
    );

    const { rows } = await client.query(
      `
      WITH ins AS (
        INSERT INTO card_instances (card_id, user_id)
        SELECT x, $1::int FROM unnest($2::int[]) AS t(x)
        RETURNING card_instance_id, card_id
      )
      SELECT
        ins.card_instance_id,
        pc.card_id,
        pc.card_type,
        pc.player_id,
        pc.attack,
        pc.defend,
        pc.card_image
      FROM ins
      JOIN play_cards pc ON pc.card_id = ins.card_id
      `,
      [uid, cardIds],
    );

    await client.query('COMMIT');
    res.json({ packId, cards: rows, card_coins_spent: cost });
  } catch (err) {
    try {
      await client.query('ROLLBACK');
    } catch (_) {
      /* ignore */
    }
    console.error(err);
    if (err.code === '23503') {
      return res.status(400).json({
        error: `user_id ${uid} not found in users — create that user first or set DEV_USER_ID.`,
      });
    }
    res.status(500).json({ error: err.message ?? String(err) });
  } finally {
    client.release();
  }
}

app.post('/packs/open', openPackHandler);
app.post('/api/packs/open', openPackHandler);

/** Google Drive file id (folders use shorter ids; file ids are typically 25+ chars). */
const DRIVE_FILE_ID_RE = /^[a-zA-Z0-9_-]{10,}$/;

/**
 * Serves playable image bytes for Flutter Image.network.
 * Direct drive.google.com/uc?export=view often returns HTML (virus scan / consent), which breaks clients.
 */
async function googleDriveImageHandler(req, res) {
  const fileId = req.params.id;
  if (!fileId || !DRIVE_FILE_ID_RE.test(fileId)) {
    return res.status(400).json({ error: 'Invalid Google Drive file id' });
  }
  const sources = [
    `https://drive.google.com/thumbnail?id=${encodeURIComponent(fileId)}&sz=w2000`,
    `https://lh3.googleusercontent.com/d/${encodeURIComponent(fileId)}=w2000`,
    `https://drive.google.com/uc?export=download&id=${encodeURIComponent(fileId)}`,
    `https://drive.google.com/uc?export=view&id=${encodeURIComponent(fileId)}`,
  ];
  const ua = 'Mozilla/5.0 (compatible; BasketballApp/1.0; +https://localhost)';
  for (const imageUrl of sources) {
    try {
      const r = await fetch(imageUrl, { redirect: 'follow', headers: { 'User-Agent': ua } });
      if (!r.ok) continue;
      const buf = Buffer.from(await r.arrayBuffer());
      if (buf.length < 256) continue;
      const head = buf.subarray(0, Math.min(64, buf.length)).toString('latin1').trimStart().toLowerCase();
      if (head.startsWith('<!') || head.startsWith('<html')) continue;
      let ct = r.headers.get('content-type') || '';
      if (!ct.startsWith('image/')) {
        if (buf[0] === 0xff && buf[1] === 0xd8) ct = 'image/jpeg';
        else if (buf[0] === 0x89 && buf[1] === 0x50) ct = 'image/png';
        else if (buf[0] === 0x47 && buf[1] === 0x49) ct = 'image/gif';
        else if (buf[0] === 0x52 && buf[1] === 0x49) ct = 'image/webp';
        else ct = 'application/octet-stream';
      }
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Cache-Control', 'public, max-age=86400');
      res.type(ct);
      return res.send(buf);
    } catch (err) {
      console.error('card-image fetch', imageUrl, err.message ?? err);
    }
  }
  res.status(502).json({ error: 'Could not load image from Google Drive (check sharing: Anyone with the link).' });
}

app.get('/card-image/:id', googleDriveImageHandler);
app.get('/api/card-image/:id', googleDriveImageHandler);

// --- Card catalog (all play_cards + ownership + wishlist flag) ---
async function catalogCardsHandler(req, res) {
  const raw = req.query.user_id ?? req.query.userId;
  if (raw == null || raw === '' || Number.isNaN(Number(raw))) {
    return res.status(400).json({ error: 'user_id query parameter is required (integer).' });
  }
  const userId = Number(raw);
  const position = (req.query.position ?? '').trim() || null;
  const nationality = (req.query.nationality ?? '').trim() || null;
  const teamRaw = req.query.team_id ?? req.query.teamId;
  const teamId = teamRaw != null && teamRaw !== '' && !Number.isNaN(Number(teamRaw)) ? Number(teamRaw) : null;
  const onlyMissing =
    req.query.only_missing === '1' ||
    req.query.only_missing === 'true' ||
    req.query.onlyMissing === '1' ||
    req.query.onlyMissing === 'true';
  const cardTypeRaw = (req.query.card_type ?? req.query.cardType ?? '').trim().toLowerCase();
  const cardType =
    cardTypeRaw === 'base' || cardTypeRaw === 'import' ? cardTypeRaw : null;

  const params = [userId];
  const cond = [];

  if (position) {
    params.push(position);
    cond.push(`COALESCE(NULLIF(TRIM(p.position), ''), '?') = $${params.length}`);
  }
  if (teamId != null) {
    params.push(teamId);
    cond.push(`t.team_id = $${params.length}`);
  }
  if (nationality != null && nationality !== '') {
    params.push(nationality);
    cond.push(
      `LOWER(TRIM(COALESCE(p.nationality, ''))) = LOWER(TRIM($${params.length}::text))`,
    );
  }
  if (cardType != null) {
    params.push(cardType);
    cond.push(`LOWER(TRIM(COALESCE(pc.card_type::text, ''))) = $${params.length}`);
  }

  if (onlyMissing) {
    cond.push(
      `NOT EXISTS (SELECT 1 FROM card_instances ci0 WHERE ci0.user_id = $1 AND ci0.card_id = pc.card_id)`,
    );
  }

  const whereSql = cond.length ? `WHERE ${cond.join(' AND ')}` : '';

  try {
    const { rows } = await pool.query(
      `
      SELECT
        pc.card_id,
        pc.card_type,
        pc.player_id,
        pc.attack,
        pc.defend,
        pc.card_image,
        COALESCE(NULLIF(TRIM(p.position), ''), '?') AS position,
        COALESCE(NULLIF(TRIM(p.nationality), ''), '') AS nationality,
        COALESCE(NULLIF(TRIM(p.first_name), ''), '') AS first_name,
        COALESCE(NULLIF(TRIM(p.last_name), ''), '') AS last_name,
        t.team_id,
        t.team_name,
        ROUND((pc.attack + pc.defend) / 2.0)::int AS overall,
        (SELECT COUNT(*)::int FROM card_instances ci WHERE ci.user_id = $1 AND ci.card_id = pc.card_id) AS owned_count,
        EXISTS (
          SELECT 1 FROM wishlists w
          JOIN wishlist_cards wc ON wc.wishlist_id = w.wishlist_id AND wc.card_id = pc.card_id
          WHERE w.user_id = $1
        ) AS on_wishlist
      FROM play_cards pc
      LEFT JOIN players p ON p.player_id = pc.player_id
      LEFT JOIN teams t ON t.team_id = p.team_id
      ${whereSql}
      ORDER BY overall DESC, pc.card_id ASC
      `,
      params,
    );
    res.json({ cards: rows });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

app.get('/cards/catalog', catalogCardsHandler);
app.get('/api/cards/catalog', catalogCardsHandler);

/** GET /cards/filter-options — men's division-1 clubs + distinct player nationalities (Lebanon variants first). */
async function cardCatalogFilterOptionsHandler(_req, res) {
  try {
    let teamsRows = [];
    try {
      const strict = await pool.query(
        `SELECT team_id, team_name, team_logo
         FROM teams
         WHERE UPPER(TRIM(COALESCE(gender, ''))) = 'M'
           AND COALESCE(division, 1) = 1
         ORDER BY team_name ASC`,
      );
      teamsRows = strict.rows ?? [];
    } catch (e) {
      console.warn('[GET /cards/filter-options] strict teams query:', e.message ?? e);
      teamsRows = [];
    }
    if (!teamsRows.length) {
      const fb = await pool.query(
        `SELECT team_id, team_name, team_logo
         FROM teams
         ORDER BY team_name ASC
         LIMIT 400`,
      );
      teamsRows = fb.rows ?? [];
    }

    let nationalities = [];
    try {
      const natRes = await pool.query(
        `SELECT nationality
         FROM (
           SELECT DISTINCT TRIM(nationality) AS nationality
           FROM players
           WHERE TRIM(COALESCE(nationality, '')) <> ''
         ) sub
         ORDER BY
           CASE
             WHEN UPPER(nationality) IN ('LB','LEB','LEBANON','LBN') THEN 0
             ELSE 1
           END,
           nationality ASC`,
      );
      nationalities = natRes.rows
        .map((r) => r.nationality)
        .filter((s) => s != null && String(s).trim() !== '');
    } catch (e) {
      console.warn('[GET /cards/filter-options] nationalities query:', e.message ?? e);
    }

    res.json({ teams: teamsRows, nationalities });
  } catch (err) {
    console.error('[GET /cards/filter-options]', err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

app.get('/cards/filter-options', cardCatalogFilterOptionsHandler);
app.get('/api/cards/filter-options', cardCatalogFilterOptionsHandler);

// --- Wishlist ---
async function ensureWishlistRow(client, userId) {
  await client.query(
    `INSERT INTO wishlists (user_id) VALUES ($1::int) ON CONFLICT (user_id) DO NOTHING`,
    [userId],
  );
  const { rows } = await client.query(`SELECT wishlist_id FROM wishlists WHERE user_id = $1::int`, [userId]);
  return rows[0]?.wishlist_id ?? null;
}

async function wishlistGetHandler(req, res) {
  const raw = req.query.user_id ?? req.query.userId;
  if (raw == null || raw === '' || Number.isNaN(Number(raw))) {
    return res.status(400).json({ error: 'user_id query parameter is required (integer).' });
  }
  const userId = Number(raw);
  const client = await pool.connect();
  try {
    try {
      await ensureWishlistRow(client, userId);
    } catch (e) {
      if (e.code === '23503') {
        return res.status(404).json({
          error:
            'No user row for this user_id (foreign key). Use a valid users.user_id or register/login first.',
        });
      }
      throw e;
    }
    const { rows: wrows } = await client.query(
      `SELECT wishlist_id, msg FROM wishlists WHERE user_id = $1::int`,
      [userId],
    );
    const wishlistId = wrows[0]?.wishlist_id;
    if (wishlistId == null) {
      return res.json({ wishlist_id: null, card_ids: [], msg: 'Best cards Please' });
    }
    const rawMsg = wrows[0]?.msg;
    const msg =
      rawMsg == null || String(rawMsg).trim() === ''
        ? 'Best cards Please'
        : String(rawMsg).trim().slice(0, 50);
    const { rows: crows } = await client.query(
      `SELECT card_id FROM wishlist_cards WHERE wishlist_id = $1::int ORDER BY added_at ASC`,
      [wishlistId],
    );
    res.json({
      wishlist_id: wishlistId,
      card_ids: crows.map((r) => r.card_id),
      msg,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  } finally {
    client.release();
  }
}

async function wishlistPutHandler(req, res) {
  const userId = req.body?.user_id ?? req.body?.userId;
  const cardIdsRaw = req.body?.card_ids ?? req.body?.cardIds;
  if (userId == null || Number.isNaN(Number(userId))) {
    return res.status(400).json({ error: 'user_id is required' });
  }
  if (!Array.isArray(cardIdsRaw)) {
    return res.status(400).json({ error: 'card_ids must be an array of integers' });
  }
  const uid = Number(userId);
  const cardIds = [...new Set(cardIdsRaw.map((x) => Number(x)).filter((n) => !Number.isNaN(n)))];
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const wid = await ensureWishlistRow(client, uid);
    if (wid == null) {
      throw new Error('Could not create wishlist');
    }
    await client.query(`DELETE FROM wishlist_cards WHERE wishlist_id = $1::int`, [wid]);
    for (const cid of cardIds) {
      const { rows: chk } = await client.query(`SELECT 1 FROM play_cards WHERE card_id = $1::int LIMIT 1`, [cid]);
      if (chk.length === 0) continue;
      await client.query(
        `INSERT INTO wishlist_cards (wishlist_id, card_id) VALUES ($1::int, $2::int) ON CONFLICT DO NOTHING`,
        [wid, cid],
      );
    }
    const msgRaw = req.body?.msg ?? req.body?.message;
    if (typeof msgRaw === 'string') {
      let m = String(msgRaw).trim().slice(0, 50);
      if (m === '') m = 'Best cards Please';
      await client.query(`UPDATE wishlists SET msg = $1::varchar(50) WHERE wishlist_id = $2::int`, [m, wid]);
    }
    await client.query('COMMIT');
    res.json({ wishlist_id: wid, card_ids: cardIds });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  } finally {
    client.release();
  }
}

async function wishlistPatchMsgHandler(req, res) {
  const userId = req.body?.user_id ?? req.body?.userId;
  const msgRaw = req.body?.msg;
  if (userId == null || Number.isNaN(Number(userId))) {
    return res.status(400).json({ error: 'user_id is required' });
  }
  if (typeof msgRaw !== 'string') {
    return res.status(400).json({ error: 'msg must be a string' });
  }
  const uid = Number(userId);
  let m = String(msgRaw).trim().slice(0, 50);
  if (m === '') m = 'Best cards Please';
  const client = await pool.connect();
  try {
    try {
      await ensureWishlistRow(client, uid);
    } catch (e) {
      if (e.code === '23503') {
        return res.status(404).json({
          error:
            'No user row for this user_id (foreign key). Use a valid users.user_id or register/login first.',
        });
      }
      throw e;
    }
    const { rows: wrows } = await client.query(`SELECT wishlist_id FROM wishlists WHERE user_id = $1::int`, [uid]);
    const wid = wrows[0]?.wishlist_id;
    if (wid == null) {
      return res.status(500).json({ error: 'Could not resolve wishlist' });
    }
    await client.query(`UPDATE wishlists SET msg = $1::varchar(50) WHERE wishlist_id = $2::int`, [m, wid]);
    res.json({ wishlist_id: wid, msg: m });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  } finally {
    client.release();
  }
}

app.get('/wishlist', wishlistGetHandler);
app.get('/api/wishlist', wishlistGetHandler);
app.put('/wishlist', wishlistPutHandler);
app.put('/api/wishlist', wishlistPutHandler);
app.patch('/wishlist', wishlistPatchMsgHandler);
app.patch('/api/wishlist', wishlistPatchMsgHandler);

// --- In-memory trade rooms (MVP) ---
const tradeRooms = new Map();

function genTradeCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let s = '';
  for (let i = 0; i < 6; i++) s += chars[Math.floor(Math.random() * chars.length)];
  if (tradeRooms.has(s)) return genTradeCode();
  return s;
}

function pruneStaleRooms() {
  const now = Date.now();
  for (const [code, room] of tradeRooms) {
    if (now - room.createdAt > 60 * 60 * 1000) tradeRooms.delete(code);
  }
}

async function tradeCreateHandler(req, res) {
  pruneStaleRooms();
  const userId = req.body?.user_id ?? req.body?.userId;
  if (userId == null || Number.isNaN(Number(userId))) {
    return res.status(400).json({ error: 'user_id is required' });
  }
  const uid = Number(userId);
  const { rows } = await pool.query(`SELECT username FROM users WHERE user_id = $1::int`, [uid]);
  if (rows.length === 0) return res.status(400).json({ error: 'User not found' });
  const code = genTradeCode();
  tradeRooms.set(code, {
    code,
    createdAt: Date.now(),
    users: [uid],
    usernames: { [uid]: rows[0].username },
    offers: { [uid]: [null, null, null] },
    ready: { [uid]: false },
    finalize: { [uid]: false },
    summary_choice: { [uid]: null },
    coins: { [uid]: 0 },
    /** targetUserId -> viewerUserId -> [null | 'up' | 'down'] for each slot */
    slotReactions: {},
    lastQuickMessage: null,
  });
  res.status(201).json({ code, host: true });
}

async function tradeJoinHandler(req, res) {
  pruneStaleRooms();
  const code = (req.params.code ?? '').toUpperCase();
  const userId = req.body?.user_id ?? req.body?.userId;
  if (!code || userId == null || Number.isNaN(Number(userId))) {
    return res.status(400).json({ error: 'code and user_id are required' });
  }
  const uid = Number(userId);
  const room = tradeRooms.get(code);
  if (!room) return res.status(404).json({ error: 'Room not found or expired' });
  if (room.users.includes(uid)) {
    return res.json({ code, joined: true, peer: room.users.find((u) => u !== uid) ?? null });
  }
  if (room.users.length >= 2) {
    return res.status(409).json({ error: 'Room is full' });
  }
  const { rows } = await pool.query(`SELECT username FROM users WHERE user_id = $1::int`, [uid]);
  if (rows.length === 0) return res.status(400).json({ error: 'User not found' });
  room.users.push(uid);
  room.usernames[uid] = rows[0].username;
  room.offers[uid] = [null, null, null];
  room.ready[uid] = false;
  room.finalize[uid] = false;
  if (!room.coins) room.coins = {};
  room.coins[uid] = 0;
  if (!room.slotReactions) room.slotReactions = {};
  if (!room.summary_choice) room.summary_choice = {};
  room.summary_choice[uid] = null;
  res.json({ code, joined: true, peer: room.users[0] });
}

function ensureRoomTradeFields(room) {
  if (!room.coins) room.coins = {};
  for (const u of room.users) {
    if (room.coins[u] == null) room.coins[u] = 0;
  }
  if (!room.slotReactions) room.slotReactions = {};
  if (!room.summary_choice) room.summary_choice = {};
  for (const u of room.users) {
    if (!(u in room.summary_choice)) room.summary_choice[u] = null;
  }
}

function slotReactionArray(room, targetUid, viewerUid) {
  if (!room.slotReactions[targetUid]) room.slotReactions[targetUid] = {};
  if (!room.slotReactions[targetUid][viewerUid]) {
    room.slotReactions[targetUid][viewerUid] = [null, null, null];
  }
  return room.slotReactions[targetUid][viewerUid];
}

async function loadWishlistMsg(client, userId) {
  const { rows } = await client.query(
    `SELECT COALESCE(NULLIF(TRIM(w.msg), ''), 'Best cards Please') AS m
     FROM wishlists w WHERE w.user_id = $1::int LIMIT 1`,
    [userId],
  );
  if (rows.length === 0) return 'Best cards Please';
  const s = rows[0]?.m != null ? String(rows[0].m) : 'Best cards Please';
  return s.trim() === '' ? 'Best cards Please' : s.trim().slice(0, 50);
}

async function loadWishlistCardRows(client, userId) {
  const { rows } = await client.query(
    `
    SELECT
      pc.card_id,
      pc.card_type,
      pc.player_id,
      pc.attack,
      pc.defend,
      pc.card_image,
      COALESCE(NULLIF(TRIM(p.position), ''), '?') AS position,
      COALESCE(NULLIF(TRIM(p.nationality), ''), '') AS nationality,
      COALESCE(NULLIF(TRIM(p.first_name), ''), '') AS first_name,
      COALESCE(NULLIF(TRIM(p.last_name), ''), '') AS last_name,
      t.team_id,
      t.team_name,
      ROUND((pc.attack + pc.defend) / 2.0)::int AS overall
    FROM wishlists w
    JOIN wishlist_cards wc ON wc.wishlist_id = w.wishlist_id
    JOIN play_cards pc ON pc.card_id = wc.card_id
    LEFT JOIN players p ON p.player_id = pc.player_id
    LEFT JOIN teams t ON t.team_id = p.team_id
    WHERE w.user_id = $1::int
    ORDER BY wc.added_at ASC
    `,
    [userId],
  );
  return rows;
}

async function tradeStateHandler(req, res) {
  pruneStaleRooms();
  const code = (req.params.code ?? '').toUpperCase();
  const raw = req.query.user_id ?? req.query.userId;
  if (!code || raw == null || Number.isNaN(Number(raw))) {
    return res.status(400).json({ error: 'code and user_id are required' });
  }
  const userId = Number(raw);
  const room = tradeRooms.get(code);
  if (!room) return res.status(404).json({ error: 'Room not found or expired' });
  if (!room.users.includes(userId)) {
    return res.status(403).json({ error: 'Not a member of this room' });
  }
  ensureRoomTradeFields(room);
  const peerId = room.users.find((u) => u !== userId) ?? null;
  const client = await pool.connect();
  try {
    let peerWishlist = [];
    let peerWishlistMeta = [];
    if (peerId != null) {
      peerWishlist = await loadWishlistCardRows(client, peerId);
      for (const row of peerWishlist) {
        const { rows: cnt } = await client.query(
          `SELECT COUNT(*)::int AS n FROM card_instances WHERE user_id = $1::int AND card_id = $2::int`,
          [userId, row.card_id],
        );
        const n = cnt[0]?.n ?? 0;
        peerWishlistMeta.push({
          ...row,
          you_own_count: n,
          you_have_duplicate: n >= 2,
        });
      }
    }

    async function slotDetails(uid, slots) {
      const out = [];
      for (const instId of slots) {
        if (instId == null) {
          out.push(null);
          continue;
        }
        const { rows: ir } = await client.query(
          `
          SELECT ci.card_instance_id, ci.card_id, ci.user_id,
            pc.card_type, pc.attack, pc.defend, pc.card_image,
            COALESCE(NULLIF(TRIM(p.position), ''), '?') AS position,
            COALESCE(NULLIF(TRIM(p.first_name), ''), '') AS first_name,
            COALESCE(NULLIF(TRIM(p.last_name), ''), '') AS last_name
          FROM card_instances ci
          JOIN play_cards pc ON pc.card_id = ci.card_id
          LEFT JOIN players p ON p.player_id = pc.player_id
          WHERE ci.card_instance_id = $1::int AND ci.user_id = $2::int
          `,
          [instId, uid],
        );
        out.push(ir[0] ?? null);
      }
      return out;
    }

    const yourSlots = await slotDetails(userId, room.offers[userId] ?? [null, null, null]);
    const theirSlots =
      peerId != null ? await slotDetails(peerId, room.offers[peerId] ?? [null, null, null]) : [null, null, null];

    const yourMsg = await loadWishlistMsg(client, userId);
    const peerMsg = peerId != null ? await loadWishlistMsg(client, peerId) : '';

    const peerOnYou = peerId != null ? slotReactionArray(room, userId, peerId) : [null, null, null];
    const youOnPeer = peerId != null ? slotReactionArray(room, peerId, userId) : [null, null, null];

    res.json({
      code,
      rev: room.rev ?? 0,
      peer_user_id: peerId,
      peer_username: peerId != null ? room.usernames[peerId] : null,
      your_username: room.usernames[userId] ?? 'Player',
      your_slots: yourSlots,
      their_slots: theirSlots,
      your_msg: yourMsg,
      peer_msg: peerMsg,
      your_coins: room.coins[userId] ?? 0,
      peer_coins: peerId != null ? room.coins[peerId] ?? 0 : 0,
      /** How the peer rated each of your slots (same order as your_slots). */
      peer_reactions_on_your_slots: peerOnYou,
      /** How you rated each of the peer's slots (same order as their_slots). */
      your_reactions_on_peer_slots: youOnPeer,
      peer_wishlist: peerWishlistMeta,
      ready_confirm: room.ready,
      final_confirm: room.finalize,
      summary_choice: room.summary_choice ?? {},
      last_quick_message: room.lastQuickMessage ?? null,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  } finally {
    client.release();
  }
}

const TRADE_QUICK_MSG_PRESETS = new Set([
  'hello',
  'cards_only',
  'coins_only',
  'how_much',
  'make_offer',
  'look_wishlist',
  'sorry_no_match',
  'more_coins',
]);

async function tradeQuickMessageHandler(req, res) {
  pruneStaleRooms();
  const code = (req.params.code ?? '').toUpperCase();
  const userId = req.body?.user_id ?? req.body?.userId;
  const presetRaw = req.body?.preset ?? req.body?.message_key ?? req.body?.key;
  if (!code || userId == null || Number.isNaN(Number(userId))) {
    return res.status(400).json({ error: 'code and user_id are required' });
  }
  const preset = presetRaw != null ? String(presetRaw).trim() : '';
  if (!TRADE_QUICK_MSG_PRESETS.has(preset)) {
    return res.status(400).json({ error: 'Invalid preset message' });
  }
  const uid = Number(userId);
  const room = tradeRooms.get(code);
  if (!room) return res.status(404).json({ error: 'Room not found or expired' });
  if (!room.users.includes(uid)) return res.status(403).json({ error: 'Not a member of this room' });
  room.lastQuickMessage = {
    from_user_id: uid,
    from_username: room.usernames[uid] ?? 'Player',
    preset,
    sent_at: Date.now(),
  };
  room.rev = (room.rev ?? 0) + 1;
  return res.json({ ok: true, rev: room.rev });
}

async function tradeOfferHandler(req, res) {
  pruneStaleRooms();
  const code = (req.params.code ?? '').toUpperCase();
  const userId = req.body?.user_id ?? req.body?.userId;
  const slots = req.body?.slots ?? req.body?.card_instance_ids;
  if (!code || userId == null || Number.isNaN(Number(userId))) {
    return res.status(400).json({ error: 'code and user_id are required' });
  }
  if (!Array.isArray(slots) || slots.length !== 3) {
    return res.status(400).json({ error: 'slots must be an array of exactly 3 elements (null or card_instance_id)' });
  }
  const uid = Number(userId);
  const room = tradeRooms.get(code);
  if (!room) return res.status(404).json({ error: 'Room not found or expired' });
  if (!room.users.includes(uid)) return res.status(403).json({ error: 'Not a member of this room' });
  ensureRoomTradeFields(room);
  if (room.ready[uid]) {
    return res
      .status(400)
      .json({ error: 'Remove your trade confirmation before changing cards.' });
  }

  const normalized = slots.map((x) => (x == null || x === '' ? null : Number(x)));
  if (normalized.some((x) => x !== null && Number.isNaN(x))) {
    return res.status(400).json({ error: 'Invalid slot values' });
  }

  const client = await pool.connect();
  try {
    const seen = new Set();
    for (const instId of normalized) {
      if (instId == null) continue;
      if (seen.has(instId)) return res.status(400).json({ error: 'Duplicate instance in offer' });
      seen.add(instId);
      const { rows } = await client.query(
        `SELECT card_instance_id, card_id FROM card_instances WHERE card_instance_id = $1::int AND user_id = $2::int`,
        [instId, uid],
      );
      if (rows.length === 0) return res.status(400).json({ error: `Instance ${instId} not owned by you` });
      const cardId = rows[0].card_id;
      const { rows: cr } = await client.query(
        `SELECT COUNT(*)::int AS n FROM card_instances WHERE user_id = $1::int AND card_id = $2::int`,
        [uid, cardId],
      );
      if ((cr[0]?.n ?? 0) < 2) {
        return res.status(400).json({
          error: `Card ${cardId} is not a duplicate (need 2+ copies to trade one).`,
        });
      }
    }
    room.offers[uid] = normalized;
    room.slotReactions = {};
    for (const u of room.users) {
      room.ready[u] = false;
      room.finalize[u] = false;
      room.summary_choice[u] = null;
    }
    room.rev = (room.rev ?? 0) + 1;
    res.json({ ok: true, rev: room.rev });
  } finally {
    client.release();
  }
}

/** Any member leaving closes the room for everyone. */
async function tradeLeaveHandler(req, res) {
  pruneStaleRooms();
  const code = (req.params.code ?? '').toUpperCase();
  const userId = req.body?.user_id ?? req.body?.userId;
  if (!code || userId == null || Number.isNaN(Number(userId))) {
    return res.status(400).json({ error: 'code and user_id are required' });
  }
  const uid = Number(userId);
  const room = tradeRooms.get(code);
  if (!room) return res.json({ ok: true });
  if (!room.users.includes(uid)) {
    return res.status(403).json({ error: 'Not a member of this room' });
  }
  tradeRooms.delete(code);
  return res.json({ ok: true, closed_for_all: true });
}

/** Set coins this user offers in the trade (display / future settlement). Resets lock-in. */
async function tradeCoinsHandler(req, res) {
  pruneStaleRooms();
  const code = (req.params.code ?? '').toUpperCase();
  const userId = req.body?.user_id ?? req.body?.userId;
  const rawCoins = req.body?.coins ?? req.body?.card_coins;
  if (!code || userId == null || Number.isNaN(Number(userId))) {
    return res.status(400).json({ error: 'code and user_id are required' });
  }
  const uid = Number(userId);
  const coins = Number(rawCoins);
  if (!Number.isFinite(coins) || coins < 0) {
    return res.status(400).json({ error: 'coins must be a non-negative number' });
  }
  const c = Math.min(Math.floor(coins), 999_999_999);
  const room = tradeRooms.get(code);
  if (!room) return res.status(404).json({ error: 'Room not found or expired' });
  if (!room.users.includes(uid)) return res.status(403).json({ error: 'Not a member of this room' });
  ensureRoomTradeFields(room);
  if (room.ready[uid]) {
    return res
      .status(400)
      .json({ error: 'Remove your trade confirmation before changing coins.' });
  }
  room.coins[uid] = c;
  for (const u of room.users) {
    room.ready[u] = false;
    room.finalize[u] = false;
    room.summary_choice[u] = null;
  }
  room.rev = (room.rev ?? 0) + 1;
  return res.json({ ok: true, rev: room.rev });
}

/** Viewer rates peer's card in slot_index: reaction `up` | `down` | `clear`. */
async function tradeSlotReactionHandler(req, res) {
  pruneStaleRooms();
  const code = (req.params.code ?? '').toUpperCase();
  const userId = req.body?.user_id ?? req.body?.userId;
  const slotRaw = req.body?.slot_index ?? req.body?.slotIndex;
  const rawReaction = req.body?.reaction ?? req.body?.vote;
  if (!code || userId == null || Number.isNaN(Number(userId))) {
    return res.status(400).json({ error: 'code and user_id are required' });
  }
  const uid = Number(userId);
  const slotIndex = Number(slotRaw);
  if (slotIndex !== 0 && slotIndex !== 1 && slotIndex !== 2) {
    return res.status(400).json({ error: 'slot_index must be 0, 1, or 2' });
  }
  const reaction =
    rawReaction === 'up' || rawReaction === 'down' || rawReaction === 'clear' ? rawReaction : null;
  if (reaction == null) {
    return res.status(400).json({ error: 'reaction must be up, down, or clear' });
  }
  const room = tradeRooms.get(code);
  if (!room) return res.status(404).json({ error: 'Room not found or expired' });
  if (!room.users.includes(uid)) return res.status(403).json({ error: 'Not a member of this room' });
  const peerId = room.users.find((u) => u !== uid);
  if (peerId == null) return res.status(400).json({ error: 'Waiting for second player' });
  ensureRoomTradeFields(room);
  if (room.ready[uid]) {
    return res
      .status(400)
      .json({ error: 'Remove your trade confirmation before changing reactions.' });
  }
  const arr = slotReactionArray(room, peerId, uid);
  arr[slotIndex] = reaction === 'clear' ? null : reaction;
  room.rev = (room.rev ?? 0) + 1;
  return res.json({ ok: true, rev: room.rev });
}

/** Phase 1: lock in current offer (0–3 cards). Both must do this before finalize. */
async function tradeConfirmReadyHandler(req, res) {
  pruneStaleRooms();
  const code = (req.params.code ?? '').toUpperCase();
  const userId = req.body?.user_id ?? req.body?.userId;
  if (!code || userId == null || Number.isNaN(Number(userId))) {
    return res.status(400).json({ error: 'code and user_id are required' });
  }
  const uid = Number(userId);
  const room = tradeRooms.get(code);
  if (!room) return res.status(404).json({ error: 'Room not found or expired' });
  if (room.users.length < 2) return res.status(400).json({ error: 'Waiting for second player' });
  if (!room.users.includes(uid)) return res.status(403).json({ error: 'Not a member of this room' });
  const peerId = room.users.find((u) => u !== uid);
  ensureRoomTradeFields(room);
  room.ready[uid] = true;
  for (const u of room.users) {
    room.summary_choice[u] = null;
  }
  if (!room.ready[peerId]) {
    room.rev = (room.rev ?? 0) + 1;
    return res.json({ status: 'waiting_peer_ready', rev: room.rev });
  }
  room.rev = (room.rev ?? 0) + 1;
  return res.json({ status: 'both_ready', rev: room.rev });
}

/** Clear lock-in for this user (and summary flags) so they can edit offer/coins again. */
async function tradeUnconfirmHandler(req, res) {
  pruneStaleRooms();
  const code = (req.params.code ?? '').toUpperCase();
  const userId = req.body?.user_id ?? req.body?.userId;
  if (!code || userId == null || Number.isNaN(Number(userId))) {
    return res.status(400).json({ error: 'code and user_id are required' });
  }
  const uid = Number(userId);
  const room = tradeRooms.get(code);
  if (!room) return res.status(404).json({ error: 'Room not found or expired' });
  if (!room.users.includes(uid)) return res.status(403).json({ error: 'Not a member of this room' });
  ensureRoomTradeFields(room);
  room.ready[uid] = false;
  for (const u of room.users) {
    room.summary_choice[u] = null;
    room.finalize[u] = false;
  }
  room.rev = (room.rev ?? 0) + 1;
  return res.json({ status: 'unconfirmed', rev: room.rev });
}

async function validateTradeOffersInTx(client, user, offer) {
  for (const instId of offer) {
    const { rows } = await client.query(
      `SELECT card_id FROM card_instances WHERE card_instance_id = $1::int AND user_id = $2::int`,
      [instId, user],
    );
    if (rows.length === 0) throw new Error('Invalid trade offer');
    const { rows: cr } = await client.query(
      `SELECT COUNT(*)::int AS n FROM card_instances WHERE user_id = $1::int AND card_id = $2::int`,
      [user, rows[0].card_id],
    );
    if ((cr[0]?.n ?? 0) < 2) throw new Error('Offer includes a card that is not a duplicate');
  }
}

/** Swap offered cards and transfer agreed card_coins between the two users (caller holds BEGIN). */
async function runTradeExchange(client, room) {
  const a = room.users[0];
  const b = room.users[1];
  const offerA = (room.offers[a] ?? [null, null, null]).filter((x) => x != null);
  const offerB = (room.offers[b] ?? [null, null, null]).filter((x) => x != null);
  const coinsA = Math.min(Math.max(0, Math.floor(Number(room.coins[a] ?? 0))), 999_999_999);
  const coinsB = Math.min(Math.max(0, Math.floor(Number(room.coins[b] ?? 0))), 999_999_999);

  await validateTradeOffersInTx(client, a, offerA);
  await validateTradeOffersInTx(client, b, offerB);

  const lo = a < b ? a : b;
  const hi = a < b ? b : a;
  await client.query(
    `SELECT user_id FROM users WHERE user_id IN ($1::int, $2::int) ORDER BY user_id FOR UPDATE`,
    [lo, hi],
  );

  const { rows: wA } = await client.query(
    `SELECT COALESCE(card_coins,0)::int AS c FROM users WHERE user_id = $1::int`,
    [a],
  );
  const { rows: wB } = await client.query(
    `SELECT COALESCE(card_coins,0)::int AS c FROM users WHERE user_id = $1::int`,
    [b],
  );
  if ((wA[0]?.c ?? 0) < coinsA) {
    throw new Error('One player does not have enough card coins for this trade');
  }
  if ((wB[0]?.c ?? 0) < coinsB) {
    throw new Error('One player does not have enough card coins for this trade');
  }

  for (const instId of offerA) {
    await client.query(`UPDATE card_instances SET user_id = $1::int WHERE card_instance_id = $2::int`, [
      b,
      instId,
    ]);
  }
  for (const instId of offerB) {
    await client.query(`UPDATE card_instances SET user_id = $1::int WHERE card_instance_id = $2::int`, [
      a,
      instId,
    ]);
  }
  if (coinsA > 0) {
    await client.query(`UPDATE users SET card_coins = COALESCE(card_coins,0) - $1::int WHERE user_id = $2::int`, [
      coinsA,
      a,
    ]);
    await client.query(`UPDATE users SET card_coins = COALESCE(card_coins,0) + $1::int WHERE user_id = $2::int`, [
      coinsA,
      b,
    ]);
  }
  if (coinsB > 0) {
    await client.query(`UPDATE users SET card_coins = COALESCE(card_coins,0) - $1::int WHERE user_id = $2::int`, [
      coinsB,
      b,
    ]);
    await client.query(`UPDATE users SET card_coins = COALESCE(card_coins,0) + $1::int WHERE user_id = $2::int`, [
      coinsB,
      a,
    ]);
  }
}

/** After both locked in: accept (execute when both accept) or modify (both return to trading). */
async function tradeSummaryChoiceHandler(req, res) {
  pruneStaleRooms();
  const code = (req.params.code ?? '').toUpperCase();
  const userId = req.body?.user_id ?? req.body?.userId;
  const choice = req.body?.choice;
  if (!code || userId == null || Number.isNaN(Number(userId))) {
    return res.status(400).json({ error: 'code and user_id are required' });
  }
  if (choice !== 'accept' && choice !== 'modify') {
    return res.status(400).json({ error: 'choice must be accept or modify' });
  }
  const uid = Number(userId);
  const room = tradeRooms.get(code);
  if (!room) return res.status(404).json({ error: 'Room not found or expired' });
  if (room.users.length < 2) return res.status(400).json({ error: 'Waiting for second player' });
  if (!room.users.includes(uid)) return res.status(403).json({ error: 'Not a member of this room' });
  const peerId = room.users.find((u) => u !== uid);
  ensureRoomTradeFields(room);
  if (!room.ready[uid] || !room.ready[peerId]) {
    return res.status(400).json({ error: 'Both players must confirm their offers first' });
  }

  if (choice === 'modify') {
    for (const u of room.users) {
      room.ready[u] = false;
      room.finalize[u] = false;
      room.summary_choice[u] = null;
    }
    room.rev = (room.rev ?? 0) + 1;
    return res.json({ status: 'returned_to_trading', rev: room.rev });
  }

  room.summary_choice[uid] = 'accept';
  if (room.summary_choice[peerId] !== 'accept') {
    room.rev = (room.rev ?? 0) + 1;
    return res.json({ status: 'waiting_peer_accept', rev: room.rev });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(`SELECT pg_advisory_xact_lock(abs(hashtext($1::text))::bigint)`, [`trade_room:${code}`]);
    const r = tradeRooms.get(code);
    if (!r) {
      await client.query('COMMIT');
      return res.status(404).json({ error: 'Room not found or expired' });
    }
    const u0 = r.users[0];
    const u1 = r.users[1];
    if (!r.ready[u0] || !r.ready[u1] || r.summary_choice[u0] !== 'accept' || r.summary_choice[u1] !== 'accept') {
      await client.query('COMMIT');
      r.rev = (r.rev ?? 0) + 1;
      return res.json({ status: 'waiting_peer_accept', rev: r.rev });
    }
    await runTradeExchange(client, r);
    await client.query('COMMIT');
    tradeRooms.delete(code);
    return res.json({ status: 'completed' });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error(err);
    return res.status(500).json({ error: err.message ?? String(err) });
  } finally {
    client.release();
  }
}

app.post('/trade/rooms', tradeCreateHandler);
app.post('/api/trade/rooms', tradeCreateHandler);
app.post('/trade/rooms/:code/join', tradeJoinHandler);
app.post('/api/trade/rooms/:code/join', tradeJoinHandler);
app.get('/trade/rooms/:code', tradeStateHandler);
app.get('/api/trade/rooms/:code', tradeStateHandler);
app.put('/trade/rooms/:code/offer', tradeOfferHandler);
app.put('/api/trade/rooms/:code/offer', tradeOfferHandler);
app.post('/trade/rooms/:code/leave', tradeLeaveHandler);
app.post('/api/trade/rooms/:code/leave', tradeLeaveHandler);
app.post('/trade/rooms/:code/confirm-ready', tradeConfirmReadyHandler);
app.post('/api/trade/rooms/:code/confirm-ready', tradeConfirmReadyHandler);
app.post('/trade/rooms/:code/unconfirm', tradeUnconfirmHandler);
app.post('/api/trade/rooms/:code/unconfirm', tradeUnconfirmHandler);
app.post('/trade/rooms/:code/summary-choice', tradeSummaryChoiceHandler);
app.post('/api/trade/rooms/:code/summary-choice', tradeSummaryChoiceHandler);
app.put('/trade/rooms/:code/coins', tradeCoinsHandler);
app.put('/api/trade/rooms/:code/coins', tradeCoinsHandler);
app.post('/trade/rooms/:code/slot-reaction', tradeSlotReactionHandler);
app.post('/api/trade/rooms/:code/slot-reaction', tradeSlotReactionHandler);
app.post('/trade/rooms/:code/quick-message', tradeQuickMessageHandler);
app.post('/api/trade/rooms/:code/quick-message', tradeQuickMessageHandler);

/** All [card_instance_id] rows the user may put in a trade offer (owned + that card_id is duplicated). */
async function tradeableInstancesHandler(req, res) {
  const raw = req.query.user_id ?? req.query.userId;
  if (raw == null || raw === '' || Number.isNaN(Number(raw))) {
    return res.status(400).json({ error: 'user_id query parameter is required (integer).' });
  }
  const uid = Number(raw);
  try {
    const { rows } = await pool.query(
      `
      SELECT
        ci.card_instance_id,
        ci.card_id,
        pc.card_type,
        pc.attack,
        pc.defend,
        pc.card_image,
        COALESCE(NULLIF(TRIM(p.first_name), ''), '') AS first_name,
        COALESCE(NULLIF(TRIM(p.last_name), ''), '') AS last_name,
        ROUND((pc.attack + pc.defend) / 2.0)::int AS overall
      FROM card_instances ci
      INNER JOIN play_cards pc ON pc.card_id = ci.card_id
      LEFT JOIN players p ON p.player_id = pc.player_id
      WHERE ci.user_id = $1::int
        AND ci.card_id IN (
          SELECT card_id FROM card_instances
          WHERE user_id = $1::int
          GROUP BY card_id
          HAVING COUNT(*) > 1
        )
      ORDER BY ci.card_id, ci.card_instance_id
      `,
      [uid],
    );
    res.json({ instances: rows });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

app.get('/trade/instances', tradeableInstancesHandler);
app.get('/api/trade/instances', tradeableInstancesHandler);

// --- In-memory 1v1 friend rooms (card battle) ---
const oneVOneRooms = new Map();
const OVO_MATCH_ROUNDS_TO_WIN = 2;
const OVO_PLAYS_PER_ROUND = 5;
const OVO_SQUAD_PICK_MS = 5000;
const OVO_LOCKED_SQUAD_MS = 2500;
const OVO_REVEAL_MS = 3500;

function genOneVOneCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let s = '';
  for (let i = 0; i < 6; i += 1) s += chars[Math.floor(Math.random() * chars.length)];
  if (oneVOneRooms.has(s)) return genOneVOneCode();
  return s;
}

function pruneStaleOneVOneRooms() {
  const now = Date.now();
  for (const [code, room] of oneVOneRooms) {
    if (now - room.createdAt > 60 * 60 * 1000) oneVOneRooms.delete(code);
  }
}

async function ovoUserHasThreeFullSquads(client, userId) {
  for (let sn = 1; sn <= 3; sn += 1) {
    const row = await loadCardsSquadRow(client, userId, sn);
    if (!row) return false;
    for (const k of ['pg', 'sg', 'sf', 'pf', 'c']) {
      if (squadSlotFromRow(row, k) <= 0) return false;
    }
  }
  return true;
}

async function ovoPickRandomSquadNumber(client, userId, excludedSquads = []) {
  const ex = new Set((excludedSquads ?? []).map((n) => Number(n)).filter((n) => n >= 1 && n <= 3));
  const valid = [];
  for (let sn = 1; sn <= 3; sn += 1) {
    if (ex.has(sn)) continue;
    const row = await loadCardsSquadRow(client, userId, sn);
    if (!row) continue;
    let ok = true;
    for (const k of ['pg', 'sg', 'sf', 'pf', 'c']) {
      if (squadSlotFromRow(row, k) <= 0) ok = false;
    }
    if (ok) valid.push(sn);
  }
  if (valid.length === 0) return 1;
  return valid[Math.floor(Math.random() * valid.length)];
}

async function ovoBuildSquadSnapshot(client, userId, squadNumber) {
  const row = await loadCardsSquadRow(client, userId, squadNumber);
  if (!row) return null;
  const ids = ['pg', 'sg', 'sf', 'pf', 'c'].map((k) => squadSlotFromRow(row, k)).filter((id) => id > 0);
  if (ids.length !== 5) return null;
  const sm = await fetchPlayCardSummariesForSquad(client, ids);
  const payload = buildCardsSquadPayload(row, sm);
  return { squad_number: squadNumber, squad: payload };
}

function ovoInitRound(room, roundFirstUid) {
  room.round_first_actor = roundFirstUid;
  room.subround_first_actor = roundFirstUid;
  room.round_play_wins = {};
  for (const u of room.users) room.round_play_wins[u] = 0;
  room.used_slots = {};
  for (const u of room.users) room.used_slots[u] = [];
  room.plays_completed_this_round = 0;
  room.last_non_tie_winner = null;
  room.battle_step = 'lead';
  room.lead_pending = null;
  room.response_pending = null;
  room.reveal = null;
  room.reveal_deadline = null;
}

function ovoPeer(room, uid) {
  return room.users.find((u) => u !== uid) ?? null;
}

async function ovoTryStartSquadPick(client, room) {
  if (room.users.length < 2) return;
  const [a, b] = room.users;
  const okA = await ovoUserHasThreeFullSquads(client, a);
  const okB = await ovoUserHasThreeFullSquads(client, b);
  if (!okA || !okB) {
    room.phase = 'need_squads';
    room.squad_ready = { [a]: okA, [b]: okB };
    room.squad_pick_deadline = null;
    return;
  }
  room.phase = 'pick_squad';
  room.squad_ready = { [a]: true, [b]: true };
  room.squad_pick = { [a]: null, [b]: null };
  room.squad_pick_deadline = Date.now() + OVO_SQUAD_PICK_MS;
  if (!room.squads_used_per_user) room.squads_used_per_user = {};
  if (!room.squads_used_per_user[a]) room.squads_used_per_user[a] = [];
  if (!room.squads_used_per_user[b]) room.squads_used_per_user[b] = [];
}

async function ovoMaybePromoteFromNeedSquads(client, room) {
  if (room.phase !== 'need_squads' || room.users.length < 2) return;
  await ovoTryStartSquadPick(client, room);
}

async function ovoFinalizeSquadPickPhase(client, room, now) {
  if (room.phase !== 'pick_squad') return;
  const [a, b] = room.users;
  const deadlineHit = room.squad_pick_deadline != null && now >= room.squad_pick_deadline;
  const bothChosen = room.squad_pick[a] != null && room.squad_pick[b] != null;
  if (!bothChosen && !deadlineHit) return;
  if (!bothChosen && deadlineHit) {
    if (room.squad_pick[a] == null) {
      room.squad_pick[a] = await ovoPickRandomSquadNumber(client, a, room.squads_used_per_user?.[a] ?? []);
    }
    if (room.squad_pick[b] == null) {
      room.squad_pick[b] = await ovoPickRandomSquadNumber(client, b, room.squads_used_per_user?.[b] ?? []);
    }
  }
  const snapA = await ovoBuildSquadSnapshot(client, a, room.squad_pick[a]);
  const snapB = await ovoBuildSquadSnapshot(client, b, room.squad_pick[b]);
  if (!snapA || !snapB) {
    room.phase = 'need_squads';
    return;
  }
  room.squad_snapshots = { [a]: snapA, [b]: snapB };
  room.phase = 'locked_squad';
  room.locked_squad_deadline = now + OVO_LOCKED_SQUAD_MS;
}

function ovoStartBattleFromLocked(room, now) {
  if (room.phase !== 'locked_squad') return;
  if (room.locked_squad_deadline == null || now < room.locked_squad_deadline) return;
  room.phase = 'battle';
  if (!room.match_round_wins) {
    room.match_round_wins = {};
    for (const u of room.users) room.match_round_wins[u] = 0;
  }
  if (room.round_index == null || room.round_index < 1) room.round_index = 1;
  room.battle_session_count = (room.battle_session_count ?? 0) + 1;
  const [u0, u1] = room.users;
  if (room.battle_session_count === 1) {
    const rnd = Math.random() < 0.5 ? u0 : u1;
    room.round_first_actor = rnd;
    ovoInitRound(room, rnd);
  } else {
    const wl = room.prev_round_winner ?? u0;
    room.round_first_actor = wl;
    ovoInitRound(room, wl);
  }
}

function ovoScoreSubround(leadMode, leadAtk, leadDef, respAtk, respDef) {
  if (leadMode === 'attack') {
    return { lead_score: leadAtk, resp_score: respDef };
  }
  return { lead_score: leadDef, resp_score: respAtk };
}

function ovoApplyReveal(room) {
  const rev = room.reveal;
  if (!rev) return;
  const leadUid = rev.lead_uid;
  const respUid = rev.respond_uid;
  const leadSlot = rev.lead_slot;
  const respSlot = rev.respond_slot;
  if (!room.used_slots) room.used_slots = {};
  if (!room.used_slots[leadUid]) room.used_slots[leadUid] = [];
  if (!room.used_slots[respUid]) room.used_slots[respUid] = [];
  if (leadSlot && !room.used_slots[leadUid].includes(leadSlot)) room.used_slots[leadUid].push(leadSlot);
  if (respSlot && !room.used_slots[respUid].includes(respSlot)) room.used_slots[respUid].push(respSlot);
  room.plays_completed_this_round = (room.plays_completed_this_round ?? 0) + 1;

  const { winner_uid, tie } = rev;
  if (!tie && winner_uid != null) {
    room.round_play_wins[winner_uid] = (room.round_play_wins[winner_uid] ?? 0) + 1;
    room.subround_first_actor = winner_uid;
    room.last_non_tie_winner = winner_uid;
  }

  const [a, b] = room.users;
  const wa = room.round_play_wins[a] ?? 0;
  const wb = room.round_play_wins[b] ?? 0;
  const playsDone = room.plays_completed_this_round ?? 0;

  if (playsDone >= OVO_PLAYS_PER_ROUND) {
    let roundWinner = null;
    if (wa > wb) roundWinner = a;
    else if (wb > wa) roundWinner = b;
    else roundWinner = room.last_non_tie_winner ?? a;

    room.match_round_wins[roundWinner] = (room.match_round_wins[roundWinner] ?? 0) + 1;
    room.prev_round_winner = roundWinner;
    const ma = room.match_round_wins[a] ?? 0;
    const mb = room.match_round_wins[b] ?? 0;
    if (ma >= OVO_MATCH_ROUNDS_TO_WIN || mb >= OVO_MATCH_ROUNDS_TO_WIN) {
      room.phase = 'match_over';
      room.match_winner = ma >= OVO_MATCH_ROUNDS_TO_WIN ? a : b;
      room.battle_step = 'done';
      room.reveal = null;
      room.reveal_deadline = null;
      return;
    }
    if (!room.squads_used_per_user) room.squads_used_per_user = {};
    for (const u of room.users) {
      const sn = room.squad_snapshots?.[u]?.squad_number;
      if (sn != null) {
        if (!room.squads_used_per_user[u]) room.squads_used_per_user[u] = [];
        room.squads_used_per_user[u].push(Number(sn));
      }
    }
    room.round_index = (room.round_index ?? 1) + 1;
    room.phase = 'pick_squad';
    room.squad_pick = { [a]: null, [b]: null };
    room.squad_pick_deadline = Date.now() + OVO_SQUAD_PICK_MS;
    room.squad_snapshots = null;
    room.locked_squad_deadline = null;
    room.battle_step = 'idle';
    room.round_play_wins = null;
    room.used_slots = null;
    room.plays_completed_this_round = null;
    room.reveal = null;
    room.reveal_deadline = null;
    room.lead_pending = null;
    room.response_pending = null;
    return;
  }
  room.battle_step = 'lead';
  room.lead_pending = null;
  room.response_pending = null;
  room.reveal = null;
  room.reveal_deadline = null;
}

function ovoMaybeExpireReveal(room, now) {
  if (room.phase !== 'battle' || room.battle_step !== 'reveal') return;
  if (room.reveal_deadline == null || now < room.reveal_deadline) return;
  ovoApplyReveal(room);
}

async function ovoAdvanceRoom(client, room, now) {
  await ovoMaybePromoteFromNeedSquads(client, room);
  if (room.phase === 'pick_squad') {
    await ovoFinalizeSquadPickPhase(client, room, now);
  }
  if (room.phase === 'locked_squad') {
    ovoStartBattleFromLocked(room, now);
  }
  ovoMaybeExpireReveal(room, now);
}

function ovoSlotPositionFromSnapshot(snap, slotKey) {
  const slots = snap?.squad?.slots ?? {};
  const s = slots[slotKey];
  return s?.position != null ? String(s.position) : slotKey.toUpperCase();
}

async function oneVOneCreateHandler(req, res) {
  pruneStaleOneVOneRooms();
  const userId = req.body?.user_id ?? req.body?.userId;
  if (userId == null || Number.isNaN(Number(userId))) {
    return res.status(400).json({ error: 'user_id is required' });
  }
  const uid = Number(userId);
  const { rows } = await pool.query(`SELECT username FROM users WHERE user_id = $1::int`, [uid]);
  if (rows.length === 0) return res.status(400).json({ error: 'User not found' });
  const code = genOneVOneCode();
  oneVOneRooms.set(code, {
    code,
    createdAt: Date.now(),
    users: [uid],
    usernames: { [uid]: rows[0].username },
    phase: 'lobby',
    squad_pick: {},
    squad_snapshots: null,
    match_winner: null,
    squads_used_per_user: { [uid]: [] },
  });
  res.status(201).json({ code, host: true });
}

async function oneVOneJoinHandler(req, res) {
  pruneStaleOneVOneRooms();
  const code = (req.params.code ?? '').toUpperCase();
  const userId = req.body?.user_id ?? req.body?.userId;
  if (!code || userId == null || Number.isNaN(Number(userId))) {
    return res.status(400).json({ error: 'code and user_id are required' });
  }
  const uid = Number(userId);
  const room = oneVOneRooms.get(code);
  if (!room) return res.status(404).json({ error: 'Room not found or expired' });
  if (room.users.includes(uid)) {
    return res.json({ code, joined: true, peer: room.users.find((u) => u !== uid) ?? null });
  }
  if (room.users.length >= 2) return res.status(409).json({ error: 'Room is full' });
  const { rows } = await pool.query(`SELECT username FROM users WHERE user_id = $1::int`, [uid]);
  if (rows.length === 0) return res.status(400).json({ error: 'User not found' });
  room.users.push(uid);
  room.usernames[uid] = rows[0].username;
  if (!room.squads_used_per_user) room.squads_used_per_user = {};
  for (const u of room.users) {
    room.squads_used_per_user[u] = room.squads_used_per_user[u] ?? [];
  }
  const client = await pool.connect();
  try {
    await ovoTryStartSquadPick(client, room);
  } finally {
    client.release();
  }
  res.json({ code, joined: true, peer: room.users[0] });
}

async function oneVOneLeaveHandler(req, res) {
  pruneStaleOneVOneRooms();
  const code = (req.params.code ?? '').toUpperCase();
  const userId = req.body?.user_id ?? req.body?.userId;
  if (!code || userId == null || Number.isNaN(Number(userId))) {
    return res.status(400).json({ error: 'code and user_id are required' });
  }
  const uid = Number(userId);
  const room = oneVOneRooms.get(code);
  if (!room) return res.status(404).json({ error: 'Room not found' });
  room.users = room.users.filter((u) => u !== uid);
  if (room.users.length === 0) oneVOneRooms.delete(code);
  res.json({ left: true });
}

async function oneVOneSquadPickHandler(req, res) {
  pruneStaleOneVOneRooms();
  const code = (req.params.code ?? '').toUpperCase();
  const userId = req.body?.user_id ?? req.body?.userId;
  const rawSq = req.body?.squad_number ?? req.body?.squadNumber;
  if (!code || userId == null || Number.isNaN(Number(userId))) {
    return res.status(400).json({ error: 'code and user_id are required' });
  }
  const uid = Number(userId);
  const sn = parseCardsSquadNumber(rawSq);
  if (sn == null) return res.status(400).json({ error: 'squad_number must be 1, 2, or 3' });
  const room = oneVOneRooms.get(code);
  if (!room) return res.status(404).json({ error: 'Room not found' });
  if (!room.users.includes(uid)) return res.status(403).json({ error: 'Not a member' });
  if (room.phase !== 'pick_squad') return res.status(400).json({ error: 'Not in squad pick phase' });
  const client = await pool.connect();
  try {
    const used = room.squads_used_per_user?.[uid] ?? [];
    if (used.includes(sn)) {
      return res.status(400).json({ error: 'You already used this squad earlier in the match. Pick another.' });
    }
    const row = await loadCardsSquadRow(client, uid, sn);
    if (!row) return res.status(400).json({ error: 'Squad not found' });
    for (const k of ['pg', 'sg', 'sf', 'pf', 'c']) {
      if (squadSlotFromRow(row, k) <= 0) return res.status(400).json({ error: 'Squad must be complete' });
    }
    room.squad_pick[uid] = sn;
    await ovoFinalizeSquadPickPhase(client, room, Date.now());
  } finally {
    client.release();
  }
  res.json({ ok: true });
}

async function oneVOneLeadHandler(req, res) {
  pruneStaleOneVOneRooms();
  const code = (req.params.code ?? '').toUpperCase();
  const userId = req.body?.user_id ?? req.body?.userId;
  const slot = (req.body?.slot ?? '').toString().trim().toLowerCase();
  const mode = (req.body?.mode ?? '').toString().trim().toLowerCase();
  if (!code || userId == null || Number.isNaN(Number(userId))) {
    return res.status(400).json({ error: 'code and user_id are required' });
  }
  if (!['pg', 'sg', 'sf', 'pf', 'c'].includes(slot)) return res.status(400).json({ error: 'Invalid slot' });
  if (mode !== 'attack' && mode !== 'defend') return res.status(400).json({ error: 'mode must be attack or defend' });
  const uid = Number(userId);
  const room = oneVOneRooms.get(code);
  if (!room) return res.status(404).json({ error: 'Room not found' });
  if (room.phase !== 'battle' || room.battle_step !== 'lead') {
    return res.status(400).json({ error: 'Not your turn to lead' });
  }
  if (room.subround_first_actor !== uid) return res.status(400).json({ error: 'Not your turn to lead' });
  const snap = room.squad_snapshots?.[uid];
  if (!snap?.squad?.slots?.[slot]) return res.status(400).json({ error: 'Invalid squad state' });
  const card = snap.squad.slots[slot];
  if (!card?.card_id || card.card_id <= 0) return res.status(400).json({ error: 'Empty slot' });
  const used = room.used_slots?.[uid] ?? [];
  if (used.includes(slot)) return res.status(400).json({ error: 'This player was already used this round' });
  room.lead_pending = { uid, slot, mode };
  room.battle_step = 'respond';
  res.json({ ok: true });
}

async function oneVOneRespondHandler(req, res) {
  pruneStaleOneVOneRooms();
  const code = (req.params.code ?? '').toUpperCase();
  const userId = req.body?.user_id ?? req.body?.userId;
  const slot = (req.body?.slot ?? '').toString().trim().toLowerCase();
  if (!code || userId == null || Number.isNaN(Number(userId))) {
    return res.status(400).json({ error: 'code and user_id are required' });
  }
  if (!['pg', 'sg', 'sf', 'pf', 'c'].includes(slot)) return res.status(400).json({ error: 'Invalid slot' });
  const uid = Number(userId);
  const room = oneVOneRooms.get(code);
  if (!room) return res.status(404).json({ error: 'Room not found' });
  if (room.phase !== 'battle' || room.battle_step !== 'respond') {
    return res.status(400).json({ error: 'Cannot respond now' });
  }
  const lead = room.lead_pending;
  if (!lead || lead.uid === uid) return res.status(400).json({ error: 'Invalid respond turn' });
  const peer = ovoPeer(room, lead.uid);
  if (peer !== uid) return res.status(403).json({ error: 'Not your turn to respond' });
  const needMode = lead.mode === 'attack' ? 'defend' : 'attack';
  const snap = room.squad_snapshots?.[uid];
  if (!snap?.squad?.slots?.[slot]) return res.status(400).json({ error: 'Invalid squad state' });
  const respCard = snap.squad.slots[slot];
  if (!respCard?.card_id || respCard.card_id <= 0) return res.status(400).json({ error: 'Empty slot' });
  const usedR = room.used_slots?.[uid] ?? [];
  if (usedR.includes(slot)) return res.status(400).json({ error: 'This player was already used this round' });
  const leadSnap = room.squad_snapshots[lead.uid];
  const leadCard = leadSnap.squad.slots[lead.slot];
  const leadAtk = Number(leadCard.attack ?? 0);
  const leadDef = Number(leadCard.defend ?? 0);
  const respAtk = Number(respCard.attack ?? 0);
  const respDef = Number(respCard.defend ?? 0);
  const scores = ovoScoreSubround(lead.mode, leadAtk, leadDef, respAtk, respDef);
  let winner_uid = null;
  let tie = false;
  if (scores.lead_score > scores.resp_score) winner_uid = lead.uid;
  else if (scores.resp_score > scores.lead_score) winner_uid = uid;
  else tie = true;
  room.response_pending = { uid, slot, implicit_mode: needMode };
  room.reveal = {
    lead_uid: lead.uid,
    respond_uid: uid,
    lead_slot: lead.slot,
    respond_slot: slot,
    lead_mode: lead.mode,
    respond_mode: needMode,
    lead_card_id: leadCard.card_id,
    respond_card_id: respCard.card_id,
    lead_score: scores.lead_score,
    respond_score: scores.resp_score,
    winner_uid,
    tie,
    lead_label: `${leadCard.first_name ?? ''} ${leadCard.last_name ?? ''}`.trim(),
    respond_label: `${respCard.first_name ?? ''} ${respCard.last_name ?? ''}`.trim(),
  };
  room.battle_step = 'reveal';
  room.reveal_deadline = Date.now() + OVO_REVEAL_MS;
  room.lead_pending = null;
  res.json({ ok: true });
}

async function oneVOneStateHandler(req, res) {
  pruneStaleOneVOneRooms();
  const code = (req.params.code ?? '').toUpperCase();
  const raw = req.query.user_id ?? req.query.userId;
  if (!code || raw == null || Number.isNaN(Number(raw))) {
    return res.status(400).json({ error: 'code and user_id are required' });
  }
  const userId = Number(raw);
  const room = oneVOneRooms.get(code);
  if (!room) return res.status(404).json({ error: 'Room not found or expired' });
  if (!room.users.includes(userId)) return res.status(403).json({ error: 'Not a member of this room' });
  const client = await pool.connect();
  try {
    const now = Date.now();
    await ovoAdvanceRoom(client, room, now);
    const peerId = room.users.find((u) => u !== userId) ?? null;
    const out = {
      code: room.code,
      phase: room.phase,
      usernames: room.usernames,
      peer_user_id: peerId,
      squad_pick_deadline: room.squad_pick_deadline ?? null,
      squad_pick: room.squad_pick ?? {},
      squad_ready: room.squad_ready ?? null,
      my_squad_number: room.squad_pick?.[userId] ?? null,
      my_squad: room.squad_snapshots?.[userId] ?? null,
      match_round_wins: room.match_round_wins ?? null,
      round_play_wins: room.round_play_wins ?? null,
      round_index: room.round_index ?? null,
      plays_per_round: OVO_PLAYS_PER_ROUND,
      plays_completed_this_round: room.plays_completed_this_round ?? null,
      my_used_slots: room.used_slots?.[userId] ?? [],
      squads_used_my: room.squads_used_per_user?.[userId] ?? [],
      battle_step: room.battle_step ?? null,
      subround_first_actor: room.subround_first_actor ?? null,
      round_first_actor: room.round_first_actor ?? null,
      match_winner: room.match_winner ?? null,
      reveal: room.reveal,
      reveal_deadline: room.reveal_deadline ?? null,
    };
    if (room.phase === 'battle') {
      out.is_my_lead_turn = room.battle_step === 'lead' && room.subround_first_actor === userId;
      const lp = room.lead_pending;
      out.is_my_respond_turn = room.battle_step === 'respond' && lp != null && lp.uid !== userId;
      if (room.battle_step === 'respond' && lp && lp.uid !== userId) {
        const snapLead = room.squad_snapshots?.[lp.uid];
        const pos = ovoSlotPositionFromSnapshot(snapLead, lp.slot);
        out.opponent_action_hint = { mode: lp.mode, position: pos };
      } else {
        out.opponent_action_hint = null;
      }
      out.waiting_opponent_lead = room.battle_step === 'lead' && room.subround_first_actor !== userId;
      out.waiting_opponent_respond = room.battle_step === 'respond' && lp != null && lp.uid === userId;
    }
    res.json(out);
  } finally {
    client.release();
  }
}

app.post('/cards/one-v-one/rooms', oneVOneCreateHandler);
app.post('/api/cards/one-v-one/rooms', oneVOneCreateHandler);
app.post('/cards/one-v-one/rooms/:code/join', oneVOneJoinHandler);
app.post('/api/cards/one-v-one/rooms/:code/join', oneVOneJoinHandler);
app.get('/cards/one-v-one/rooms/:code', oneVOneStateHandler);
app.get('/api/cards/one-v-one/rooms/:code', oneVOneStateHandler);
app.post('/cards/one-v-one/rooms/:code/leave', oneVOneLeaveHandler);
app.post('/api/cards/one-v-one/rooms/:code/leave', oneVOneLeaveHandler);
app.post('/cards/one-v-one/rooms/:code/squad-pick', oneVOneSquadPickHandler);
app.post('/api/cards/one-v-one/rooms/:code/squad-pick', oneVOneSquadPickHandler);
app.post('/cards/one-v-one/rooms/:code/lead', oneVOneLeadHandler);
app.post('/api/cards/one-v-one/rooms/:code/lead', oneVOneLeadHandler);
app.post('/cards/one-v-one/rooms/:code/respond', oneVOneRespondHandler);
app.post('/api/cards/one-v-one/rooms/:code/respond', oneVOneRespondHandler);

/** --- Public court reservation (no owner credentials exposed) --- */

async function listPublicCourtsHandler(req, res) {
  const search = (req.query.search ?? req.query.q ?? '').trim();
  try {
    const has = search.length > 0;
    const sql = `
      SELECT court_id, court_name, location, phone_number, logo_url
      FROM courts
      ${has ? 'WHERE court_name ILIKE $1 OR location ILIKE $1' : ''}
      ORDER BY court_name ASC
    `;
    const params = has ? [`%${search}%`] : [];
    const { rows } = await pool.query(sql, params);
    res.json({ courts: rows });
  } catch (err) {
    if (err.code === '42P01') {
      return res.status(503).json({
        error: 'Court tables are missing. Apply lebanon_hoops/DB/court_reservation_schema.sql to your database.',
      });
    }
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

async function getPublicCourtPlaygroundsHandler(req, res) {
  const courtId = Number(req.params.id);
  if (Number.isNaN(courtId)) {
    return res.status(400).json({ error: 'court id must be an integer.' });
  }
  try {
    const { rows: courtRows } = await pool.query(
      `SELECT court_id, court_name, location, phone_number, logo_url
       FROM courts WHERE court_id = $1`,
      [courtId],
    );
    if (courtRows.length === 0) {
      return res.status(404).json({ error: 'Court not found' });
    }
    const { rows: pgRows } = await pool.query(
      `
      SELECT
        p.playground_id,
        p.court_id,
        p.playground_name,
        p.price_per_hour::float8 AS price_per_hour,
        p.is_active,
        p.can_half_court,
        COALESCE(
          json_agg(pp.photo_url ORDER BY pp.photo_id)
            FILTER (WHERE pp.photo_id IS NOT NULL),
          '[]'::json
        ) AS photo_urls
      FROM playgrounds p
      LEFT JOIN playground_photos pp ON pp.playground_id = p.playground_id
      WHERE p.court_id = $1::int
      GROUP BY p.playground_id, p.court_id, p.playground_name, p.price_per_hour, p.is_active, p.can_half_court
      ORDER BY p.playground_name ASC
      `,
      [courtId],
    );
    const playgrounds = pgRows.map((r) => ({
      ...r,
      photo_urls: Array.isArray(r.photo_urls) ? r.photo_urls : JSON.parse(String(r.photo_urls ?? '[]')),
    }));
    res.json({ court: courtRows[0], playgrounds });
  } catch (err) {
    if (err.code === '42P01') {
      return res.status(503).json({
        error: 'Court tables are missing. Apply lebanon_hoops/DB/court_reservation_schema.sql to your database.',
      });
    }
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

async function getPublicPlaygroundAvailabilityHandler(req, res) {
  const playgroundId = Number(req.params.id);
  const dateStr = String(req.query.date ?? '').trim();
  if (Number.isNaN(playgroundId)) {
    return res.status(400).json({ error: 'playground id must be an integer.' });
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(dateStr)) {
    return res.status(400).json({ error: 'Query ?date=YYYY-MM-DD is required.' });
  }
  try {
    const { rows } = await pool.query(
      `
      SELECT
        a.availability_id,
        a.available_date::text AS available_date,
        to_char(a.start_time, 'HH24:MI') AS start_time,
        to_char(a.end_time, 'HH24:MI') AS end_time,
        a.is_available,
        (r.reservation_id IS NOT NULL) AS is_booked
      FROM playground_availability a
      LEFT JOIN reservations r ON r.availability_id = a.availability_id
      WHERE a.playground_id = $1::int
        AND a.available_date = $2::date
      ORDER BY a.start_time ASC
      `,
      [playgroundId, dateStr],
    );
    res.json({ slots: rows });
  } catch (err) {
    if (err.code === '42P01') {
      return res.status(503).json({
        error: 'Court tables are missing. Apply lebanon_hoops/DB/court_reservation_schema.sql to your database.',
      });
    }
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

async function postPublicReservationHandler(req, res) {
  const userId = Number(req.body?.user_id ?? req.body?.userId);
  const availabilityId = Number(req.body?.availability_id ?? req.body?.availabilityId);
  if (Number.isNaN(userId) || Number.isNaN(availabilityId)) {
    return res.status(400).json({ error: 'user_id and availability_id are required integers.' });
  }
  try {
    const { rows: ok } = await pool.query(
      `
      SELECT a.availability_id
      FROM playground_availability a
      WHERE a.availability_id = $1::int
        AND a.is_available = TRUE
        AND NOT EXISTS (
          SELECT 1 FROM reservations r WHERE r.availability_id = a.availability_id
        )
      `,
      [availabilityId],
    );
    if (ok.length === 0) {
      return res.status(409).json({ error: 'That slot is not available to book.' });
    }
    const { rows } = await pool.query(
      `
      INSERT INTO reservations (user_id, availability_id)
      VALUES ($1::int, $2::int)
      RETURNING reservation_id, reservation_date, status
      `,
      [userId, availabilityId],
    );
    res.status(201).json({ reservation: rows[0] });
  } catch (err) {
    if (err.code === '23505') {
      return res.status(409).json({ error: 'This time slot was just booked. Pick another.' });
    }
    if (err.code === '23503') {
      return res.status(400).json({ error: 'Invalid user_id or availability_id.' });
    }
    if (err.code === '42P01') {
      return res.status(503).json({
        error: 'Court tables are missing. Apply lebanon_hoops/DB/court_reservation_schema.sql to your database.',
      });
    }
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

app.get('/public/courts', listPublicCourtsHandler);
app.get('/api/public/courts', listPublicCourtsHandler);
app.get('/public/courts/:id/playgrounds', getPublicCourtPlaygroundsHandler);
app.get('/api/public/courts/:id/playgrounds', getPublicCourtPlaygroundsHandler);
app.get('/public/playgrounds/:id/availability', getPublicPlaygroundAvailabilityHandler);
app.get('/api/public/playgrounds/:id/availability', getPublicPlaygroundAvailabilityHandler);
app.post('/public/reservations', postPublicReservationHandler);
app.post('/api/public/reservations', postPublicReservationHandler);

// ─────────────────────────────────────────────────────────────────────────────
// FLB Game routes
// ─────────────────────────────────────────────────────────────────────────────

/** `games` row shape with home/away logos taken from `teams` when set (else `games.*` logos). */
const GAME_ROW_SELECT_WITH_TEAM_LOGOS = `
  g.match_id,
  g.competition_id,
  g.status,
  g.raw_status,
  g.date_time_text,
  g.venue,
  g.venue_id,
  g.home_team_id,
  g.home_team_name,
  COALESCE(NULLIF(TRIM(th.team_logo), ''), g.home_team_logo) AS home_team_logo,
  g.away_team_id,
  g.away_team_name,
  COALESCE(NULLIF(TRIM(ta.team_logo), ''), g.away_team_logo) AS away_team_logo,
  g.home_score,
  g.away_score,
  g.summary_url,
  g.boxscore_url,
  g.playbyplay_url,
  g.shotchart_url,
  g.week,
  g.updated_at
`;

const GAME_ROW_FROM_WITH_TEAM_LOGOS = `
  FROM games g
  LEFT JOIN teams th ON th.team_id = g.home_team_id
  LEFT JOIN teams ta ON ta.team_id = g.away_team_id
`;

/** GET /games  — optional ?competition_id=… & ?week=… & ?team_id=… (integer). Upcoming + live + recent finals ordered by date */
async function listGamesHandler(req, res) {
  try {
    const rawComp = req.query.competition_id ?? req.query.competitionId;
    const compId = rawComp != null && rawComp !== '' ? Number(rawComp) : null;
    const rawWeek = req.query.week;
    const weekNum = rawWeek != null && rawWeek !== '' ? Number(rawWeek) : null;
    const rawTeam = req.query.team_id ?? req.query.teamId;
    const teamId = rawTeam != null && rawTeam !== '' ? Number(rawTeam) : null;
    const params = [];
    let compClause = '';
    if (compId != null && !Number.isNaN(compId)) {
      params.push(compId);
      compClause = `AND g.competition_id = $${params.length}`;
    }
    let weekClause = '';
    if (weekNum != null && !Number.isNaN(weekNum)) {
      params.push(weekNum);
      weekClause = `AND g.week = $${params.length}`;
    }
    let teamClause = '';
    if (teamId != null && !Number.isNaN(teamId)) {
      params.push(teamId);
      const i = params.length;
      teamClause = `AND (g.home_team_id = $${i}::bigint OR g.away_team_id = $${i}::bigint)`;
    }
    const { rows } = await pool.query(
      `
      SELECT ${GAME_ROW_SELECT_WITH_TEAM_LOGOS}
      ${GAME_ROW_FROM_WITH_TEAM_LOGOS}
      WHERE g.status IN ('live', 'scheduled', 'postponed', 'final')
      ${compClause}
      ${weekClause}
      ${teamClause}
      ORDER BY
        CASE g.status WHEN 'live' THEN 0 WHEN 'scheduled' THEN 1 WHEN 'postponed' THEN 2 ELSE 3 END,
        g.updated_at DESC
      LIMIT 200
    `,
      params,
    );
    res.json(rows);
  } catch (err) {
    console.error('[GET /games]', err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

/** GET /games/weeks?competition_id=… — distinct `games.week` values for swipe UI */
async function listGameWeeksHandler(req, res) {
  try {
    const rawComp = req.query.competition_id ?? req.query.competitionId;
    const compId = rawComp != null && rawComp !== '' ? Number(rawComp) : null;
    if (compId == null || Number.isNaN(compId)) {
      return res.status(400).json({ error: 'competition_id is required' });
    }
    const { rows } = await pool.query(
      `
      SELECT DISTINCT week
      FROM games
      WHERE competition_id = $1
        AND week IS NOT NULL
        AND status IN ('live', 'scheduled', 'final')
      ORDER BY week ASC
    `,
      [compId],
    );
    const weeks = rows
      .map((r) => Number(r.week))
      .filter((n) => Number.isFinite(n));
    res.json({ weeks });
  } catch (err) {
    console.error('[GET /games/weeks]', err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

app.get('/games', listGamesHandler);
app.get('/api/games', listGamesHandler);
app.get('/games/weeks', listGameWeeksHandler);
app.get('/api/games/weeks', listGameWeeksHandler);

/** GET /games/team-stats?competition_id=… — per-team sums: GP = every final/live game; missing box score = 0 for that game. */
function _parseTotalsJson(raw) {
  if (raw == null) return {};
  if (typeof raw === 'object' && !Array.isArray(raw)) return raw;
  if (typeof raw === 'string') {
    try {
      const o = JSON.parse(raw);
      return typeof o === 'object' && o != null && !Array.isArray(o) ? o : {};
    } catch {
      return {};
    }
  }
  return {};
}

function _totalsNum(totals, keys) {
  for (const k of keys) {
    if (Object.prototype.hasOwnProperty.call(totals, k)) {
      const v = totals[k];
      if (v != null && String(v).trim() !== '') {
        const n = Number(String(v).replace(/[^\d.-]/g, ''));
        if (Number.isFinite(n)) return Math.round(n);
      }
    }
  }
  const lowerMap = {};
  for (const [k, v] of Object.entries(totals)) {
    lowerMap[k.toLowerCase()] = v;
  }
  for (const k of keys) {
    const v = lowerMap[k.toLowerCase()];
    if (v != null && String(v).trim() !== '') {
      const n = Number(String(v).replace(/[^\d.-]/g, ''));
      if (Number.isFinite(n)) return Math.round(n);
    }
  }
  return 0;
}

function _accumulateTotalsFromBox(row, totalsRaw) {
  const t = _parseTotalsJson(totalsRaw);
  row.pts += _totalsNum(t, ['Pts', 'PTS', 'pts', 'Points']);
  row.reb += _totalsNum(t, ['REB', 'Reb', 'reb', 'TRB']);
  row.ast += _totalsNum(t, ['AST', 'Ast', 'ast']);
  row.fgm += _totalsNum(t, ['FGM', 'Fgm', 'fgm']);
  row.fga += _totalsNum(t, ['FGA', 'Fga', 'fga']);
  row.three_pm += _totalsNum(t, ['3PM', '3pm', 'TPM']);
  row.three_pa += _totalsNum(t, ['3PA', '3pa', 'TPA']);
  row.ftm += _totalsNum(t, ['FTM', 'Ftm', 'ftm']);
  row.fta += _totalsNum(t, ['FTA', 'Fta', 'fta']);
  row.oreb += _totalsNum(t, ['OREB', 'ORB', 'OFF', 'Off', 'oreb', 'orb']);
  row.dreb += _totalsNum(t, ['DREB', 'DRB', 'DEF', 'Def', 'dreb', 'drb']);
  row.stl += _totalsNum(t, ['STL', 'Stl', 'stl']);
  row.blk += _totalsNum(t, ['BLK', 'Blk', 'blk']);
}

async function listTeamStatsHandler(req, res) {
  try {
    const rawComp = req.query.competition_id ?? req.query.competitionId;
    const compId = rawComp != null && rawComp !== '' ? Number(rawComp) : null;
    if (compId == null || Number.isNaN(compId)) {
      return res.status(400).json({ error: 'competition_id is required' });
    }

    const [teamsRes, gamesRes, boxRes] = await Promise.all([
      pool.query(
        `SELECT t.team_id,
                t.team_name,
                NULLIF(TRIM(t.team_logo), '') AS team_logo
         FROM teams t
         INNER JOIN competition_teams ct ON ct.team_id = t.team_id
         WHERE ct.competition_id = $1::int
         ORDER BY t.team_name ASC`,
        [compId],
      ),
      pool.query(
        `SELECT g.match_id, g.home_team_id, g.away_team_id
         FROM games g
         WHERE g.competition_id = $1::int
           AND g.status IN ('final', 'live')
           AND g.home_team_id IS NOT NULL
           AND g.away_team_id IS NOT NULL`,
        [compId],
      ),
      pool.query(
        `SELECT tb.match_id, tb.team_id, tb.totals
         FROM team_boxscores tb
         INNER JOIN games g ON g.match_id = tb.match_id
         WHERE g.competition_id = $1::int
           AND g.status IN ('final', 'live')
           AND tb.team_id IS NOT NULL`,
        [compId],
      ),
    ]);

    const empty = () => ({
      team_id: null,
      team_name: '',
      team_logo: null,
      gp: 0,
      pts: 0,
      reb: 0,
      ast: 0,
      fgm: 0,
      fga: 0,
      three_pm: 0,
      three_pa: 0,
      ftm: 0,
      fta: 0,
      oreb: 0,
      dreb: 0,
      stl: 0,
      blk: 0,
    });

    const byId = new Map();
    for (const r of teamsRes.rows ?? []) {
      const id = Number(r.team_id);
      if (Number.isNaN(id)) continue;
      const row = empty();
      row.team_id = id;
      row.team_name = (r.team_name ?? '').toString().trim() || `Team ${id}`;
      const logo = r.team_logo;
      row.team_logo =
        logo != null && String(logo).trim() !== '' ? String(logo).trim() : null;
      byId.set(id, row);
    }

    const boxMap = new Map();
    for (const r of boxRes.rows ?? []) {
      const mid = String(r.match_id);
      const tid = Number(r.team_id);
      if (Number.isNaN(tid)) continue;
      boxMap.set(`${mid}:${tid}`, r.totals);
    }

    const ensureRow = (teamId) => {
      let row = byId.get(teamId);
      if (!row) {
        row = empty();
        row.team_id = teamId;
        row.team_name = `Team ${teamId}`;
        row.team_logo = null;
        byId.set(teamId, row);
      }
      return row;
    };

    for (const g of gamesRes.rows ?? []) {
      const mid = String(g.match_id);
      const homeId = Number(g.home_team_id);
      const awayId = Number(g.away_team_id);
      if (Number.isNaN(homeId) || Number.isNaN(awayId)) continue;

      const rh = ensureRow(homeId);
      rh.gp += 1;
      _accumulateTotalsFromBox(rh, boxMap.get(`${mid}:${homeId}`));

      const ra = ensureRow(awayId);
      ra.gp += 1;
      _accumulateTotalsFromBox(ra, boxMap.get(`${mid}:${awayId}`));
    }

    const out = [...byId.values()].sort((a, b) => {
      if (b.pts !== a.pts) return b.pts - a.pts;
      return String(a.team_name).localeCompare(String(b.team_name));
    });

    res.json(out);
  } catch (err) {
    console.error('[GET /games/team-stats]', err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

app.get('/games/team-stats', listTeamStatsHandler);
app.get('/api/games/team-stats', listTeamStatsHandler);

// ─── Player leaders from player_boxscores (per competition) ─────────────────

/** Single-game line: rebounds total + oreb/dreb for per-game splits. */
function _playerLineRebounds(statsJson) {
  const t = _parseTotalsJson(statsJson);
  const oreb = _totalsNum(t, ['OREB', 'ORB', 'OFF', 'Off', 'oreb', 'orb']);
  const dreb = _totalsNum(t, ['DREB', 'DRB', 'DEF', 'Def', 'dreb', 'drb']);
  const trb = _totalsNum(t, ['REB', 'Reb', 'reb', 'TRB', 'Trb', 'Tot Reb']);
  const reb = trb > 0 ? trb : oreb + dreb;
  return { reb, oreb, dreb };
}

function _playerLineTurnovers(statsJson) {
  const t = _parseTotalsJson(statsJson);
  return _totalsNum(t, ['TO', 'TOV', 'Tov', 'to', 'Turnovers', 'From', 'FROM']);
}

async function aggregatePlayerBoxscoresForCompetition(compId) {
  const { rows } = await pool.query(
    `SELECT pb.player_id,
            pb.player_name,
            pb.player_number,
            pb.side,
            pb.stats,
            g.home_team_id,
            g.away_team_id,
            g.home_team_name,
            g.away_team_name,
            g.home_team_logo,
            g.away_team_logo
     FROM player_boxscores pb
     INNER JOIN games g ON g.match_id = pb.match_id
     WHERE g.competition_id = $1::int
       AND g.status IN ('final', 'live')`,
    [compId],
  );

  const byKey = new Map();
  for (const r of rows ?? []) {
    const side = String(r.side ?? '').toLowerCase();
    const homeId = Number(r.home_team_id);
    const awayId = Number(r.away_team_id);
    if (Number.isNaN(homeId) || Number.isNaN(awayId)) continue;
    const teamId = side === 'home' ? homeId : awayId;
    const teamName = (side === 'home' ? r.home_team_name : r.away_team_name) ?? '';
    const rawLogo = side === 'home' ? r.home_team_logo : r.away_team_logo;
    const teamLogo =
      rawLogo != null && String(rawLogo).trim() !== '' ? String(rawLogo).trim() : null;

    const pid = r.player_id != null ? Number(r.player_id) : null;
    const pname = String(r.player_name ?? '').trim();
    if (!pname) continue;
    const key =
      pid != null && !Number.isNaN(pid)
        ? `id:${pid}:t${teamId}`
        : `n:${teamId}:${pname.toLowerCase()}`;

    const stats = r.stats;
    const { reb, oreb, dreb } = _playerLineRebounds(stats);
    const t = _parseTotalsJson(stats);
    const pts = _totalsNum(t, ['Pts', 'PTS', 'pts', 'Points']);
    const ast = _totalsNum(t, ['AST', 'Ast', 'ast']);
    const stl = _totalsNum(t, ['STL', 'Stl', 'stl']);
    const blk = _totalsNum(t, ['BLK', 'Blk', 'blk']);
    const tpm = _totalsNum(t, ['3PM', '3pm', 'TPM', '3P']);
    const tov = _playerLineTurnovers(stats);

    let a = byKey.get(key);
    if (!a) {
      a = {
        player_id: pid != null && !Number.isNaN(pid) ? pid : null,
        player_name: pname,
        player_number: r.player_number != null ? String(r.player_number) : '',
        team_id: teamId,
        team_name: String(teamName).trim() || `Team ${teamId}`,
        team_logo: teamLogo,
        gp: 0,
        pts: 0,
        reb: 0,
        oreb: 0,
        dreb: 0,
        ast: 0,
        stl: 0,
        blk: 0,
        tpm: 0,
        tov: 0,
        position: null,
        headshot_url: null,
      };
      byKey.set(key, a);
    }
    a.gp += 1;
    a.pts += pts;
    a.reb += reb;
    a.oreb += oreb;
    a.dreb += dreb;
    a.ast += ast;
    a.stl += stl;
    a.blk += blk;
    a.tpm += tpm;
    a.tov += tov;
  }

  // Leaders use only `player_boxscores` + `games` (no `players` join — roster
  // rows are not guaranteed to match box score player_id yet).
  return [...byKey.values()];
}

const PLAYER_LEADER_STAT_DEFS = [
  {
    key: 'ppg',
    title: 'POINTS PER GAME',
    decimals: 1,
    ascending: false,
    value: (a) => a.pts / Math.max(1, a.gp),
  },
  {
    key: 'rpg',
    title: 'REBOUNDS PER GAME',
    decimals: 1,
    ascending: false,
    value: (a) => a.reb / Math.max(1, a.gp),
  },
  {
    key: 'apg',
    title: 'ASSISTS PER GAME',
    decimals: 1,
    ascending: false,
    value: (a) => a.ast / Math.max(1, a.gp),
  },
  {
    key: 'spg',
    title: 'STEALS PER GAME',
    decimals: 1,
    ascending: false,
    value: (a) => a.stl / Math.max(1, a.gp),
  },
  {
    key: 'bpg',
    title: 'BLOCKS PER GAME',
    decimals: 1,
    ascending: false,
    value: (a) => a.blk / Math.max(1, a.gp),
  },
  {
    key: 'tpm_pg',
    title: '3-POINTERS MADE / G',
    decimals: 1,
    ascending: false,
    value: (a) => a.tpm / Math.max(1, a.gp),
  },
  {
    key: 'oreb_pg',
    title: 'OFFENSIVE REBOUNDS / G',
    decimals: 1,
    ascending: false,
    value: (a) => a.oreb / Math.max(1, a.gp),
  },
  {
    key: 'dreb_pg',
    title: 'DEFENSIVE REBOUNDS / G',
    decimals: 1,
    ascending: false,
    value: (a) => a.dreb / Math.max(1, a.gp),
  },
  {
    key: 'to_pg',
    title: 'TURNOVERS / G',
    decimals: 1,
    ascending: false,
    value: (a) => a.tov / Math.max(1, a.gp),
  },
];

function _sortedForStat(players, def, limit) {
  const list = players.filter((a) => a.gp >= 1);
  list.sort((a, b) => {
    const va = def.value(a);
    const vb = def.value(b);
    if (def.ascending) {
      if (va !== vb) return va - vb;
    } else {
      if (vb !== va) return vb - va;
    }
    return String(a.player_name).localeCompare(String(b.player_name));
  });
  return list.slice(0, limit);
}

function _leaderRowPayload(a, def, rank) {
  const v = def.value(a);
  return {
    rank,
    player_id: a.player_id,
    player_name: a.player_name,
    player_number: a.player_number,
    position: a.position,
    team_id: a.team_id,
    team_name: a.team_name,
    team_logo: a.team_logo,
    headshot_url: a.headshot_url,
    gp: a.gp,
    value: Number.isFinite(v) ? v : 0,
    decimals: def.decimals,
  };
}

async function listPlayerLeadersHandler(req, res) {
  try {
    const rawComp = req.query.competition_id ?? req.query.competitionId;
    const compId = rawComp != null && rawComp !== '' ? Number(rawComp) : null;
    if (compId == null || Number.isNaN(compId)) {
      return res.status(400).json({ error: 'competition_id is required' });
    }
    const players = await aggregatePlayerBoxscoresForCompetition(compId);
    const stats = PLAYER_LEADER_STAT_DEFS.map((def) => {
      const sorted = _sortedForStat(players, def, 3);
      return {
        key: def.key,
        title: def.title,
        decimals: def.decimals,
        ascending: def.ascending,
        top3: sorted.map((a, i) => _leaderRowPayload(a, def, i + 1)),
      };
    });
    res.json({ competition_id: compId, stats });
  } catch (err) {
    console.error('[GET /games/player-leaders]', err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

async function listPlayerLeadersDetailHandler(req, res) {
  try {
    const rawComp = req.query.competition_id ?? req.query.competitionId;
    const compId = rawComp != null && rawComp !== '' ? Number(rawComp) : null;
    const statKey = String(req.query.stat ?? '').trim();
    const limRaw = req.query.limit ?? '20';
    const limit = Math.min(50, Math.max(1, Number(limRaw) || 20));
    if (compId == null || Number.isNaN(compId)) {
      return res.status(400).json({ error: 'competition_id is required' });
    }
    const def = PLAYER_LEADER_STAT_DEFS.find((d) => d.key === statKey);
    if (!def) {
      return res.status(400).json({
        error: `Unknown stat. Use one of: ${PLAYER_LEADER_STAT_DEFS.map((d) => d.key).join(', ')}`,
      });
    }
    const players = await aggregatePlayerBoxscoresForCompetition(compId);
    const sorted = _sortedForStat(players, def, limit);
    res.json({
      competition_id: compId,
      stat: def.key,
      title: def.title,
      decimals: def.decimals,
      ascending: def.ascending,
      rows: sorted.map((a, i) => _leaderRowPayload(a, def, i + 1)),
    });
  } catch (err) {
    console.error('[GET /games/player-leaders/detail]', err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

app.get('/games/player-leaders/detail', listPlayerLeadersDetailHandler);
app.get('/api/games/player-leaders/detail', listPlayerLeadersDetailHandler);
app.get('/games/player-leaders', listPlayerLeadersHandler);
app.get('/api/games/player-leaders', listPlayerLeadersHandler);

/** GET /games/:matchId — single game row */
async function getGameHandler(req, res) {
  const matchId = Number(req.params.matchId);
  if (Number.isNaN(matchId)) return res.status(400).json({ error: 'matchId must be an integer' });
  try {
    const { rows } = await pool.query(
      `
      SELECT ${GAME_ROW_SELECT_WITH_TEAM_LOGOS}
      ${GAME_ROW_FROM_WITH_TEAM_LOGOS}
      WHERE g.match_id = $1::bigint
      `,
      [matchId],
    );
    if (rows.length === 0) return res.status(404).json({ error: 'Game not found' });
    res.json(rows[0]);
  } catch (err) {
    console.error('[GET /games/:matchId]', err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

app.get('/games/:matchId', getGameHandler);
app.get('/api/games/:matchId', getGameHandler);

/** GET /games/:matchId/events — play-by-play timeline, newest first */
async function getGameEventsHandler(req, res) {
  const matchId = Number(req.params.matchId);
  if (Number.isNaN(matchId)) return res.status(400).json({ error: 'matchId must be an integer' });
  try {
    const { rows } = await pool.query(
      `SELECT event_id, match_id, period, clock, score, team_side, team_name,
              player, player_number, action_text, event_type, is_scoring_event, created_at
       FROM game_events
       WHERE match_id = $1::bigint
       ORDER BY created_at DESC NULLS LAST, event_id DESC`,
      [matchId],
    );
    res.json(rows);
  } catch (err) {
    console.error('[GET /games/:matchId/events]', err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

app.get('/games/:matchId/events', getGameEventsHandler);
app.get('/api/games/:matchId/events', getGameEventsHandler);

/** GET /games/:matchId/boxscore — full boxscore payload for stats tab + play-by-play */
async function getGameBoxscoreHandler(req, res) {
  const matchId = Number(req.params.matchId);
  if (Number.isNaN(matchId)) return res.status(400).json({ error: 'matchId must be an integer' });
  try {
    const [gameRes, teamsRes, playersRes, eventsRes] = await Promise.all([
      pool.query(
        `
        SELECT ${GAME_ROW_SELECT_WITH_TEAM_LOGOS}
        ${GAME_ROW_FROM_WITH_TEAM_LOGOS}
        WHERE g.match_id = $1::bigint
        `,
        [matchId],
      ),
      pool.query('SELECT * FROM team_boxscores WHERE match_id = $1::bigint ORDER BY side', [matchId]),
      pool.query(
        'SELECT * FROM player_boxscores WHERE match_id = $1::bigint ORDER BY side, player_name',
        [matchId],
      ),
      pool.query(
        `SELECT event_id, match_id, period, clock, score, team_side, team_name,
                player, player_number, action_text, event_type, is_scoring_event, created_at
         FROM game_events
         WHERE match_id = $1::bigint
         ORDER BY created_at ASC NULLS LAST, event_id ASC`,
        [matchId],
      ),
    ]);
    if (gameRes.rows.length === 0) return res.status(404).json({ error: 'Game not found' });
    res.json({
      game: gameRes.rows[0],
      teams: teamsRes.rows,
      players: playersRes.rows,
      events: eventsRes.rows,
    });
  } catch (err) {
    console.error('[GET /games/:matchId/boxscore]', err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

app.get('/games/:matchId/boxscore', getGameBoxscoreHandler);
app.get('/api/games/:matchId/boxscore', getGameBoxscoreHandler);

// --- SBC (squad building challenges) ---
function parsePositiveInt(raw) {
  if (raw == null || raw === '') return null;
  const n = Number(raw);
  if (!Number.isInteger(n) || n <= 0) return null;
  return n;
}

function parseSbcSlotsStrict(slotsIn) {
  if (slotsIn == null || typeof slotsIn !== 'object') {
    const err = new Error('slots is required with pg, sg, sf, pf, c (positive card ids).');
    err.statusCode = 400;
    throw err;
  }
  return {
    pg: parseSlotStrictPositive(slotsIn.pg ?? slotsIn.guard1, 'pg'),
    sg: parseSlotStrictPositive(slotsIn.sg ?? slotsIn.guard2, 'sg'),
    sf: parseSlotStrictPositive(slotsIn.sf ?? slotsIn.forward1, 'sf'),
    pf: parseSlotStrictPositive(slotsIn.pf ?? slotsIn.forward2, 'pf'),
    c: parseSlotStrictPositive(slotsIn.c ?? slotsIn.center, 'c'),
  };
}

function evaluateSbcRequirement(req, selectedCards) {
  const minCount = Number.isInteger(Number(req.min_count)) ? Number(req.min_count) : 1;
  const type = String(req.requirement_type ?? '').trim().toUpperCase();
  const value = parsePositiveInt(req.required_value);
  let matchedCount = 0;
  if (type === 'TEAM') {
    matchedCount = selectedCards.filter((c) => Number(c.team_id) === value).length;
  } else if (type === 'PLAYER_REQUIRED') {
    matchedCount = selectedCards.filter((c) => Number(c.player_id) === value).length;
  } else {
    return {
      ok: false,
      requirement_id: req.requirement_id,
      requirement_type: req.requirement_type,
      required_value: req.required_value,
      required_text: req.required_text,
      min_count: minCount,
      matched_count: 0,
      message: `Unsupported requirement type "${req.requirement_type}".`,
    };
  }
  const targetLabel = req.required_text?.trim()
    ? req.required_text.trim()
    : (value != null ? String(value) : 'value');
  return {
    ok: matchedCount >= minCount,
    requirement_id: req.requirement_id,
    requirement_type: req.requirement_type,
    required_value: req.required_value,
    required_text: req.required_text,
    min_count: minCount,
    matched_count: matchedCount,
    message:
      type === 'TEAM'
        ? `Need at least ${minCount} card(s) from team ${targetLabel}.`
        : `Need at least ${minCount} card(s) for player ${targetLabel}.`,
  };
}

async function validateSbcUsesDuplicatesOnly(client, userId, cardIds) {
  const uniq = [...new Set(cardIds.filter((x) => Number.isInteger(x) && x > 0))];
  if (uniq.length === 0) return;
  const { rows } = await client.query(
    `SELECT card_id, COUNT(*)::int AS cnt
     FROM card_instances
     WHERE user_id = $1::int AND card_id = ANY($2::int[])
     GROUP BY card_id`,
    [userId, uniq],
  );
  const counts = new Map(rows.map((r) => [Number(r.card_id), Number(r.cnt)]));
  for (const cardId of uniq) {
    const have = counts.get(cardId) ?? 0;
    if (have < 2) {
      const err = new Error(`Card ${cardId} is not a duplicate. SBC requires at least 2 copies of every submitted card.`);
      err.statusCode = 400;
      throw err;
    }
  }
}

async function sbcChallengesHandler(req, res) {
  try {
    const rawUserId = req.query.user_id ?? req.query.userId;
    const userId = parsePositiveInt(rawUserId);
    const { rows: challenges } = await pool.query(
      `SELECT
         s.sbc_id, s.sbc_name, s.description, s.reward_card_id, s.is_active, s.created_at,
         CASE
           WHEN $1::int IS NULL THEN FALSE
           ELSE EXISTS (
             SELECT 1
             FROM card_instances ci
             WHERE ci.user_id = $1::int
               AND ci.card_id = s.reward_card_id
             LIMIT 1
           )
         END AS completed,
         pc.card_type AS reward_card_type,
         pc.attack AS reward_attack,
         pc.defend AS reward_defend,
         pc.card_image AS reward_card_image,
         pc.player_id AS reward_player_id,
         COALESCE(NULLIF(TRIM(p.first_name), ''), '') AS reward_first_name,
         COALESCE(NULLIF(TRIM(p.last_name), ''), '') AS reward_last_name,
         COALESCE(NULLIF(TRIM(p.position), ''), '?') AS reward_position,
         t.team_id AS reward_team_id,
         t.team_name AS reward_team_name
       FROM sbc_challenges s
       LEFT JOIN play_cards pc ON pc.card_id = s.reward_card_id
       LEFT JOIN players p ON p.player_id = pc.player_id
       LEFT JOIN teams t ON t.team_id = p.team_id
       WHERE s.is_active = TRUE
       ORDER BY completed ASC, s.created_at ASC NULLS LAST, s.sbc_id ASC`,
      [userId],
    );
    if (challenges.length === 0) {
      return res.json({ challenges: [] });
    }
    const sbcIds = challenges.map((r) => r.sbc_id);
    const { rows: reqs } = await pool.query(
      `SELECT requirement_id, sbc_id, requirement_type, required_value, required_text, min_count
       FROM sbc_requirements
       WHERE sbc_id = ANY($1::int[])
       ORDER BY sbc_id ASC, requirement_id ASC`,
      [sbcIds],
    );
    const playerReqIds = reqs
      .filter((r) => String(r.requirement_type ?? '').toUpperCase() === 'PLAYER_REQUIRED')
      .map((r) => parsePositiveInt(r.required_value))
      .filter((v) => v != null);
    const teamReqIds = reqs
      .filter((r) => String(r.requirement_type ?? '').toUpperCase() === 'TEAM')
      .map((r) => parsePositiveInt(r.required_value))
      .filter((v) => v != null);
    const uniqPlayerIds = [...new Set(playerReqIds)];
    const uniqTeamIds = [...new Set(teamReqIds)];
    const playerNameById = new Map();
    const teamNameById = new Map();
    if (uniqPlayerIds.length > 0) {
      const { rows: pRows } = await pool.query(
        `SELECT player_id,
                COALESCE(NULLIF(TRIM(first_name), ''), '') AS first_name,
                COALESCE(NULLIF(TRIM(last_name), ''), '') AS last_name
         FROM players
         WHERE player_id = ANY($1::int[])`,
        [uniqPlayerIds],
      );
      for (const p of pRows) {
        const label = `${p.first_name} ${p.last_name}`.trim();
        playerNameById.set(p.player_id, label || `Player #${p.player_id}`);
      }
    }
    if (uniqTeamIds.length > 0) {
      const { rows: tRows } = await pool.query(
        `SELECT team_id, team_name FROM teams WHERE team_id = ANY($1::int[])`,
        [uniqTeamIds],
      );
      for (const t of tRows) {
        teamNameById.set(t.team_id, t.team_name ?? `Team #${t.team_id}`);
      }
    }
    const reqBySbc = new Map();
    for (const rawReq of reqs) {
      const r = { ...rawReq };
      const reqType = String(r.requirement_type ?? '').toUpperCase();
      const reqValue = parsePositiveInt(r.required_value);
      const rawText = String(r.required_text ?? '').trim();
      const textLooksLikeId = reqValue != null && (rawText === String(reqValue) || /^\d+$/.test(rawText));
      const shouldReplaceText = rawText.isEmpty || textLooksLikeId;
      if (shouldReplaceText && reqValue != null) {
        if (reqType === 'PLAYER_REQUIRED') {
          r.required_text = playerNameById.get(reqValue) ?? `Player #${reqValue}`;
        } else if (reqType === 'TEAM') {
          r.required_text = teamNameById.get(reqValue) ?? `Team #${reqValue}`;
        }
      }
      if (reqType === 'PLAYER_REQUIRED') {
        r.resolved_name = reqValue != null ? (playerNameById.get(reqValue) ?? `Player #${reqValue}`) : null;
      } else if (reqType === 'TEAM') {
        r.resolved_name = reqValue != null ? (teamNameById.get(reqValue) ?? `Team #${reqValue}`) : null;
      } else {
        r.resolved_name = null;
      }
      if (!reqBySbc.has(r.sbc_id)) reqBySbc.set(r.sbc_id, []);
      reqBySbc.get(r.sbc_id).push(r);
    }
    const payload = challenges.map((r) => ({
      sbc_id: r.sbc_id,
      sbc_name: r.sbc_name,
      description: r.description,
      reward_card_id: r.reward_card_id,
      is_active: r.is_active,
      completed: r.completed === true,
      created_at: r.created_at,
      reward_card: {
        card_id: r.reward_card_id,
        card_type: r.reward_card_type,
        attack: r.reward_attack,
        defend: r.reward_defend,
        overall: Math.round((Number(r.reward_attack ?? 0) + Number(r.reward_defend ?? 0)) / 2),
        card_image: r.reward_card_image,
        player_id: r.reward_player_id,
        first_name: r.reward_first_name,
        last_name: r.reward_last_name,
        position: r.reward_position,
        team_id: r.reward_team_id,
        team_name: r.reward_team_name,
      },
      requirements: reqBySbc.get(r.sbc_id) ?? [],
    }));
    return res.json({ challenges: payload });
  } catch (err) {
    console.error('[GET /sbc/challenges]', err);
    const msg = err.message ?? String(err);
    if (msg.toLowerCase().includes('sbc_challenges') && msg.toLowerCase().includes('relation')) {
      return res.status(503).json({
        error:
          'SBC tables are missing. Apply a migration that creates sbc_challenges and sbc_requirements.',
      });
    }
    return res.status(500).json({ error: msg });
  }
}

async function sbcSubmitHandler(req, res) {
  const body = req.body ?? {};
  const userId = parsePositiveInt(body.user_id ?? body.userId);
  const sbcId = parsePositiveInt(body.sbc_id ?? body.sbcId);
  if (userId == null) return res.status(400).json({ error: 'user_id is required (integer).' });
  if (sbcId == null) return res.status(400).json({ error: 'sbc_id is required (integer).' });

  let slots;
  try {
    slots = parseSbcSlotsStrict(body.slots);
  } catch (err) {
    return res.status(err.statusCode ?? 400).json({ error: err.message ?? String(err) });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { rows: users } = await client.query(`SELECT 1 FROM users WHERE user_id = $1::int`, [userId]);
    if (users.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'User not found.' });
    }

    const { rows: sbcRows } = await client.query(
      `SELECT sbc_id, sbc_name, description, reward_card_id, is_active
       FROM sbc_challenges
       WHERE sbc_id = $1::int
       LIMIT 1`,
      [sbcId],
    );
    if (sbcRows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'SBC challenge not found.' });
    }
    const sbc = sbcRows[0];
    if (!sbc.is_active) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'This SBC is not active right now.' });
    }
    const { rows: priorReward } = await client.query(
      `SELECT 1
       FROM card_instances
       WHERE user_id = $1::int AND card_id = $2::int
       LIMIT 1`,
      [userId, sbc.reward_card_id],
    );
    if (priorReward.length > 0) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'You already completed this SBC.' });
    }

    const { rows: reqRows } = await client.query(
      `SELECT requirement_id, requirement_type, required_value, required_text, min_count
       FROM sbc_requirements
       WHERE sbc_id = $1::int
       ORDER BY requirement_id ASC`,
      [sbcId],
    );

    await validateUserOwnsSquadMultiset(client, userId, slots.pg, slots.sg, slots.sf, slots.pf, slots.c);
    await validateSbcUsesDuplicatesOnly(client, userId, [slots.pg, slots.sg, slots.sf, slots.pf, slots.c]);
    await validateSquadLineupPositions(client, slots.pg, slots.sg, slots.sf, slots.pf, slots.c);

    const selectedMap = await fetchPlayCardSummariesForSquad(client, [slots.pg, slots.sg, slots.sf, slots.pf, slots.c]);
    const selectedCards = [slots.pg, slots.sg, slots.sf, slots.pf, slots.c]
      .map((id) => selectedMap.get(id))
      .filter(Boolean);

    const checks = reqRows.map((req) => evaluateSbcRequirement(req, selectedCards));
    const failed = checks.filter((c) => !c.ok);
    if (failed.length > 0) {
      await client.query('ROLLBACK');
      return res.status(400).json({
        error: 'SBC requirements not met.',
        unmet_requirements: failed,
        requirement_results: checks,
      });
    }

    const { rows: rewardRows } = await client.query(
      `INSERT INTO card_instances (card_id, user_id)
       VALUES ($1::int, $2::int)
       RETURNING card_instance_id, card_id`,
      [sbc.reward_card_id, userId],
    );
    const rewardInstance = rewardRows[0];
    const rewardSummaryMap = await fetchPlayCardSummariesForSquad(client, [sbc.reward_card_id]);
    const rewardCard = rewardSummaryMap.get(sbc.reward_card_id) ?? null;

    await client.query('COMMIT');
    return res.status(201).json({
      ok: true,
      sbc_id: sbc.sbc_id,
      sbc_name: sbc.sbc_name,
      reward_card_id: sbc.reward_card_id,
      reward_instance_id: rewardInstance?.card_instance_id ?? null,
      reward_card: rewardCard,
      requirement_results: checks,
    });
  } catch (err) {
    await client.query('ROLLBACK').catch(() => {});
    console.error('[POST /sbc/submit]', err);
    const code = err.statusCode ?? 500;
    const msg = err.message ?? String(err);
    if (msg.toLowerCase().includes('sbc_challenges') && msg.toLowerCase().includes('relation')) {
      return res.status(503).json({
        error:
          'SBC tables are missing. Apply a migration that creates sbc_challenges and sbc_requirements.',
      });
    }
    return res.status(code >= 400 && code < 600 ? code : 500).json({ error: msg });
  } finally {
    client.release();
  }
}

app.get('/sbc/challenges', sbcChallengesHandler);
app.get('/api/sbc/challenges', sbcChallengesHandler);
app.post('/sbc/submit', sbcSubmitHandler);
app.post('/api/sbc/submit', sbcSubmitHandler);

// --- 1v1 card squads (`cards_squad`) ---
function parseCardsSquadNumber(raw) {
  const n = Number(raw);
  if (Number.isNaN(n) || n < 1 || n > 3) return null;
  return n;
}

function intOrNull(v) {
  if (v === undefined || v === null || v === '') return null;
  const n = Number(v);
  if (!Number.isInteger(n)) return null;
  return n;
}

/** undefined = leave unchanged; null = clear slot; positive int = assign card */
function parseSlotUpdate(v) {
  if (v === undefined) return undefined;
  if (v === null) return null;
  if (v === '') return undefined;
  const n = Number(v);
  if (!Number.isFinite(n)) return undefined;
  if (n === -1 || n === 0) return null;
  if (!Number.isInteger(n) || n < 0) {
    const err = new Error('Slot value must be a positive card_id, -1 to clear, or null.');
    err.statusCode = 400;
    throw err;
  }
  return n;
}

function slotKeyToPositionCode(slotKey) {
  return { pg: 'PG', sg: 'SG', sf: 'SF', pf: 'PF', c: 'C' }[slotKey] ?? null;
}

/** Map `players.position` text to PG | SG | SF | PF | C (strict for lineup rules). */
function normalizeDbBasketballPosition(raw) {
  const t = String(raw ?? '')
    .trim()
    .toUpperCase()
    .replace(/\./g, '')
    .replace(/_/g, ' ')
    .replace(/\s+/g, ' ');
  if (!t || t === '?') return null;
  if (['PG', 'SG', 'SF', 'PF', 'C'].includes(t)) return t;
  const longForm = new Map([
    ['POINT GUARD', 'PG'],
    ['SHOOTING GUARD', 'SG'],
    ['SMALL FORWARD', 'SF'],
    ['POWER FORWARD', 'PF'],
    ['CENTER', 'C'],
    ['CENTRE', 'C'],
  ]);
  if (longForm.has(t)) return longForm.get(t);
  if (t.includes('POINT') && t.includes('GUARD')) return 'PG';
  if (t.includes('SHOOTING') && t.includes('GUARD')) return 'SG';
  if (t.includes('SMALL') && t.includes('FORWARD')) return 'SF';
  if (t.includes('POWER') && t.includes('FORWARD')) return 'PF';
  return null;
}

async function fetchPlayCardSummariesForSquad(client, cardIds) {
  const uniq = [...new Set(cardIds.filter((x) => Number.isInteger(x) && x > 0))];
  if (uniq.length === 0) return new Map();
  const { rows } = await client.query(
    `SELECT pc.card_id, pc.card_type, pc.player_id, pc.attack, pc.defend, pc.card_image,
        COALESCE(NULLIF(TRIM(p.position), ''), '?') AS position,
        COALESCE(NULLIF(TRIM(p.nationality), ''), '') AS nationality,
        COALESCE(NULLIF(TRIM(p.first_name), ''), '') AS first_name,
        COALESCE(NULLIF(TRIM(p.last_name), ''), '') AS last_name,
        t.team_id, t.team_name,
        ROUND((pc.attack + pc.defend) / 2.0)::int AS overall
     FROM play_cards pc
     LEFT JOIN players p ON p.player_id = pc.player_id
     LEFT JOIN teams t ON t.team_id = p.team_id
     WHERE pc.card_id = ANY($1::int[])`,
    [uniq],
  );
  const m = new Map();
  for (const r of rows) m.set(r.card_id, r);
  return m;
}

/** DB columns pg, sg, sf, pf, c (lowercase; PostgreSQL folds unquoted identifiers). API slots same keys. Empty: DB NULL, JSON card_id -1. */
const CARDS_SQUAD_SQL_COLS = 'pg, sg, sf, pf, c';

const SQUAD_SLOT_DB_COL = { pg: 'pg', sg: 'sg', sf: 'sf', pf: 'pf', c: 'c' };

function squadSlotRawFromRow(row, slotKey) {
  const name = SQUAD_SLOT_DB_COL[slotKey];
  if (row == null || name == null) return undefined;
  return row[name] ?? row[name.toLowerCase()];
}

function squadSlotIntFromRow(v) {
  if (v == null || v === -1) return -1;
  const n = Number(v);
  if (!Number.isFinite(n) || n <= 0) return -1;
  return n;
}

function squadSlotFromRow(row, slotKey) {
  return squadSlotIntFromRow(squadSlotRawFromRow(row, slotKey));
}

/** Map logical slot (-1 / empty) to SQL NULL so FK to play_cards is not violated. */
function squadSlotToSqlParam(v) {
  if (v == null || v === -1) return null;
  const n = Number(v);
  if (!Number.isFinite(n) || n <= 0) return null;
  return n;
}

function parseSlotStrictPositive(v, label) {
  const n = Number(v);
  if (!Number.isInteger(n) || n <= 0) {
    const err = new Error(`slots.${label} must be a positive card_id.`);
    err.statusCode = 400;
    throw err;
  }
  return n;
}

function buildCardsSquadPayload(row, summaryMap) {
  const slotKeys = ['pg', 'sg', 'sf', 'pf', 'c'];
  const slots = {};
  for (const key of slotKeys) {
    const rawId = squadSlotRawFromRow(row, key);
    const id = rawId == null || rawId === -1 ? -1 : Number(rawId);
    if (!Number.isFinite(id) || id <= 0) {
      slots[key] = {
        card_id: -1,
        cardId: -1,
        player_id: null,
        playerId: null,
        overall: null,
        position: slotKeyToPositionCode(key),
        first_name: '',
        firstName: '',
        last_name: '',
        lastName: '',
        team_name: null,
        teamName: null,
        card_type: null,
        cardType: null,
      };
      continue;
    }
    const s = summaryMap.get(id);
    const img = s?.card_image ?? s?.cardImage;
    slots[key] = {
      card_id: id,
      cardId: id,
      player_id: s?.player_id ?? null,
      playerId: s?.player_id ?? null,
      attack: s?.attack ?? null,
      defend: s?.defend ?? null,
      overall: s?.overall ?? null,
      position: s?.position ?? '?',
      first_name: s?.first_name ?? '',
      firstName: s?.first_name ?? '',
      last_name: s?.last_name ?? '',
      lastName: s?.last_name ?? '',
      team_name: s?.team_name ?? null,
      teamName: s?.team_name ?? null,
      card_type: s?.card_type ?? null,
      cardType: s?.card_type ?? null,
      card_image: img ?? null,
      cardImage: img ?? null,
    };
  }
  return {
    id: row.id,
    user_id: row.user_id,
    userId: row.user_id,
    squad_number: row.squad_number,
    squadNumber: row.squad_number,
    squad_name: row.squad_name,
    squadName: row.squad_name,
    slots,
  };
}

async function loadCardsSquadRow(client, userId, squadNumber) {
  const sel = await client.query(
    `SELECT id, user_id, squad_number, squad_name, ${CARDS_SQUAD_SQL_COLS}
     FROM cards_squad WHERE user_id = $1::int AND squad_number = $2::int`,
    [userId, squadNumber],
  );
  return sel.rows[0] ?? null;
}

async function validateUserOwnsSquadMultiset(client, userId, slotPg, slotSg, slotSf, slotPf, slotC) {
  const multiset = [slotPg, slotSg, slotSf, slotPf, slotC].filter((id) => id != null && Number.isInteger(id) && id > 0);
  if (multiset.length === 0) return;
  const needed = new Map();
  for (const id of multiset) {
    needed.set(id, (needed.get(id) || 0) + 1);
  }
  const ids = [...needed.keys()];
  const { rows } = await client.query(
    `SELECT card_id, COUNT(*)::int AS cnt
     FROM card_instances
     WHERE user_id = $1::int AND card_id = ANY($2::int[])
     GROUP BY card_id`,
    [userId, ids],
  );
  const owned = new Map(rows.map((r) => [r.card_id, r.cnt]));
  for (const [cardId, need] of needed) {
    const have = owned.get(cardId) ?? 0;
    if (have < need) {
      const err = new Error(
        `Not enough copies of card ${cardId} in your collection for this lineup (need ${need}, have ${have}).`,
      );
      err.statusCode = 400;
      throw err;
    }
  }
  const { rows: pc } = await client.query(`SELECT card_id FROM play_cards WHERE card_id = ANY($1::int[])`, [ids]);
  if (pc.length !== ids.length) {
    const err = new Error('One or more card_id values are not valid play_cards.');
    err.statusCode = 400;
    throw err;
  }
}

async function validateSquadLineupPositions(client, slotPg, slotSg, slotSf, slotPf, slotC) {
  const slots = [
    ['pg', slotPg],
    ['sg', slotSg],
    ['sf', slotSf],
    ['pf', slotPf],
    ['c', slotC],
  ];
  for (const [slotKey, cardId] of slots) {
    if (cardId == null || cardId <= 0 || cardId === -1) continue;
    const expected = slotKeyToPositionCode(slotKey);
    const { rows } = await client.query(
      `SELECT COALESCE(NULLIF(TRIM(p.position), ''), '?') AS position
       FROM play_cards pc
       LEFT JOIN players p ON p.player_id = pc.player_id
       WHERE pc.card_id = $1::int
       LIMIT 1`,
      [cardId],
    );
    if (rows.length === 0) {
      const err = new Error(`Unknown card_id ${cardId}.`);
      err.statusCode = 400;
      throw err;
    }
    const dbPos = normalizeDbBasketballPosition(rows[0].position);
    if (dbPos == null || dbPos !== expected) {
      const err = new Error(
        `Card ${cardId} is listed as "${rows[0].position}" — only ${expected} players can fill this slot.`,
      );
      err.statusCode = 400;
      throw err;
    }
  }
}

/** Distinct positive card_ids assigned in other squads (same user, excluding [excludeSquadNumber]). */
async function fetchCardIdsUsedInOtherSquads(client, userId, excludeSquadNumber) {
  const { rows } = await client.query(
    `SELECT pg, sg, sf, pf, c FROM cards_squad WHERE user_id = $1::int AND squad_number <> $2::int`,
    [userId, excludeSquadNumber],
  );
  const out = new Set();
  for (const r of rows) {
    for (const key of ['pg', 'sg', 'sf', 'pf', 'c']) {
      const v = r[key];
      if (v != null && Number.isInteger(Number(v)) && Number(v) > 0) out.add(Number(v));
    }
  }
  return [...out];
}

async function validateCardsNotUsedInOtherSquads(client, userId, currentSquadNumber, slotPg, slotSg, slotSf, slotPf, slotC) {
  const usedElsewhere = new Set(await fetchCardIdsUsedInOtherSquads(client, userId, currentSquadNumber));
  const incoming = [slotPg, slotSg, slotSf, slotPf, slotC].filter((id) => id != null && Number.isInteger(id) && id > 0);
  for (const id of incoming) {
    if (usedElsewhere.has(id)) {
      const err = new Error(
        `Card ${id} is already on another squad. Remove it from that squad before using it here.`,
      );
      err.statusCode = 400;
      throw err;
    }
  }
}

/** GET /cards/squad?squad_number=1..3&user_id=… — returns { exists, squad? }; no row is created until POST. */
async function getCardsSquadHandler(req, res) {
  const rawUser = req.query.user_id ?? req.query.userId;
  const rawSq = req.query.squad_number ?? req.query.squadNumber;
  if (rawUser == null || rawUser === '' || Number.isNaN(Number(rawUser))) {
    return res.status(400).json({ error: 'user_id query parameter is required (integer).' });
  }
  const squadNumber = parseCardsSquadNumber(rawSq);
  if (squadNumber == null) {
    return res.status(400).json({ error: 'squad_number must be 1, 2, or 3.' });
  }
  const userId = Number(rawUser);
  const client = await pool.connect();
  try {
    const { rows: u } = await client.query(`SELECT 1 FROM users WHERE user_id = $1::int`, [userId]);
    if (u.length === 0) return res.status(404).json({ error: 'User not found.' });

    const reservedElsewhere = await fetchCardIdsUsedInOtherSquads(client, userId, squadNumber);
    const row = await loadCardsSquadRow(client, userId, squadNumber);
    if (row == null) {
      return res.json({ exists: false, card_ids_in_other_squads: reservedElsewhere });
    }
    const sm = await fetchPlayCardSummariesForSquad(client, [
      squadSlotFromRow(row, 'pg'),
      squadSlotFromRow(row, 'sg'),
      squadSlotFromRow(row, 'sf'),
      squadSlotFromRow(row, 'pf'),
      squadSlotFromRow(row, 'c'),
    ].filter((id) => id > 0));
    return res.json({
      exists: true,
      squad: buildCardsSquadPayload(row, sm),
      card_ids_in_other_squads: reservedElsewhere,
    });
  } catch (err) {
    console.error('[GET /cards/squad]', err);
    const msg = err.message ?? String(err);
    if (msg.includes('cards_squad') && msg.toLowerCase().includes('relation')) {
      return res.status(503).json({
        error:
          'Database table cards_squad is missing. Apply the migration that creates cards_squad.',
      });
    }
    res.status(500).json({ error: msg });
  } finally {
    client.release();
  }
}

/** POST /cards/squad — create row: all five slots must be positive card_ids. Body: { user_id, squad_number, squad_name?, slots } */
async function postCardsSquadHandler(req, res) {
  const body = req.body ?? {};
  const rawUser = body.user_id ?? body.userId;
  const rawSq = body.squad_number ?? body.squadNumber;
  if (rawUser == null || rawUser === '' || Number.isNaN(Number(rawUser))) {
    return res.status(400).json({ error: 'user_id is required (integer).' });
  }
  const squadNumber = parseCardsSquadNumber(rawSq);
  if (squadNumber == null) {
    return res.status(400).json({ error: 'squad_number must be 1, 2, or 3.' });
  }
  const userId = Number(rawUser);
  const slotsIn = body.slots;
  if (slotsIn == null || typeof slotsIn !== 'object') {
    return res.status(400).json({ error: 'slots is required with pg, sg, sf, pf, c (positive card ids).' });
  }
  let slotPg;
  let slotSg;
  let slotSf;
  let slotPf;
  let slotC;
  try {
    slotPg = parseSlotStrictPositive(slotsIn.pg ?? slotsIn.guard1, 'pg');
    slotSg = parseSlotStrictPositive(slotsIn.sg ?? slotsIn.guard2, 'sg');
    slotSf = parseSlotStrictPositive(slotsIn.sf ?? slotsIn.forward1, 'sf');
    slotPf = parseSlotStrictPositive(slotsIn.pf ?? slotsIn.forward2, 'pf');
    slotC = parseSlotStrictPositive(slotsIn.c ?? slotsIn.center, 'c');
  } catch (e) {
    return res.status(e.statusCode ?? 400).json({ error: e.message });
  }

  const nameRaw = body.squad_name ?? body.squadName;
  let nm = nameRaw != null ? String(nameRaw).trim() : '';
  if (!nm) nm = `Squad ${squadNumber}`;
  if (nm.length > 100) nm = nm.slice(0, 100);

  const client = await pool.connect();
  try {
    const { rows: u } = await client.query(`SELECT 1 FROM users WHERE user_id = $1::int`, [userId]);
    if (u.length === 0) return res.status(404).json({ error: 'User not found.' });

    await client.query('BEGIN');
    const existing = await loadCardsSquadRow(client, userId, squadNumber);
    if (existing != null) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'Squad already exists for this slot. Use Save to update.' });
    }
    await validateUserOwnsSquadMultiset(client, userId, slotPg, slotSg, slotSf, slotPf, slotC);
    await validateSquadLineupPositions(client, slotPg, slotSg, slotSf, slotPf, slotC);
    await validateCardsNotUsedInOtherSquads(client, userId, squadNumber, slotPg, slotSg, slotSf, slotPf, slotC);

    const { rows: ins } = await client.query(
      `INSERT INTO cards_squad (user_id, squad_number, squad_name, pg, sg, sf, pf, c)
       VALUES ($1::int, $2::int, $3, $4::int, $5::int, $6::int, $7::int, $8::int)
       RETURNING id, user_id, squad_number, squad_name, ${CARDS_SQUAD_SQL_COLS}`,
      [userId, squadNumber, nm, slotPg, slotSg, slotSf, slotPf, slotC],
    );
    const row = ins[0];
    await client.query('COMMIT');

    const sm = await fetchPlayCardSummariesForSquad(client, [slotPg, slotSg, slotSf, slotPf, slotC]);
    res.status(201).json({ exists: true, squad: buildCardsSquadPayload(row, sm) });
  } catch (err) {
    await client.query('ROLLBACK').catch(() => {});
    if (err.code === '23505') {
      return res.status(409).json({ error: 'Squad already exists for this slot. Use Save to update.' });
    }
    const code = err.statusCode ?? 500;
    console.error('[POST /cards/squad]', err);
    const msg = err.message ?? String(err);
    if (msg.includes('cards_squad') && msg.toLowerCase().includes('relation')) {
      return res.status(503).json({
        error:
          'Database table cards_squad is missing. Apply the migration that creates cards_squad.',
      });
    }
    res.status(code >= 400 && code < 600 ? code : 500).json({ error: msg });
  } finally {
    client.release();
  }
}

/** PATCH /cards/squad — update existing row only. Body: { user_id, squad_number, squad_name?, slots? } (-1 or null clears a slot in DB). */
async function patchCardsSquadHandler(req, res) {
  const body = req.body ?? {};
  const rawUser = body.user_id ?? body.userId;
  const rawSq = body.squad_number ?? body.squadNumber;
  if (rawUser == null || rawUser === '' || Number.isNaN(Number(rawUser))) {
    return res.status(400).json({ error: 'user_id is required (integer).' });
  }
  const squadNumber = parseCardsSquadNumber(rawSq);
  if (squadNumber == null) {
    return res.status(400).json({ error: 'squad_number must be 1, 2, or 3.' });
  }
  const userId = Number(rawUser);
  const nameRaw = body.squad_name ?? body.squadName;
  const slotsIn = body.slots;
  const hasName = nameRaw !== undefined && nameRaw !== null;
  const hasSlots = slotsIn != null && typeof slotsIn === 'object';

  if (!hasName && !hasSlots) {
    return res.status(400).json({ error: 'Provide squad_name and/or slots to update.' });
  }

  const client = await pool.connect();
  try {
    const { rows: u } = await client.query(`SELECT 1 FROM users WHERE user_id = $1::int`, [userId]);
    if (u.length === 0) return res.status(404).json({ error: 'User not found.' });

    await client.query('BEGIN');
    let row = await loadCardsSquadRow(client, userId, squadNumber);
    if (row == null) {
      await client.query('ROLLBACK');
      return res.status(404).json({
        error:
          'No squad saved yet for this slot. Fill all five positions, then tap Create squad.',
      });
    }

    let nextName = row.squad_name;
    if (hasName) {
      let nm = String(nameRaw).trim();
      if (!nm) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'squad_name cannot be empty.' });
      }
      if (nm.length > 100) nm = nm.slice(0, 100);
      nextName = nm;
    }

    let slotPg = squadSlotFromRow(row, 'pg');
    let slotSg = squadSlotFromRow(row, 'sg');
    let slotSf = squadSlotFromRow(row, 'sf');
    let slotPf = squadSlotFromRow(row, 'pf');
    let slotC = squadSlotFromRow(row, 'c');

    if (hasSlots) {
      const pg = parseSlotUpdate(slotsIn.pg ?? slotsIn.guard1);
      const sg = parseSlotUpdate(slotsIn.sg ?? slotsIn.guard2);
      const sf = parseSlotUpdate(slotsIn.sf ?? slotsIn.forward1);
      const pf = parseSlotUpdate(slotsIn.pf ?? slotsIn.forward2);
      const ce = parseSlotUpdate(slotsIn.c ?? slotsIn.center);
      if (pg !== undefined) slotPg = pg === null ? -1 : pg;
      if (sg !== undefined) slotSg = sg === null ? -1 : sg;
      if (sf !== undefined) slotSf = sf === null ? -1 : sf;
      if (pf !== undefined) slotPf = pf === null ? -1 : pf;
      if (ce !== undefined) slotC = ce === null ? -1 : ce;
      await validateUserOwnsSquadMultiset(client, userId, slotPg, slotSg, slotSf, slotPf, slotC);
      await validateSquadLineupPositions(client, slotPg, slotSg, slotSf, slotPf, slotC);
      await validateCardsNotUsedInOtherSquads(client, userId, squadNumber, slotPg, slotSg, slotSf, slotPf, slotC);
    }

    await client.query(
      `UPDATE cards_squad
       SET squad_name = $1, pg = $2, sg = $3, sf = $4, pf = $5, c = $6
       WHERE id = $7::int`,
      [
        nextName,
        squadSlotToSqlParam(slotPg),
        squadSlotToSqlParam(slotSg),
        squadSlotToSqlParam(slotSf),
        squadSlotToSqlParam(slotPf),
        squadSlotToSqlParam(slotC),
        row.id,
      ],
    );

    const { rows: fresh } = await client.query(
      `SELECT id, user_id, squad_number, squad_name, ${CARDS_SQUAD_SQL_COLS}
       FROM cards_squad WHERE id = $1::int`,
      [row.id],
    );
    row = fresh[0];
    await client.query('COMMIT');

    const sm = await fetchPlayCardSummariesForSquad(client, [
      squadSlotFromRow(row, 'pg'),
      squadSlotFromRow(row, 'sg'),
      squadSlotFromRow(row, 'sf'),
      squadSlotFromRow(row, 'pf'),
      squadSlotFromRow(row, 'c'),
    ].filter((id) => id > 0));
    res.json({ exists: true, squad: buildCardsSquadPayload(row, sm) });
  } catch (err) {
    await client.query('ROLLBACK').catch(() => {});
    const code = err.statusCode ?? 500;
    console.error('[PATCH /cards/squad]', err);
    const msg = err.message ?? String(err);
    if (msg.includes('cards_squad') && msg.toLowerCase().includes('relation')) {
      return res.status(503).json({
        error:
          'Database table cards_squad is missing. Apply the migration that creates cards_squad.',
      });
    }
    res.status(code >= 400 && code < 600 ? code : 500).json({ error: msg });
  } finally {
    client.release();
  }
}

app.get('/cards/squad', getCardsSquadHandler);
app.get('/api/cards/squad', getCardsSquadHandler);
app.post('/cards/squad', postCardsSquadHandler);
app.post('/api/cards/squad', postCardsSquadHandler);
app.patch('/cards/squad', patchCardsSquadHandler);
app.patch('/api/cards/squad', patchCardsSquadHandler);

// ─── Game period scores ──────────────────────────────────────────────────────

function periodToIndex(period) {
  const pm = period.match(/^P(\d+)$/);
  if (pm) return parseInt(pm[1], 10);
  const otm = period.match(/^OT(\d+)$/);
  if (otm) return 4 + parseInt(otm[1], 10);
  return 999;
}

async function rebuildPeriodScores(matchId) {
  const { rows } = await pool.query(
    `SELECT DISTINCT ON (period) period, score
     FROM game_events
     WHERE match_id = $1 AND score IS NOT NULL
     ORDER BY period, created_at DESC`,
    [matchId],
  );

  if (rows.length === 0) return [];

  rows.sort((a, b) => periodToIndex(a.period) - periodToIndex(b.period));

  let prevHome = 0;
  let prevAway = 0;
  const records = rows.map((row) => {
    const [homeStr, awayStr] = row.score.split('-');
    const homeRunning = parseInt(homeStr, 10);
    const awayRunning = parseInt(awayStr, 10);
    const rec = {
      match_id: matchId,
      period: row.period,
      period_index: periodToIndex(row.period),
      home_score: homeRunning - prevHome,
      away_score: awayRunning - prevAway,
      home_running_total: homeRunning,
      away_running_total: awayRunning,
    };
    prevHome = homeRunning;
    prevAway = awayRunning;
    return rec;
  });

  for (const r of records) {
    await pool.query(
      `INSERT INTO game_period_scores
         (match_id, period, period_index, home_score, away_score,
          home_running_total, away_running_total, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
       ON CONFLICT (match_id, period) DO UPDATE SET
         period_index         = EXCLUDED.period_index,
         home_score           = EXCLUDED.home_score,
         away_score           = EXCLUDED.away_score,
         home_running_total   = EXCLUDED.home_running_total,
         away_running_total   = EXCLUDED.away_running_total,
         updated_at           = NOW()`,
      [r.match_id, r.period, r.period_index, r.home_score, r.away_score,
       r.home_running_total, r.away_running_total],
    );
  }

  return records;
}

async function rebuildAllPeriodScores() {
  const { rows } = await pool.query(
    `SELECT DISTINCT match_id FROM game_events ORDER BY match_id`,
  );
  const results = [];
  for (const { match_id } of rows) {
    const records = await rebuildPeriodScores(Number(match_id));
    results.push({ match_id: Number(match_id), periods: records.length });
  }
  return results;
}

async function getPeriodScoresHandler(req, res) {
  const matchId = Number(req.params.matchId);
  if (Number.isNaN(matchId)) {
    return res.status(400).json({ error: 'matchId must be an integer.' });
  }
  try {
    const { rows } = await pool.query(
      `SELECT match_id, period, period_index, home_score, away_score,
              home_running_total, away_running_total
       FROM game_period_scores
       WHERE match_id = $1
       ORDER BY period_index ASC`,
      [matchId],
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

app.get('/games/:matchId/period-scores', getPeriodScoresHandler);
app.get('/api/games/:matchId/period-scores', getPeriodScoresHandler);

// ── Fan Shop vendor (owner) sessions ─────────────────────────────────────────

const shopVendorSessions = new Map();

function getShopVendorId(req) {
  const h = req.headers.authorization ?? '';
  if (!h.startsWith('Bearer ')) return null;
  const token = h.slice(7).trim();
  if (!token) return null;
  const s = shopVendorSessions.get(token);
  if (!s || s.expMs < Date.now()) {
    if (token) shopVendorSessions.delete(token);
    return null;
  }
  return s.shopVendorId;
}

async function shopVendorLoginHandler(req, res) {
  const username = req.body?.username?.trim();
  const password = req.body?.password;
  if (!username || !password) {
    return res.status(400).json({ error: 'username and password required' });
  }
  try {
    const { rows } = await pool.query(
      `SELECT shop_vendor_id, shop_name, username, password_hash
       FROM shop_vendors WHERE username = $1 LIMIT 1`,
      [username],
    );
    if (rows.length === 0) {
      return res.status(401).json({ error: 'Invalid shop vendor username or password' });
    }
    const ok = await bcrypt.compare(password, rows[0].password_hash);
    if (!ok) {
      return res.status(401).json({ error: 'Invalid shop vendor username or password' });
    }
    const token = crypto.randomBytes(32).toString('hex');
    shopVendorSessions.set(token, { shopVendorId: rows[0].shop_vendor_id, expMs: Date.now() + VENDOR_SESSION_MS });
    res.json({
      token,
      shop_vendor_id: rows[0].shop_vendor_id,
      shop_name: rows[0].shop_name,
      username: rows[0].username,
    });
  } catch (err) {
    if (err.code === '42P01') {
      return res.status(503).json({ error: 'shop_vendors table missing. Run DB/shop_vendor_schema.sql' });
    }
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

async function shopVendorListItemsHandler(req, res) {
  const svId = getShopVendorId(req);
  if (!svId) return res.status(401).json({ error: 'Shop vendor session required' });
  try {
    const { rows } = await pool.query(
      `SELECT
         i.item_id,
         i.name,
         i.subtitle,
         i.category,
         i.price::float8 AS price,
         i.original_price::float8 AS original_price,
         i.quantity_available,
         i.image_url,
         i.badge,
         i.is_featured,
         i.description,
         COALESCE(
           json_agg(json_build_object('photo_id', p.photo_id, 'photo_url', p.photo_url) ORDER BY p.photo_id)
           FILTER (WHERE p.photo_id IS NOT NULL),
           '[]'::json
         ) AS photos
       FROM shop_items i
       LEFT JOIN shop_item_photos p ON p.item_id = i.item_id
       WHERE i.shop_vendor_id = $1::int
       GROUP BY i.item_id
       ORDER BY i.is_featured DESC, i.item_id ASC`,
      [svId],
    );
    const items = rows.map((r) => ({
      ...r,
      photos: Array.isArray(r.photos) ? r.photos : JSON.parse(String(r.photos ?? '[]')),
    }));
    res.json({ items });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

async function shopVendorCreateItemHandler(req, res) {
  const svId = getShopVendorId(req);
  if (!svId) return res.status(401).json({ error: 'Shop vendor session required' });
  const name = (req.body?.name ?? '').trim();
  const category = (req.body?.category ?? 'Other').trim();
  const price = req.body?.price;
  const qty = req.body?.quantity_available ?? req.body?.quantityAvailable;
  if (!name || price == null || qty == null) {
    return res.status(400).json({ error: 'name, price, and quantity_available are required' });
  }
  const orig = req.body?.original_price ?? req.body?.originalPrice ?? null;
  const isFeatured = req.body?.is_featured === true || req.body?.isFeatured === true;
  try {
    const { rows } = await pool.query(
      `INSERT INTO shop_items
         (name, subtitle, category, price, original_price, quantity_available,
          image_url, badge, is_featured, description, shop_vendor_id)
       VALUES ($1,$2,$3,$4::numeric,$5::numeric,$6::int,$7,$8,$9::bool,$10,$11::int)
       RETURNING item_id, name, subtitle, category,
         price::float8, original_price::float8,
         quantity_available, image_url, badge, is_featured, description`,
      [
        name,
        req.body?.subtitle?.trim() || null,
        category,
        Number(price),
        orig != null ? Number(orig) : null,
        Number(qty),
        req.body?.image_url?.trim() || req.body?.imageUrl?.trim() || null,
        req.body?.badge?.trim() || null,
        isFeatured,
        req.body?.description?.trim() || null,
        svId,
      ],
    );
    res.status(201).json({ item: { ...rows[0], photos: [] } });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

async function shopVendorPatchItemHandler(req, res) {
  const svId = getShopVendorId(req);
  if (!svId) return res.status(401).json({ error: 'Shop vendor session required' });
  const itemId = Number(req.params.itemId);
  if (Number.isNaN(itemId)) return res.status(400).json({ error: 'invalid item id' });
  const b = req.body ?? {};
  try {
    const { rows } = await pool.query(
      `UPDATE shop_items SET
         name              = COALESCE($3::varchar,  name),
         subtitle          = COALESCE($4::varchar,  subtitle),
         category          = COALESCE($5::varchar,  category),
         price             = COALESCE($6::numeric,  price),
         original_price    = COALESCE($7::numeric,  original_price),
         quantity_available= COALESCE($8::int,      quantity_available),
         image_url         = COALESCE($9::text,     image_url),
         badge             = COALESCE($10::varchar, badge),
         is_featured       = COALESCE($11::bool,    is_featured),
         description       = COALESCE($12::text,    description)
       WHERE item_id = $2::int AND shop_vendor_id = $1::int
       RETURNING item_id, name, subtitle, category,
         price::float8, original_price::float8,
         quantity_available, image_url, badge, is_featured, description`,
      [
        svId, itemId,
        b.name?.trim() || null,
        'subtitle' in b ? (b.subtitle?.trim() || null) : undefined,
        b.category?.trim() || null,
        b.price != null ? Number(b.price) : null,
        'original_price' in b || 'originalPrice' in b
          ? (b.original_price ?? b.originalPrice) != null ? Number(b.original_price ?? b.originalPrice) : null
          : undefined,
        b.quantity_available != null || b.quantityAvailable != null
          ? Number(b.quantity_available ?? b.quantityAvailable) : null,
        'image_url' in b || 'imageUrl' in b ? (b.image_url?.trim() ?? b.imageUrl?.trim() ?? null) : undefined,
        'badge' in b ? (b.badge?.trim() || null) : undefined,
        b.is_featured != null || b.isFeatured != null ? Boolean(b.is_featured ?? b.isFeatured) : null,
        'description' in b ? (b.description?.trim() || null) : undefined,
      ],
    );
    if (rows.length === 0) return res.status(404).json({ error: 'Item not found' });
    res.json({ item: rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

async function shopVendorDeleteItemHandler(req, res) {
  const svId = getShopVendorId(req);
  if (!svId) return res.status(401).json({ error: 'Shop vendor session required' });
  const itemId = Number(req.params.itemId);
  if (Number.isNaN(itemId)) return res.status(400).json({ error: 'invalid item id' });
  try {
    const { rowCount } = await pool.query(
      `DELETE FROM shop_items WHERE item_id = $2::int AND shop_vendor_id = $1::int`,
      [svId, itemId],
    );
    if (!rowCount) return res.status(404).json({ error: 'Item not found' });
    res.status(204).end();
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

async function shopVendorAddPhotoHandler(req, res) {
  const svId = getShopVendorId(req);
  if (!svId) return res.status(401).json({ error: 'Shop vendor session required' });
  const itemId = Number(req.params.itemId);
  const url = (req.body?.photo_url ?? req.body?.photoUrl ?? '').trim();
  if (Number.isNaN(itemId) || !url) {
    return res.status(400).json({ error: 'photo_url required' });
  }
  try {
    const { rows } = await pool.query(
      `INSERT INTO shop_item_photos (item_id, photo_url)
       SELECT i.item_id, $3
       FROM shop_items i
       WHERE i.item_id = $2::int AND i.shop_vendor_id = $1::int
       RETURNING photo_id, item_id, photo_url`,
      [svId, itemId, url],
    );
    if (rows.length === 0) return res.status(404).json({ error: 'Item not found' });
    res.status(201).json({ photo: rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

async function shopVendorDeletePhotoHandler(req, res) {
  const svId = getShopVendorId(req);
  if (!svId) return res.status(401).json({ error: 'Shop vendor session required' });
  const photoId = Number(req.params.photoId);
  if (Number.isNaN(photoId)) return res.status(400).json({ error: 'invalid photo id' });
  try {
    const { rowCount } = await pool.query(
      `DELETE FROM shop_item_photos p
       USING shop_items i
       WHERE p.photo_id = $2::int
         AND p.item_id = i.item_id
         AND i.shop_vendor_id = $1::int`,
      [svId, photoId],
    );
    if (!rowCount) return res.status(404).json({ error: 'Photo not found' });
    res.status(204).end();
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

app.post('/auth/shop-vendor-login', shopVendorLoginHandler);
app.post('/api/auth/shop-vendor-login', shopVendorLoginHandler);
app.get('/shop-vendor/items', shopVendorListItemsHandler);
app.get('/api/shop-vendor/items', shopVendorListItemsHandler);
app.post('/shop-vendor/items', shopVendorCreateItemHandler);
app.post('/api/shop-vendor/items', shopVendorCreateItemHandler);
app.patch('/shop-vendor/items/:itemId', shopVendorPatchItemHandler);
app.patch('/api/shop-vendor/items/:itemId', shopVendorPatchItemHandler);
app.delete('/shop-vendor/items/:itemId', shopVendorDeleteItemHandler);
app.delete('/api/shop-vendor/items/:itemId', shopVendorDeleteItemHandler);
app.post('/shop-vendor/items/:itemId/photos', shopVendorAddPhotoHandler);
app.post('/api/shop-vendor/items/:itemId/photos', shopVendorAddPhotoHandler);
app.delete('/shop-vendor/photos/:photoId', shopVendorDeletePhotoHandler);
app.delete('/api/shop-vendor/photos/:photoId', shopVendorDeletePhotoHandler);

// ── Fan Shop ──────────────────────────────────────────────────────────────────

async function listShopItemsHandler(req, res) {
  try {
    const category = req.query.category ?? req.query.category_name ?? null;
    const { rows } = category && category !== 'All Items'
      ? await pool.query(
          `SELECT item_id, name, subtitle, category, price, original_price,
                  quantity_available, image_url, badge, is_featured, description
           FROM shop_items
           WHERE LOWER(category) = LOWER($1)
           ORDER BY is_featured DESC, item_id ASC`,
          [category],
        )
      : await pool.query(
          `SELECT item_id, name, subtitle, category, price, original_price,
                  quantity_available, image_url, badge, is_featured, description
           FROM shop_items
           ORDER BY is_featured DESC, item_id ASC`,
        );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

async function getShopItemHandler(req, res) {
  const itemId = Number(req.params.itemId);
  if (Number.isNaN(itemId)) {
    return res.status(400).json({ error: 'itemId must be an integer' });
  }
  try {
    const { rows } = await pool.query(
      `SELECT item_id, name, subtitle, category, price, original_price,
              quantity_available, image_url, badge, is_featured, description
       FROM shop_items WHERE item_id = $1`,
      [itemId],
    );
    if (rows.length === 0) return res.status(404).json({ error: 'Item not found' });
    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  }
}

app.get('/shop/items', listShopItemsHandler);
app.get('/api/shop/items', listShopItemsHandler);
app.get('/shop/items/:itemId', getShopItemHandler);
app.get('/api/shop/items/:itemId', getShopItemHandler);

// ─────────────────────────────────────────────────────────────────────────────

const port = Number(process.env.PORT ?? 3000);
app.listen(port, '0.0.0.0', () => {
  console.log(`BasketballApp API listening on http://127.0.0.1:${port}`);
  console.log('  GET /teams');
  console.log('  GET /api/teams');
  console.log('  POST /packs/open');
  console.log('  POST /api/packs/open');
  console.log('  POST /auth/register  POST /auth/login');
  console.log('  GET /card-image/:id  (Google Drive proxy for card art)');
  console.log('  GET /collection?user_id=…  (&duplicates_only=1 for duplicate stacks)');
  console.log('  GET /collection-duplicates?user_id=…  (alias for duplicates)');
  console.log('  GET /cards/catalog  PUT/PATCH /wishlist  trade: /trade/rooms …');
  console.log('  GET /public/courts  GET /public/courts/:id/playgrounds  GET /public/playgrounds/:id/availability?date=…');
  console.log('  POST /public/reservations { user_id, availability_id }');
  console.log(
    '  GET /games  GET /games/weeks  GET /games/team-stats  GET /games/player-leaders  GET /games/player-leaders/detail  GET /games/:matchId  GET /games/:matchId/events  GET /games/:matchId/boxscore',
  );
  console.log('  GET/POST/PATCH /cards/squad …user_id=… (1v1 lineups; POST creates, PATCH updates)');
  console.log('  1v1 friend: POST/GET /cards/one-v-one/rooms … squad-pick, lead, respond');
});
