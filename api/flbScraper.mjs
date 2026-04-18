/**
 * flbScraper.mjs
 * Scrapes FLB (Genius Sports) pages for Lebanese basketball data.
 * Exports: getSchedule, getBoxscore, getPlayByPlay, getMatchBundle
 */

import axios from 'axios';
import * as cheerio from 'cheerio';

const BASE = 'https://flb.web.geniussports.com';

/** Build a Genius Sports iframe URL. */
function gsUrl(path) {
  return `${BASE}/?p=9&WHurl=${encodeURIComponent(path)}`;
}

/** Shared axios instance with a browser-like UA to avoid bot blocks. */
const http = axios.create({
  timeout: 15_000,
  headers: {
    'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
  },
});

/** Fetch HTML and return a cheerio root. */
async function fetchCheerio(url) {
  const { data } = await http.get(url);
  return cheerio.load(String(data));
}

/**
 * Normalize a raw status string into a canonical status key.
 * @param {string} raw
 * @returns {'scheduled'|'live'|'final'|'postponed'}
 */
function normalizeStatus(raw) {
  if (!raw) return 'scheduled';
  const s = raw.trim().toLowerCase();
  if (s === 'final' || s === 'finished' || s === 'ft') return 'final';
  if (
    s.includes('live') ||
    s.includes('q1') ||
    s.includes('q2') ||
    s.includes('q3') ||
    s.includes('q4') ||
    s.includes('ot') ||
    s.includes('halftime') ||
    s.includes('half time') ||
    /^\d+:\d+$/.test(s)          // clock like "08:43"
  ) {
    return 'live';
  }
  if (s.includes('postpone') || s.includes('cancel')) return 'postponed';
  return 'scheduled';
}

/** Extract a numeric ID from a url segment like "/team/109252/" → 109252 */
function extractId(href, segment) {
  if (!href) return null;
  const re = new RegExp(`/${segment}/(\\d+)`);
  const m = href.match(re);
  return m ? Number(m[1]) : null;
}

// ─────────────────────────────────────────────
// 1. getSchedule
// ─────────────────────────────────────────────

/**
 * Fetch the schedule page for a competition.
 * @param {number|string} competitionId
 * @returns {Promise<Array>}
 */
