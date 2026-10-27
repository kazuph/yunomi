import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdtempSync, writeFileSync, readFileSync, readdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { chromium } from 'playwright';
const dir = mkdtempSync(join(tmpdir(), 'yunomi-cell-chat-'));
const fixture = join(dir, 'r.md');
const source = '# Review\n\nIntro paragraph.\n\n| Name | Status | Note |\n| --- | --- | --- |\n| alpha | ok | first row note |\n| beta | ng | second row note |\n\nAfter table.\n\n![document-relative](target.png)\n\n| Document image |\n| --- |\n| ![document-cell](target.png) |\n';
writeFileSync(fixture, source);
writeFileSync(join(dir, 'target.png'), Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=', 'base64'));
const notifyLog = join(dir, 'notify.log');
const notifyScript = join(dir, 'notify.mjs');
writeFileSync(notifyLog, '');
writeFileSync(notifyScript, "import { appendFileSync } from 'node:fs'; appendFileSync(process.env.NOTIFY_LOG, process.argv[2] + '\\n');");
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
async function drop(selector: string, file = true, png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=') {
  return page.locator(selector).first().evaluate((el, { file, png }) => {
    const dt = new DataTransfer();
    if (file) dt.items.add(new File([Uint8Array.from(atob(png), c => c.charCodeAt(0))], 'drop.png', { type: 'image/png' }));
    else dt.setData('text/plain', 'drag text');
    const over = new DragEvent('dragover', { dataTransfer: dt, bubbles: true, cancelable: true }); el.dispatchEvent(over);
    const event = new DragEvent('drop', { dataTransfer: dt, bubbles: true, cancelable: true }); el.dispatchEvent(event);
    return { over: over.defaultPrevented, drop: event.defaultPrevented };
  }, { file, png });
}
try {
  await page.goto(url); await page.waitForSelector('#review-loop-panel');
  await shot('D-initial');
  await check('D initial chat is collapsed', async () => assert.match(await page.locator('#review-loop-panel').getAttribute('class') || '', /review-loop-sidebar-collapsed/));
  await check('B shared Markdown renderer handles headings, ordered/nested lists, tables, images, fences and sanitization', async () => {
    const result = await page.evaluate(() => {
      const format = (window as any).__yunomiFormatChatMarkdown;
      const t = document.createElement('div');
      t.innerHTML = format('# Heading\n\n1. first\n   - nested\n2. second\n\n> quoted\n\n| A | B |\n| --- | --- |\n| x | y |\n\n![alt](data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=)\n\n```js\nconst x = 1\n```\n\n[link](https://example.com)\n\n<script>window.__unsafe=1</script><img src=x onerror="window.__unsafe=1">');
      return { heading: !!t.querySelector('h1'), ordered: !!t.querySelector('ol li'), nested: !!t.querySelector('ol ul li'), table: !!t.querySelector('table td'), image: !!t.querySelector('img[alt="alt"]'), code: !!t.querySelector('pre code'), highlighted: !!t.querySelector('pre code.hljs[data-highlighted="yes"] .hljs-keyword'), quote: !!t.querySelector('blockquote'), link: !!t.querySelector('a'), unsafe: !!t.querySelector('script,[onerror]'), positions: !!t.querySelector('[data-source-line],[data-row],[data-col],[data-source-start-line]') };
    });
    assert.deepEqual(result, { heading: true, ordered: true, nested: true, table: true, image: true, code: true, highlighted: true, quote: true, link: true, unsafe: false, positions: false });
  });
  const cellTarget = page.locator('#md-preview tbody tr').first().locator('td').nth(2);
  const originalCellStyle = await cellTarget.evaluate(el => ({ padding: getComputedStyle(el).padding, lineHeight: getComputedStyle(el).lineHeight }));
  async function assertCellMediaStyle() {
    assert.deepEqual(await cellTarget.evaluate(el => ({ padding: getComputedStyle(el).padding, lineHeight: getComputedStyle(el).lineHeight })), originalCellStyle);
    const images = cellTarget.locator('.review-loop-markdown img[alt="cell-markdown"], .review-loop-conversation-image');
    assert.equal(await images.count(), 2);
    for (const image of await images.all()) {
      const size = await image.evaluate(async (img: HTMLImageElement) => {
        await img.decode();
        return { width: img.getBoundingClientRect().width, container: img.parentElement!.getBoundingClientRect().width };
      });
      assert.ok(size.width < size.container, `comment image must retain its own width: ${JSON.stringify(size)}`);
    }
    assert.equal(await page.locator('#md-preview img[alt="document-cell"]').evaluate(img => getComputedStyle(img.closest('td')!).padding), '4px');
  }
  await cellTarget.click();
  await page.locator('#comment-input').fill('## Comment\n\n1. first\n   - nested\n2. second\n\n![cell-markdown](target.png)\n\n```js\nconst x = 1\n```');
  await shot('B-editor');
  await check('C inline drop attaches using the existing preview', async () => {
    assert.deepEqual(await drop('#comment-input'), { over: true, drop: true });
    await page.waitForSelector('#comment-image-preview img', { timeout: 2000 });
    const replacement = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
    await drop('#comment-input', true, replacement);
    await page.waitForFunction(png => document.querySelector<HTMLImageElement>('#comment-image-preview img')?.src.endsWith(png), replacement);
    assert.equal(await page.locator('#comment-image-preview img').count(), 1);
    assert.equal(await page.locator('#review-loop-panel .review-loop-reply-preview img').count(), 0);

  });
  await page.locator('#send-now-comment').click();
  await page.waitForSelector('.review-loop-inline .review-loop-quote');
  await shot('A-B-C-sent');
  await check('B cell Markdown and attachment images preserve outer cell spacing and own image width after send', assertCellMediaStyle);
  await check('C dropped inline image is stored and served as a valid image', async () => {
    const image = page.locator('.review-loop-inline .review-loop-conversation-image').first();
    await image.waitFor();
    assert.equal(await image.evaluate(async (img: HTMLImageElement) => { await img.decode(); return img.naturalWidth; }), 1);
  });
  await check('A sent cell quotes cell text with column', async () => {
    assert.equal(await page.locator('.review-loop-inline .review-loop-quote').first().textContent(), 'first row note');
    assert.match(await page.locator('.review-loop-inline .review-loop-comment-head').first().textContent() || '', /3列目/);
  });
  await check('B sent Markdown has ordered/nested lists and scoped list styles', async () => {
    await page.locator('.review-loop-inline .review-loop-markdown pre code.hljs[data-highlighted="yes"] .hljs-keyword').first().waitFor();
    await page.waitForSelector('.review-loop-inline .review-loop-markdown ol ul li', { timeout: 2000 });
    assert.equal(await page.locator('.review-loop-inline .review-loop-markdown ol').first().evaluate(el => getComputedStyle(el).listStyleType), 'decimal');
  });
  await check('C reply drop attaches', async () => {
    await drop('.review-loop-inline textarea');
    await page.waitForSelector('.review-loop-inline .review-loop-reply-preview img', { timeout: 2000 });
  });
  await check('C files outside editor prevented; text drops preserved', async () => {
    assert.deepEqual(await drop('#md-preview h1'), { over: true, drop: true });
    assert.deepEqual(await drop('#md-preview h1', false), { over: false, drop: false });
  });
  await check('A notifications and live log contain cell quote and column', async () => {
    await page.waitForFunction(() => !!document.querySelector('.review-loop-inline'));
    assert.match(readFileSync(notifyLog, 'utf8'), /send-now r.md:7 col=3[\s\S]*> first row note/);
    const live = readFileSync(join(tmpdir(), `yunomi-live-${server.pid}.jsonl`), 'utf8').trim().split('\n').map(line => JSON.parse(line));
    const sent = live.find(e => e.type === 'send-now');
    assert.equal(sent.quote, 'first row note'); assert.equal(sent.col, 3);
    if (process.env.SHOT_DIR) {
      writeFileSync(join(resolve(process.env.SHOT_DIR), 'notification.txt'), readFileSync(notifyLog));
      writeFileSync(join(resolve(process.env.SHOT_DIR), 'live.jsonl'), live.map(e => JSON.stringify(e)).join('\n'));
    }
  });
  await page.reload(); await page.waitForSelector('.review-loop-inline .review-loop-quote');
  await check('B cell Markdown and attachment images preserve outer cell spacing and own image width after reload', assertCellMediaStyle);
  await check('A reload preserves display and stored source quote', async () => {
    assert.equal(await page.locator('.review-loop-inline .review-loop-quote').first().textContent(), 'first row note');
    const files = readdirSync(join(dir, 'reviews'), { recursive: true }) as string[];
    const review = files.find(f => f.endsWith('review.json'))!;
    const state = JSON.parse(readFileSync(join(dir, 'reviews', review), 'utf8'));
    assert.equal(state.comments[0].quote, '| alpha | ok | first row note |');
  });
  await check('A prepending source lines reanchors without changing source quote', async () => {
    writeFileSync(fixture, 'Preface.\n\n' + source);
    assert.equal((await fetch(url + '/go', { method: 'POST' })).status, 200);
    await page.waitForFunction(() => document.querySelector('#md-preview')?.textContent?.includes('Preface.'));
    await page.waitForFunction(() => document.querySelector('.review-loop-inline .review-loop-comment-head')?.textContent?.includes('9行目'));
    assert.equal(await page.locator('.review-loop-inline .review-loop-quote').first().textContent(), 'first row note');
    await shot('A-reanchored');
  });
  if (await page.locator('#review-loop-panel').evaluate(el => el.classList.contains('review-loop-sidebar-collapsed'))) await page.locator('.review-loop-sidebar-toggle').click();
  await check('C global chat drop attaches', async () => {
    await drop('#review-loop-panel textarea');
    await page.waitForSelector('#review-loop-panel .review-loop-reply-preview img', { timeout: 2000 });
  });
  await shot('C-chat');
  await check('D expanded preference survives reload', async () => {
    await page.reload(); await page.waitForSelector('#review-loop-panel textarea:visible');
  });
  await check('B Markdown in drafts, thread replies and global chat uses the shared structure', async () => {
    const markdown = '## Heading\n\n1. first\n   - nested\n2. second\n\n> quote\n\n| A | B |\n| --- | --- |\n| x | y |\n\n![alt](data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=)\n\n```js\nconst x = 1\n```\n\n[link](https://example.com)\n\n![relative](target.png)' + '\n\n<script>window.__commentUnsafe=1</script><img src=x onerror="window.__commentUnsafe=1">';
    await page.locator('#md-preview > p').last().click();
    await page.locator('#comment-input').fill(markdown);
    await page.locator('#save-comment').click();
    const draft = page.locator('.yunomi-inline-comment-view .review-loop-markdown');
    await draft.locator('ol ul li').waitFor();
    await draft.locator('pre code.hljs[data-highlighted="yes"] .hljs-keyword').waitFor();
    const draftHtml = await draft.innerHTML();
    assert.equal(await draft.locator('[data-source-line],[data-row],[data-col],[data-source-start-line]').count(), 0);
    await shot('B-draft');
    // A click inside a sent Markdown table must not open a document comment.
    const thread = page.locator('.review-loop-inline').first();
    assert.equal(await thread.locator('.review-loop-thread-line').first().locator('pre code').evaluate(el => el.outerHTML), await draft.locator('pre code').evaluate(el => el.outerHTML));
    await thread.locator('textarea').fill(markdown);
    await thread.locator('button[type=submit]').click();
    const reply = thread.locator('.review-loop-thread-line').last().locator('.review-loop-markdown');
    await reply.locator('table td').first().waitFor();
    await reply.locator('pre code.hljs[data-highlighted="yes"] .hljs-keyword').waitFor();
    assert.equal(await reply.innerHTML(), draftHtml);
    await reply.locator('table td').first().click();
    assert.equal(await page.locator('.yunomi-inline-comment-editor').count(), 0);
    await page.locator('#review-loop-panel textarea').fill(markdown);
    await page.locator('#review-loop-panel button[type=submit]').click();
    const chat = page.locator('#review-loop-panel .review-loop-conversation-message .review-loop-markdown').last();
    await chat.locator('table td').first().waitFor();
    await chat.locator('pre code.hljs[data-highlighted="yes"] .hljs-keyword').waitFor();
    assert.equal(await chat.innerHTML(), draftHtml);
    const styles = async (root: typeof draft) => root.evaluate(el => {
      const selectors = ['h2', 'ol', 'ol > li', 'ul', 'ul > li', 'blockquote', 'table', 'td', 'pre', 'code', 'img', 'a'];
      return Object.fromEntries(selectors.map(selector => {
        const node = el.querySelector(selector)!; const css = getComputedStyle(node);
        return [selector, [css.fontSize, css.lineHeight, css.whiteSpace, css.marginTop, css.marginBottom, css.paddingLeft, /^(OL|UL|LI)$/.test(node.tagName) ? css.listStyleType : null]];
      }));
    });
    assert.deepEqual(await styles(reply), await styles(draft));
    assert.deepEqual(await styles(chat), await styles(draft));
    assert.equal(await page.evaluate(() => (window as any).__commentUnsafe), undefined);
    assert.equal(await page.locator('.review-loop-markdown script,.review-loop-markdown [onerror]').count(), 0);
    if (process.env.SHOT_DIR) writeFileSync(join(resolve(process.env.SHOT_DIR), 'markdown-styles.json'), JSON.stringify(await styles(chat), null, 2));
    await chat.locator('img[alt="relative"]').evaluate(async (img: HTMLImageElement) => { await img.decode(); });
    assert.equal(await chat.locator('img[alt="relative"]').evaluate((img: HTMLImageElement) => img.currentSrc), await page.locator('#md-preview img[alt="document-relative"]').first().evaluate((img: HTMLImageElement) => img.currentSrc));

    await shot('B-reply-chat');
  });
  await check('D closed chat remains closed on agent reply and unread badge opens it', async () => {
    await page.locator('#review-loop-panel .review-loop-sidebar-toggle').click();
    const id = await page.locator('#review-loop-panel .review-loop-reply-form').getAttribute('data-review-comment-id');
    const response = await fetch(url + '/reply-comment', { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify({ id, text: 'Agent unread reply', author: 'agent' }) });
    assert.equal(response.status, 200);
    await page.waitForFunction(() => (window as any).__YUNOMI_UNREAD__?.global === 1);
    await page.waitForSelector('#review-loop-panel .review-loop-unread-dot:not([hidden])');
    assert.equal(await page.locator('#review-loop-panel.review-loop-sidebar-collapsed').count(), 1);
    const unreadState = () => page.evaluate(() => ({
      unread: (window as any).__YUNOMI_UNREAD__,
      collapsed: document.querySelector('#review-loop-panel')?.classList.contains('review-loop-sidebar-collapsed'),
      focused: document.activeElement?.outerHTML?.slice(0, 100),
    }));
    console.log('D_BEFORE_SCREENSHOT', JSON.stringify(await unreadState()));
    await shot('D-unread-closed');
    console.log('D_AFTER_SCREENSHOT', JSON.stringify(await unreadState()));
    await page.locator('#conversation-unread').click();
    await page.waitForSelector('#review-loop-panel textarea:visible');
  });
  await check('D phone viewport starts closed and remembers explicit open/close', async () => {
    const phone = await browser.newPage({ viewport: { width: 390, height: 844 } });
    try {
      await phone.goto(url); await phone.waitForSelector('#review-loop-panel');
      assert.equal(await phone.locator('#review-loop-panel.review-loop-sidebar-collapsed').count(), 1);
      await phone.locator('.review-loop-sidebar-toggle').click();
      await phone.reload(); await phone.waitForSelector('#review-loop-panel textarea:visible');
      await phone.locator('.review-loop-sidebar-toggle').click();
      await phone.reload(); await phone.waitForSelector('#review-loop-panel.review-loop-sidebar-collapsed');
      if (process.env.SHOT_DIR) await phone.screenshot({ path: join(resolve(process.env.SHOT_DIR), 'after-D-phone.png'), fullPage: true });
    } finally { await phone.close(); }
  });
  await check('A Submit preserves element_text and emits final cell quote plus column', async () => {
    if (!await page.locator('#review-loop-panel').evaluate(el => el.classList.contains('review-loop-sidebar-collapsed'))) await page.locator('#review-loop-panel .review-loop-sidebar-toggle').click();
    await page.locator('#md-preview td[data-row="9"][data-col="3"]').click();
    await page.locator('#comment-input').fill('Submit cell');
    await page.locator('#save-comment').click();
    const emitted = new Promise<void>((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('final YAML missing: ' + output)), 10000);
      const listener = () => { if (/quote: second row note/.test(output)) { clearTimeout(timeout); server.stdout!.off('data', listener); resolve(); } };
      server.stdout!.on('data', listener);
    });
    await page.locator('#send-and-exit').click();
    await page.locator('#modal-request-changes').click();
    await emitted;
    assert.match(output, /col: 3[\s\S]*quote: second row note/);
    const stateFile = (readdirSync(join(dir, 'reviews'), { recursive: true }) as string[]).find(f => f.endsWith('review.json'))!;
    const state = JSON.parse(readFileSync(join(dir, 'reviews', stateFile), 'utf8'));
    const submitted = state.comments.find((c: any) => c.text === 'Submit cell');
    assert.equal(submitted.quote, '| beta | ng | second row note |');
    assert.match(submitted.element_text, /^Markdown table cell/);
    assert.equal(submitted.value, undefined);
    if (process.env.SHOT_DIR) {
      writeFileSync(join(resolve(process.env.SHOT_DIR), 'final-output.txt'), output);
      writeFileSync(join(resolve(process.env.SHOT_DIR), 'final-review.json'), JSON.stringify(state, null, 2));
    }
  });
  assert.deepEqual(errors, []);
} finally { await browser.close(); server.kill(); }
if (failures) process.exitCode = 1;
