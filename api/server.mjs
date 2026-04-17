import bcrypt from 'bcryptjs';
import crypto from 'crypto';
import cors from 'cors';
import express from 'express';
import pg from 'pg';
import dotenv from 'dotenv';

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

async function listTeams(_req, res) {
  try {
    const { rows } = await pool.query(
      'SELECT team_id, team_name FROM teams ORDER BY team_name ASC',
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

async function getTeamDetails(req, res) {
  const teamId = Number(req.params.id);
  if (Number.isNaN(teamId)) {
    return res.status(400).json({ error: 'team id must be an integer.' });
  }
  try {
    const { rows: teamRows } = await pool.query(
      'SELECT team_id, team_name FROM teams WHERE team_id = $1',
      [teamId]
    );
    if (teamRows.length === 0) {
      return res.status(404).json({ error: 'Team not found' });
    }
    const team = teamRows[0];

    const { rows: playerRows } = await pool.query(
      'SELECT player_id, jersey_number, first_name, last_name, nationality, position, dominant_hand, dob FROM players WHERE team_id = $1 ORDER BY jersey_number ASC',
      [teamId]
    );

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

    res.json({ team, players: playerRows, trophies, stadium });
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
 * Import chance = slot1: 10% import (else base); if import pool empty on 10% roll, slot1 is base.
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
    const rollImport = Math.random() < 0.1;

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
  if (nationality === 'Lebanon') {
    cond.push(
      `UPPER(TRIM(COALESCE(p.nationality, ''))) IN ('LB','LEB','LEBANON','LBN')`,
    );
  } else if (nationality === 'USA') {
    cond.push(`UPPER(TRIM(COALESCE(p.nationality, ''))) IN ('US','USA','UNITED STATES')`);
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
});
