import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { chromium, type Locator } from 'playwright';
import { createServer } from 'node:http';

const dir = mkdtempSync(join(tmpdir(), 'yunomi-attachments-'));
const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=', 'base64');
writeFileSync(join(dir, 'target.png'), readFileSync(new URL('../../assets/screenshot-comment-dialog.png', import.meta.url)));
writeFileSync(join(dir, 'demo.mp4'), readFileSync(new URL('../../assets/demo.mp4', import.meta.url)));
const file = { name: 'attachment.png', mimeType: 'image/png', buffer: png };
const fixtures = [
  { name: 'element.html', text: '<!doctype html><html><body><button id="target">Target</button></body></html>', target: '#target' },
  { name: 'text.txt', text: 'First line\nSecond line\nThird line\n', target: '.text-line[data-row="0"]' },
  { name: 'table.csv', text: 'left,right\none,two\n', target: 'tbody td[data-row][data-col]' },
  { name: 'table.tsv', text: 'left\tright\none\ttwo\n', target: 'tbody td[data-row][data-col]' },
  { name: 'change.diff', text: 'diff --git a/a b/a\n--- a/a\n+++ b/a\n@@ -1 +1 @@\n-old\n+new\n', target: '.diff-line[data-row]' },
  { name: 'paragraph.md', text: '# Title\n\nParagraph target\n', target: '#md-preview p[data-source-start-line]' },
  { name: 'source.md', text: '# Title\n\nSource target\n', target: '.md-right td[data-row="2"][data-col="1"]' },
  { name: 'cell.md', text: '| Left | Right |\n| --- | --- |\n| one | two |\n', target: '#md-preview tbody td' },
  { name: 'image.md', text: '| Image |\n| --- |\n| ![Target](target.png) |\n', target: '#md-preview tbody td .yunomi-comment-button' },
  { name: 'video.md', text: '<video src="demo.mp4" controls></video>\n', target: '#md-preview .video-overlay-wrapper .yunomi-comment-button' },
  { name: 'diagram.md', text: '```mermaid\ngraph TD\n A --> B\n```\n', target: '#md-preview .mermaid-container .yunomi-comment-button' },
  { name: 'list.md', text: '- List target\n- Next target\n', target: '#md-preview li[data-source-line]' },
];
async function imageLoaded(image: Locator) {
  await image.waitFor({ state: 'visible' });
  await image.evaluate(async (el: HTMLImageElement) => { await el.decode(); });
  const result = await image.evaluate((el: HTMLImageElement) => {
    const r = el.getBoundingClientRect(), b = el.closest('.review-loop-thread-line,.review-loop-conversation-message')?.getBoundingClientRect();
    return { width: el.naturalWidth, height: el.naturalHeight, inside: !!b && r.left >= b.left && r.right <= b.right && r.top >= b.top && r.bottom <= b.bottom };
  });
  assert.deepEqual(result, { width: 1, height: 1, inside: true });
}
const liveTarget = createServer((_req, res) => { res.writeHead(200, { 'Content-Type': 'text/html' }); res.end('<!doctype html><html><body><button id="target">Target</button></body></html>'); });
await new Promise<void>(resolve => liveTarget.listen(0, '127.0.0.1', resolve));
const liveUrl = `http://127.0.0.1:${(liveTarget.address() as {port: number}).port}`;
fixtures.push({ name: 'live', text: '', target: '#target' });
const browser = await chromium.launch({ headless: true });
try {
for (const fixture of fixtures) {
  const path = join(dir, fixture.name), state = join(dir, fixture.name + '-state');
  writeFileSync(path, fixture.text);
  if (fixture.name === 'element.html' || fixture.name === 'live') {
    mkdirSync(state, { recursive: true });
    writeFileSync(join(state, 'review.json'), JSON.stringify({ version: 1, files: [], rounds: [{ round: 1, submitted_at: null }], comments: [{ id: 'r-1', scope: 'round', round: 1, text: 'Earlier overall comment', status: 'unresolved', replies: [], attachments: [] }] }));
  }
  const probe = createServer();
  await new Promise<void>(resolve => probe.listen(0, '127.0.0.1', resolve));
  const port = (probe.address() as { port: number }).port;
  await new Promise<void>(resolve => probe.close(() => resolve()));
  const server = spawn(process.execPath, [new URL('../_build/js/release/build/server/server.js', import.meta.url).pathname, ...(fixture.name === 'live' ? ['live', liveUrl] : [path]), '--no-open', '--loop', '--port', String(port)], {
    env: { ...process.env, HERDR_PANE_ID: '', TMUX_PANE: '', YUNOMI_NOTIFY_CMD: '', YUNOMI_LOCK_DIR: join(dir, 'locks'), YUNOMI_REVIEW_DIR: state }, stdio: ['ignore', 'pipe', 'pipe'],
  });
  let output = '';
  const ready = new Promise<string>((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error(output)), 30000);
    const read = (data: Buffer) => { output += data; const match = output.match(fixture.name === "live" ? /at (http:\/\/127\.0\.0\.1:\d+)/ : /(http:\/\/127\.0\.0\.1:\d+)/); if (match) { clearTimeout(timeout); resolve(match[1]); } };
    server.stdout!.on('data', read); server.stderr!.on('data', read);
  });
  const context = await browser.newContext({ viewport: { width: 1100, height: 900 } });
  const page = await context.newPage();
  const errors: string[] = []; page.on('pageerror', error => errors.push(error.message));
  try {
    const url = await ready;
    await page.goto(url);
    if (fixture.name === 'element.html' || fixture.name === 'live') {
      const live = fixture.name === 'live';
      const prefix = live ? 'yunomi-live' : 'yunomi-html';
      const frame = live ? page : page.frameLocator('#yunomi-html-frame');
      await frame.locator('#target').click();
      const card = frame.locator(`#${prefix}-card`);
      await card.locator('input[type=file]').setInputFiles(file);
      await card.locator('.yunomi-html-attachment img').waitFor();
      await card.locator('textarea').fill('HTML attached');
      await card.locator('[data-yunomi-save]').click();
      await page.reload();
      await frame.locator('#target').click();
      const attached = card.locator(`.${prefix}-saved-comment img`);
      await attached.waitFor();
      assert.equal(await attached.evaluate(async (img: HTMLImageElement) => { await img.decode(); return img.naturalWidth; }), 1);
      await card.locator('[data-yunomi-cancel]').click();
      await frame.locator(`#${prefix}-submit`).click();
      const submit = frame.locator(live ? '#yunomi-live-card' : '#yunomi-html-submit-card');
      await submit.locator('input[type=file]').setInputFiles(file);
      await submit.locator('.yunomi-html-attachment img').waitFor();
      const storageObserver = await page.context().newPage();
      await storageObserver.goto(url);
      const response = page.waitForResponse(r => new URL(r.url()).pathname === '/exit');
      await submit.locator(live ? '[data-yunomi-save]' : '[data-yunomi-submit]').click();
      assert.equal((await response).ok(), true);
      await storageObserver.waitForFunction(key => localStorage.getItem(key) === null, (live ? 'yunomi:live-comments:' + liveUrl : 'yunomi:html-comments:' + path));
      await storageObserver.close();
      const saved = JSON.parse(readFileSync(join(state, 'review.json'), 'utf8'));
      for (const comment of saved.comments) {
        assert.equal(comment.attachments.length, 1);
        assert.deepEqual(readFileSync(join(state, comment.attachments[0])), png);
      }
      assert.equal(saved.comments.length, 2);
      assert.ok(output.includes(state + '/./comment-attachments/'));
      assert.equal(new Set(saved.comments.map((c: any) => c.id)).size, saved.comments.length);
      console.log(fixture.name + ': PASS element attachment / saved bubble / reload / overall attachment / saved file bytes');
      assert.deepEqual(errors, []);
      continue;
    }
    if (fixture.name === "source.md") await page.locator("#view-toggle").click();
    await page.locator(fixture.target).first().click();
    const editor = page.locator('.yunomi-inline-comment-editor');
    await editor.locator('input[type=file]').setInputFiles(file);
    await editor.locator('#comment-image-preview img').waitFor();
    await page.locator('#comment-input').fill('Attached ' + fixture.name);
    await page.locator('#save-comment').click();
    const draft = page.locator('.yunomi-inline-comment-view');
    await imageLoaded(draft.locator('.yunomi-inline-comment-image'));
    if (fixture.name === 'text.txt') {
      await page.locator('#pill-comments').click();
      await page.locator('#comment-list img').waitFor();
      assert.equal(await page.locator('#comment-list img').evaluate(async (img: HTMLImageElement) => { await img.decode(); return img.naturalWidth; }), 1);
    }
    await page.reload();
    await imageLoaded(draft.locator('.yunomi-inline-comment-image'));
    await draft.click();
    await page.locator('#comment-input').fill(''); // Image-only is content too.
    const sent = page.waitForResponse(r => new URL(r.url()).pathname === '/comment' && r.request().method() === 'POST');
    await page.locator('#comment-input').press('Meta+Enter');
    assert.equal((await sent).ok(), true);
    const bubble = page.locator('.review-loop-inline .review-loop-thread-line.is-human').first();
    await imageLoaded(bubble.locator('img'));
    const review = JSON.parse(readFileSync(join(state, 'review.json'), 'utf8'));
    const root = review.comments.find((c: any) => c.send_now);
    assert.equal(root.attachments.length, 1);
    assert.deepEqual(readFileSync(join(state, root.attachments[0])), png);
    assert.deepEqual(Buffer.from(await (await fetch(new URL(root.attachments[0], url))).arrayBuffer()), png);
    await page.reload();
    await imageLoaded(bubble.locator('img'));
    if (fixture.name === 'paragraph.md') {
      await page.getByRole('button', { name: 'Resolve conversation', exact: true }).click();
      await page.locator('.review-loop-inline').waitFor({ state: 'hidden' });
      await page.locator(fixture.target).first().click();
      await page.locator('#comment-input').fill('Resent after resolving');
      await editor.locator('input[type=file]').setInputFiles(file);
      await editor.locator('#comment-image-preview img').waitFor();
      await page.locator('#send-now-comment').click();
      await imageLoaded(bubble.locator('img'));
      assert.equal(await bubble.textContent(), 'Resent after resolving');
      assert.notEqual(JSON.parse(readFileSync(join(state, 'review.json'), 'utf8')).comments.find((c: any) => c.id === root.id).attachments[0], root.attachments[0]);
      await page.reload();
      await imageLoaded(bubble.locator('img'));
      assert.equal(await bubble.locator('.yunomi-comment-button').count(), 0);
      assert.equal(JSON.parse(readFileSync(join(state, 'review.json'), 'utf8')).comments.find((c: any) => c.id === root.id).status, 'unresolved');
    }
    const thread = page.locator('.review-loop-inline').first();
    await thread.locator('input[type=file]').setInputFiles(file);
    await thread.locator('.review-loop-reply-preview img').waitFor();
    await thread.locator('textarea').fill('Reply attachment');
    await page.reload();
    await thread.locator('.review-loop-reply-preview img').waitFor();
    await thread.locator('button[type=submit]').click();
    const reply = thread.locator('.review-loop-thread-line').filter({ hasText: 'Reply attachment' });
    await imageLoaded(reply.locator('img'));
    await page.reload();
    await imageLoaded(reply.locator('img'));
    if (fixture.name === 'paragraph.md') {
      await page.getByRole('button', { name: 'Resolve conversation', exact: true }).click();
      await thread.waitFor({ state: 'hidden' });
      await page.locator(fixture.target).first().click();
      await page.locator('#comment-input').fill('Image removed on resend');
      await page.locator('#comment-image-preview button').click();
      const resend = page.waitForResponse(r => new URL(r.url()).pathname === '/comment');
      await page.locator('#send-now-comment').click();
      await resend;
      await page.reload();
      await page.getByText('Image removed on resend', { exact: true }).waitFor();
      assert.equal(await bubble.locator('img').count(), 0);
      assert.deepEqual(JSON.parse(readFileSync(join(state, 'review.json'), 'utf8')).comments.find((c: any) => c.id === root.id).attachments, []);
    }
    if (fixture.name === 'text.txt') {
      const chat = page.locator('#review-loop-panel');
      for (const text of ['Global root image', 'Global reply image']) {
        await chat.locator('input[type=file]').setInputFiles(file);
        await chat.locator('.review-loop-reply-preview img').waitFor();
        await chat.locator('textarea').fill(text);
        await chat.locator('button[type=submit]').click();
        await imageLoaded(chat.locator('.review-loop-conversation-message').filter({ hasText: text }).locator('img'));
      }
      await page.reload();
      for (const text of ['Global root image', 'Global reply image']) await imageLoaded(chat.locator('.review-loop-conversation-message').filter({ hasText: text }).locator('img'));
      await page.locator('.text-line[data-row="1"]').click();
      await editor.locator('input[type=file]').setInputFiles(file);
      await editor.locator('#comment-image-preview img').waitFor();
      await page.locator('#save-comment').click();
      if (!await page.locator('#submit-modal').isVisible()) await page.locator('#send-and-exit').click();
      assert.equal(await page.locator('#modal-summary img').count(), 1);
      await page.locator('#global-comment').evaluate((el, base64) => {
        const data = Uint8Array.from(atob(base64), c => c.charCodeAt(0));
        const clipboardData = new DataTransfer(); clipboardData.items.add(new File([data], 'summary.png', { type: 'image/png' }));
        el.dispatchEvent(new ClipboardEvent('paste', { bubbles: true, clipboardData }));
      }, png.toString('base64'));
      await page.locator('#submit-image-preview img').waitFor();
      await page.reload();
      if (!await page.locator('#submit-modal').isVisible()) await page.locator('#send-and-exit').click();
      await page.locator('#submit-image-preview img').waitFor();
      const submitted = page.waitForResponse(r => new URL(r.url()).pathname === '/exit');
      await page.locator('#modal-request-changes').click();
      assert.equal((await submitted).ok(), true);
      const saved = JSON.parse(readFileSync(join(state, 'review.json'), 'utf8'));
      const onlyImage = saved.comments.find((c: any) => c.text === '' && !c.send_now && c.scope !== 'round');
      assert.equal(onlyImage.attachments.length, 1);
      const summary = saved.comments.find((c: any) => c.id === 'r-1');
      assert.equal(summary.attachments.length, 1);
      await page.reload();
      await imageLoaded(page.locator('[data-message-key="r-1#root#h"] img'));
      await imageLoaded(page.locator(`[data-message-key="${onlyImage.id}#root#h"] img`));
      await page.locator('#history-toggle').click();
      await page.locator('.history-entry img').waitFor();
      assert.equal(await page.locator('.history-entry img').evaluate(async (el: HTMLImageElement) => { await el.decode(); return el.naturalWidth; }), 1);
      await page.locator('#history-panel-close').click();
      console.log('PASS global root / global reply / image-only pending submit / image-only overall submit / reload');
    }
    if (fixture.name === 'text.txt') {
      await page.evaluate(() => {
        const chunk = 'x'.repeat(1024 * 1024);
        for (const size of [chunk.length, 1024]) for (let i = 0; ; i++) { try { localStorage.setItem('quota-fixture-' + size + '-' + i, chunk.slice(0, size)); } catch (_) { break; } }
      });
      const chat = page.locator('#review-loop-panel');
      await chat.locator('input[type=file]').setInputFiles({ name: 'large.png', mimeType: 'image/png', buffer: readFileSync(new URL('../../assets/screenshot-comment-dialog.png', import.meta.url)) });
      await chat.locator('.review-loop-reply-preview img').waitFor();
      await page.locator('#yunomi-draft-storage-error').waitFor();
      await chat.locator('textarea').fill('Reply still sendable when storage is full');
      await chat.locator('button[type=submit]').click();
      await chat.getByText('Reply still sendable when storage is full', { exact: true }).waitFor();
      await page.locator('.text-line[data-row="2"]').click();
      {
        const screenshot = readFileSync(new URL('../../assets/screenshot-comment-dialog.png', import.meta.url));
        await editor.locator('input[type=file]').setInputFiles({ name: 'large.png', mimeType: 'image/png', buffer: screenshot });
        await editor.locator('#comment-image-preview img').waitFor();
        await page.locator('#yunomi-draft-storage-error').waitFor();
        await page.locator('#comment-input').fill('Still sendable when storage is full');
        await page.locator('#send-now-comment').click();
        await page.getByText('Still sendable when storage is full', { exact: true }).waitFor();
      }
    }
    await page.screenshot({ path: join(dir, fixture.name + '.png'), fullPage: true });
    assert.deepEqual(errors, []);
    console.log('PASS draft / send-now image-only / reply / reload / file bytes / bubble bounds: ' + fixture.name);
  } catch (error) { writeFileSync(join(dir, fixture.name + '-failure.html'), await page.content()); console.error('Evidence: ' + dir, errors); throw error; } finally { await context.close(); server.kill('SIGTERM'); }
}
} finally { await browser.close(); await new Promise<void>(resolve => liveTarget.close(() => resolve())); }
console.log('Evidence: ' + dir);
