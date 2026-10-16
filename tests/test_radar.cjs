const test = require('node:test');
const assert = require('node:assert/strict');
const {buildRows, buildCards, quotaView} = require('../RadarModel.js');
const now = Date.now();
function quota(label, percent, hours = 5) { return {label, percent, resetAt: new Date(now + hours * 3600000).toISOString()}; }
function account(id, changes = {}) { return {id, name: id + '@example.com', provider: 'codex', active: true, status: 'active', quotaUpdatedAt: now / 1000, quotaError: '', quotas: [quota('session', 10)], periods: {}, ...changes}; }
function router(id, accounts, changes = {}) { return {id, name: id, accounts, error: '', ...changes}; }
function rows(...routers) { return buildRows({routers}, now).rows; }
test('same email and provider share one row, different providers remain separate', () => {
  const a = account('a');
  const result = rows(router('Railway', [a]), router('Hostinger', [{...a, id: 'b'}, {...a, id: 'c', provider: 'claude'}]));
  assert.equal(result.length, 2);
  assert.equal(result.find(r => r.provider === 'codex').members.length, 2);
});
test('weekly general ranks before model-specific pools and exhausted session blocks', () => {
  const weekly = account('weekly', {quotas: [quota('weekly fable (7d)', 100), quota('session (5h)', 0), quota('weekly (7d)', 60)]});
  const blocked = account('blocked', {quotas: [quota('weekly (7d)', 0), quota('session (5h)', 100)]});
  const result = rows(router('R', [blocked, weekly]));
  assert.equal(result[0].name, weekly.name);
  assert.equal(result[0].remaining, 40);
  assert.equal(result[1].band, 3);
});
test('missing, stale and reset-passed limits never become unused quota', () => {
  const result = rows(router('R', [account('unknown', {quotas: []}), account('stale', {quotaUpdatedAt: now / 1000 - 1201}), account('expired', {quotas: [quota('session', 0, -1)]}), account('fresh')]));
  assert.equal(result[0].name, 'fresh@example.com');
  result.slice(1).forEach(r => {assert.equal(r.band, 2); assert.equal(r.remaining, null);});
});
test('a disabled duplicate does not hide the available route', () => {
  const a = account('a');
  const result = rows(router('A', [{...a, active: false}]), router('B', [{...a, id: 'b'}]));
  assert.equal(result.length, 1);
  assert.equal(result[0].route, 'B');
  assert.equal(result[0].band, 0);
});
test('offline router and unavailable connection are excluded from recommendation', () => {
  const result = rows(router('offline', [account('a')], {error: 'offline'}), router('online', [account('b', {status: 'unavailable'}), account('c')]));
  assert.equal(result[0].name, 'c@example.com');
  assert.ok(result.slice(1).every(r => r.band === 4));
});
test('headroom orders healthy accounts and a refresh error preserves uncertainty', () => {
  const result = rows(router('R', [account('low', {quotas: [quota('session', 91)]}), account('high', {quotas: [quota('session', 5)]}), account('failed', {quotaError: 'Falha na leitura'})]));
  assert.equal(result[0].name, 'high@example.com');
  assert.equal(result[1].band, 1);
  assert.equal(result[2].remaining, null);
});
test('quota colors follow the 9Router dashboard thresholds', () => {
  assert.equal(quotaView({label: 's', percent: 29}, now).tone, 'green');
  assert.equal(quotaView({label: 's', percent: 30}, now).tone, 'yellow');
  assert.equal(quotaView({label: 's', percent: 70}, now).tone, 'yellow');
  assert.equal(quotaView({label: 's', percent: 71}, now).tone, 'red');
  const counter = quotaView({label: 's', percent: 52, used: 52, total: 100, resetAt: new Date(now + 90 * 60000).toISOString()}, now);
  assert.equal(counter.usage, '52 / 100');
  assert.equal(counter.remaining, 48);
  assert.equal(quotaView({label: 's', percent: 10, resetAt: new Date(now - 1000).toISOString()}, now).tone, 'none');
});
test('router filter shows only its accounts and hides removed history', () => {
  const shared = account('shared');
  const snapshot = {routers: [router('railway', [shared, account('old', {active: false, status: 'Histórico · conta removida'})]), router('hostinger', [{...shared, id: 'h'}, account('solo')])]};
  const all = buildCards(snapshot, now, {router: 'all'});
  assert.equal(all.cards.length, 2);
  assert.equal(all.hidden, 1);
  assert.deepEqual(all.cards.find(c => c.name === shared.name).members.map(m => m.routerId).sort(), ['hostinger', 'railway']);
  const hostinger = buildCards(snapshot, now, {router: 'hostinger'});
  assert.deepEqual(hostinger.cards.map(c => c.members.length), [1, 1]);
  assert.ok(hostinger.cards.every(c => c.members[0].routerId === 'hostinger'));
});
test('cards group by provider, keep disabled last and can sort by expiry', () => {
  const snapshot = {routers: [router('R', [
    account('codex-late', {quotas: [quota('session', 10, 50)]}),
    account('claude', {provider: 'claude', quotas: [quota('session (5h)', 50, 3)]}),
    account('off', {provider: 'claude', active: false}),
    account('codex-soon', {quotas: [quota('session', 10, 1)]}),
  ])]};
  assert.deepEqual(buildCards(snapshot, now, {sort: 'provider'}).cards.map(c => c.provider + ':' + c.active), ['claude:true', 'codex:true', 'codex:true', 'claude:false']);
  assert.deepEqual(buildCards(snapshot, now, {sort: 'expiring'}).cards.map(c => c.name.split('@')[0]), ['codex-soon', 'claude', 'codex-late', 'off']);
});
