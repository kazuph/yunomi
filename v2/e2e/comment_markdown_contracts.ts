import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdtempSync, writeFileSync, readFileSync, readdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { chromium } from 'playwright';
const dir = mkdtempSync(join(tmpdir(), 'yunomi-cell-chat-'));
const fixture = join(dir, 'r.md');
const asciiRow = '| ' + 'x'.repeat(400) + ' | ASCII tail |';
const japaneseRow = '| ' + 'あ'.repeat(400) + ' | 日本語の後半 |';
const source = ['# Contract review', '', '| Long | Note |', '| --- | --- |', asciiRow, japaneseRow, '', 'Draft target.', '', 'Send target.'].join('\n');
writeFileSync(fixture, source);
writeFileSync(join(dir, 'target.png'), Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=', 'base64'));
const notifyLog = join(dir, 'notify.log');
const notifyScript = join(dir, 'notify.mjs');
writeFileSync(notifyLog, '');
writeFileSync(notifyScript, "import { appendFileSync } from 'node:fs'; appendFileSync(process.env.NOTIFY_LOG, process.argv[2] + String.fromCharCode(10));");
const server = spawn(process.execPath, [new URL('../_build/js/release/build/server/server.js', import.meta.url).pathname, fixture, '--no-open', '--loop', '--port', '0'], {
  env: { ...process.env, HERDR_PANE_ID: '', TMUX_PANE: '', YUNOMI_NOTIFY_CMD: `${process.execPath} ${notifyScript} {msg}`, NOTIFY_LOG: notifyLog, YUNOMI_LOCK_DIR: join(dir, 'locks'), YUNOMI_REVIEW_DIR: join(dir, 'reviews') }, stdio: ['ignore', 'pipe', 'pipe'] });
let output = '';
const url: string = await new Promise((res, rej) => {
  const timeout = setTimeout(() => rej(new Error(output)), 15000);
  const data = (c: Buffer) => { output += c; const m = output.match(/http:\/\/127\.0\.0\.1:\d+/); if (m) { clearTimeout(timeout); res(m[0]); } };
  server.stdout!.on('data', data); server.stderr!.on('data', data);
  server.once('exit', code => { clearTimeout(timeout); rej(new Error(`exit ${code}: ${output}`)); });
});
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
const errors: string[] = []; page.on('pageerror', e => errors.push(e.message));
let failures = 0;
async function check(name: string, test: () => Promise<void>) { try { await test(); console.log('PASS', name); } catch (e) { failures++; console.error('FAIL', name, e); } }
async function shot(name: string) { if (process.env.SHOT_DIR) await page.screenshot({ path: join(resolve(process.env.SHOT_DIR), `${process.env.SHOT_PHASE || 'after'}-${name}.png`), fullPage: true }); }
try {
  await page.goto(url); await page.waitForSelector('#review-loop-panel');
  await check('FIX1 URL protocols use browser normalization', async () => {
    const result = await page.evaluate(() => {
      const t = document.createElement('div');
      t.innerHTML = (window as any).__yunomiFormatChatMarkdown('[x]( java\tscript:alert%281%29)\n\n<a href="java\tscript:alert(1)">bad</a><a href="JaVaScRiPt:alert(1)">bad</a><a href="data:text/html,bad">bad</a><img src="data:text/html,bad"><a href="https://example.com">ok</a><a href="mailto:a@example.com">mail</a>\n\n![local](target.png)');
      return Array.from(t.querySelectorAll('[href],[src]')).map(el => ({tag: el.tagName, url: el.getAttribute('href') || el.getAttribute('src'), protocol: new URL(el.getAttribute('href') || el.getAttribute('src')!, location.href).protocol}));
    });
    assert.ok(result.every(r => ['http:', 'https:', 'mailto:'].includes(r.protocol)), JSON.stringify(result));
    assert.ok(result.some(r => r.url === 'target.png'));
    assert.ok(result.some(r => r.protocol === 'mailto:'));
  });
  await check('FIX2 comment frontmatter-like text never disappears', async () => {
    for (const text of ['---\nKeep this instruction\n---\nTail', '---\ntitle: Keep YAML\n---\nTail', '---\nKeep unclosed']) {
      const html = await page.evaluate(text => (window as any).__yunomiFormatChatMarkdown(text), text);
      assert.ok(html.includes(text.split('\n')[1]), html);
    }
  });
  const send = async (row: number, text: string) => {
    await page.locator(`#md-preview td[data-row="${row}"][data-col="2"]`).click();
    await page.locator('#comment-input').fill(text);
    const response = page.waitForResponse(r => new URL(r.url()).pathname === '/comment' && r.request().postDataJSON()?.type === 'send-now');
    await page.locator('#send-now-comment').click(); await response;
    await page.locator('.review-loop-inline').filter({hasText:text}).waitFor();
  };
  await check('FIX3 long ASCII and Japanese table rows retain cell display and unchanged stored quote', async () => {
    await send(4, 'ASCII row comment'); await send(5, 'Japanese row comment');
    for (const [row, part] of [[4, 'tail'], [5, '後半']] as const) {
      const cell = page.locator(`#md-preview td[data-row="${row}"][data-col="2"]`);
      await cell.evaluate(el => el.scrollIntoView({ block: 'center' }));
      const box = await cell.evaluate((el, part) => {
        const node = el.firstChild!; const start = node.textContent!.indexOf(part);
        const range = document.createRange(); range.setStart(node, start); range.setEnd(node, start + part.length);
        const rect = range.getBoundingClientRect(); return {x:rect.left,y:rect.top+rect.height/2,end:rect.right};
      }, part);
      await page.mouse.move(box.x, box.y); await page.mouse.down(); await page.mouse.move(box.end, box.y, {steps:12}); await page.mouse.up();
      await page.locator('#comment-input').fill('Partial ' + part);
      await page.locator('#send-now-comment').click();
      const thread = page.locator('.review-loop-inline').filter({hasText:'Partial ' + part});
      await thread.waitFor(); assert.equal(await thread.locator('.review-loop-quote').textContent(), part);
    }
    const notices = readFileSync(notifyLog, 'utf8');
    assert.match(notices, /> ASCII tail\n/); assert.match(notices, /> 日本語の後半\n/);
    const live = readFileSync(join(tmpdir(), `yunomi-live-${server.pid}.jsonl`), 'utf8').trim().split('\n').map(JSON.parse);
    assert.equal(live.find(e=>e.text==='ASCII row comment').quote, 'ASCII tail');
    assert.equal(live.find(e=>e.text==='Japanese row comment').quote, '日本語の後半');
    for (const part of ['tail', '後半']) {
      assert.equal(live.find(e=>e.text==='Partial ' + part).quote, part);
      assert.ok(notices.includes('> ' + part + '\n'));
    }
    const file = (readdirSync(join(dir,'reviews'), {recursive:true}) as string[]).find(f=>f.endsWith('review.json'))!;
    const comments = JSON.parse(readFileSync(join(dir,'reviews',file),'utf8')).comments;
    assert.equal(comments.find((c:any)=>c.text==='ASCII row comment').quote, asciiRow.slice(0, 300) + '...');
    assert.equal(await page.locator('.review-loop-inline').filter({hasText:'ASCII row comment'}).locator('.review-loop-quote').textContent(), 'ASCII tail');
    assert.equal(comments.find((c:any)=>c.text==='Japanese row comment').quote, japaneseRow.slice(0, 300) + '...');
    assert.equal(await page.locator('.review-loop-inline').filter({hasText:'Japanese row comment'}).locator('.review-loop-quote').textContent(), '日本語の後半');
    for (const part of ['tail', '後半']) assert.equal(comments.find((c:any)=>c.text==='Partial ' + part).quote, part);
  });
  await check('FIX2 and FIX4 all comment surfaces preserve text and render isolated Mermaid', async () => {
    const markdown = '---\nKeep instruction\n---\nTail\n\n---\ntitle: Keep YAML\n---\nTail\n\n---\nKeep unclosed\n\n```mermaid\ngraph TD\n A-->B\n```\n\n```mermaid\nthis is invalid mermaid !\n```';
    await page.locator('#md-preview p[data-source-start-line="8"]').click();
    await page.locator('#comment-input').fill(markdown); await page.locator('#save-comment').click();
    const draft = page.locator('.yunomi-inline-comment-view').filter({hasText:'Keep instruction'});
    await draft.waitFor(); await draft.locator('.yunomi-comment-mermaid svg').first().waitFor({timeout:10000});
    await page.locator('#md-preview p[data-source-start-line="10"]').click();
    await page.locator('#comment-input').fill(markdown); await page.locator('#send-now-comment').click();
    const thread = page.locator('.review-loop-inline').filter({hasText:'Keep instruction'});
    await thread.locator('.yunomi-comment-mermaid svg').first().waitFor({timeout:10000});
    await thread.locator('textarea').fill(markdown); await thread.locator('button[type=submit]').click();
    await page.waitForFunction(()=>document.querySelectorAll('.review-loop-inline .yunomi-comment-mermaid svg').length >= 2);
    await page.locator('#review-loop-panel .review-loop-sidebar-toggle').click();
    await page.locator('#review-loop-panel textarea').fill(markdown); await page.locator('#review-loop-panel button[type=submit]').click();
    await page.locator('#review-loop-panel .yunomi-comment-mermaid svg').first().waitFor({timeout:10000});
    await page.reload(); await page.locator('#review-loop-panel .yunomi-comment-mermaid svg').first().waitFor({timeout:10000});
    await page.locator('#theme-toggle').click();
    await page.waitForFunction(() => Array.from(document.querySelectorAll('.yunomi-comment-mermaid')).every(el => el.getAttribute('data-comment-theme') === document.documentElement.getAttribute('data-theme')));
    await page.locator('#review-loop-panel .yunomi-comment-mermaid svg').first().waitFor({timeout:10000});
    await page.evaluate(()=> (window as any).__yunomiRenderCommentDiagrams());
    await page.evaluate(()=> (window as any).__collectMermaidErrors());
    assert.deepEqual(await page.evaluate(()=> (window as any).__mermaidErrors), []);
    for (const root of [page.locator('.yunomi-inline-comment-view'), page.locator('.review-loop-inline .review-loop-thread-line').filter({hasText:'Keep instruction'}), page.locator('#review-loop-panel .review-loop-conversation-message')]) {
      assert.ok(await root.count() > 0);
      for (const element of await root.all()) {
        const text = await element.textContent();
        for (const expected of ['Keep instruction', 'Keep YAML', 'Keep unclosed']) assert.ok(text?.includes(expected), text);
        assert.equal(await element.locator('.yunomi-comment-mermaid-error').count(), 1);
        assert.equal(await element.locator('.yunomi-comment-mermaid svg').count(), 1);
      }
    }
    writeFileSync(fixture, source + '\nBody update.\n');
    await page.waitForFunction(() => document.querySelector('#md-preview')?.textContent?.includes('Body update.'));
    await page.evaluate(() => (window as any).__yunomiRenderCommentDiagrams());
    await page.evaluate(() => (window as any).__collectMermaidErrors());
    assert.deepEqual(await page.evaluate(() => (window as any).__mermaidErrors), []);
    assert.equal(await page.locator('.review-loop-markdown .yunomi-comment-button').count(), 0);
    if (process.env.SHOT_DIR) await page.screenshot({path:join(resolve(process.env.SHOT_DIR), 'fix1-diagrams.png'),fullPage:true});

    assert.equal(await page.locator('#media-sidebar .media-sidebar-thumb-mermaid').count(), 0);
  });  await page.locator('#send-and-exit').click();
  const submitted = page.waitForRequest(request => new URL(request.url()).pathname === '/exit' && request.method() === 'POST');
  await page.locator('#modal-request-changes').click();
  const payload = (await submitted).postDataJSON();
  assert.deepEqual(payload.mermaidErrors || [], []);

} finally { await browser.close(); server.kill(); }
if (failures) process.exitCode=1;
