import assert from 'node:assert/strict';
import http from 'node:http';
import { randomUUID } from 'node:crypto';
import { spawn } from 'node:child_process';
import { chmodSync, mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { chromium } from 'playwright';

const dir = mkdtempSync(join(tmpdir(), 'yunomi-send-feedback-'));
const reviewDir = join(dir, 'review');
mkdirSync(reviewDir);
const report = join(dir, 'report.md');
writeFileSync(report, '# Send feedback\n\nText to review.\n');
const notificationLog = join(dir, 'notifications.log');
const notificationScript = join(dir, 'notify.mjs');
writeFileSync(notificationLog, '');
writeFileSync(notificationScript, "import { appendFileSync, existsSync } from 'node:fs'; if (existsSync(process.env.NOTIFY_FAIL)) process.exit(1); appendFileSync(process.env.NOTIFY_LOG, 'sent\\n');");
const notificationFail = join(dir, 'fail-notification');
const serverPath = new URL('../_build/js/release/build/server/server.js', import.meta.url).pathname;
const server = spawn(process.execPath, [serverPath, '--no-open', '--port', '5472', report], {
  cwd: dir, env: { ...process.env, IKESU_PANE_ID: '', IKESU_SOCKET_PATH: '', IKESU: '', HERDR_PANE_ID: '', TMUX_PANE: '', YUNOMI_NOTIFY_CMD: `${process.execPath} ${notificationScript} {msg}`, NOTIFY_LOG: notificationLog, NOTIFY_FAIL: notificationFail, YUNOMI_REVIEW_DIR: reviewDir }, stdio: ['ignore', 'pipe', 'pipe'],
});
let output = '';
const port = await new Promise<number>((resolve, reject) => {
  const read = (chunk: Buffer) => { output += chunk.toString(); const match = output.match(/http:\/\/127\.0\.0\.1:(\d+)/); if (match) resolve(Number(match[1])); };
  server.stdout.on('data', read); server.stderr.on('data', read);
  server.once('exit', code => reject(new Error(`server exit ${code}: ${output}`)));
  setTimeout(() => reject(new Error(`startup timeout: ${output}`)), 15000).unref();
});
const browser = await chromium.launch();
try {
  const page = await browser.newPage();
  const errors: string[] = [];
  page.on('pageerror', e => errors.push(e.message));
  await page.goto(`http://127.0.0.1:${port}/`);
  const toggle = page.locator('#review-loop-panel .review-loop-sidebar-toggle');
  await toggle.waitFor();
  if (await page.locator('#review-loop-panel.review-loop-sidebar-collapsed').count()) await toggle.click();
  const form = page.locator('#review-loop-panel .review-loop-reply-form');
  await form.waitFor();
  const requests: string[] = [];
  const failedResponses: number[] = [];
  page.on('response', r => { if (/\/(create-global-comment|reply-comment)/.test(r.url()) && !r.ok()) failedResponses.push(r.status()); });
  const countNotifications = () => readFileSync(notificationLog, 'utf8').split('\n').filter(Boolean).length;
  page.on('request', r => { if (/\/(create-global-comment|reply-comment)/.test(r.url())) requests.push(new URL(r.url()).pathname); });
  await form.locator('textarea').fill('same message');
  const immediate = await form.evaluate(el => {
    const started = performance.now();
    el.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));
    const input = document.querySelector('#review-loop-panel .review-loop-reply-form textarea') as HTMLTextAreaElement;
    input.value = 'same message';
    input.dispatchEvent(new Event('input', { bubbles: true }));
    input.closest('form')!.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));
    return { elapsed: performance.now() - started, bubbles: document.querySelectorAll('.review-loop-conversation-message').length, spinners: document.querySelectorAll('.review-loop-conversation-message .conversation-send-status.is-sending, .review-loop-conversation-message .conversation-send-status.is-queued').length };
  });
  assert.ok(immediate.elapsed < 400);
  assert.equal(immediate.bubbles, 2);
  assert.equal(immediate.spinners, 2);
  assert.equal(await page.locator('.review-loop-conversation-message', { hasText: 'same message' }).count(), 2);
  await page.waitForFunction(() => document.querySelectorAll('.review-loop-conversation-message .conversation-send-status.is-saved').length === 2, null, { timeout: 20000 });
  assert.deepEqual(requests, ['/create-global-comment', '/reply-comment']);
  const reviewPath = join(reviewDir, 'review.json');
  const saved = JSON.parse(readFileSync(reviewPath, 'utf8'));
  const thread = saved.comments.find((c: any) => c.scope === 'round');
  assert.equal(thread.text, 'same message');
  assert.equal(thread.replies[0].text, 'same message');
  assert.notEqual(thread.clientId, thread.replies[0].clientId);
  const retry = await page.request.post(`http://127.0.0.1:${port}/reply-comment`, { data: { id: thread.id, text: 'same message', author: 'human', clientId: thread.replies[0].clientId } });
  assert.equal(retry.status(), 200);
  assert.equal(JSON.parse(readFileSync(reviewPath, 'utf8')).comments.find((c: any) => c.id === thread.id).replies.length, 1);
  const beforeWriteFailure = countNotifications();
  chmodSync(reviewPath, 0o444);
  await form.locator('textarea').fill('write failure');
  await form.evaluate(el => {
    el.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));
    const input = document.querySelector('#review-loop-panel .review-loop-reply-form textarea') as HTMLTextAreaElement;
    input.value = 'queued after failure';
    input.dispatchEvent(new Event('input', { bubbles: true }));
    input.closest('form')!.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));
  });
  await page.locator('.review-loop-conversation-message', { hasText: 'write failure' }).locator('.conversation-send-status.is-failed').waitFor({ timeout: 20000 });
  assert.equal(await page.locator('.review-loop-conversation-message', { hasText: 'write failure' }).locator('.conversation-send-status.is-saved').count(), 0);
  assert.equal(JSON.parse(readFileSync(reviewPath, 'utf8')).comments.find((c: any) => c.id === thread.id).replies.length, 1);
  assert.equal(countNotifications(), beforeWriteFailure);
  assert.ok(failedResponses.includes(500));
  if (process.env.EVIDENCE_DIR) await page.screenshot({path: join(process.env.EVIDENCE_DIR, 'failed-chat.png')});
  await page.reload();
  await page.locator('.review-loop-conversation-message', { hasText: 'write failure' }).locator('.conversation-send-status.is-failed').waitFor({ timeout: 20000 });
  assert.equal(await page.locator('.review-loop-conversation-message', { hasText: 'queued after failure' }).count(), 1);
  chmodSync(reviewPath, 0o600);
  const inlineRoot = await page.request.post(`http://127.0.0.1:${port}/comment`, { data: { type: 'send-now', key: 'inline-send-test', row: 2, col: 0, text: 'inline root', value: 'Text to review.' } });
  assert.equal(inlineRoot.status(), 200);
  const inlineForm = page.locator('.review-loop-inline .review-loop-reply-form').first();
  await inlineForm.waitFor({ timeout: 20000 });
  await inlineForm.locator('textarea').fill('inline immediate');
  const start = Date.now();
  const inlineSpinner = await inlineForm.evaluate(el => { el.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true })); return !!document.querySelector('.review-loop-inline .conversation-send-status.is-sending'); });
  assert.equal(inlineSpinner, true);
  const inlineBubble = page.locator('.review-loop-inline .review-loop-thread-line', { hasText: 'inline immediate' });
  await inlineBubble.waitFor({ timeout: 400 });
  assert.ok(Date.now() - start < 400, 'inline bubble appears within 400 ms');
  await inlineBubble.locator('.conversation-send-status.is-saved').waitFor({ timeout: 20000 });
  assert.equal(await page.locator('.review-loop-inline .review-loop-thread-line', { hasText: 'inline immediate' }).count(), 1);
  if (process.env.EVIDENCE_DIR) await page.screenshot({path: join(process.env.EVIDENCE_DIR, 'inline-saved.png')});
  await page.locator('.review-loop-conversation-message', { hasText: 'write failure' }).getByRole('button', { name: 'Retry' }).click();
  await page.locator('.review-loop-conversation-message', { hasText: 'queued after failure' }).locator('.conversation-send-status.is-saved').waitFor({ timeout: 20000 });
  const afterRetry = JSON.parse(readFileSync(reviewPath, 'utf8')).comments.find((c: any) => c.id === thread.id);
  assert.deepEqual(afterRetry.replies.map((r: any) => r.text), ['same message', 'write failure', 'queued after failure']);
  const beforeDisconnect = countNotifications();
  const proxy = http.createServer((incoming, outgoing) => {
    const upstream = http.request({ host: '127.0.0.1', port, method: incoming.method, path: incoming.url, headers: incoming.headers }, response => {
      response.resume();
      outgoing.destroy();
    });
    incoming.pipe(upstream);
  });
  await new Promise<void>(resolve => proxy.listen(0, '127.0.0.1', resolve));
  const proxyPort = (proxy.address() as { port: number }).port;
  const clientId = randomUUID();
  const payload = JSON.stringify({ id: thread.id, text: 'connection cut', author: 'human', clientId });
  await new Promise<void>((resolve, reject) => {
    const req = http.request({ host: '127.0.0.1', port: proxyPort, path: '/reply-comment', method: 'POST', headers: { 'content-type': 'application/json', 'content-length': Buffer.byteLength(payload) } }, () => reject(new Error('response unexpectedly received')));
    req.on('error', () => resolve()); req.end(payload);
  });
  await new Promise<void>(resolve => proxy.close(() => resolve()));
  assert.equal(countNotifications(), beforeDisconnect + 1);
  const duplicate = await page.request.post(`http://127.0.0.1:${port}/reply-comment`, { data: JSON.parse(payload) });
  assert.equal(duplicate.status(), 200);
  assert.equal(countNotifications(), beforeDisconnect + 1);
  assert.equal(JSON.parse(readFileSync(reviewPath, 'utf8')).comments.find((c: any) => c.id === thread.id).replies.filter((r: any) => r.clientId === clientId).length, 1);

  const attachmentDir = join(reviewDir, 'comment-attachments');
  mkdirSync(attachmentDir, { recursive: true });
  chmodSync(attachmentDir, 0o555);
  const beforeImageFailure = countNotifications();
  const failuresBeforeImage = failedResponses.length;
  const image = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=', 'base64');
  await page.locator('#review-loop-panel input[type=file]').setInputFiles({ name: 'pixel.png', mimeType: 'image/png', buffer: image });
  await page.locator('#review-loop-panel .review-loop-reply-preview img').waitFor();
  await page.locator('#review-loop-panel .review-loop-reply-form button[type=submit]').click();
  const imageMessage = page.locator('.review-loop-conversation-message').filter({ has: page.locator('img[src^="data:image"]') }).last();
  await imageMessage.locator('.conversation-send-status.is-failed').waitFor({ timeout: 20000 });
  assert.equal(await imageMessage.locator('img').count(), 1);
  assert.equal(countNotifications(), beforeImageFailure);
  assert.equal(failedResponses.length, failuresBeforeImage + 1);
  assert.equal(failedResponses.at(-1), 500);
  await page.reload();
  await page.locator('.review-loop-conversation-message').filter({ has: page.locator('img[src^="data:image"]') }).locator('.conversation-send-status.is-failed').waitFor({ timeout: 20000 });
  chmodSync(attachmentDir, 0o755);
  const failedImage = page.locator('.review-loop-conversation-message').filter({ has: page.locator('img[src^="data:image"]') }).last();
  await failedImage.getByRole('button', { name: 'Retry' }).click();
  await page.locator('.review-loop-conversation-message').filter({ has: page.locator('img') }).last().locator('.conversation-send-status.is-saved').waitFor({ timeout: 20000 });
  writeFileSync(notificationFail, 'fail');
  await page.locator('#review-loop-panel .review-loop-reply-form textarea').fill('notification failure');
  await page.locator('#review-loop-panel .review-loop-reply-form button[type=submit]').click();
  await page.locator('.review-loop-conversation-message', { hasText: 'notification failure' }).locator('.conversation-send-status.is-saved').waitFor({ timeout: 20000 });
  await page.locator('#notify-undelivered:not([hidden])').waitFor({ timeout: 20000 });
  const editor = page.locator('#review-loop-panel .review-loop-reply-form textarea');
  await editor.fill('keep draft when storage is full');
  await page.evaluate(() => {
    let i = 0;
    try { for (; i < 20; i++) localStorage.setItem(`quota-fill-${i}`, 'x'.repeat(1024 * 1024)); } catch (_) {}
    try { for (; i < 2048; i++) localStorage.setItem(`quota-tail-${i}`, 'x'.repeat(1024)); } catch (_) {}
    try { for (; i < 4096; i++) localStorage.setItem(`q${i}`, 'x'); } catch (_) {}
  });
  const requestCount = requests.length;
  await page.locator('#review-loop-panel .review-loop-reply-form button[type=submit]').click();
  assert.equal(await editor.inputValue(), 'keep draft when storage is full');
  assert.equal(requests.length, requestCount);
  assert.match(await page.locator('.conversation-storage-error').getAttribute('title') || '', /Unable to save pending message/);
  assert.deepEqual(errors, []);
  console.log('PASS immediate two messages, ordered create/reply, idempotence, write failure and retry');
} finally {
  await browser.close();
  server.kill('SIGTERM');
  rmSync(dir, { recursive: true, force: true });
}
