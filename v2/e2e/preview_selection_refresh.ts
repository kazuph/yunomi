import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { chromium } from 'playwright';

const dir = mkdtempSync(join(tmpdir(), 'yunomi-selection-refresh-'));
const fixture = join(dir, 'selection.md');
const source = '# Selection\n\nParagraph alpha.\n\nParagraph beta.\n';
writeFileSync(fixture, source);
const server = spawn(process.execPath, [new URL('../_build/js/release/build/server/server.js', import.meta.url).pathname, fixture, '--no-open', '--loop', '--port', '0'], {
  env: { ...process.env, HERDR_PANE_ID: '', TMUX_PANE: '', YUNOMI_NOTIFY_CMD: '', YUNOMI_LOCK_DIR: join(dir, 'locks'), YUNOMI_REVIEW_DIR: join(dir, 'reviews') }, stdio: ['ignore', 'pipe', 'pipe'],
});
let output = '';
const ready = new Promise<string>((resolve, reject) => {
  const timeout = setTimeout(() => reject(new Error(output || 'Server startup timed out')), 30000);
  const read = (chunk: Buffer) => {
    output += chunk.toString();
    const match = output.match(/http:\/\/127\.0\.0\.1:\d+/);
    if (match) { clearTimeout(timeout); resolve(match[0]); }
  };
  server.stdout!.on('data', read); server.stderr!.on('data', read);
  server.on('exit', code => { clearTimeout(timeout); reject(new Error(`Server exited ${code}: ${output}`)); });
});
const browser = await chromium.launch();
let release!: () => void;
const gate = new Promise<void>(resolve => { release = resolve; });
try {
  const url = await ready;
  const page = await browser.newPage({ viewport: { width: 1100, height: 900 } });
  await page.goto(url);
  await page.locator('#md-preview p').last().waitFor();
  let requested!: () => void;
  const requestStarted = new Promise<void>(resolve => { requested = resolve; });
  // Delay the real refresh response; no response data or browser selection is replaced.
  await page.route(url + '/', async route => {
    if (route.request().isNavigationRequest()) return route.continue();
    requested(); await gate; await route.continue();
  });
  writeFileSync(fixture, 'Inserted paragraph.\n\n' + source);
  assert.equal((await fetch(url + '/go', { method: 'POST' })).status, 200);
  await requestStarted;
  const points = await page.locator('#md-preview').evaluate(preview => {
    const first = [...preview.querySelectorAll('p')].find(el => el.textContent === 'Paragraph alpha.')!;
    const last = [...preview.querySelectorAll('p')].find(el => el.textContent === 'Paragraph beta.')!;
    const r = document.createRange(); r.selectNodeContents(first); const a = r.getBoundingClientRect();
    r.selectNodeContents(last); const b = r.getBoundingClientRect();
    return { x: a.left, y: a.top + a.height / 2, mid: a.left + a.width / 2, end: b.right, endY: b.top + b.height / 2 };
  });
  await page.mouse.move(points.x, points.y); await page.mouse.down();
  await page.mouse.move(points.mid, points.y, { steps: 3 });
  const before = await page.evaluate(() => window.getSelection()!.toString());
  assert.ok(before.length > 0);
  const responsePromise = page.waitForResponse(response => response.url() === url + '/' && !response.request().isNavigationRequest());
  release();
  await (await responsePromise).finished();
  await page.evaluate(() => new Promise<void>(resolve => requestAnimationFrame(() => resolve())));
  assert.equal(await page.evaluate(() => window.getSelection()!.toString()), before, 'a refresh response must not destroy an active native selection');
  await page.mouse.move(points.end, points.endY, { steps: 15 }); await page.mouse.up();
  const editor = page.locator('.yunomi-inline-comment-editor'); await editor.waitFor();
  await page.waitForFunction(() => document.querySelector('#md-preview p')?.textContent === 'Inserted paragraph.');
  assert.equal((await page.locator('#cell-preview').textContent())!.replace(/\s+/g, ' ').trim(), 'Paragraph alpha. Paragraph beta.');
  assert.match((await editor.getAttribute('data-comment-key'))!, /\|2-4$/);
  console.log('PASS: an in-flight refresh waits for native drag and mouseup consumption, then updates the preview without changing the exact quote');
} finally { release(); await browser.close(); server.kill('SIGTERM'); }
