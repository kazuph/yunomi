import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { chromium, type Page } from 'playwright';

const dir = mkdtempSync(join(tmpdir(), 'yunomi-selection-'));
const fixture = join(dir, 'selection.md');
const reviewDir = join(dir, 'reviews');
writeFileSync(fixture, '# Selection comments\n\nFirst repeated word.\n\nSecond repeated word with **bold text** and 日本語。\n\nParagraph alpha.\n\nParagraph beta.\n\n| Left | Right |\n| --- | --- |\n| repeated | repeated |\n\nFirst soft line\nSecond **bold** line\n\n```text\nfirst code line\nsecond code line\n```\n\nLiteral Image alt="cat" is text.\n');
const server = spawn(process.execPath, [new URL('../_build/js/release/build/server/server.js', import.meta.url).pathname, fixture, '--no-open', '--loop', '--port', '0'], {
  env: { ...process.env, HERDR_PANE_ID: '', TMUX_PANE: '', YUNOMI_NOTIFY_CMD: '', YUNOMI_LOCK_DIR: join(dir, 'locks'), YUNOMI_REVIEW_DIR: reviewDir },
  stdio: ['ignore', 'pipe', 'pipe'],
});
let output = '';
const ready = new Promise<string>((resolve, reject) => {
  const timeout = setTimeout(() => reject(new Error(output || 'Server startup timed out')), 30000);
  const read = (chunk: Buffer) => {
    output += chunk.toString();
    const match = output.match(/http:\/\/127\.0\.0\.1:\d+/);
    if (match) { clearTimeout(timeout); resolve(match[0]); }
  };
  server.stdout!.on('data', read);
  server.stderr!.on('data', read);
  server.on('exit', code => { clearTimeout(timeout); reject(new Error(`Server exited ${code}: ${output}`)); });
});

// Measure actual rendered text, then select with pointer events rather than setting window.Selection.
async function dragText(page: Page, selector: string, text: string, backwards = false) {
  const target = page.locator(selector);
  await target.scrollIntoViewIfNeeded();
  const points = await target.evaluate((el, needle) => {
    const walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
    let node: Node | null;
    while ((node = walker.nextNode())) {
      const start = (node.textContent || '').indexOf(needle);
      if (start < 0) continue;
      const r = document.createRange();
      r.setStart(node, start); r.setEnd(node, start + needle.length);
      const rects = Array.from(r.getClientRects());
      return { from: { x: rects[0].left, y: rects[0].top + rects[0].height / 2 }, to: { x: rects.at(-1)!.right, y: rects.at(-1)!.top + rects.at(-1)!.height / 2 } };
    }
    throw new Error(`Text not found: ${needle}`);
  }, text);
  const from = backwards ? points.to : points.from;
  const to = backwards ? points.from : points.to;
  await page.mouse.move(from.x, from.y); await page.mouse.down();
  await page.mouse.move(to.x, to.y, { steps: 12 }); await page.mouse.up();
}

