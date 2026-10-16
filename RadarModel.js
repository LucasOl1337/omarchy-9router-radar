function resetTime(value) {
  if (!value) return 0;
  var n = typeof value === "number" ? (value < 100000000000 ? value * 1000 : value) : Date.parse(value);
  return isFinite(n) ? n : 0;
}

function primaryQuota(quotas) {
  var known = (quotas || []).filter(q => q.percent !== null && typeof q.percent === "number" && isFinite(q.percent) && !q.unlimited);
  var weekly = known.filter(q => /^(weekly|weekly supergrok)(\s*\(7d\))?$/i.test(q.label));
  return weekly[0] || known.filter(q => /^session(?:\s*\(5h\))?$/i.test(q.label))[0] || known[0] || null;
}

function memberState(account, router, now) {
  var primary = primaryQuota(account.quotas);
  var session = (account.quotas || []).filter(q => /^session/i.test(q.label) && typeof q.percent === "number")[0];
  var active = account.active && !router.error;
  var fresh = account.quotaUpdatedAt && now - account.quotaUpdatedAt * 1000 <= 20 * 60000;
  var expired = [primary, session].some(q => q && resetTime(q.resetAt) > 0 && resetTime(q.resetAt) <= now);
  var known = !!(active && primary && fresh && !expired && !account.quotaError);
  var blocked = known && (primary.percent >= 100 || session && session.percent >= 100);
  var unavailable = ["unavailable", "invalid", "expired", "error"].indexOf(account.status) >= 0;
  var remaining = known ? Math.max(0, 100 - primary.percent) : null;
  var limiting = blocked && session && session.percent >= 100 ? session : primary;
  var resetMs = limiting ? resetTime(limiting.resetAt) - now : 0;
  var band = !active || unavailable ? 4 : blocked ? 3 : !known ? 2 : remaining <= 10 && resetMs > 30 * 60000 ? 1 : 0;
  var score = remaining === null ? 0 : remaining / 100;
  if (known && primary.percent >= 70 && resetMs > 0) score += .05 / (1 + resetMs / 3600000);
  var note = !account.active ? (String(account.status).indexOf("removida") >= 0 ? "Histórico" : "Desativada") : router.error ? "Router sem acesso" : unavailable ? "Rota indisponível" : blocked ? "Cota esgotada" : !known ? account.quotaError || (expired || !fresh ? "Cota precisa atualizar" : "Cota não informada") : "";
  return {account: account, router: router, primary: primary, band: band, score: score, remaining: remaining, resetMs: resetMs, note: note};
}

function buildRows(snapshot, now) {
  var groups = {}, count = 0;
  (snapshot.routers || []).forEach(function(router) {
    (router.accounts || []).forEach(function(account) {
      count++;
      var email = account.email || (/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(account.name) ? account.name : "");
      var key = email ? account.provider + ":" + email.toLowerCase() : router.id + ":" + account.id;
      if (!groups[key]) groups[key] = {key: key, name: account.name, provider: account.provider, members: []};
      groups[key].members.push(memberState(account, router, now));
    });
  });
  var rows = Object.keys(groups).map(function(key) {
    var row = groups[key];
    row.members.sort((a, b) => a.band - b.band || b.score - a.score || a.router.name.localeCompare(b.router.name));
    var best = row.members[0];
    row.band = best.band; row.score = best.score; row.remaining = best.remaining;
    row.primary = best.primary; row.resetMs = best.resetMs; row.note = best.note;
    row.route = best.router.name; row.quotas = best.account.quotas;
    row.section = best.band <= 1 ? "USAR PRIMEIRO" : best.band === 2 ? "SEM LEITURA DE COTA" : "ESGOTADAS / INDISPONÍVEIS";
    return row;
  });
  rows.sort((a, b) => a.band - b.band || (a.band === 3 ? (a.resetMs || Infinity) - (b.resetMs || Infinity) : b.score - a.score) || a.provider.localeCompare(b.provider) || a.name.localeCompare(b.name));
  rows.forEach(function(row, index) {
    row.rank = index + 1;
    row.sectionStart = index === 0 || rows[index - 1].section !== row.section;
  });
  return {rows: rows, connections: count};
}

