/** Routing-only shell fixtures; no live CLI or delivery command is invoked. */
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, symlinkSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('../../', import.meta.url).pathname;
const bin = mkdtempSync('/tmp/yn-route-');
const jq = spawnSync('/usr/bin/which', ['jq'], { encoding: 'utf8' }).stdout.trim();
assert.ok(jq, 'real jq required');
symlinkSync(jq, join(bin, 'jq'));
symlinkSync('/usr/bin/printenv', join(bin, 'printenv'));
function paneFunction(name: string, pane: string, currentFails = false, getFails = false) {
  return `${name}() {
    if [ "$1 $2" = 'pane current' ]; then
      ${currentFails ? 'return 1' : `printf '%s\\n' '{"result":{"pane":{"pane_id":"${pane}"}}}'`}
    elif [ "$1 $2" = 'pane get' ]; then
      ${getFails ? 'return 1' : `test "$3" = '${pane}'`}
    else return 97; fi
  }\n`;
}
const cases = [
  { name: 'ikesu available', prelude: paneFunction('ikesu', 'p10'), route: 'ikesu', status: 0 },
  { name: 'ikesu absent, herdr available', prelude: paneFunction('herdr', 'p20'), route: 'herdr', status: 0 },
  { name: 'both absent, tmux available', prelude: `export TMUX=isolated TMUX_PANE=%30 YUNOMI_NOTIFY_CMD=true; tmux() { printf '%s\\n' '%30'; }`, route: 'tmux', status: 0 },
  { name: 'no route', prelude: '', route: '', status: 1 },
  { name: 'ikesu current fails, herdr available', prelude: paneFunction('ikesu', 'p10', true) + paneFunction('herdr', 'p20'), route: 'herdr', status: 0 },
  { name: 'ikesu pane validation fails', prelude: paneFunction('ikesu', 'p10', false, true) + paneFunction('herdr', 'p20'), route: '', status: 1 },
];
let generatedRouteSource = '';
try {
  for (const file of ['v2/src/server/main.mbt', 'CLAUDE.md', 'README.md', 'README.ja.md']) {
    const source = readFileSync(join(root, file), 'utf8');
    const markdown = file.endsWith('.mbt') ? source.split('\n').filter(l => /^\s*#\|/.test(l)).map(l => l.replace(/^\s*#\|/, '')).join('\n') : source;
    const route = [...markdown.matchAll(/```bash\n([\s\S]*?)```/g)].map(m => m[1]).find(code => code.includes('YUNOMI_ROUTE=ikesu'));
    assert.ok(route, `${file}: full route selection documented`);
    if (file.endsWith('.mbt')) generatedRouteSource = route;
    assert.ok(!route.includes('${'), `${file}: no JS template interpolation`);
    for (const flags of [[], ['-eu']]) for (const scenario of cases) {
      const result = spawnSync('/bin/bash', [...flags, '-c', scenario.prelude + '\n' + route + '\nprintf "%s\\n" "$YUNOMI_ROUTE"'], { env: { PATH: bin }, encoding: 'utf8' });
      const label = `${file}: bash ${flags.join(' ')} / ${scenario.name}`;
      assert.equal(result.status, scenario.status, `${label}: ${result.stderr}`);
      assert.equal(result.stdout.trim(), scenario.route, label);
      console.log('PASS routing only:', label);
    }
    assert.ok(markdown.includes('Bash') && markdown.includes('ikesu log <job>'), `${file}: separate background task and job result instructions`);
  }
  const generated = spawnSync(process.execPath, [join(root, 'v2/_build/js/release/build/server/server.js'), '--skill'], { encoding: 'utf8' });
  assert.equal(generated.status, 0, generated.stderr);
  const generatedRoute = [...generated.stdout.matchAll(/```bash\n([\s\S]*?)```/g)].map(m => m[1]).find(code => code.includes('YUNOMI_ROUTE=ikesu'));
  assert.equal(generatedRoute?.trim(), generatedRouteSource.trim(), 'the built skill uses the exact tested route');
  assert.ok(generated.stdout.includes('Bash background task') && generated.stdout.includes('ikesu log <job>'), 'built skill separates result collection by launch method');
  assert.ok(!readFileSync(join(root, 'v2/src/server/main.mbt'), 'utf8').includes('From then on Herdr, use'));
  console.log('PASS all 48 routing-only cases; no live server or delivery command invoked');
} finally { rmSync(bin, { recursive: true, force: true }); }
