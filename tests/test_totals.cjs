const test = require('node:test');
const assert = require('node:assert/strict');
const {buildTotals, brasiliaTime} = require('../RadarModel.js');
const now = Date.parse('2026-11-14T12:00:00Z');
const q = (label, used, reset = now + 3600000) => ({label, percent: used, resetAt: reset});
const a = (id, changes = {}) => ({id, name: `${id}@example.com`, provider: 'claude', plan: '20x', active: true, status: 'active', quotaUpdatedAt: now / 1000, quotas: [q('weekly (7d)', 60)], ...changes});
const r = (id, accounts, changes = {}) => ({id, name: id, accounts, error: '', ...changes});
const totals = (...routers) => buildTotals({routers}, now);
test('eight 20x accounts at 40% sum to 320% of 800%', () => {
  const total = totals(r('A', ['a','b','c','d','e','f','g','h'].map(id => a(id))))[0];
  assert.equal(total.remaining, 320); assert.equal(total.maximum, 800); assert.equal(total.ratio, .4);
});
test('two full 20x accounts yield 200%; a 5x contributes half its balance and maximum', () => {
  const total = totals(r('A', [a('a', {quotas:[q('weekly', 0)]}), a('b', {quotas:[q('weekly', 0)]}), a('c', {plan:'5x'})]))[0];
  assert.equal(total.remaining, 220); assert.equal(total.maximum, 250);
  assert.equal(total.twenty, 2); assert.equal(total.five, 1);
});
test('same login counts once, inherits its known plan and uses latest successful reading', () => {
  const total = totals(r('A', [a('same', {plan:'', active:false, quotas:[q('weekly', 90)], quotaUpdatedAt:now/1000-10})]), r('B', [a('same', {plan:'5x'})]))[0];
  assert.equal(total.accounts, 1); assert.equal(total.remaining, 20); assert.equal(total.maximum, 50); assert.equal(total.paused, 0);
});
test('paused subscriptions retain balance; removed history is excluded; session reset does not erase weekly balance', () => {
  const total = totals(r('A', [a('paused', {active:false, status:'unavailable', quotas:[q('session (5h)', 100, now-1000), q('weekly (7d)', 60)]}), a('removed',{active:false,status:'Histórico · conta removida'})]))[0];
  assert.equal(total.accounts, 1); assert.equal(total.remaining, 40); assert.equal(total.paused, 1);
});
test('missing, stale, failed and expired readings are partial, never treated as full', () => {
  const total = totals(r('A', [a('missing',{quotas:[]}), a('stale',{quotaUpdatedAt:now/1000-1201}), a('failed',{quotaError:'erro'}), a('expired',{quotas:[q('weekly',0,now-1000)]}), a('good')]))[0];
  assert.equal(total.remaining, 40); assert.equal(total.maximum, 500); assert.equal(total.missing, 4); assert.equal(total.partial, true);
});
test('unknown and conflicting plans are explicit and do not inflate total', () => {
  const total = totals(r('A', [a('unknown',{plan:''}), a('conflict')]), r('B',[a('conflict',{plan:'5x'})]))[0];
  assert.equal(total.maximum, 0); assert.equal(total.unknownPlans, 2); assert.equal(total.partial, true);
});
test('three GPT accounts give 300% capacity, ignore model-specific pools and deduplicate across routers', () => {
  const accounts=[a('g1',{provider:'codex',quotas:[q('session',10)]}),a('g2',{provider:'codex',quotas:[q('session',20)]}),a('g3',{provider:'codex',quotas:[q('weekly model (7d)',100),q('weekly (7d)',30)]})];
  const total=totals(r('A',accounts),r('B',[accounts[0]]))[1];
  assert.equal(total.maximum,300);assert.equal(total.remaining,240);assert.equal(total.accounts,3);
});
test('offline router cannot supply a current balance, and empty providers are explicit',()=>{
  const [claude,gpt]=totals(r('A',[a('a')],{error:'offline'}));
  assert.equal(claude.known,0);assert.equal(claude.missing,1);assert.equal(claude.maximum,100);
  assert.equal(gpt.accounts,0);assert.equal(gpt.maximum,0);
});
test('clock always renders Brasília',()=>assert.equal(brasiliaTime(now/1000),'09:00'));
