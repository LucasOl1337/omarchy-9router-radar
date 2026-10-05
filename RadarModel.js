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

if (typeof module !== "undefined") module.exports = {buildRows: buildRows, primaryQuota: primaryQuota};