export async function getSchedule(competitionId) {
  const url = gsUrl(`/competition/${competitionId}/schedule`);
  const $ = await fetchCheerio(url);

  const games = [];

  // Each game row is typically a <tr> or a <div> depending on the season.
  // Genius Sports uses a table-based layout; rows contain team names, score, date, venue.
  $('table.schedule tbody tr, .match-row, [class*="game-row"], [class*="schedule-row"]').each(
    (_i, el) => {
      try {
        const $el = $(el);
        const text = $el.text().trim();
        if (!text) return;

        // Match link — contains match id
        const matchLink =
          $el.find('a[href*="/match/"]').first().attr('href') ||
          $el.find('a[href*="matchId="]').first().attr('href') ||
          '';
        const matchId =
          extractId(matchLink, 'match') ||
          (() => {
            const m = matchLink.match(/matchId=(\d+)/);
            return m ? Number(m[1]) : null;
          })();
        if (!matchId) return; // skip non-game rows (headers etc.)

        // Status
        const rawStatus =
          $el.find('[class*="status"], .game-status, .match-status').first().text().trim() || '';
        const status = normalizeStatus(rawStatus);
        const isLive = status === 'live';

        // Date / time
        const dateTimeText =
          $el
            .find('[class*="date"], [class*="time"], .match-date, .game-date')
            .first()
            .text()
            .trim() || $el.find('td').eq(0).text().trim();

        // Venue
        const venue =
          $el.find('[class*="venue"], [class*="arena"], .venue').first().text().trim() || '';

        // Venue id from link
        const venueLink = $el.find('a[href*="/venue/"]').first().attr('href') || '';
        const venueId = extractId(venueLink, 'venue');

        // Teams
        const teamLinks = $el.find('a[href*="/team/"]');
        const homeLink = teamLinks.eq(0).attr('href') || '';
        const awayLink = teamLinks.eq(1).attr('href') || '';

        const homeId = extractId(homeLink, 'team');
        const awayId = extractId(awayLink, 'team');
        const homeName =
          $el.find('[class*="home"] [class*="name"], .home-team .team-name').first().text().trim() ||
          teamLinks.eq(0).text().trim();
        const awayName =
          $el
            .find('[class*="away"] [class*="name"], .away-team .team-name')
            .first()
            .text()
            .trim() || teamLinks.eq(1).text().trim();

        // Logo urls
        const homeLogoImg =
          $el.find('[class*="home"] img, .home-team img').first().attr('src') || '';
        const awayLogoImg =
          $el.find('[class*="away"] img, .away-team img').first().attr('src') || '';
        const toAbsImg = (src) =>
          src ? (src.startsWith('http') ? src : `${BASE}${src}`) : null;

        // Derived URLs
        const summaryUrl = `${BASE}/?p=9&WHurl=${encodeURIComponent(
          `/competition/${competitionId}/match/${matchId}/summary`,
        )}`;
        const boxScoreUrl = `${BASE}/?p=9&WHurl=${encodeURIComponent(
          `/competition/${competitionId}/match/${matchId}/boxscore`,
        )}`;
        const playByPlayUrl = `${BASE}/?p=9&WHurl=${encodeURIComponent(
          `/competition/${competitionId}/match/${matchId}/playbyplay`,
        )}`;
        const shotChartUrl = `${BASE}/?p=9&WHurl=${encodeURIComponent(
          `/competition/${competitionId}/match/${matchId}/shotchart`,
        )}`;

        games.push({
          competitionId: Number(competitionId),
          matchId,
          status,
          rawStatus,
          isLive,
          dateTimeText,
          venue,
          venueId,
          homeTeam: {
            id: homeId,
            name: homeName,
            logoUrl: toAbsImg(homeLogoImg),
          },
          awayTeam: {
            id: awayId,
            name: awayName,
            logoUrl: toAbsImg(awayLogoImg),
          },
          summaryUrl,
          boxScoreUrl,
          playByPlayUrl,
          shotChartUrl,
        });
      } catch (err) {
        console.error('[getSchedule] row parse error:', err.message ?? err);
      }
    },
  );

  return games;
}

// ─────────────────────────────────────────────
// 2. getBoxscore
// ─────────────────────────────────────────────

/**
 * Parse a boxscore header block (score, teams, status).
 */
function parseBoxscoreHeader($, competitionId, matchId) {
  const rawStatus =
    $('[class*="status"], .game-status, .match-status').first().text().trim() || '';
  const status = normalizeStatus(rawStatus);
  const dateTimeText =
    $('[class*="date"], .match-date').first().text().trim() || '';

  const homeName =
    $('[class*="home"] [class*="team-name"], .home-team .team-name').first().text().trim() ||
    $('[class*="home-name"]').first().text().trim();
  const awayName =
    $('[class*="away"] [class*="team-name"], .away-team .team-name').first().text().trim() ||
    $('[class*="away-name"]').first().text().trim();

  const homeScoreText = $('[class*="home"] [class*="score"], .home-score').first().text().trim();
  const awayScoreText = $('[class*="away"] [class*="score"], .away-score').first().text().trim();
  const homeScore = homeScoreText !== '' ? Number(homeScoreText) : null;
  const awayScore = awayScoreText !== '' ? Number(awayScoreText) : null;

  const homeId = extractId(
    $('[class*="home"] a[href*="/team/"]').first().attr('href') || '',
    'team',
  );
  const awayId = extractId(
    $('[class*="away"] a[href*="/team/"]').first().attr('href') || '',
    'team',
  );

  return {
    competitionId: Number(competitionId),
    matchId: Number(matchId),
    status,
    dateTimeText,
    homeTeam: { id: homeId, name: homeName, score: homeScore },
    awayTeam: { id: awayId, name: awayName, score: awayScore },
  };
}