const browser = await chromium.launch({ headless: true });
try {
  const url = await ready;
  const page = await browser.newPage({ viewport: { width: 1100, height: 900 } });
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  const requests: Record<string, unknown>[] = [];
  page.on('request', request => { if (request.method() === 'POST' && new URL(request.url()).pathname === '/comment') requests.push(request.postDataJSON()); });
  await page.goto(url);
  const editor = page.locator('.yunomi-inline-comment-editor');
  const input = page.locator('#comment-input');
  const quote = page.locator('#cell-preview');
  await page.locator('#md-preview p[data-source-start-line="3"]').click({ clickCount: 3 });
  await editor.waitFor();
  assert.equal((await quote.textContent())!.trim(), 'First repeated word.');
  assert.equal(await editor.getAttribute('data-comment-key').then(key => key!.split('|').at(-1)), '2:0');
  await input.press('Escape');
  await dragText(page, '#md-preview p[data-source-start-line="5"]', 'word', true);
  await editor.waitFor({ state: 'visible' });
  assert.equal(await quote.textContent(), 'word');
  assert.equal(await input.evaluate(el => document.activeElement === el), true);
  assert.equal(await editor.getAttribute('data-comment-key').then(key => key!.split('|').at(-1)), '4:0');
  await input.fill('Keep the short quote');
  await page.locator('#save-comment').click();
  await page.reload();
  const saved = page.locator('.yunomi-inline-comment-view').filter({ hasText: 'Keep the short quote' });
  await saved.waitFor();
  assert.equal(await saved.locator('.review-loop-quote').textContent(), 'word');
  await saved.click();
  assert.equal(await quote.textContent(), 'word');
  await input.press('Meta+Enter');
  await page.locator('.review-loop-inline').filter({ hasText: 'Keep the short quote' }).waitFor();
  const sent = requests.filter(r => r.text === 'Keep the short quote');
  assert.equal(sent.length, 1); assert.equal(sent[0].type, 'send-now'); assert.equal(sent[0].quote, 'word');
  const stored = JSON.parse(readFileSync(join(reviewDir, 'review.json'), 'utf8')).comments.find((c: { text: string }) => c.text === 'Keep the short quote');
  assert.equal(stored.quote, 'word'); assert.equal(stored.row, 4);
  console.log('PASS: backward short selection, exact row/quote, focus, save/reload/edit, Meta+Enter sends exactly once and persists quote');

  await dragText(page, '#md-preview p[data-source-start-line="5"] strong', 'bold text');
  await editor.waitFor(); assert.equal(await quote.textContent(), 'bold text');
  await input.press('Escape');
  await dragText(page, '#md-preview tbody tr td:nth-child(2)', 'repeated');
  await editor.waitFor(); assert.equal(await quote.textContent(), 'repeated');
  assert.match((await editor.getAttribute('data-comment-key'))!, /\|12:2$/);
  await input.fill('Right cell only'); await input.press('Control+Enter');
  await page.waitForFunction(() => Array.from(document.querySelectorAll('.review-loop-thread-line')).some(el => el.textContent?.includes('Right cell only')));
  assert.equal(requests.filter(r => r.text === 'Right cell only').length, 1);
  console.log('PASS: formatted text selection, cancel, identical table text retains column, Ctrl+Enter sends once');

  await page.locator('#md-preview tbody tr td:nth-child(1)').click();
  await editor.waitFor();
  await input.fill('Left cell only'); await input.press('Meta+Enter');
  const leftThread = page.locator('.review-loop-inline').filter({ hasText: 'Left cell only' });
  await leftThread.waitFor();
  assert.equal(await leftThread.locator('.review-loop-comment-head strong').textContent(), '表のセル（Markdown 13行目・1列目）');
  assert.equal(await leftThread.evaluate(el => el.closest('td')?.getAttribute('data-col')), '1');
  await page.reload();
  await leftThread.waitFor();
  assert.equal(await leftThread.evaluate(el => el.closest('td')?.getAttribute('data-col')), '1');
  console.log('PASS: Send now retains the left table cell and column label after reload');

  await dragText(page, '#md-preview p[data-source-start-line="15"] strong', 'bold');
  await editor.waitFor(); assert.equal(await quote.textContent(), 'bold');
  assert.match((await editor.getAttribute('data-comment-key'))!, /\|15:0$/);
  await input.fill('Second source line'); await page.locator('#save-comment').click();
  await page.reload();
  const softSaved = page.locator('.yunomi-inline-comment-view').filter({ hasText: 'Second source line' });
  await softSaved.waitFor(); await softSaved.click();
  assert.equal(await quote.textContent(), 'bold'); await input.fill(''); await page.locator('#save-comment').click();
  await dragText(page, '#md-preview pre code', 'first code line\nsecond code line');
  await editor.waitFor(); assert.equal(await quote.textContent(), 'first code line\nsecond code line');
  await input.press('Escape');
  await dragText(page, '#md-preview pre code', 'second code line');
  await editor.waitFor(); assert.equal(await quote.textContent(), 'second code line');
  assert.match((await editor.getAttribute('data-comment-key'))!, /\|19:0$/);
  await input.press('Escape');
  await dragText(page, '#md-preview p[data-source-start-line="23"]', 'Image alt="cat"');
  await editor.waitFor(); assert.equal(await quote.textContent(), 'Image alt="cat"');
  await input.press('Escape');
  console.log('PASS: soft-wrapped paragraph and code selections retain exact source lines, restore in place, and literal media-like text stays literal');

  writeFileSync(fixture, 'Inserted paragraph.\n\n' + readFileSync(fixture, 'utf8'));
  assert.equal((await fetch(url + '/go', { method: 'POST' })).status, 200);
  await page.waitForFunction(async () => { const state = await (await fetch('/review-state')).json(); return state.review?.comments?.some((c: { text: string; row: number }) => c.text === 'Keep the short quote' && c.row === 6); });
  await page.locator('#md-preview p[data-source-start-line="7"]').filter({ hasText: 'Second repeated' }).waitFor();
  await leftThread.waitFor();
  const moved = JSON.parse(readFileSync(join(reviewDir, 'review.json'), 'utf8')).comments.find((c: { text: string }) => c.text === 'Keep the short quote');
  assert.equal(moved.row, 6); assert.notEqual(moved.unanchored, true); assert.equal(moved.quote, 'word');
  assert.equal(await leftThread.evaluate(el => el.closest('td')?.getAttribute('data-col')), '1');
  console.log('PASS: selected quote and table cell remain anchored after inserting source lines');

  await page.locator('#md-preview p[data-source-start-line="9"]').scrollIntoViewIfNeeded();
  const a = await page.locator('#md-preview p[data-source-start-line="9"]').boundingBox();
  const b = await page.locator('#md-preview p[data-source-start-line="11"]').boundingBox();
  await page.mouse.move(a!.x, a!.y + a!.height / 2); await page.mouse.down();
  await page.mouse.move(b!.x + b!.width, b!.y + b!.height / 2, { steps: 15 }); await page.mouse.up();
  await editor.waitFor();
  assert.equal((await quote.textContent())!.replace(/\s+/g, ' ').trim(), 'Paragraph alpha. Paragraph beta.');
  assert.match((await editor.getAttribute('data-comment-key'))!, /\|8-10$/);
  const geometry = await editor.evaluate(el => {
    const r = el.getBoundingClientRect();
    return { width: r.width, within: r.left >= 0 && r.right <= innerWidth, editors: document.querySelectorAll('.yunomi-inline-comment-editor').length };
  });
  assert.equal(geometry.within, true); assert.equal(geometry.editors, 1); assert.ok(geometry.width > 0);
  await input.fill('Multiline quote');
  await page.screenshot({ path: join(dir, 'selection-desktop.png'), fullPage: true });
  await page.setViewportSize({ width: 390, height: 844 });
  assert.equal(await editor.evaluate(el => { const r = el.getBoundingClientRect(); return r.left >= 0 && r.right <= innerWidth; }), true);
  await page.screenshot({ path: join(dir, 'selection-mobile.png'), fullPage: true });
  await input.press('Enter');
  assert.equal(await input.inputValue(), 'Multiline quote\n');
  assert.equal(await editor.count(), 1);
  await page.locator('#save-comment').click();
  await page.locator('#send-and-exit').click();
  const submission = page.waitForResponse(response => new URL(response.url()).pathname === '/exit');
  await page.locator('#modal-request-changes').click();
  assert.equal((await submission).status(), 200);
  const submitted = JSON.parse(readFileSync(join(reviewDir, 'review.json'), 'utf8')).comments.find((c: { text: string }) => c.text === 'Multiline quote\n');
  assert.ok(submitted);
  assert.equal(submitted.quote.replace(/\s+/g, ' ').trim(), 'Paragraph alpha. Paragraph beta.');
  assert.deepEqual(errors, []);
  console.log('PASS: cross-paragraph selection, exact range, one editor, desktop/mobile bounds, no page errors');
  console.log(`Evidence: ${dir}`);
} finally { await browser.close(); server.kill('SIGTERM'); }
