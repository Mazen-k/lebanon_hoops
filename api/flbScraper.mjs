/**
 * flbScraper.mjs
 * Scrapes FLB (Genius Sports) pages for Lebanese basketball data.
 *
 * Schedule uses Playwright (headless Chromium) because the page is JS-rendered.
 * Boxscore / play-by-play use axios (lighter) — upgrade to Playwright if needed.
 *
 * Exports: getSchedule, getBoxscore, getPlayByPlay, getMatchBundle
 */

import axios from 'axios';
import * as cheerio from 'cheerio';
import { chromium } from 'playwright';

const BASE = 'https://flb.web.geniussports.com';

// ─────────────────────────────────────────────────────────────────────────────
// Shared browser instance (lazy-initialised, reused across calls)
// ─────────────────────────────────────────────────────────────────────────────

let _browser = null;

async function getBrowser() {
  if (_browser && _browser.isConnected()) return _browser;
  console.log('[FLB] Launching headless Chromium browser...');
  _browser = await chromium.launch({
    headless: true,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-gpu',
      '--single-process',          // important for Render / Docker environments
    ],
  });
  console.log('[FLB] Browser launched');
  return _browser;
}

/**
 * Open a URL in a new browser page, wait for JS to render, return the HTML.
 * Waits for .match-wrap to appear, or falls back to networkidle, then a hard timeout.
 * @param {string} url
 * @param {{ waitForSelector?: string, timeoutMs?: number }} [opts]
 * @returns {Promise<{ html: string, finalUrl: string }>}
 */