/**
 * Parse a single team's boxscore table.
 * @param {CheerioAPI} $ cheerio root
 * @param {Element} tableEl
 * @param {'home'|'away'} side
 */
function parseTeamTable($, tableEl, side) {
  const $table = $(tableEl);

  // Determine column headers
  const headers = [];
  $table.find('thead tr th, thead tr td').each((_i, th) => {
    headers.push($(th).text().trim());
  });

  const players = [];
  const totalsRow = { Pts: '0' };
  let teamId = null;
  let teamName = '';

  // Try to find the team id from a link above the table or within
  const teamLink =
    $table.closest('[class*="team-section"]').find('a[href*="/team/"]').first().attr('href') ||
    $table.prev().find('a[href*="/team/"]').first().attr('href') || '';
  teamId = extractId(teamLink, 'team');
  teamName =
    $table
      .closest('[class*="team-section"]')
      .find('[class*="team-name"]')
      .first()
      .text()
      .trim() ||
    $table.prev().find('[class*="team-name"]').first().text().trim();

  $table.find('tbody tr').each((_i, row) => {
    const cells = [];
    $(row)
      .find('td')
      .each((_j, td) => cells.push($(td).text().trim()));

    if (cells.length === 0) return;

    // Detect totals row (first cell says "Total" or "TOTALS")
    if (/^totals?$/i.test(cells[0]) || /^totals?$/i.test(cells[1] ?? '')) {
      headers.forEach((h, idx) => {
        if (h && cells[idx] !== undefined) totalsRow[h] = cells[idx];
      });
      return;
    }

    // Player row: first cell is jersey number, second is name
    const playerNumber = cells[0] ?? '';
    const playerName = cells[1] ?? '';
    if (!playerName) return;

    // Player id from link
    const playerLink =
      $(row).find('a[href*="/player/"]').first().attr('href') || '';
    const playerId = extractId(playerLink, 'player');

    const stats = {};
    headers.forEach((h, idx) => {
      if (h && idx >= 2 && cells[idx] !== undefined) {
        stats[h] = cells[idx];
      }
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
  const $ = await fetchCheerio(url);

  const header = parseBoxscoreHeader($, competitionId, matchId);

  const teams = [];
  // Genius Sports boxscore: two adjacent tables or sections (home + away)
  const tables = $('table.boxscore, table[class*="stats"], table').toArray();

  if (tables.length >= 2) {
    teams.push(parseTeamTable($, tables[0], 'home'));
    teams.push(parseTeamTable($, tables[1], 'away'));
  } else if (tables.length === 1) {
    teams.push(parseTeamTable($, tables[0], 'home'));
  } else {
    // Fallback: look for section-based layout
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

// ─────────────────────────────────────────────
// 3. getPlayByPlay
// ─────────────────────────────────────────────

/**
 * Derive which side an event belongs to based on team name comparison.
 */
function resolveSide(teamName, homeTeamName , awayTeamName) {
  if (!teamName) return null;
  const t = teamName.trim().toLowerCase();
  if (homeTeamName && t === homeTeamName.trim().toLowerCase()) return 'home';
  if (awayTeamName && t === awayTeamName.trim().toLowerCase()) return 'away';
  return null;
}

/** Detect whether an event type is a scoring action. */
function isScoringType(eventType) {
  const t = (eventType ?? '').toLowerCase();
  return (
    t.includes('2pt') ||
    t.includes('3pt') ||
    t.includes('freethrow') ||
    t.includes('free throw') ||
    t.includes('ft')
  );
}

/**
 * Fetch and parse a play-by-play page.
 * @param {number|string} competitionId
 * @param {number|string} matchId
 */
export async function getPlayByPlay(competitionId, matchId) {
  const url = gsUrl(`/competition/${competitionId}/match/${matchId}/playbyplay`);
  const $ = await fetchCheerio(url);

  const header = parseBoxscoreHeader($, competitionId, matchId);
  const homeTeamName = header.homeTeam.name;
  const awayTeamName = header.awayTeam.name;

  const events = [];

  // Events are typically in a table or list of divs
  $('table.pbp tbody tr, [class*="play-row"], [class*="event-row"], [class*="pbp-row"]').each(
    (_i, el) => {
      try {
        const $el = $(el);
        const text = $el.text().trim();
        if (!text) return;

        const cells = [];
        $el.find('td').each((_j, td) => cells.push($(td).text().trim()));

        // Typical columns: Period | Clock | Score | Team | Player | Action
        // Column positions vary; we read them positionally and by class
        const period =
          $el.find('[class*="period"], [class*="quarter"]').first().text().trim() ||
          cells[0] ||
          '';
        const clock =
          $el.find('[class*="clock"], [class*="time"]').first().text().trim() ||
          cells[1] ||
          '';
        const score =
          $el.find('[class*="score"]').first().text().trim() || cells[2] || '';

        const teamName =
          $el.find('[class*="team"]').first().text().trim() || cells[3] || '';
        const playerCell = $el.find('[class*="player"]').first();
        const player = playerCell.text().trim() || cells[4] || '';
        const playerNumber =
          $el.find('[class*="number"], [class*="jersey"]').first().text().trim() || '';

        const actionText =
          $el.find('[class*="action"], [class*="desc"]').first().text().trim() ||
          cells[5] ||
          cells[4] ||
          '';

        // Try to get event type from class or text pattern
        let eventType = 'event';
        const rowClass = ($el.attr('class') ?? '').toLowerCase();
        if (rowClass.includes('2pt') || /\b2pt\b/i.test(actionText)) eventType = '2pt';
        else if (rowClass.includes('3pt') || /\b3pt\b/i.test(actionText)) eventType = '3pt';
        else if (
          rowClass.includes('freethrow') ||
          rowClass.includes('free-throw') ||
          /free.?throw/i.test(actionText)
        )
          eventType = 'freethrow';
        else if (rowClass.includes('rebound') || /rebound/i.test(actionText)) eventType = 'rebound';
        else if (rowClass.includes('turnover') || /turnover/i.test(actionText)) eventType = 'turnover';
        else if (rowClass.includes('foul') || /foul/i.test(actionText)) eventType = 'foul';
        else if (rowClass.includes('assist') || /assist/i.test(actionText)) eventType = 'assist';
        else if (rowClass.includes('block') || /block/i.test(actionText)) eventType = 'block';
        else if (rowClass.includes('steal') || /steal/i.test(actionText)) eventType = 'steal';
        else if (rowClass.includes('sub') || /substitution/i.test(actionText)) eventType = 'substitution';
        else if (/quarter|period|start|end/i.test(actionText)) eventType = 'period_marker';

        const isScoringEvent =
          isScoringType(eventType) && /made|scored/i.test(actionText);

        const teamSide = resolveSide(teamName, homeTeamName, awayTeamName);

        // Compose a deterministic event id
        const safeP = (period || 'P').replace(/\s+/g, '');
        const safeClock = (clock || '00:00').replace(/\s+/g, '').replace(/:/g, ':');
        const eventId = `${matchId}_${safeP}_${safeClock}_${eventType}_${score}`.replace(
          /\s/g,
          '',
        );

        events.push({
          eventId,
          period,
          clock,
          score,
          teamSide,
          teamName,
          player,
          playerNumber,
          actionText,
          eventType,
          isScoringEvent,
        });
      } catch (err) {
        console.error('[getPlayByPlay] row parse error:', err.message ?? err);
      }
    },
  );

  return { header, events };
}

// ─────────────────────────────────────────────
// 4. getMatchBundle
// ─────────────────────────────────────────────

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
