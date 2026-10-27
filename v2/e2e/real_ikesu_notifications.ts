/** Opt-in real ikesu contract suite. No fake ikesu, no production socket. */
import assert from 'node:assert/strict';
import { spawn, spawnSync, type ChildProcess } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, symlinkSync, writeFileSync } from 'node:fs';
import { basename, join, resolve } from 'node:path';
import { chromium } from 'playwright';

const binary = process.env.YUNOMI_REAL_IKESU;
assert.ok(binary && existsSync(binary), 'YUNOMI_REAL_IKESU must name a real ikesu binary; no fallback');
const root = mkdtempSync('/tmp/yi-');
const artifacts = resolve(process.env.YUNOMI_E2E_ARTIFACTS || root);
mkdirSync(artifacts, { recursive: true });
const serverJs = new URL('../_build/js/release/build/server/server.js', import.meta.url).pathname;
const cleanEnv = Object.fromEntries(Object.entries(process.env).filter(([k]) => !/^(IKESU|HERDR|TMUX|YUNOMI_|NODE_OPTIONS)/.test(k)));
const children: ChildProcess[] = [];
const outputs: string[] = [];
const flushLogs: (() => void)[] = [];
const log = (s: string) => { outputs.push(s); console.log(s); };
// Bounded condition waits belong to the test, not job-completion polling.
async function until(check: () => boolean | Promise<boolean>, label: string, timeout = 15000) {
  const end = Date.now() + timeout;
  while (!(await check())) {
    if (Date.now() >= end) throw new Error('timeout: ' + label);
    await new Promise(r => setTimeout(r, 50));
  }
}
async function stable(check: () => void, duration = 700) {
  const end = Date.now() + duration;
  do { check(); await new Promise(r => setTimeout(r, 50)); } while (Date.now() < end);
}
function checked(command: string, args: string[], env: NodeJS.ProcessEnv) {
  const r = spawnSync(command, args, { env, encoding: 'utf8', timeout: 10000 });
  assert.equal(r.status, 0, `${command} ${args.join(' ')}: ${r.stderr}${r.stdout}`);
  return r.stdout;
}
function shellQuote(value: string) { return "'" + value.replaceAll("'", "'\\''") + "'"; }
async function runtime(name: string) {
  const dir = join(root, name); mkdirSync(join(dir, 'bin'), { recursive: true });
  symlinkSync(binary!, join(dir, 'bin', 'ikesu'));
  symlinkSync(process.execPath, join(dir, 'bin', 'pi'));
  const socket = join(dir, 'state', 'default', 'ikesu.sock');
  const env = { ...cleanEnv, PATH: `${join(dir, 'bin')}:${process.env.PATH}`, SHELL: '/bin/sh',
    IKESU_STATE_DIR: join(dir, 'state'), IKESU_CONFIG: join(dir, 'config.toml'),
    IKESU_SOCKET_PATH: socket, IKESU_SOCKET_PATH_EXPLICIT: '1',
    XDG_CONFIG_HOME: join(dir, 'config'), XDG_RUNTIME_DIR: join(dir, 'run') };
  writeFileSync(env.IKESU_CONFIG, '[experimental]\nallow_nested = true\n');
  const server = spawn(join(dir, 'bin', 'ikesu'), ['server'], { env, cwd: dir, stdio: ['ignore', 'pipe', 'pipe'] });
  children.push(server);
  let output = ''; server.stdout!.on('data', d => output += d); server.stderr!.on('data', d => output += d);
  await until(() => { assert.equal(server.exitCode, null, output); return existsSync(socket); }, 'isolated socket');
  const cli = (...args: string[]) => checked(join(dir, 'bin', 'ikesu'), args, env);
  const ws = JSON.parse(cli('workspace', 'create', '--cwd', dir));
  const pane: string = ws.result.root_pane.pane_id;
  const receivedFile = join(dir, 'received.jsonl'); writeFileSync(receivedFile, '');
  const reader = join(dir, 'reader.cjs');
  writeFileSync(reader, 'const fs=require("fs");require("readline").createInterface({input:process.stdin}).on("line",l=>{fs.appendFileSync(process.argv[2],JSON.stringify(l)+"\\n");console.log("AGENT_GOT:"+l)});console.log("READER_READY");');
  cli('pane', 'run', pane, `${join(dir, 'bin', 'pi')} ${reader} ${receivedFile}`);
  await until(() => cli('pane', 'read', pane, '--lines', '20').includes('READER_READY'), 'reader ready');
  const state = (value: string) => cli('pane', 'report-agent', pane, '--source', 'yunomi-test', '--agent', 'pi', '--state', value);
  state('idle');
  const received = (): string[] => readFileSync(receivedFile, 'utf8').split('\n').filter(Boolean).map(l => JSON.parse(l));
  log(`isolated ${name}: ${cli('--version').trim()} socket=${socket} pane=${pane}`);
  return { dir, env, cli, pane, state, received };
}
type Runtime = Awaited<ReturnType<typeof runtime>>;
const browser = await chromium.launch();
let sequence = 0;
async function review(rt: Runtime, args = ['--notify-ikesu-pane', rt.pane], extra: NodeJS.ProcessEnv = {}) {
  const reviewId = ++sequence;
  const dir = join(rt.dir, `review-${reviewId}`); mkdirSync(dir);
  const report = join(dir, 'REPORT.md'); writeFileSync(report, '# delivery check\n\n- [ ] 通知が届くか確認する\n');
  const callsFile = join(dir, 'calls.jsonl'); writeFileSync(callsFile, '');
  // Observe real child calls without substituting commands, results, or transports.
  const observer = join(dir, 'observe.cjs');
  writeFileSync(observer, `const fs=require('node:fs'),cp=require('node:child_process');const original=cp.spawnSync;cp.spawnSync=function(cmd,args,opts){fs.appendFileSync(${JSON.stringify(callsFile)},JSON.stringify([cmd,...args])+'\\n');return original.call(this,cmd,args,opts)};require('node:module').syncBuiltinESMExports();`);
  const child = spawn(process.execPath, ['--require', observer, serverJs, report, '--loop', '--no-open', '--port', '0', ...args], {
    cwd: dir, env: { ...rt.env, YUNOMI_LOCK_DIR: join(dir, 'locks'), YUNOMI_REVIEW_DIR: join(dir, 'reviews'), ...extra }, stdio: ['ignore', 'pipe', 'pipe'],
  });
  children.push(child);
  let output = ''; child.stdout!.on('data', d => output += d); child.stderr!.on('data', d => output += d);
  const flush = () => writeFileSync(join(artifacts, `review-${reviewId}.log`), output);
  flushLogs.push(flush); child.on('exit', flush);
  await until(() => { assert.equal(child.exitCode, null, output); return /http:\/\/127\.0\.0\.1:\d+/.test(output); }, 'yunomi startup');
  const url = output.match(/http:\/\/127\.0\.0\.1:\d+/)![0];
  const page = await browser.newPage({ viewport: { width: 1100, height: 700 } });
  await page.goto(url);
  const calls = (): string[][] => readFileSync(callsFile, 'utf8').split('\n').filter(Boolean).map(l => JSON.parse(l));
  const items = async (): Promise<{id: string, message: string}[]> => (await (await fetch(url + '/notify/undelivered')).json()).items;
  const retry = async (id: string) => {
    const r = await fetch(url + '/notify/retry', { method: 'POST', headers: { 'Content-Type': 'application/json', Origin: url }, body: JSON.stringify({ id }) });
    assert.equal(r.status, 200);
  };
  const expected = [`[yunomi] decision REPORT.md:3 checked=true`, '> - [x] 通知が届くか確認する', `url=${url}`];
  return { page, child, calls, items, retry, expected, dir };
}
function ownKill(child: ChildProcess) {
  if (child.exitCode !== null || !child.pid) return;
  const found = spawnSync('pgrep', ['-u', String(process.getuid!()), '-f', `${root}|${serverJs}`], { encoding: 'utf8' });
  assert.ok(found.stdout.split('\n').includes(String(child.pid)), `own PID ${child.pid} verified before kill`);
  process.kill(child.pid, 'SIGTERM');
}
async function closeReview(h: Awaited<ReturnType<typeof review>>) { ownKill(h.child); await h.page.close(); }
try {
  const rt = await runtime('a');
  let before = rt.received().length;
  const delivery = await review(rt);
  await delivery.page.locator('.task-decision-checkbox').first().click();
  await until(() => rt.received().length >= before + 3, 'multiline delivery');
  await stable(() => assert.deepEqual(rt.received().slice(before), delivery.expected));
  await delivery.page.screenshot({ path: join(artifacts, 'ikesu-delivery.png') });
  assert.equal(delivery.calls().filter(c => c[1] === 'agent' && c[2] === 'prompt').length, 1);
  log('PASS ① browser checkbox: exact multiline notification once');
  await closeReview(delivery);

  rt.state('blocked'); before = rt.received().length;
  const blocked = await review(rt);
  await blocked.page.locator('.task-decision-checkbox').first().click();
  await until(async () => (await blocked.items()).length === 1, 'blocked undelivered');
  await stable(() => assert.equal(rt.received().length, before));
  await blocked.page.reload();
  assert.equal((await blocked.items()).length, 1);
  if (!(await blocked.page.locator('#notify-undelivered-panel').isVisible())) await blocked.page.locator('#notify-undelivered').click();
  await blocked.page.screenshot({ path: join(artifacts, 'ikesu-blocked.png') });
  rt.state('idle'); await blocked.page.locator('#notify-undelivered-panel .notify-undelivered-retry').first().click();
  await until(async () => (await blocked.items()).length === 0 && rt.received().length >= before + 3, 'blocked retry');
  await stable(() => assert.deepEqual(rt.received().slice(before), blocked.expected));
  log('PASS ② blocked: zero delivery, reload preserves list, retry delivers once');
  await closeReview(blocked);

  rt.state('blocked'); before = rt.received().length;
  const held = await review(rt);
  await held.page.locator('.task-decision-checkbox').first().click();
  await until(async () => (await held.items()).length === 1, 'ordinary held item');
  await held.page.locator('#send-and-exit').click();
  await held.page.locator('#submit-modal.visible').waitFor();
  await held.page.locator('#modal-approve').click();
  await until(async () => (await held.items()).some(i => i.message.startsWith('[yunomi] verdict')), 'held verdict');
  await stable(() => { assert.equal(held.child.exitCode, null); assert.equal(rt.received().length, before); });
  const pending = await held.items();
  const ordinary = pending.find(i => i.message.startsWith('[yunomi] decision'))!;
  const verdict = pending.find(i => i.message.startsWith('[yunomi] verdict'))!;
  rt.state('idle'); await held.retry(ordinary.id);
  await until(() => rt.received().length >= before + 3, 'ordinary retry while verdict held');
  await stable(() => assert.equal(held.child.exitCode, null));
  await held.page.screenshot({ path: join(artifacts, 'ikesu-held.png') });
  await held.retry(verdict.id);
  await until(() => held.child.exitCode !== null, 'final retry exit');
  assert.equal(held.child.exitCode, 0);
  await until(() => rt.received().length >= before + 3 + verdict.message.split('\n').length, 'verdict reader');
  assert.deepEqual(rt.received().slice(before), [...held.expected, ...verdict.message.split('\n')]);
  log('PASS ③ final refusal holds exit; ordinary retry does not exit; final retry exits 0');
  await held.page.close();

  // Mail proves its sender by process ancestry: launch yunomi in an owned
  // isolated pane, rather than claiming a pane ID from an unrelated process.
  rt.state('blocked'); // Keep durable mail queued so recipient inbox can read it.
  const mailDir = join(rt.dir, 'mail'); mkdirSync(mailDir);
  const mailReport = join(mailDir, 'REPORT.md'); writeFileSync(mailReport, '# mail check\n\n- [ ] 部屋つき通知を確認する\n');
  const mailOutput = join(mailDir, 'yunomi.log'); writeFileSync(mailOutput, '');
  const sender = JSON.parse(rt.cli('workspace', 'create', '--cwd', mailDir)).result.root_pane.pane_id;
  rt.cli('pane', 'run', sender, `env PATH=${shellQuote(join(rt.dir, 'bin') + ':/opt/homebrew/bin:/usr/bin:/bin')} ${[join(rt.dir, 'bin', 'pi'), serverJs, mailReport, '--loop', '--no-open', '--port', '0', '--notify-ikesu-pane', rt.pane, '--notify-room', 'yunomi-isolated'].map(shellQuote).join(' ')} > ${shellQuote(mailOutput)} 2>&1`);
  const mailPage = await browser.newPage();
  try {
    await until(() => /http:\/\/127\.0\.0\.1:\d+/.test(readFileSync(mailOutput, 'utf8')), 'mail yunomi in owned sender pane');
    rt.cli('pane', 'report-agent', sender, '--source', 'yunomi-test', '--agent', 'pi', '--state', 'working');
    const mailUrl = readFileSync(mailOutput, 'utf8').match(/http:\/\/127\.0\.0\.1:\d+/)![0];
    await mailPage.goto(mailUrl);
    await mailPage.locator('.task-decision-checkbox').first().click();
    await until(() => rt.cli('msg', 'history', '--room', 'yunomi-isolated').includes('[yunomi] decision'), 'room delivery in history');
    const history = rt.cli('msg', 'history', '--room', 'yunomi-isolated');
    assert.ok(history.includes('yunomi-isolated') && history.includes('[yunomi] decision'), history);
    const inbox = rt.cli('inbox', '--room', 'yunomi-isolated', '--to', rt.pane);
    assert.ok(inbox.includes('[yunomi] decision'), inbox);
    assert.equal((history.match(/\[yunomi\] decision/g) || []).length, 1, 'one durable mailbox notification');
    writeFileSync(join(artifacts, 'ikesu-room.txt'), history + '\n' + inbox);
    await mailPage.screenshot({ path: join(artifacts, 'ikesu-room.png') });
    log('PASS ④ room mail exists once in history and recipient inbox, sender ancestry proved');
  } finally {
    writeFileSync(join(artifacts, 'ikesu-room-yunomi.log'), readFileSync(mailOutput));
    writeFileSync(join(artifacts, 'ikesu-room-sender.txt'), rt.cli('pane', 'read', sender, '--lines', '50'));
    rt.cli('pane', 'close', sender);
    await mailPage.close();
  }

  const tmuxBin = spawnSync('which', ['tmux'], { encoding: 'utf8' }).stdout.trim();
  assert.ok(tmuxBin, 'real tmux required');
  const tmuxSocket = `yi-${basename(root)}`;
  const tmuxDir = join(root, 'tmux'); mkdirSync(tmuxDir);
  const tmuxEnv = { ...cleanEnv, TMUX_TMPDIR: tmuxDir };
  const tmux = (...args: string[]) => checked(tmuxBin, ['-L', tmuxSocket, ...args], tmuxEnv);
  tmux('new-session', '-d', '-s', 'isolated', '-c', root);
  try {
    const pane = tmux('display-message', '-p', '#{pane_id}').trim();
    const tmuxAddress = tmux('display-message', '-p', '#{socket_path}').trim();
    const receivedFile = join(root, 'tmux-received.jsonl'); writeFileSync(receivedFile, '');
    tmux('send-keys', '-t', pane, '-l', `${process.execPath} ${join(rt.dir, 'reader.cjs')} ${receivedFile}`); tmux('send-keys', '-t', pane, 'Enter');
    await until(() => tmux('capture-pane', '-p', '-t', pane).includes('READER_READY'), 'tmux reader');
    const tmuxLines = (): string[] => readFileSync(receivedFile, 'utf8').split('\n').filter(Boolean).map(l => JSON.parse(l));
    rt.state('blocked'); before = rt.received().length;
    const mixed = await review(rt, ['--notify-ikesu-pane', rt.pane, '--notify-tmux-pane', pane], { TMUX: `${tmuxAddress},0,0`, TMUX_TMPDIR: tmuxDir });
    await mixed.page.locator('.task-decision-checkbox').first().click();
    await until(async () => (await mixed.items()).length === 1 && tmuxLines().length >= 3, 'partial success');
    assert.deepEqual(tmuxLines(), mixed.expected); assert.equal(rt.received().length, before);
    const callsBefore = mixed.calls().filter(c => basename(c[0]) === 'tmux').length;
    rt.state('idle'); await mixed.retry((await mixed.items())[0].id);
    await until(async () => (await mixed.items()).length === 0 && rt.received().length >= before + 3, 'failed-route retry');
    await stable(() => { assert.deepEqual(tmuxLines(), mixed.expected); assert.deepEqual(rt.received().slice(before), mixed.expected); });
    assert.equal(mixed.calls().filter(c => basename(c[0]) === 'tmux').length, callsBefore);
    log('PASS ⑤ real isolated tmux succeeds, ikesu fails; retry only failed ikesu route');
    await closeReview(mixed);
  } finally { tmux('kill-server'); }

  const other = await runtime('b'); assert.equal(other.pane, rt.pane, 'same pane ID in isolated servers');
  before = rt.received().length;
  const routes = await review(rt, [], { IKESU_PANE_ID: rt.pane, HERDR_PANE_ID: rt.pane, HERDR_SOCKET_PATH: join(other.dir, 'absent-herdr.sock'), TMUX_PANE: '%99' });
  await routes.page.locator('.task-decision-checkbox').first().click();
  await until(() => rt.received().length >= before + 3, 'implicit ikesu');
  await stable(() => { assert.deepEqual(rt.received().slice(before), routes.expected); assert.deepEqual(other.received(), []); });
  assert.equal(routes.calls().filter(c => basename(c[0]) === 'herdr' || basename(c[0]) === 'tmux').length, 0);
  writeFileSync(join(artifacts, 'ikesu-route-calls.json'), JSON.stringify(routes.calls(), null, 2));
  log('PASS ⑥ inherited HERDR/TMUX ignored; same ID in second server receives zero; no herdr/tmux calls');
  await closeReview(routes);

  const customFile = join(root, 'custom.jsonl'); writeFileSync(customFile, '');
  const custom = join(root, 'custom.cjs'); writeFileSync(custom, 'require("fs").appendFileSync(process.argv[2],JSON.stringify(process.argv[3])+"\\n")');
  before = rt.received().length;
  const override = await review(rt, ['--notify-ikesu-pane', rt.pane, '--notify-tmux-pane', '%99', '--notify-pane', rt.pane], { YUNOMI_NOTIFY_CMD: `${process.execPath} ${custom} ${customFile} {msg}` });
  await override.page.locator('.task-decision-checkbox').first().click();
  await until(() => readFileSync(customFile, 'utf8').length > 0, 'custom command');
  await stable(() => {
    assert.deepEqual(readFileSync(customFile, 'utf8').trim().split('\n').map(l => JSON.parse(l)), [override.expected.join('\n')]);
    assert.equal(rt.received().length, before);
  });
  assert.equal(override.calls().filter(c => /^(ikesu|herdr|tmux)$/.test(basename(c[0]))).length, 0);
  log('PASS ⑦ YUNOMI_NOTIFY_CMD overrides all three routes and runs once');
  await closeReview(override);
  log('PASS real ikesu scenarios ①〜⑦');
} finally {
  await browser.close();
  for (const flush of flushLogs) flush();
  for (const child of children.reverse()) ownKill(child);
  writeFileSync(join(artifacts, 'real-ikesu-summary.log'), outputs.join('\n') + '\n');
  log(`isolated test files retained: ${root}`);
}
