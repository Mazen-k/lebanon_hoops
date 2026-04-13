import bcrypt from 'bcryptjs';
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
    res.json({ team, players: playerRows });
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
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message ?? String(err) });
  } finally {
    client.release();
  }
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
});
