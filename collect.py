#!/usr/bin/python3
"""Dashboard usage and accounts from the three registered gateways. No AI calls."""
import concurrent.futures
import http.cookiejar
import json
import math
import os
import shlex
import subprocess
import time
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import quote
from urllib.request import Request, build_opener, HTTPCookieProcessor

STATE = Path.home() / '.local/state/omarchy-trackers/routers'
REGISTRY = Path(os.environ.get('RADAR_9ROUTER_CONFIG', str(Path.home() / '.config/omarchy-9router-radar/routers.json')))
LEGACY_REGISTRY = Path.home() / '.config/rotas/routers.json'
PERIODS = ('today', '7d', '30d', 'all')
QUOTA_PROVIDERS = {'codex', 'claude', 'grok-cli', 'github', 'antigravity', 'gemini-cli', 'cursor', 'kiro', 'qwen', 'devin', 'devin-cli'}


def number(value):
    try:
        n = float(value)
        return max(0, n) if math.isfinite(n) else 0
    except (TypeError, ValueError):
        return 0


def clean_quotas(payload):
    result = []
    for label, q in (payload.get('quotas') or {}).items():
        if not isinstance(q, dict):
            continue
        total = number(q.get('total'))
        used = number(q.get('used')) if q.get('used') is not None else None
        percent = min(100, 100 * used / total) if used is not None and total > 0 else None
        if percent is None and q.get('remainingPercentage') is not None:
            percent = max(0, min(100, 100 - number(q['remainingPercentage'])))
        reset = q.get('resetAt')
        result.append(dict(label=str(label), percent=round(percent, 1) if percent is not None else None,
            used=used, total=total if total > 0 else None,
            resetAt=reset if isinstance(reset, (str, int, float)) else None, unlimited=q.get('unlimited') is True))
    return result


def clean_connections(payload):
    # Explicit allowlist: nested provider data may contain credentials.
    return [{k: c.get(k) for k in ('id', 'provider', 'name', 'email', 'isActive', 'testStatus')}
            for c in payload.get('connections', [])]


def dashboard_password(name, config):
    environment = config.get('password_env')
    if environment:
        value = os.environ.get(environment, '').strip()
        if not value:
            raise RuntimeError('Credencial do painel indisponível')
        return value
    args = config.get('password_command')
    if args is None:
        # Compatibility with the initial machine-local registry.
        args = {'railway': ['cofre', 'pessoal', 'pega', '9Router Railway · painel'],
                'sherlocker': ['cofre', 'teiax', 'pega', '9router']}.get(name)
    if not isinstance(args, list) or not args or not all(isinstance(arg, str) for arg in args):
        raise RuntimeError('Configure password_command ou password_env')
    try:
        password = subprocess.run(args, capture_output=True, text=True, timeout=180)
    except subprocess.TimeoutExpired:
        raise RuntimeError('Cofre ocupado: senha do painel demorou') from None
    if password.returncode or not password.stdout.strip():
        raise RuntimeError('Credencial do painel indisponível')
    return password.stdout.strip()


def http_gateway(name, config, previous):
    base = config['base_url'].rstrip('/').removesuffix('/v1')
    password = dashboard_password(name, config)
    opener = build_opener(HTTPCookieProcessor(http.cookiejar.CookieJar()))
    req = Request(base + '/api/auth/login', data=json.dumps({'password': password}).encode(),
        headers={'Content-Type': 'application/json', 'User-Agent': 'omarchy-trackers/1.0'})
    try:
        with opener.open(req, timeout=20) as response:
            response.read()
    except HTTPError as error:
        raise RuntimeError('Login do painel: HTTP ' + str(error.code)) from None

    def get(path):
        with opener.open(Request(base + path, headers={'Accept': 'application/json', 'User-Agent': 'omarchy-trackers/1.0'}), timeout=20) as response:
            return json.load(response)

    connections = clean_connections(get('/api/providers'))
    stats = {}
    for period in PERIODS:
        try:
            stats[period] = get('/api/usage/stats?period=' + period)
        except (OSError, ValueError):
            stats[period] = None
    quotas = {}
    for c in connections:
        # Disabled connections keep showing their limits, like the dashboard.
        if c.get('provider') not in QUOTA_PROVIDERS:
            continue
        try:
            raw = get('/api/usage/' + quote(c['id'], safe=''))
            quotas[c['id']] = dict(quotas=clean_quotas(raw), updatedAt=int(time.time()),
                error='Limite indisponível' if raw.get('error') or raw.get('message') and not raw.get('quotas') else '')
        except (OSError, ValueError):
            quotas[c['id']] = dict(error='Leitura de limite indisponível')
    return normalize(name, config, connections, stats, quotas, previous)


