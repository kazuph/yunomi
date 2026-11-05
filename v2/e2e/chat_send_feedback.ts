import assert from 'node:assert/strict';
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
const serverPath = new URL('../_build/js/release/build/server/server.js', import.meta.url).pathname;
const server = spawn(process.execPath, [serverPath, '--no-open', '--port', '5472', report], {
  cwd: dir, env: { ...process.env, IKESU_PANE_ID: '', IKESU_SOCKET_PATH: '', IKESU: '', HERDR_PANE_ID: '', TMUX_PANE: '', YUNOMI_NOTIFY_CMD: '', YUNOMI_REVIEW_DIR: reviewDir }, stdio: ['ignore', 'pipe', 'pipe'],
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
  page.on('request', r => { if (/\/(create-global-comment|reply-comment)/.test(r.url())) requests.push(new URL(r.url()).pathname); });
  await form.locator('textarea').fill('same message');
  await form.evaluate(el => {
    el.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));
    const input = document.querySelector('#review-loop-panel .review-loop-reply-form textarea') as HTMLTextAreaElement;
    input.value = 'same message';
    input.dispatchEvent(new Event('input', { bubbles: true }));
    input.closest('form')!.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));
  });
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
  chmodSync(reviewPath, 0o444);
  await form.locator('textarea').fill('write failure');
  await form.locator('button[type=submit]').click();
  await page.locator('.review-loop-conversation-message', { hasText: 'write failure' }).locator('.conversation-send-status.is-failed').waitFor({ timeout: 20000 });
  assert.equal(await page.locator('.review-loop-conversation-message', { hasText: 'write failure' }).locator('.conversation-send-status.is-saved').count(), 0);
  chmodSync(reviewPath, 0o600);
  await page.locator('.review-loop-conversation-message', { hasText: 'write failure' }).getByRole('button', { name: 'Retry' }).click();
  await page.locator('.review-loop-conversation-message', { hasText: 'write failure' }).locator('.conversation-send-status.is-saved').waitFor({ timeout: 20000 });
  assert.deepEqual(errors, []);
  console.log('PASS immediate two messages, ordered create/reply, idempotence, write failure and retry');
} finally {
  await browser.close();
  server.kill('SIGTERM');
  rmSync(dir, { recursive: true, force: true });
}
