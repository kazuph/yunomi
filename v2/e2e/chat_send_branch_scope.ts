import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const script = new URL('../_build/js/release/build/server/server.js', import.meta.url).pathname;
const root = mkdtempSync(join(tmpdir(), 'yunomi-send-branch-'));
const git = (...args: string[]) => { const r = spawnSync('git', args, { cwd: root, encoding: 'utf8' }); assert.equal(r.status, 0, r.stderr); };
git('init', '-b', 'main'); git('config', 'user.name', 'Test'); git('config', 'user.email', 'test@example.invalid');
writeFileSync(join(root, 'a.md'), '# A\n'); writeFileSync(join(root, 'b.md'), '# B\n');
git('add', 'a.md', 'b.md'); git('commit', '-m', 'base');
git('switch', '-c', 'before');
writeFileSync(join(root, 'a.md'), '# Changed A\n'); writeFileSync(join(root, 'b.md'), '# Changed B\n');
git('add', 'a.md', 'b.md'); git('commit', '-m', 'changes');
async function start(args: string[], override = '') {
  const env = { ...process.env, IKESU_PANE_ID: '', IKESU_SOCKET_PATH: '', IKESU: '', HERDR_PANE_ID: '', TMUX_PANE: '', YUNOMI_NOTIFY_CMD: '', YUNOMI_LOCK_DIR: join(root, 'locks') };
  if (override) env.YUNOMI_REVIEW_DIR = override; else delete env.YUNOMI_REVIEW_DIR;
  const proc = spawn(process.execPath, [script, ...args, '--no-open', '--port', '0'], { cwd: root, env, stdio: ['ignore', 'pipe', 'pipe'] });
  let output = '';
  const port = await new Promise<number>((resolve, reject) => {
    const onData = (data: Buffer) => { output += data.toString(); const m = output.match(/http:\/\/127\.0\.0\.1:(\d+)/); if (m) resolve(Number(m[1])); };
    proc.stdout.on('data', onData); proc.stderr.on('data', onData);
    proc.once('exit', c => reject(new Error(`exit ${c}: ${output}`)));
    setTimeout(() => reject(new Error(`startup: ${output}`)), 15000).unref();
  });
  return { proc, port };
}
async function state(port: number, query = '') { const r = await fetch(`http://127.0.0.1:${port}/review-state${query}`); assert.equal(r.status, 200); return r.json(); }
async function create(port: number, text: string, query = '') { const r = await fetch(`http://127.0.0.1:${port}/create-global-comment${query}`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ text, clientId: text }) }); assert.equal(r.status, 200); }
async function stop(proc: ReturnType<typeof spawn>) { await new Promise<void>(resolve => { proc.once('exit', () => resolve()); proc.kill('SIGTERM'); }); }
try {
  const single = await start([join(root, 'a.md')]);
  await create(single.port, 'single-before');
  assert.ok((await state(single.port)).review.comments.some((c: any) => c.text === 'single-before'));
  git('switch', '-c', 'after');
  assert.ok(!(await state(single.port)).review.comments.some((c: any) => c.text === 'single-before'));
  await create(single.port, 'single-after');
  git('switch', 'before');
  assert.ok((await state(single.port)).review.comments.some((c: any) => c.text === 'single-before'));
  await stop(single.proc);
  const mux = await start(['review', 'main']);
  await create(mux.port, 'mux-before', '?f=0');
  git('switch', 'after');
  assert.ok((await state(mux.port, '?f=0')).review.comments.some((c: any) => c.text === 'mux-before'));
  await stop(mux.proc);
  const fixed = await start([join(root, 'a.md')], join(root, 'fixed'));
  await create(fixed.port, 'fixed-before');
  git('switch', 'before');
  assert.ok((await state(fixed.port)).review.comments.some((c: any) => c.text === 'fixed-before'));
  await stop(fixed.proc);
  console.log('PASS request-scoped branch changes and fixed mux/override review destinations');
} finally { rmSync(root, { recursive: true, force: true }); }
