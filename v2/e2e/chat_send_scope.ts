import assert from 'node:assert/strict';
import { spawn, type ChildProcess } from 'node:child_process';
import { chmodSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { chromium } from 'playwright';
const root = mkdtempSync(join(tmpdir(), 'yunomi-chat-scope-'));
const serverJs = new URL('../_build/js/release/build/server/server.js', import.meta.url).pathname;
async function start(name: string, port: number): Promise<{proc: ChildProcess; port: number}> {
  const dir = join(root, name); mkdirSync(dir, {recursive:true});
  const file = join(dir, 'report.md'); writeFileSync(file, `# ${name}\n`);
  const proc = spawn(process.execPath, [serverJs, file, '--no-open', '--port', String(port)], {cwd:root, env:{...process.env, IKESU_PANE_ID:'', IKESU_SOCKET_PATH:'', IKESU:'', HERDR_PANE_ID:'', TMUX_PANE:'', YUNOMI_NOTIFY_CMD:'', YUNOMI_REVIEW_DIR:join(dir,'review'), YUNOMI_LOCK_DIR:join(root,'locks')},stdio:['ignore','pipe','pipe']});
  let output = '';
  const actual = await new Promise<number>((resolve,reject) => { const onData=(c:Buffer)=>{output+=c.toString();const m=output.match(/http:\/\/127\.0\.0\.1:(\d+)/);if(m)resolve(Number(m[1]));}; proc.stdout!.on('data',onData);proc.stderr!.on('data',onData);proc.once('exit',c=>reject(Error(`exit ${c}: ${output}`)));setTimeout(()=>reject(Error(output)),15000).unref(); });
  return {proc, port: actual};
}
async function stop(proc: ChildProcess) { await new Promise<void>(resolve=>{proc.once('exit',()=>resolve());proc.kill('SIGTERM');}); }
let active = await start('first',0);
const port = active.port;
const browser = await chromium.launch();
try {
  const page = await browser.newPage(); await page.goto(`http://127.0.0.1:${port}/`);
  const toggle=page.locator('#review-loop-panel .review-loop-sidebar-toggle');await toggle.waitFor();
  if (await page.locator('#review-loop-panel.review-loop-sidebar-collapsed').count()) await toggle.click();
  const reviewPath=join(root,'first','review','review.json'); chmodSync(reviewPath,0o444);
  await page.locator('#review-loop-panel textarea').fill('first only');
  await page.locator('#review-loop-panel .review-loop-reply-form button[type=submit]').click();
  await page.locator('.review-loop-conversation-message', {hasText:'first only'}).locator('.conversation-send-status.is-failed').waitFor({timeout:20000});
  await stop(active.proc);
  active=await start('second',port); assert.equal(active.port,port);
  await page.goto(`http://127.0.0.1:${port}/`);
  await page.locator('#review-loop-panel .review-loop-sidebar-toggle').waitFor();
  assert.equal(await page.locator('.review-loop-conversation-message', {hasText:'first only'}).count(),0);
  await stop(active.proc);
  active=await start('first',port);
  await page.goto(`http://127.0.0.1:${port}/`);
  await page.locator('.review-loop-conversation-message', {hasText:'first only'}).locator('.conversation-send-status.is-failed').waitFor({timeout:20000});
  assert.equal(await page.locator('.review-loop-conversation-message', {hasText:'first only'}).count(),1);
  console.log('PASS unsent conversation is isolated per review and survives reload');
} finally { await browser.close(); if(active.proc.exitCode===null) await stop(active.proc); rmSync(root,{recursive:true,force:true}); }