HOSTINGER_JS = r'''
const fs = require('fs'), crypto = require('crypto'), http = require('http');
const token = crypto.createHash('sha256').update(fs.readFileSync('/app/data/machine-id','utf8').trim() + '9r-cli-auth' + fs.readFileSync('/app/data/auth/cli-secret','utf8').trim()).digest('hex').slice(0,16);
function get(path) { return new Promise((resolve,reject) => {
 const req = http.request({host:'127.0.0.1',port:20128,path,headers:{'x-9r-cli-token':token,accept:'application/json'}}, res => {
  let data=''; res.on('data',x=>data+=x); res.on('end',()=>{try { if(res.statusCode!==200) throw Error('HTTP '+res.statusCode); resolve(JSON.parse(data)); }catch(e){reject(e)}});
 }); req.on('error',reject); req.setTimeout(20000,()=>req.destroy(Error('timeout'))); req.end();
}) }
(async()=>{
 const raw=await get('/api/providers');
 const connections=raw.connections.map(c=>Object.fromEntries(['id','provider','name','email','isActive','testStatus'].map(k=>[k,c[k]])));
 const stats={}, quotas={};
 for(const p of ['today','7d','30d','all']) { try{stats[p]=await get('/api/usage/stats?period='+p)}catch(e){stats[p]=null} }
 for(const c of connections) {
  if(!['codex','claude','grok-cli','github','antigravity','gemini-cli','cursor','kiro','qwen','devin','devin-cli'].includes(c.provider)) continue;
  try { const u=await get('/api/usage/'+encodeURIComponent(c.id));
   quotas[c.id]={quotas:u.quotas||{},updatedAt:Math.floor(Date.now()/1000),error:u.error||u.message?'Limite indisponível':''};
  }catch(e){quotas[c.id]={error:'Leitura de limite indisponível'}}
 }
 // Stats also contain API-key labels. Python projects only numeric counters.
 process.stdout.write(JSON.stringify({connections,stats,quotas}));
})().catch(e=>{console.error('Falha na leitura do painel');process.exit(1)});
'''


def ssh_gateway(name, config, previous):
    host = config.get('ssh_host', 'sennin-kvm' if name == 'hostinger' else '')
    if not host or host.startswith('-'):
        raise RuntimeError('Configure ssh_host')
    port = int(config.get('api_port', 20128))
    if not 1 <= port <= 65535:
        raise RuntimeError('Porta do painel inválida')
    remote = shlex.join(['docker', 'exec', '-i', config.get('container', '9router'), 'node'])
    proc = subprocess.run(['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=10', host, remote],
        input=HOSTINGER_JS.replace('port:20128', 'port:' + str(port)), text=True, capture_output=True, timeout=360)
    if proc.returncode:
        raise RuntimeError('Painel indisponível por SSH')
    payload = json.loads(proc.stdout)
    quotas = {}
    for key, raw in payload['quotas'].items():
        quotas[key] = dict(quotas=clean_quotas(raw), updatedAt=raw.get('updatedAt'), error=raw.get('error', ''))
    return normalize(name, config, payload['connections'], payload['stats'], quotas, previous)


def counters(raw):
    return dict(requests=int(number(raw.get('requests', raw.get('totalRequests')))),
        tokens=int(number(raw.get('promptTokens', raw.get('totalPromptTokens'))) + number(raw.get('completionTokens', raw.get('totalCompletionTokens')))),
        cost=number(raw.get('cost', raw.get('totalCost'))))


