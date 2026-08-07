#!/usr/bin/env node
// Seam eval runner — the `make eval` gate (Build & Run §1, §4).
// Covers today: M0 (store + ledger roundtrip), M1 fixture ingestion
// (counts, idempotency, watermark advance, dark-source isolation), and the
// banned-tools lint (§6.1). Exits non-zero on any failure.
import { mkdtempSync, rmSync, writeFileSync, readFileSync, readdirSync, mkdirSync } from 'fs';
import { tmpdir } from 'os';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { initStore, readWatermarks } from '../src/lib/store.mjs';
import { appendEvent, readEvents } from '../src/lib/ledger.mjs';
import { loadProfile } from '../src/lib/profile.mjs';
import { syncOnce } from '../src/sync.mjs';

const pluginRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const results = [];
const check = (name, cond, detail = '') => results.push(`${cond ? 'PASS' : 'FAIL'} ${name}${cond || !detail ? '' : ` — ${detail}`}`);

const work = mkdtempSync(join(tmpdir(), 'seam-eval-'));
const storeRoot = join(work, 'store');
const home = join(work, 'home');
process.env.SEAM_HOME = home;

// ---- M0: profile load, store init, actor-attributed roundtrip ----
mkdirSync(join(home, 'profiles'), { recursive: true });
writeFileSync(join(home, 'profiles', 'personal.yaml'),
  readFileSync(join(pluginRoot, 'profiles', 'personal.yaml.template'), 'utf8')
    .replace('store_root: ""', `store_root: "${storeRoot}"`));
let profile;
try {
  ({ profile } = loadProfile('personal'));
  check('M0 profile loads from template-derived instance config', true);
} catch (err) {
  check('M0 profile loads from template-derived instance config', false, err.message);
}
initStore(storeRoot, 'personal');
appendEvent(storeRoot, { actor: 'agent', type: 'store_initialized', profile: 'personal' });
const m0Events = readEvents(storeRoot, { type: 'store_initialized' });
check('M0 store created + one actor-attributed event round-trips',
  m0Events.length === 1 && m0Events[0].actor === 'agent', JSON.stringify(m0Events));
let rejected = false;
try { appendEvent(storeRoot, { actor: 'model', type: 'nope' }); } catch { rejected = true; }
check('M0 ledger rejects unattributed actor', rejected);
let residency = false;
try { initStore(storeRoot, 'work'); } catch { residency = true; }
check('M0 residency guard refuses cross-profile store', residency);

// ---- M1: fixture ingestion ----
const golden = JSON.parse(readFileSync(join(pluginRoot, 'evals', 'goldens', 'm1_ingest.json'), 'utf8'));
const ctx = { profile, storeRoot, fixturesRoot: join(pluginRoot, 'fixtures') };
const first = syncOnce(ctx);
for (const [surface, want] of Object.entries(golden.counts)) {
  check(`M1 ${surface} appended ${want}`, first[surface]?.appended === want, JSON.stringify(first[surface]));
}
const wm = readWatermarks(storeRoot);
check('M1 watermarks advanced for all surfaces',
  Object.keys(golden.counts).every((s) => wm[s]?.high_water && wm[s]?.last_ok && wm[s]?.dark === false),
  JSON.stringify(wm));
const second = syncOnce(ctx);
for (const [surface, want] of Object.entries(golden.rerun_appends)) {
  check(`M1 re-run idempotent on ${surface} (${want} new)`, second[surface]?.appended === want, JSON.stringify(second[surface]));
}
const rawDays = readdirSync(join(storeRoot, 'raw', 'email'));
check('M1 raw JSONL laid out by day', rawDays.length >= 1 && rawDays.every((f) => /^\d{4}-\d{2}-\d{2}\.jsonl$/.test(f)), rawDays.join(','));
const syncEvents = readEvents(storeRoot, { type: 'sync_requested' });
check('M1 sync events carry per-source results', syncEvents.length === 2 && syncEvents.every((e) => e.actor === 'agent' && e.result.email));

// Dark-source isolation: a live (not-enabled) surface fails alone.
const darkProfile = { ...profile, sources: profile.sources.map((s) => s.surface === 'slack' ? { ...s, backend: 'live' } : s) };
const third = syncOnce({ ...ctx, profile: darkProfile });
check('M1 dark source isolated (slack fails, email/calendar ok)',
  third.slack?.ok === false && third.email?.ok === true && third.calendar?.ok === true, JSON.stringify(third));
const wmDark = readWatermarks(storeRoot);
check('M1 dark window recorded with dark_since', wmDark.slack?.dark === true && !!wmDark.slack?.dark_since);

// ---- §6.1 banned-tools lint ----
const { banned_regexes } = JSON.parse(readFileSync(join(pluginRoot, 'evals', 'banned-tools.json'), 'utf8'));
const offenders = [];
function scan(dir) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const p = join(dir, entry.name);
    if (entry.isDirectory()) scan(p);
    else if (/\.(mjs|js|md|json|yaml|template)$/.test(entry.name) && !p.includes('banned-tools.json')) {
      const text = readFileSync(p, 'utf8');
      for (const re of banned_regexes) {
        if (new RegExp(re).test(text)) offenders.push(`${p} matches /${re}/`);
      }
    }
  }
}
for (const d of ['src', 'bin', 'skills', 'profiles']) {
  try { scan(join(pluginRoot, d)); } catch { /* dir may not exist yet */ }
}
check('§6.1 zero send-capable tool names in plugin code', offenders.length === 0, offenders.join('; '));


// ---- board smoke validator (M3 prerequisite; skipped when jsdom absent) ----
try {
  await import('jsdom');
  const { execFileSync } = await import('child_process');
  const out = execFileSync(process.execPath, [join(pluginRoot, 'src', 'board', 'validate.mjs')], { encoding: 'utf8' });
  const lines = out.trim().split('\n');
  check(`board validator ${lines.length} checks`, !lines.some((l) => l.startsWith('FAIL')), out);
} catch (err) {
  if (err?.code === 'ERR_MODULE_NOT_FOUND') results.push('SKIP board validator (jsdom not installed)');
  else check('board validator', false, String(err.stdout ?? err.message ?? err));
}

rmSync(work, { recursive: true, force: true });
console.log(results.join('\n'));
process.exit(results.some((r) => r.startsWith('FAIL')) ? 1 : 0);
