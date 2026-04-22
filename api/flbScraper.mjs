/**
 * flbScraper.mjs
 * Scrapes the FLB Genius Sports portal (https://flb.web.geniussports.com) for
 * Lebanese basketball games, boxscores and play-by-play.
 *
 * All three pages are rendered by a single-page app, so the page HTML that
 * arrives over axios is just the SPA shell with no data — everything is
 * populated at runtime by JS. That is why this module drives a headless
 * Chromium via Playwright for every fetch. A single browser instance is
 * reused across calls; contexts + pages are short-lived.
 *
 * Exports:
 *   - getSchedule(competitionId)
 *   - getBoxscore(competitionId, matchId)
 *   - getPlayByPlay(competitionId, matchId)
 *   - getMatchBundle(competitionId, matchId)
 *   - shutdownBrowser()
 */

import * as cheerio from 'cheerio';
import { chromium } from 'playwright';
import crypto from 'node:crypto';

const BASE = 'https://flb.web.geniussports.com';

const DEFAULT_NAV_TIMEOUT_MS   = 45_000;
const DEFAULT_WAIT_TIMEOUT_MS  = 25_000;
const DEFAULT_IDLE_TIMEOUT_MS  = 8_000;
const DEFAULT_SETTLE_MS        = 1_200;
const DEFAULT_MAX_ATTEMPTS     = 2;

const USER_AGENT =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

// ─────────────────────────────────────────────────────────────────────────────
// Browser lifecycle (singleton, lazy, auto-heal)
// ─────────────────────────────────────────────────────────────────────────────

let _browserPromise = null;

async function launchBrowser() {
  // Default args are safe on Windows, macOS, and most Linux containers.
  // `--single-process` is only useful in very constrained environments and
  // crashes Chromium on Windows/macOS — opt-in via FLB_CHROMIUM_SINGLE_PROCESS=1.
  const args = [
    '--no-sandbox',
    '--disable-setuid-sandbox',
    '--disable-dev-shm-usage',
    '--disable-gpu',
  ];
  if (process.env.FLB_CHROMIUM_SINGLE_PROCESS === '1') args.push('--single-process');

  console.log('[FLB] Launching headless Chromium…');
  const browser = await chromium.launch({ headless: true, args });
  browser.on('disconnected', () => {
    console.warn('[FLB] Chromium disconnected — will relaunch on next request');
    _browserPromise = null;
  });
  console.log('[FLB] Chromium ready');
  return browser;
}

async function getBrowser() {
  if (!_browserPromise) _browserPromise = launchBrowser();
  try {
    const browser = await _browserPromise;
    if (!browser.isConnected()) {
      _browserPromise = null;
      return getBrowser();
    }
    return browser;
  } catch (err) {
    _browserPromise = null;
    throw err;
  }
}