var PROVIDERS = {claude: "Claude Code", codex: "OpenAI Codex", "grok-cli": "Grok CLI", cursor: "Cursor", "devin-cli": "Devin CLI", devin: "Devin", github: "GitHub Copilot", "gemini-cli": "Gemini CLI", gemini: "Gemini", antigravity: "Antigravity", kiro: "Kiro", qwen: "Qwen", openrouter: "OpenRouter"};
var PROVIDER_ORDER = ["claude", "codex", "grok-cli", "cursor", "devin-cli", "github", "gemini-cli", "antigravity", "kiro", "qwen", "gemini", "openrouter"];
var STALE_MS = 20 * 60000;

function providerTitle(provider) { return /compatible/.test(provider) ? "API compatível" : PROVIDERS[provider] || provider }
function providerIcon(provider) { return /compatible/.test(provider) ? "openai" : provider }
function providerRank(provider) { var i = PROVIDER_ORDER.indexOf(provider); return i < 0 ? PROVIDER_ORDER.length : i }
function isRemoved(account) { return !account.active && String(account.status).indexOf("removida") >= 0 }

function countText(n) { return Number.isInteger(n) ? String(n) : n.toFixed(1) }

// Same thresholds as the 9Router Quota Tracker: >70% green, >=30% yellow, below red.
function quotaView(q, now) {
  var known = typeof q.percent === "number" && isFinite(q.percent);
  var remaining = q.unlimited || !known ? null : Math.max(0, Math.min(100, Math.round(100 - q.percent)));
  var reset = resetTime(q.resetAt);
  var expired = reset > 0 && reset <= now;
  var tone = q.unlimited ? "green" : remaining === null || expired ? "none" : remaining > 70 ? "green" : remaining >= 30 ? "yellow" : "red";
  var usage = q.unlimited ? "sem teto" : typeof q.used === "number" && q.total > 0 ? countText(q.used) + " / " + countText(q.total) : known ? Math.round(q.percent) + " / 100" : "sem leitura";
  return {label: q.label, remaining: remaining, tone: tone, usage: usage, resetMs: reset > 0 ? reset - now : 0, expired: expired, unlimited: q.unlimited === true};
}

function earliestReset(card) {
  var times = card.quotas.filter(q => q.resetMs > 0).map(q => q.resetMs);
  return times.length ? Math.min.apply(null, times) : Infinity;
}

// One card per account for the selected router ("all" merges the same login across routers).
function buildCards(snapshot, now, options) {
  options = options || {};
  var hidden = 0;
  var routers = (snapshot.routers || []).filter(r => !options.router || options.router === "all" || r.id === options.router).map(function(router) {
    var accounts = (router.accounts || []).filter(function(a) { if (isRemoved(a)) { hidden++; return false } return true });
    return Object.assign({}, router, {accounts: accounts});
  });
  var built = buildRows({routers: routers}, now);
  var cards = built.rows.map(function(row) {
    var source = row.members.filter(m => (m.account.quotas || []).length)[0] || row.members[0];
    var updated = source.account.quotaUpdatedAt ? source.account.quotaUpdatedAt * 1000 : 0;
    return {
      key: row.key, provider: row.provider, title: providerTitle(row.provider), icon: providerIcon(row.provider),
      name: row.name, active: row.members.some(m => m.account.active), band: row.band, remaining: row.remaining,
      note: row.note, route: row.band <= 1 ? row.route : "",
      stale: (source.account.quotas || []).length > 0 && (!updated || now - updated > STALE_MS), updatedAgoMs: updated ? now - updated : 0,
      quotas: (source.account.quotas || []).map(q => quotaView(q, now)),
      members: row.members.map(m => ({router: m.router.name, routerId: m.router.id, active: m.account.active && !m.router.error, periods: m.account.periods || {}, note: m.note}))
    };
  });
  var sort = options.sort || "provider";
  cards.forEach((card, index) => card.order = index);
  cards.sort(function(a, b) {
    if (a.active !== b.active) return a.active ? -1 : 1;
    if (sort === "free") return a.order - b.order;
    if (sort === "expiring") return earliestReset(a) - earliestReset(b) || a.order - b.order;
    return providerRank(a.provider) - providerRank(b.provider) || a.provider.localeCompare(b.provider) || a.order - b.order;
  });
  return {cards: cards, hidden: hidden, connections: built.connections};
}

if (typeof module !== "undefined") module.exports = {buildRows: buildRows, buildCards: buildCards, quotaView: quotaView, primaryQuota: primaryQuota};