async function fetchWithBrowser(url, opts = {}) {
  const { waitForSelector = '.match-wrap', timeoutMs = 30_000 } = opts;
  const browser = await getBrowser();
  const context = await browser.newContext({
    userAgent:
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    extraHTTPHeaders: {
      'Accept-Language': 'en-US,en;q=0.9',
      Referer: `${BASE}/competitions/`,
    },
  });
  const page = await context.newPage();

  try {
    console.log(`[FLB] Browser navigating to: ${url}`);
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: timeoutMs });

    // Try to wait for real content; fall back to networkidle if selector never appears
    try {
      await page.waitForSelector(waitForSelector, { timeout: 15_000 });
      console.log(`[FLB] Selector "${waitForSelector}" found on page`);
    } catch {
      console.log(`[FLB] Selector "${waitForSelector}" not found — waiting for networkidle`);
      try {
        await page.waitForLoadState('networkidle', { timeout: 10_000 });
      } catch {
        console.log('[FLB] networkidle timeout — proceeding with current DOM');
      }
    }

    const finalUrl = page.url();
    const html = await page.content();
    console.log(`[FLB] Page loaded. Final URL: ${finalUrl} | html.length: ${html.length}`);
    return { html, finalUrl };
  } finally {
    await page.close();
    await context.close();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lightweight axios client (used for boxscore / play-by-play only)
// ─────────────────────────────────────────────────────────────────────────────

const http = axios.create({
  timeout: 20_000,
  maxRedirects: 10,
  headers: {
    'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Cache-Control': 'no-cache',
    Referer: `${BASE}/competitions/`,
  },
});

async function fetchCheerio(url) {
  const response = await http.get(url, { responseType: 'text' });
  const html = String(response.data ?? '');
  const finalUrl = response.request?.res?.responseUrl ?? response.config?.url ?? url;
  const $ = cheerio.load(html);
  return { $, html, finalUrl };
}

// ─────────────────────────────────────────────────────────────────────────────
// URL builder
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Build the correct FLB Genius Sports URL.
 * Always appends a trailing ? to the WHurl path before encoding.
 */
function gsUrl(path) {
  const withTrailing = path.endsWith('?') ? path : `${path}?`;
  return `${BASE}/competitions/?WHurl=${encodeURIComponent(withTrailing)}`;
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

function normalizeStatus(raw) {
  if (!raw) return 'scheduled';
  const s = raw.trim().toLowerCase();
  if (s === 'final' || s === 'finished' || s === 'ft') return 'final';
  if (
    s.includes('live') ||
    s.includes('q1') || s.includes('q2') || s.includes('q3') || s.includes('q4') ||
    s.includes('ot') || s.includes('halftime') || s.includes('half time') ||
    /^\d+:\d+$/.test(s)
  ) return 'live';
  if (s.includes('postpone') || s.includes('cancel')) return 'postponed';
  return 'scheduled';
}

function extractId(href, segment) {
  if (!href) return null;
  const re = new RegExp(`/${segment}/(\\d+)`);
  const m = href.match(re);
  return m ? Number(m[1]) : null;
}

function matchIdFromRowId(rowId) {
  if (!rowId) return null;
  const m = rowId.match(/(\d{5,})/);
  return m ? Number(m[1]) : null;
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. getSchedule  (Playwright)
// ─────────────────────────────────────────────────────────────────────────────

function parseScheduleRows($, competitionId) {
  const games = [];

  const ROW_SELECTOR =
    '.match-wrap, #schedule .match-wrap, table.schedule tbody tr, .match-row, [class*="game-row"], [class*="schedule-row"]';

  $(ROW_SELECTOR).each((_i, el) => {
    try {
      const $el = $(el);
      if (!$el.text().trim()) return;

      // matchId from link href or row id attribute
      const matchLink =
        $el.find('a[href*="/match/"]').first().attr('href') ||
        $el.find('a[href*="matchId="]').first().attr('href') || '';
      let matchId = extractId(matchLink, 'match');
      if (!matchId && matchLink) {
        const m = matchLink.match(/matchId=(\d+)/);
        if (m) matchId = Number(m[1]);
      }
      if (!matchId) matchId = matchIdFromRowId($el.attr('id') ?? '');
      if (!matchId) return;

      const rawStatus =
        $el.find('[class*="status"], .game-status, .match-status, .status-label, .match-state')
          .first().text().trim() || '';
      const status = normalizeStatus(rawStatus);
      const isLive = status === 'live';

      const dateTimeText =
        $el.find('[class*="date"], [class*="time"], .match-date, .game-date, .match-time, .kickoff')
          .first().text().trim() ||
        $el.find('td').eq(0).text().trim() || '';

      const venue =
        $el.find('[class*="venue"], [class*="arena"], .venue, .location').first().text().trim() || '';
      const venueLink = $el.find('a[href*="/venue/"]').first().attr('href') || '';
      const venueId = extractId(venueLink, 'venue');

      const teamLinks = $el.find('a[href*="/team/"]');
      const homeId = extractId(teamLinks.eq(0).attr('href') || '', 'team');
      const awayId = extractId(teamLinks.eq(1).attr('href') || '', 'team');

      const homeName =
        $el.find('.home-team .teamnames').first().text().trim() ||
        $el.find('.home-team .team-name').first().text().trim() ||
        $el.find('.home-team a').first().text().trim() ||
        $el.find('[class*="home"] [class*="name"]').first().text().trim() ||
        teamLinks.eq(0).text().trim();

      const awayName =
        $el.find('.away-team .teamnames').first().text().trim() ||
        $el.find('.away-team .team-name').first().text().trim() ||
        $el.find('.away-team a').first().text().trim() ||
        $el.find('[class*="away"] [class*="name"]').first().text().trim() ||
        teamLinks.eq(1).text().trim();

      const toAbsImg = (src) =>
        src ? (src.startsWith('http') ? src : `${BASE}${src}`) : null;

      const homeLogoImg =
        $el.find('.home-team img').first().attr('src') ||
        $el.find('[class*="home"] img').first().attr('src') || '';
      const awayLogoImg =
        $el.find('.away-team img').first().attr('src') ||
        $el.find('[class*="away"] img').first().attr('src') || '';

      games.push({
        competitionId: Number(competitionId),
        matchId,
        status,
        rawStatus,
        isLive,
        dateTimeText,
        venue,
        venueId,
        homeTeam: { id: homeId, name: homeName, logoUrl: toAbsImg(homeLogoImg) },
        awayTeam: { id: awayId, name: awayName, logoUrl: toAbsImg(awayLogoImg) },
        summaryUrl:    gsUrl(`/competition/${competitionId}/match/${matchId}/summary`),
        boxScoreUrl:   gsUrl(`/competition/${competitionId}/match/${matchId}/boxscore`),
        playByPlayUrl: gsUrl(`/competition/${competitionId}/match/${matchId}/playbyplay`),
        shotChartUrl:  gsUrl(`/competition/${competitionId}/match/${matchId}/shotchart`),
      });
    } catch (err) {
      console.error('[getSchedule] row parse error:', err.message ?? err);
    }
  });

  return games;
}

/**
 * Fetch the schedule for a competition using a headless browser.
 * @param {number|string} competitionId
 * @returns {Promise<Array>}
 */
export async function getSchedule(competitionId) {
  const url = gsUrl(`/competition/${competitionId}/schedule`);

  let html = '';
  let finalUrl = url;

  try {
    ({ html, finalUrl } = await fetchWithBrowser(url, { waitForSelector: '.match-wrap' }));
  } catch (err) {
    console.error(`[FLB] Browser fetch failed for compId=${competitionId}:`, err.message ?? err);
    return [];
  }

  const $ = cheerio.load(html);

  const matchWrapCount = $('.match-wrap').length;
  console.log(`[FLB] compId=${competitionId} | Final URL: ${finalUrl}`);
  console.log(`[FLB] compId=${competitionId} | html.length: ${html.length}`);
  console.log(`[FLB] compId=${competitionId} | .match-wrap count: ${matchWrapCount}`);
  console.log(`[FLB] compId=${competitionId} | contains "extfix_": ${html.includes('extfix_')}`);
  console.log(`[FLB] compId=${competitionId} | <title>: ${$('title').text().trim()}`);

  if (matchWrapCount === 0 && !html.includes('extfix_')) {
    // Nothing to parse — print a preview to help diagnose
    console.warn(`[FLB] compId=${competitionId} | No schedule content found. HTML preview:\n${html.slice(0, 2000)}`);
    return [];
  }

  const games = parseScheduleRows($, competitionId);
  console.log(`[FLB] Parsed ${games.length} games for competition ${competitionId}`);
  return games;
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. getBoxscore  (axios)
// ─────────────────────────────────────────────────────────────────────────────

function parseBoxscoreHeader($, competitionId, matchId) {
  const rawStatus =
    $('[class*="status"], .game-status, .match-status').first().text().trim() || '';
  const status = normalizeStatus(rawStatus);
  const dateTimeText = $('[class*="date"], .match-date').first().text().trim() || '';

  const homeName =
    $('[class*="home"] [class*="team-name"], .home-team .team-name').first().text().trim() ||
    $('[class*="home-name"]').first().text().trim();
  const awayName =
    $('[class*="away"] [class*="team-name"], .away-team .team-name').first().text().trim() ||
    $('[class*="away-name"]').first().text().trim();

  const homeScoreText = $('[class*="home"] [class*="score"], .home-score').first().text().trim();
  const awayScoreText = $('[class*="away"] [class*="score"], .away-score').first().text().trim();

  const homeId = extractId(
    $('[class*="home"] a[href*="/team/"]').first().attr('href') || '', 'team');
  const awayId = extractId(
    $('[class*="away"] a[href*="/team/"]').first().attr('href') || '', 'team');

  return {
    competitionId: Number(competitionId),
    matchId: Number(matchId),
    status,
    dateTimeText,
    homeTeam: { id: homeId, name: homeName, score: homeScoreText !== '' ? Number(homeScoreText) : null },
    awayTeam: { id: awayId, name: awayName, score: awayScoreText !== '' ? Number(awayScoreText) : null },
  };
}

function parseTeamTable($, tableEl, side) {
  const $table = $(tableEl);
  const headers = [];
  $table.find('thead tr th, thead tr td').each((_i, th) => {
    headers.push($(th).text().trim());
  });

  const players = [];
  const totalsRow = { Pts: '0' };

  const teamLink =
    $table.closest('[class*="team-section"]').find('a[href*="/team/"]').first().attr('href') ||
    $table.prev().find('a[href*="/team/"]').first().attr('href') || '';
  const teamId = extractId(teamLink, 'team');
  const teamName =
    $table.closest('[class*="team-section"]').find('[class*="team-name"]').first().text().trim() ||
    $table.prev().find('[class*="team-name"]').first().text().trim();

  $table.find('tbody tr').each((_i, row) => {
    const cells = [];
    $(row).find('td').each((_j, td) => cells.push($(td).text().trim()));
    if (cells.length === 0) return;

    if (/^totals?$/i.test(cells[0]) || /^totals?$/i.test(cells[1] ?? '')) {
      headers.forEach((h, idx) => {
        if (h && cells[idx] !== undefined) totalsRow[h] = cells[idx];
      });
      return;
    }

    const playerNumber = cells[0] ?? '';
    const playerName = cells[1] ?? '';
    if (!playerName) return;

    const playerLink = $(row).find('a[href*="/player/"]').first().attr('href') || '';
    const playerId = extractId(playerLink, 'player');

    const stats = {};
    headers.forEach((h, idx) => {
      if (h && idx >= 2 && cells[idx] !== undefined) stats[h] = cells[idx];
    });

    players.push({ playerId, playerNumber, playerName, stats });
  });

  return { side, teamId, teamName, totals: totalsRow, players };
}

/**
 * Fetch and parse a boxscore page.
 * @param {number|string} competitionId
 * @param {number|string} matchId
 */
export async function getBoxscore(competitionId, matchId) {
  const url = gsUrl(`/competition/${competitionId}/match/${matchId}/boxscore`);
  const { $ } = await fetchCheerio(url);

  const header = parseBoxscoreHeader($, competitionId, matchId);
  const teams = [];
  const tables = $('table.boxscore, table[class*="stats"], table').toArray();

  if (tables.length >= 2) {
    teams.push(parseTeamTable($, tables[0], 'home'));
    teams.push(parseTeamTable($, tables[1], 'away'));
  } else if (tables.length === 1) {
    teams.push(parseTeamTable($, tables[0], 'home'));
  } else {
    $('[class*="home-stats"], [class*="team-stats"]:first-of-type').each((_i, el) => {
      const innerTable = $(el).find('table').first();
      if (innerTable.length) teams.push(parseTeamTable($, innerTable, 'home'));
    });
    $('[class*="away-stats"]').each((_i, el) => {
      const innerTable = $(el).find('table').first();
      if (innerTable.length) teams.push(parseTeamTable($, innerTable, 'away'));
    });
  }

  return { header, teams };
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. getPlayByPlay  (axios)
// ─────────────────────────────────────────────────────────────────────────────

function resolveSide(teamName, homeTeamName, awayTeamName) {
  if (!teamName) return null;
  const t = teamName.trim().toLowerCase();
  if (homeTeamName && t === homeTeamName.trim().toLowerCase()) return 'home';
  if (awayTeamName && t === awayTeamName.trim().toLowerCase()) return 'away';
  return null;
}

function isScoringType(eventType) {
  const t = (eventType ?? '').toLowerCase();
  return (
    t.includes('2pt') || t.includes('3pt') ||
    t.includes('freethrow') || t.includes('free throw') || t.includes('ft')
  );
}

/**
 * Fetch and parse a play-by-play page.
 * @param {number|string} competitionId
 * @param {number|string} matchId
 */
export async function getPlayByPlay(competitionId, matchId) {
  const url = gsUrl(`/competition/${competitionId}/match/${matchId}/playbyplay`);
  const { $ } = await fetchCheerio(url);

  const header = parseBoxscoreHeader($, competitionId, matchId);
  const homeTeamName = header.homeTeam.name;
  const awayTeamName = header.awayTeam.name;
  const events = [];

  $('table.pbp tbody tr, [class*="play-row"], [class*="event-row"], [class*="pbp-row"]').each(
    (_i, el) => {
      try {
        const $el = $(el);
        if (!$el.text().trim()) return;

        const cells = [];
        $el.find('td').each((_j, td) => cells.push($(td).text().trim()));

        const period =
          $el.find('[class*="period"], [class*="quarter"]').first().text().trim() || cells[0] || '';
        const clock =
          $el.find('[class*="clock"], [class*="time"]').first().text().trim() || cells[1] || '';
        const score =
          $el.find('[class*="score"]').first().text().trim() || cells[2] || '';
        const teamName =
          $el.find('[class*="team"]').first().text().trim() || cells[3] || '';
        const player =
          $el.find('[class*="player"]').first().text().trim() || cells[4] || '';
        const playerNumber =
          $el.find('[class*="number"], [class*="jersey"]').first().text().trim() || '';
        const actionText =
          $el.find('[class*="action"], [class*="desc"]').first().text().trim() ||
          cells[5] || cells[4] || '';

        let eventType = 'event';
        const rowClass = ($el.attr('class') ?? '').toLowerCase();
        if (rowClass.includes('2pt') || /\b2pt\b/i.test(actionText)) eventType = '2pt';
        else if (rowClass.includes('3pt') || /\b3pt\b/i.test(actionText)) eventType = '3pt';
        else if (rowClass.includes('freethrow') || rowClass.includes('free-throw') ||
          /free.?throw/i.test(actionText)) eventType = 'freethrow';
        else if (rowClass.includes('rebound') || /rebound/i.test(actionText)) eventType = 'rebound';
        else if (rowClass.includes('turnover') || /turnover/i.test(actionText)) eventType = 'turnover';
        else if (rowClass.includes('foul') || /foul/i.test(actionText)) eventType = 'foul';
        else if (rowClass.includes('assist') || /assist/i.test(actionText)) eventType = 'assist';
        else if (rowClass.includes('block') || /block/i.test(actionText)) eventType = 'block';
        else if (rowClass.includes('steal') || /steal/i.test(actionText)) eventType = 'steal';
        else if (rowClass.includes('sub') || /substitution/i.test(actionText)) eventType = 'substitution';
        else if (/quarter|period|start|end/i.test(actionText)) eventType = 'period_marker';

        const isScoringEvent = isScoringType(eventType) && /made|scored/i.test(actionText);
        const teamSide = resolveSide(teamName, homeTeamName, awayTeamName);

        const safeP = (period || 'P').replace(/\s+/g, '');
        const safeClock = (clock || '00:00').replace(/\s+/g, '');
        const eventId =
          `${matchId}_${safeP}_${safeClock}_${eventType}_${score}`.replace(/\s/g, '');

        events.push({
          eventId, period, clock, score, teamSide, teamName,
          player, playerNumber, actionText, eventType, isScoringEvent,
        });
      } catch (err) {
        console.error('[getPlayByPlay] row parse error:', err.message ?? err);
      }
    },
  );

  return { header, events };
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. getMatchBundle
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Convenience wrapper: fetch boxscore and play-by-play in parallel.
 * @param {number|string} competitionId
 * @param {number|string} matchId
 */
export async function getMatchBundle(competitionId, matchId) {
  const [boxscore, playByPlay] = await Promise.all([
    getBoxscore(competitionId, matchId),
    getPlayByPlay(competitionId, matchId),
  ]);
  return { boxscore, playByPlay };
}