/** Close the shared browser. Safe to call more than once. */
export async function shutdownBrowser() {
  const p = _browserPromise;
  _browserPromise = null;
  if (!p) return;
  try {
    const browser = await p;
    await browser.close();
    console.log('[FLB] Chromium closed');
  } catch (err) {
    console.warn('[FLB] shutdownBrowser:', err?.message ?? err);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// URL helpers
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Build a Genius Sports wrapper URL. The site always expects a trailing `?`
 * on the WHurl path before it is percent-encoded.
 */
function gsUrl(path) {
  const withTrailing = path.endsWith('?') ? path : `${path}?`;
  return `${BASE}/competitions/?WHurl=${encodeURIComponent(withTrailing)}`;
}

function scheduleUrl(competitionId) {
  return gsUrl(`/competition/${competitionId}/schedule`);
}
function summaryUrl(competitionId, matchId) {
  return gsUrl(`/competition/${competitionId}/match/${matchId}/summary`);
}
function boxscoreUrl(competitionId, matchId) {
  return gsUrl(`/competition/${competitionId}/match/${matchId}/boxscore`);
}
function playByPlayUrl(competitionId, matchId) {
  return gsUrl(`/competition/${competitionId}/match/${matchId}/playbyplay`);
}
function shotChartUrl(competitionId, matchId) {
  return gsUrl(`/competition/${competitionId}/match/${matchId}/shotchart`);
}

// ─────────────────────────────────────────────────────────────────────────────
// Rendered fetch — Playwright with retries
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Open a URL in a fresh context, wait for the given selector, return HTML.
 * Falls back to networkidle if the selector never appears. Retries on error.
 */
async function fetchRendered(url, opts = {}) {
  const {
    waitForSelector,
    navTimeout  = DEFAULT_NAV_TIMEOUT_MS,
    waitTimeout = DEFAULT_WAIT_TIMEOUT_MS,
    idleTimeout = DEFAULT_IDLE_TIMEOUT_MS,
    settleMs    = DEFAULT_SETTLE_MS,
    maxAttempts = DEFAULT_MAX_ATTEMPTS,
  } = opts;

  let lastErr = null;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    const browser = await getBrowser();
    const context = await browser.newContext({
      userAgent: USER_AGENT,
      viewport:  { width: 1280, height: 900 },
      extraHTTPHeaders: {
        'Accept-Language': 'en-US,en;q=0.9',
        Referer: `${BASE}/competitions/`,
      },
    });
    const page = await context.newPage();

    try {
      await page.goto(url, { waitUntil: 'domcontentloaded', timeout: navTimeout });

      if (waitForSelector) {
        try {
          await page.waitForSelector(waitForSelector, { timeout: waitTimeout, state: 'attached' });
        } catch {
          // selector may never appear (e.g. postponed match with no table) —
          // fall through to networkidle so we at least capture the SPA DOM.
        }
      }

      try {
        await page.waitForLoadState('networkidle', { timeout: idleTimeout });
      } catch { /* networkidle not required */ }

      if (settleMs > 0) await page.waitForTimeout(settleMs);

      const html = await page.content();
      const finalUrl = page.url();
      return { html, finalUrl };
    } catch (err) {
      lastErr = err;
      console.warn(
        `[FLB] fetchRendered attempt ${attempt}/${maxAttempts} failed (${url}): ${err?.message ?? err}`,
      );
    } finally {
      await page.close().catch(() => {});
      await context.close().catch(() => {});
    }
  }

  throw lastErr ?? new Error(`fetchRendered failed: ${url}`);
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

function cleanText(s) {
  return (s ?? '').replace(/ /g, ' ').replace(/\s+/g, ' ').trim();
}

function toAbsoluteUrl(src) {
  if (!src) return null;
  if (src.startsWith('http://') || src.startsWith('https://')) return src;
  if (src.startsWith('//')) return `https:${src}`;
  return `${BASE}${src.startsWith('/') ? '' : '/'}${src}`;
}

function extractIdFromPath(href, segment) {
  if (!href) return null;
  // Works on both raw links like /team/86486? and on wrapped Genius Sports URLs
  // whose href is `...?WHurl=%2Fcompetition%2F42001%2Fteam%2F86486%3F`.
  const re = new RegExp(`(?:/|%2F)${segment}(?:/|%2F)(\\d+)`, 'i');
  const m  = href.match(re);
  return m ? Number(m[1]) : null;
}

function extractMatchIdFromRowId(rowId) {
  if (!rowId) return null;
  const m = rowId.match(/(\d{5,})/);
  return m ? Number(m[1]) : null;
}

function normalizeStatusFromClass(classAttr) {
  const s = (classAttr ?? '').toUpperCase();
  if (s.includes('STATUS_COMPLETE') || s.includes('STATUS_FINAL'))   return 'final';
  if (s.includes('STATUS_LIVE') || s.includes('STATUS_INPROGRESS'))  return 'live';
  if (s.includes('STATUS_POSTPONED') || s.includes('STATUS_CANCEL')) return 'postponed';
  if (s.includes('STATUS_SCHEDULED') || s.includes('STATUS_FUTURE')) return 'scheduled';
  return null;
}

function normalizeStatusFromText(raw) {
  const s = (raw ?? '').trim().toLowerCase();
  if (!s) return null;
  if (/(^|\s)(final|finished|ft|complete|completed)(\s|$)/.test(s)) return 'final';
  if (/live|q[1-4]|ot|half.?time|period/.test(s)) return 'live';
  if (/postpone|cancel/.test(s)) return 'postponed';
  return 'scheduled';
}

function parseIntOrNull(txt) {
  const s = cleanText(txt);
  if (!s || s === '-' || s === '&nbsp;') return null;
  const n = Number(s.replace(/[^\d.-]/g, ''));
  return Number.isFinite(n) ? Math.trunc(n) : null;
}

// ─────────────────────────────────────────────────────────────────────────────
// 1) Schedule
// ─────────────────────────────────────────────────────────────────────────────

function parseSchedule($, competitionId) {
  const games = [];
  const seen = new Set();

  $('.match-wrap').each((_i, el) => {
    try {
      const $el   = $(el);
      const rowId = $el.attr('id') || '';
      const cls   = $el.attr('class') || '';

      const matchId = extractMatchIdFromRowId(rowId);
      if (!matchId || seen.has(matchId)) return;
      seen.add(matchId);

      // Status — prefer the STATUS_* class, fall back to the visible text
      const statusFromClass = normalizeStatusFromClass(cls);
      const rawNotLive = cleanText($el.find('.notlive .matchStatus').first().text());
      const rawLive    = cleanText($el.find('.livenow.livedetails .matchStatus').first().text());
      const rawStatus  = rawNotLive || rawLive || '';
      const status     = statusFromClass ?? normalizeStatusFromText(rawStatus) ?? 'scheduled';
      const isLive     = status === 'live';

      // Date / time / venue
      const dateTimeText = cleanText($el.find('.match-time span').first().text());
      const venueAnchor  = $el.find('.match-venue a.venuename, .match-venue a').first();
      const venue        = cleanText(venueAnchor.text());
      const venueId      = extractIdFromPath(venueAnchor.attr('href') || '', 'venue');

      // Home team
      const $home        = $el.find('.home-team').first();
      const homeAnchor   = $home.find('a[href*="/team/"], a[href*="%2Fteam%2F"]').first();
      const homeId       = extractIdFromPath(homeAnchor.attr('href') || '', 'team');
      const homeName     = cleanText(
        $home.find('.team-name-full').first().text()
        || $home.find('.teamnames').first().text()
        || $home.find('.team-name').first().text()
        || homeAnchor.attr('title')
        || homeAnchor.find('img').attr('alt'),
      );
      const homeLogo  = toAbsoluteUrl($home.find('img').first().attr('src'));
      const homeScore = parseIntOrNull($home.find('.team-score .fake-cell').first().text());

      // Away team
      const $away        = $el.find('.away-team').first();
      const awayAnchor   = $away.find('a[href*="/team/"], a[href*="%2Fteam%2F"]').first();
      const awayId       = extractIdFromPath(awayAnchor.attr('href') || '', 'team');
      const awayName     = cleanText(
        $away.find('.team-name-full').first().text()
        || $away.find('.teamnames').first().text()
        || $away.find('.team-name').first().text()
        || awayAnchor.attr('title')
        || awayAnchor.find('img').attr('alt'),
      );
      const awayLogo  = toAbsoluteUrl($away.find('img').first().attr('src'));
      const awayScore = parseIntOrNull($away.find('.team-score .fake-cell').first().text());

      games.push({
        competitionId: Number(competitionId),
        matchId,
        status,
        rawStatus,
        isLive,
        dateTimeText,
        venue,
        venueId,
        homeTeam: { id: homeId, name: homeName, logoUrl: homeLogo, score: homeScore },
        awayTeam: { id: awayId, name: awayName, logoUrl: awayLogo, score: awayScore },
        summaryUrl:    summaryUrl(competitionId, matchId),
        boxScoreUrl:   boxscoreUrl(competitionId, matchId),
        playByPlayUrl: playByPlayUrl(competitionId, matchId),
        shotChartUrl:  shotChartUrl(competitionId, matchId),
      });
    } catch (err) {
      console.error('[FLB][schedule] row parse error:', err?.message ?? err);
    }
  });

  return games;
}

/**
 * @param {number|string} competitionId
 * @returns {Promise<Array>}
 */
export async function getSchedule(competitionId) {
  const url = scheduleUrl(competitionId);
  const { html, finalUrl } = await fetchRendered(url, { waitForSelector: '.match-wrap' });
  const $ = cheerio.load(html);

  const rows = $('.match-wrap').length;
  console.log(
    `[FLB][schedule] compId=${competitionId} rows=${rows} len=${html.length} final=${finalUrl}`,
  );
  if (rows === 0) {
    console.warn(
      `[FLB][schedule] compId=${competitionId} no .match-wrap rows — title="${cleanText($('title').text())}"`,
    );
    return [];
  }

  const games = parseSchedule($, competitionId);
  console.log(`[FLB][schedule] compId=${competitionId} parsed=${games.length}`);
  return games;
}

// ─────────────────────────────────────────────────────────────────────────────
// 2) Boxscore
// ─────────────────────────────────────────────────────────────────────────────

function parseMatchHeader($, competitionId, matchId) {
  const $header    = $('.match-header').first();
  const wrapClass  = $header.attr('class') || '';

  const $home = $header.find('.home-wrapper').first();
  const $away = $header.find('.away-wrapper').first();

  const homeAnchor = $home.find('a[href*="/team/"], a[href*="%2Fteam%2F"]').first();
  const awayAnchor = $away.find('a[href*="/team/"], a[href*="%2Fteam%2F"]').first();

  const homeName = cleanText(
    $home.find('.name a').first().text()
    || $home.find('.name').first().text()
    || homeAnchor.attr('title')
    || homeAnchor.find('img').attr('alt'),
  );
  const awayName = cleanText(
    $away.find('.name a').first().text()
    || $away.find('.name').first().text()
    || awayAnchor.attr('title')
    || awayAnchor.find('img').attr('alt'),
  );

  const homeScore = parseIntOrNull($home.find('.score').first().text());
  const awayScore = parseIntOrNull($away.find('.score').first().text());

  const homeId = extractIdFromPath(homeAnchor.attr('href') || '', 'team');
  const awayId = extractIdFromPath(awayAnchor.attr('href') || '', 'team');

  const homeLogo = toAbsoluteUrl($home.find('img').first().attr('src'));
  const awayLogo = toAbsoluteUrl($away.find('img').first().attr('src'));

  const rawStatus = cleanText(
    $header.find('.status.notlive').first().text()
    || $header.find('.status.livenow .matchStatus').first().text(),
  );
  const status =
    normalizeStatusFromClass(wrapClass) ??
    normalizeStatusFromText(rawStatus) ??
    'scheduled';

  const dateTimeText = cleanText($header.find('.match-time span').first().text());

  return {
    competitionId: Number(competitionId),
    matchId: Number(matchId),
    status,
    rawStatus,
    dateTimeText,
    homeTeam: { id: homeId, name: homeName, logoUrl: homeLogo, score: homeScore },
    awayTeam: { id: awayId, name: awayName, logoUrl: awayLogo, score: awayScore },
  };
}

function parseBoxscoreTable($, $h4, $table, side) {
  const teamAnchor = $h4.closest('a');
  const teamId   = extractIdFromPath(teamAnchor.attr('href') || '', 'team');
  const teamName = cleanText($h4.text());

  const headers = [];
  $table.find('thead tr th').each((_i, th) => headers.push(cleanText($(th).text())));

  const players = [];
  $table.find('tbody tr').each((_i, tr) => {
    const $tr    = $(tr);
    const $cells = $tr.find('td');
    if ($cells.length === 0) return;

    const playerNumber = cleanText($cells.eq(0).text());
    const $nameCell    = $cells.eq(1);
    const playerName   = cleanText($nameCell.find('a').first().text() || $nameCell.text());
    if (!playerName) return;
    const playerLink   = $nameCell.find('a').first().attr('href') || '';
    const playerId     = extractIdFromPath(playerLink, 'person') ?? extractIdFromPath(playerLink, 'player');

    const stats = {};
    headers.forEach((h, idx) => {
      if (!h || idx < 2) return;
      const raw = cleanText($cells.eq(idx).text());
      if (raw === '') return;
      stats[h] = raw;
    });

    players.push({ playerId, playerNumber, playerName, stats });
  });

  const totals = {};
  const $footCells = $table.find('tfoot tr').first().find('td');
  if ($footCells.length > 0) {
    // Layout observed: td[0]="Totals", td[1]="" (no-number cell),
    // td[2..] correspond to headers[2..] — i.e. the same alignment as tbody rows.
    headers.forEach((h, idx) => {
      if (!h || idx < 2) return;
      const raw = cleanText($footCells.eq(idx).text());
      if (raw === '') return;
      totals[h] = raw;
    });
  }

  return { side, teamId, teamName, totals, players };
}

/**
 * @param {number|string} competitionId
 * @param {number|string} matchId
 * @returns {Promise<{ header: object, teams: Array, players: Array }>}
 */
export async function getBoxscore(competitionId, matchId) {
  const url = boxscoreUrl(competitionId, matchId);
  const { html } = await fetchRendered(url, { waitForSelector: '.boxscore table.tableClass tbody tr' });
  const $ = cheerio.load(html);

  const header = parseMatchHeader($, competitionId, matchId);

  const teams = [];
  // Each team section is: <a><h4>Team Name</h4></a><div class="table-wrap"><table class="tableClass">
  const $h4s = $('.boxscore > a > h4, .boxscore h4').filter((_i, el) => {
    const txt = cleanText($(el).text());
    return txt && txt.toLowerCase() !== 'legend';
  });

  $h4s.each((idx, el) => {
    const $h4    = $(el);
    const $table = $h4.closest('a').nextAll('.table-wrap').find('table.tableClass').first();
    if ($table.length === 0) return;
    const side   = idx === 0 ? 'home' : 'away';
    teams.push(parseBoxscoreTable($, $h4, $table, side));
  });

  // Flatten players for convenience
  const players = teams.flatMap((t) =>
    (t.players ?? []).map((p) => ({
      side:          t.side,
      teamId:        t.teamId,
      teamName:      t.teamName,
      playerId:      p.playerId,
      playerNumber:  p.playerNumber,
      playerName:    p.playerName,
      stats:         p.stats,
    })),
  );

  console.log(
    `[FLB][boxscore] matchId=${matchId} status=${header.status} teams=${teams.length} players=${players.length}`,
  );

  return { header, teams, players };
}

// ─────────────────────────────────────────────────────────────────────────────
// 3) Play-by-play
// ─────────────────────────────────────────────────────────────────────────────

const PBPTY_TO_EVENT_TYPE = {
  '2pt':                '2pt',
  '3pt':                '3pt',
  freethrow:            'freethrow',
  rebound:              'rebound',
  assist:               'assist',
  steal:                'steal',
  block:                'block',
  turnover:             'turnover',
  foul:                 'foul',
  foulon:               'foul_drawn',
  substitution:         'substitution',
  jumpball:             'jumpball',
  timeout:              'timeout',
  period:               'period_marker',
  game:                 'game_marker',
  headcoachchallenge:   'challenge',
};

function classifyEvent(classes) {
  const tokens = (classes ?? '').split(/\s+/);
  for (const t of tokens) {
    const m = t.match(/^pbpty(.+)$/);
    if (m) return PBPTY_TO_EVENT_TYPE[m[1]] ?? m[1];
  }
  return 'event';
}

function extractPeriodNumber(classes) {
  const m = (classes ?? '').match(/\bper_(\d+)\b/);
  return m ? Number(m[1]) : null;
}

function isOvertime(classes) {
  return /\bper_ot\b/.test(classes ?? '');
}

function teamSideFromClass(classes) {
  if (/\bpbpt1\b/.test(classes ?? '')) return 'home';
  if (/\bpbpt2\b/.test(classes ?? '')) return 'away';
  return null;
}

function parsePlayerFromAction(actionText) {
  if (!actionText) return { playerNumber: null, player: null, action: cleanText(actionText) };
  // Pattern: "<NUMBER>, <Player Name>, rest of action"
  const m = actionText.match(/^\s*(\d+)\s*,\s*([^,]+?)\s*,\s*(.+?)\s*$/);
  if (m) {
    return {
      playerNumber: m[1],
      player:       cleanText(m[2]),
      action:       cleanText(m[3]),
    };
  }
  // Pattern: "<NUMBER>, <Player Name>" (no further action) — e.g. substitutions
  const m2 = actionText.match(/^\s*(\d+)\s*,\s*([^,]+?)\s*$/);
  if (m2) {
    return {
      playerNumber: m2[1],
      player:       cleanText(m2[2]),
      action:       '',
    };
  }
  return { playerNumber: null, player: null, action: cleanText(actionText) };
}

function stableEventId(matchId, period, clock, teamSide, eventType, actionText) {
  const key = [matchId, period ?? '', clock ?? '', teamSide ?? '', eventType ?? '', actionText ?? ''].join('|');
  const hash = crypto.createHash('sha1').update(key).digest('hex').slice(0, 16);
  return `${matchId}_${hash}`;
}

function parsePlayByPlay($, competitionId, matchId) {
  const header = parseMatchHeader($, competitionId, matchId);
  const homeName = header.homeTeam.name;
  const awayName = header.awayTeam.name;

  const events = [];
  const seen = new Set();

  $('div.pbpa').each((_i, el) => {
    try {
      const $el     = $(el);
      const classes = $el.attr('class') || '';

      const eventType = classifyEvent(classes);
      const teamSide  = teamSideFromClass(classes);
      const periodNum = extractPeriodNumber(classes);
      const ot        = isOvertime(classes);
      const period    = ot ? (periodNum ? `OT${periodNum}` : 'OT') : (periodNum ? `P${periodNum}` : '');

      // Prefer the inline pbp-period label when present
      const periodLabel = cleanText($el.find('.pbp-period').first().text()) || period;

      // Clock is the text of .pbp-time minus the period span and the score span
      const $time = $el.find('.pbp-time').first();
      let clock = '';
      if ($time.length) {
        const clone = $time.clone();
        clone.find('.pbp-period, .pbpsc').remove();
        clock = cleanText(clone.text());
      }

      const score      = cleanText($el.find('.pbpsc').first().text());
      const actionRaw  = cleanText($el.find('.pbp-action').first().text());
      const { playerNumber, player, action } = parsePlayerFromAction(actionRaw);

      const teamName =
        teamSide === 'home' ? homeName :
        teamSide === 'away' ? awayName : null;

      const isScoringEvent =
        /\bscaction\b/.test(classes) ||
        (['2pt', '3pt', 'freethrow'].includes(eventType) && /\bmade\b/i.test(actionRaw));

      const eventId = stableEventId(matchId, periodLabel, clock, teamSide, eventType, actionRaw);
      if (seen.has(eventId)) return;
      seen.add(eventId);

      events.push({
        eventId,
        period:         periodLabel,
        clock,
        score:          score || null,
        teamSide,
        teamName,
        player,
        playerNumber,
        actionText:     action || actionRaw,
        eventType,
        isScoringEvent,
      });
    } catch (err) {
      console.error('[FLB][pbp] row parse error:', err?.message ?? err);
    }
  });

  return { header, events };
}

/**
 * @param {number|string} competitionId
 * @param {number|string} matchId
 * @returns {Promise<{ header: object, events: Array }>}
 */
export async function getPlayByPlay(competitionId, matchId) {
  const url = playByPlayUrl(competitionId, matchId);
  const { html } = await fetchRendered(url, { waitForSelector: '.play-by-play, .match-header' });
  const $ = cheerio.load(html);

  const result = parsePlayByPlay($, competitionId, matchId);
  console.log(
    `[FLB][pbp] matchId=${matchId} status=${result.header.status} events=${result.events.length}`,
  );
  return result;
}

// ─────────────────────────────────────────────────────────────────────────────
// 4) Match bundle
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Fetch boxscore + play-by-play in parallel.
 * Any one failure is captured but doesn't block the other.
 */
export async function getMatchBundle(competitionId, matchId) {
  const [box, pbp] = await Promise.allSettled([
    getBoxscore(competitionId, matchId),
    getPlayByPlay(competitionId, matchId),
  ]);

  if (box.status === 'rejected') {
    console.warn(`[FLB][bundle] boxscore failed matchId=${matchId}:`, box.reason?.message ?? box.reason);
  }
  if (pbp.status === 'rejected') {
    console.warn(`[FLB][bundle] pbp failed matchId=${matchId}:`, pbp.reason?.message ?? pbp.reason);
  }

  return {
    boxscore:   box.status === 'fulfilled' ? box.value : null,
    playByPlay: pbp.status === 'fulfilled' ? pbp.value : null,
  };
}