def normalize(name, config, connections, stats, quotas, previous):
    accounts = {c['id']: dict(id=c['id'], email=str(c.get('email') or ''), name=str(c.get('email') or c.get('name') or c['id'][:8]),
        provider=str(c.get('provider') or 'Outro'), active=c.get('isActive') is not False,
        status=str(c.get('testStatus') or ''), periods={}, quotas=[], quotaError='', quotaUpdatedAt=None)
        for c in connections if c.get('id')}
    totals = {}
    for period in PERIODS:
        raw = stats.get(period)
        totals[period] = counters(raw) if isinstance(raw, dict) else None
        if raw is None:
            continue
        for a in accounts.values():
            a['periods'][period] = dict(requests=0, tokens=0, cost=0)
        for row in (raw.get('byAccount') or {}).values():
            key = row.get('connectionId')
            if not key:
                continue
            if key not in accounts:
                accounts[key] = dict(id=key, name=str(row.get('accountName') or key[:8]), provider=str(row.get('provider') or 'Outro'),
                    active=False, status='Histórico · conta removida', periods={}, quotas=[], quotaError='', quotaUpdatedAt=None)
            bucket = accounts[key]['periods'].setdefault(period, dict(requests=0, tokens=0, cost=0))
            for k, value in counters(row).items():
                bucket[k] += value
    old = {a['id']: a for a in previous.get('accounts', [])}
    for key, a in accounts.items():
        for period in PERIODS:
            if stats.get(period) is not None:
                a['periods'].setdefault(period, dict(requests=0, tokens=0, cost=0))
        q = quotas.get(key)
        if q:
            a['quotaError'] = q.get('error', '')
            if q.get('quotas'):
                a['quotas'], a['quotaUpdatedAt'] = q['quotas'], q.get('updatedAt')
            elif q.get('error') and key in old:
                a['quotas'], a['quotaUpdatedAt'] = old[key].get('quotas', []), old[key].get('quotaUpdatedAt')
        elif a['active']:
            a['quotaError'] = 'Provedor não expõe limite'
    return dict(id=name, name=config.get('rotulo', name), updatedAt=int(time.time()), error='', totals=totals,
        accounts=sorted(accounts.values(), key=lambda a: (not a['active'], a['provider'], a['name'])))


def run():
    STATE.mkdir(parents=True, exist_ok=True, mode=0o700)
    try:
        previous = json.loads((STATE / 'status.json').read_text())
    except (OSError, ValueError):
        previous = dict(routers=[])
    registry = REGISTRY if REGISTRY.exists() or 'RADAR_9ROUTER_CONFIG' in os.environ else LEGACY_REGISTRY
    routers = json.loads(registry.read_text())['routers']
    old = {r['id']: r for r in previous['routers']}
    result = dict(updatedAt=int(time.time()), refreshing=True, routers=[old.get(name, dict(id=name, name=c.get('rotulo', name), accounts=[], totals={}, error='Aguardando leitura')) for name, c in routers.items()])
    def write():
        temp = STATE / 'status.tmp'
        temp.write_text(json.dumps(result, ensure_ascii=False))
        temp.chmod(0o600)
        temp.replace(STATE / 'status.json')
    write()
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        futures = {pool.submit(ssh_gateway if c.get('transport', 'ssh' if name == 'hostinger' else 'http') == 'ssh' else http_gateway, name, c, old.get(name, {})): name for name, c in routers.items()}
        for future in concurrent.futures.as_completed(futures):
            name = futures[future]
            try:
                entry = future.result()
            except Exception as error:
                entry = dict(old.get(name, dict(id=name, name=routers[name].get('rotulo', name), accounts=[], totals={})))
                entry['error'] = str(error) if isinstance(error, RuntimeError) else 'Não foi possível atualizar este router'
            result['routers'] = [entry if r['id'] == name else r for r in result['routers']]
            write()
    result['updatedAt'], result['refreshing'] = int(time.time()), False
    write()


if __name__ == '__main__':
    os.umask(0o077)
    run()
