import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

const serverJs = new URL('../_build/js/release/build/server/server.js', import.meta.url).pathname;
const png = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
const root = mkdtempSync(join(tmpdir(), 'yunomi-reply-context-'));
let failed = 0;
async function check(name: string, run: () => Promise<void>) {
  try { await run(); console.log('PASS', name); } catch (error) { failed++; console.error('FAIL', name, error); }
}
async function start(name: string, mux = false) {
  const dir = join(root, name); mkdirSync(dir);
  const file = join(dir, 'r.md'), other = join(dir, 'z-other.md');
  const source = '# Reply context\n\nOrdinary paragraph.\n\n| Name | Status |\n| --- | --- |\n| alpha selected | same |\n\n| Image |\n| --- |\n| ![cat](cat.png) |\n\n' + 'Long paragraph ' + 'q'.repeat(300) + '\n';
  writeFileSync(file, source); writeFileSync(other, '# Other\n\nOther paragraph.\n');
  if (mux) {
    for (const args of [['init','-b','main'],['config','user.name','Notification Test'],['config','user.email','test@example.invalid'],['add','r.md','z-other.md'],['commit','-m','base']]) {
      const result = spawnSync('git',args,{cwd:dir,encoding:'utf8'}); assert.equal(result.status,0,result.stderr);
    }
    writeFileSync(file,source+'\n'); writeFileSync(other,'# Other\n\nOther paragraph.\n\n');
  }
  const reviewDir = join(dir, 'reviews'), reviewPath = join(reviewDir, 'review.json');
  const notifyPath = join(dir, 'notify.jsonl'), script = join(dir, 'notify.mjs'); writeFileSync(notifyPath, '');
  writeFileSync(script, "import {appendFileSync} from 'node:fs'; appendFileSync(process.env.NOTIFY_LOG, JSON.stringify(process.argv[2]) + String.fromCharCode(10));");
  const child = spawn(process.execPath, [serverJs, ...(mux ? ['review','main'] : [file]), '--no-open', '--loop', '--port', '0'], {
    cwd: dir, env: { ...process.env, HERDR_PANE_ID: '', TMUX_PANE: '', YUNOMI_NOTIFY_CMD: `${process.execPath} ${script} {msg}`, NOTIFY_LOG: notifyPath, YUNOMI_LOCK_DIR: join(dir, 'locks'), YUNOMI_REVIEW_DIR: reviewDir }, stdio: ['ignore', 'pipe', 'pipe'],
  });
  let output = '';
  const url = await new Promise<string>((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('server startup: ' + output)), 30000);
    const read = (chunk: Buffer) => { output += chunk.toString(); const match = output.match(/http:\/\/127\.0\.0\.1:\d+/); if (match) { clearTimeout(timer); resolve(match[0]); } };
    child.stdout!.on('data', read); child.stderr!.on('data', read);
    child.once('exit', code => { clearTimeout(timer); reject(new Error(`server exit ${code}: ${output}`)); });
  });
  const notices = (): string[] => readFileSync(notifyPath, 'utf8').trim().split('\n').filter(Boolean).map(line => JSON.parse(line));
  const stored = (): any => JSON.parse(readFileSync(reviewPath, 'utf8'));
  const comment = (id: string): any => stored().comments.find((c: any) => c.id === id);
  const post = async (path: string, body: object = {}) => fetch(url + path, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  async function send(id: string, row = 6, col = 1, text = 'Root ' + id, quote = '', value = '', image = '') {
    const response = await post('/comment' + (mux ? '?f=0' : ''), { type: 'send-now', key: id, row, col, text, quote, value, image });
    assert.equal(response.status, 200); return comment(id);
  }
  async function reply(id: string, text: string, author = 'human', image = '') {
    const before = notices().length;
    const response = await post('/reply-comment' + (mux ? '?f=0' : ''), { id, text, author, image });
    assert.equal(response.status, 200);
    const added = notices().slice(before);
    assert.equal(added.length, author === 'human' ? 1 : 0);
    return added[0] || '';
  }
  return { child, file, source, reviewPath, dir, url, notices, stored, comment, post, send, reply, attachmentDir: join(reviewDir, 'comment-attachments') };
}
const h = await start('single');
try {
  const line = '| alpha selected | same |';
  const descriptor = (col: number, text: string) => `Markdown table cell: source line 7, column ${col}: ${text} | source: ${line}`;
  await h.send('left', 6, 1, 'LEFT ROOT', '', descriptor(1, 'alpha selected'));
  const firstNotification = h.notices().at(-1)!;
  await h.send('right', 6, 2, 'RIGHT PRIVATE', '', descriptor(2, 'same'));
  await h.send('selected', 6, 1, 'SELECTED ROOT', 'selected', descriptor(1, 'alpha selected'));
  await h.send('ordinary', 2, 4, 'Ordinary root\\ncontinued\\tcolumn\\\\end');
  await h.send('image-cell', 10, 1, 'Image cell root', '', 'Markdown table cell: source line 11, column 1, image "cat" | source: | ![cat](cat.png) |');
  await check('initial send-now notification is unchanged', async () => {
    assert.match(firstNotification, /^\[yunomi\] send-now r.md:7 col=1 id=left round=1\n> alpha selected\nhuman: LEFT ROOT\nurl=/);
    assert.ok(!firstNotification.includes('history (')); assert.ok(!firstNotification.includes('location:'));
  });
  await h.reply('left', 'Agent first\\nsecond line', 'agent');
  await check('cell location and ordered same-thread history precede the unchanged new message', async () => {
    const before = h.comment('left');
    const notice = await h.reply('left', 'NEW LEFT\\nnew second line');
    assert.equal(notice, `[yunomi] conversation reply id=left round=1\nlocation: r.md:7 col=1\n> alpha selected\nhistory (2 earlier messages, oldest first):\n  | human: LEFT ROOT\n  | agent: Agent first\n  | second line\nhuman: NEW LEFT\nnew second line\nreply with: yunomi reply left <text>\nurl=${h.url}`);
    assert.equal(notice.split('NEW LEFT').length - 1, 1); assert.ok(!notice.includes('RIGHT PRIVATE'));
    const after = h.comment('left'); assert.deepEqual({ ...after, replies: before.replies }, before); assert.equal(after.replies.length, before.replies.length + 1);
  });
  await check('a different cell on the same row has only its own history and column', async () => {
    const notice = await h.reply('right', 'NEW RIGHT');
    assert.match(notice, /\nlocation: r.md:7 col=2\n> same\nhistory \(1 earlier messages, oldest first\):\n  \| human: RIGHT PRIVATE\nhuman: NEW RIGHT\n/);
    assert.ok(!notice.includes('LEFT ROOT'));
  });
  await check('selected text takes precedence over the whole cell, including Submit storage without value', async () => {
    const state = h.stored(); const selected = state.comments.find((c: any) => c.id === 'selected');
    selected.element_text = selected.value; delete selected.value;
    writeFileSync(h.reviewPath, JSON.stringify(state, null, 2));
    const notice = await h.reply('selected', 'NEW SELECTED'); assert.match(notice, /\n> selected\n/); assert.ok(!notice.includes('> alpha selected'));
  });
  await check('ordinary row ignores non-table column and expands all history escapes', async () => {
    const notice = await h.reply('ordinary', 'NEW ORDINARY');
    assert.match(notice, /\nlocation: r.md:3\n> Ordinary paragraph\.\n/);
    assert.match(notice, /  \| human: Ordinary root\n  \| continued\tcolumn\\end\nhuman: NEW ORDINARY/);
    assert.ok(!notice.includes('col='));
  });
  await check('the saved quote is not shortened by a reply-specific length limit', async () => {
    const row = h.source.split('\n').findIndex(line => line.startsWith('Long paragraph '));
    const saved = await h.send('long-quote', row, 0, 'LONG QUOTE ROOT');
    assert.ok(saved.quote.length > 200);
    const notice = await h.reply('long-quote', 'NEW LONG QUOTE');
    assert.ok(notice.includes('\n> ' + saved.quote + '\n'));
  });
  await check('image cell uses its alt display quote', async () => {
    assert.match(await h.reply('image-cell', 'NEW IMAGE CELL'), /\nlocation: r.md:11 col=1\n> 画像「cat」\n/);
  });
  await check('history includes image-only messages and every absolute attachment path', async () => {
    await h.send('images', 2, 0, '', '', '', png);
    const rootImagePath = join(h.attachmentDir, readdirSync(h.attachmentDir)[0]);
    await h.reply('images', '', 'agent', png);
    const agentImagePath = readdirSync(h.attachmentDir).map(name => join(h.attachmentDir, name)).find(path => path !== rootImagePath)!;
    const original = h.comment('images');
    // Existing saved JSON supports multiple attachments; exercise that persisted input
    // using the two files actually uploaded through the production image route.
    const state = h.stored();
    const images = state.comments.find((c: any) => c.id === 'images');
    images.attachments.push(original.replies[0].attachments[0]);
    writeFileSync(h.reviewPath, JSON.stringify(state, null, 2));
    const notice = await h.reply('images', 'NEW WITH IMAGE', 'human', png);
    assert.match(notice, /history \(2 earlier messages, oldest first\):\n  \| human: \n  \|   attachment: /);
    for (const path of [rootImagePath, agentImagePath]) assert.ok(notice.includes('  |   attachment: ' + path));
    const priorAgentPath = agentImagePath;
    const rootPaths = [rootImagePath, agentImagePath].map(path => '  |   attachment: ' + path).join('\n');
    assert.ok(notice.includes('history (2 earlier messages, oldest first):\n  | human: \n' + rootPaths + '\n  | agent: \n  |   attachment: ' + priorAgentPath + '\nhuman: NEW WITH IMAGE\n'));
    const newestPath = readdirSync(h.attachmentDir).map(name => join(h.attachmentDir, name)).find(path => path !== rootImagePath && path !== agentImagePath)!;
    assert.ok(notice.includes('\nattachment: ' + newestPath));
    assert.equal(notice.split('NEW WITH IMAGE').length - 1, 1);
  });
  await check('round chat has history but no location or quote and its first notification is unchanged', async () => {
    const response = await h.post('/create-global-comment', { text: 'ROUND ROOT', image: png }); assert.equal(response.status, 200);
    const { id } = await response.json();
    const first = h.notices().at(-1)!; assert.match(first, /^\[yunomi\] global comment id=.* round=1\nhuman: ROUND ROOT\nattachment: /); assert.ok(!first.includes('history ('));
    await h.reply(id, 'ROUND AGENT', 'agent');
    const notice = await h.reply(id, 'NEW ROUND');
    assert.ok(!notice.includes('\nlocation:')); assert.ok(!notice.includes('\n> '));
    assert.match(notice, /history \(2 earlier messages, oldest first\):\n  \| human: ROUND ROOT\n  \|   attachment: \/.*\n  \| agent: ROUND AGENT\nhuman: NEW ROUND/);
    assert.ok(!notice.includes('LEFT ROOT'));
  });
  await check('all stored attachment reference forms resolve to the known original image', async () => {
    await h.send('path-forms', 2, 0, 'PATH ROOT');
    const knownImage = join(h.dir, 'reviews', 'history-image.png');
    writeFileSync(knownImage, Buffer.from(png.split(',')[1], 'base64'));
    const state = h.stored();
    state.comments.find((c: any) => c.id === 'path-forms').attachments = ['./history-image.png', 'history-image.png', knownImage];
    writeFileSync(h.reviewPath, JSON.stringify(state, null, 2));
    const notice = await h.reply('path-forms', 'NEW PATH FORMS');
    const paths = notice.split('\n').filter(line => line.startsWith('  |   attachment: '));
    assert.deepEqual(paths, Array(3).fill('  |   attachment: ' + knownImage));
  });
  await check('exactly ten earlier messages do not produce an omission warning', async () => {
    await h.send('exact-limit', 2, 0, 'EXACT ROOT');
    for (let n = 1; n <= 9; n++) await h.reply('exact-limit', 'EXACT ' + n, 'agent');
    const notice = await h.reply('exact-limit', 'NEW EXACT');
    assert.ok(notice.includes('history (10 earlier messages, oldest first):\n  | human: EXACT ROOT\n'));
    assert.ok(!notice.includes('件は省略')); assert.equal((notice.match(/^  \| (human|agent): /gm) || []).length, 10);
  });
  await check('at most the latest ten earlier messages are included, with an omission count and full review path', async () => {
    await h.send('limit', 2, 0, 'OLD ROOT');
    for (let n = 1; n <= 12; n++) await h.reply('limit', `EARLIER ${n}` + (n === 12 ? '\n' + 'long'.repeat(300) : ''), 'agent');
    const notice = await h.reply('limit', 'NEW LIMIT');
    assert.match(notice, /history \(10 earlier messages, oldest first\):\n/);
    assert.ok(notice.includes(`  | (古い 3 件は省略。全履歴: ${resolve(h.reviewPath)})\n`));
    assert.ok(!notice.includes('OLD ROOT')); assert.ok(!notice.includes('  | agent: EARLIER 1\n')); assert.ok(!notice.includes('  | agent: EARLIER 2\n'));
    const positions = Array.from({length:10}, (_,i) => notice.indexOf(`  | agent: EARLIER ${i+3}\n`));
    assert.ok(positions.every((pos,i) => pos >= 0 && (i === 0 || pos > positions[i-1])));
    assert.ok(notice.includes('  | ' + 'long'.repeat(300))); assert.equal(notice.split('NEW LIMIT').length - 1, 1);
  });
  await check('a persisted thread with no earlier message omits the whole history block', async () => {
    await h.send('empty-history', 2, 0, 'fixture root');
    const state = h.stored(); state.comments.find((c: any) => c.id === 'empty-history').text = ''; writeFileSync(h.reviewPath, JSON.stringify(state, null, 2));
    assert.ok(!(await h.reply('empty-history', 'FIRST CONTENT')).includes('history ('));
  });
  await check('source reanchoring supplies the current row, preserving stored display descriptors', async () => {
    const old = h.comment('left');
    writeFileSync(h.file, 'Inserted paragraph.\n\n' + h.source); assert.equal((await h.post('/go')).status, 200);
    const current = h.comment('left'); assert.equal(current.line, 9); assert.equal(current.unanchored, false);
    assert.equal(current.value, old.value); assert.equal(current.quote, old.quote);
    assert.match(await h.reply('left', 'NEW MOVED'), /\nlocation: r.md:9 col=1\n> alpha selected\n/);
  });
  await check('unanchored threads clearly label the last known location as unknown', async () => {
    writeFileSync(h.file, '# Entirely different source\n'); assert.equal((await h.post('/go')).status, 200);
    const current = h.comment('left'); assert.equal(current.unanchored, true);
    const notice = await h.reply('left', 'NEW UNKNOWN');
    assert.ok(notice.includes(`\nlocation: (位置不明。元は r.md:${current.line})\n`));
    assert.ok(!notice.includes(`\nlocation: r.md:${current.line}`));
  });
  await check('agent and resolved replies never send a notification', async () => {
    await h.reply('left', 'SILENT AGENT', 'agent');
    assert.equal((await h.post('/resolve-comment', {id:'left'})).status, 200);
    const before = h.notices().length;
    assert.equal((await h.post('/reply-comment', {id:'left',text:'REJECTED HUMAN',author:'human'})).status,409);
    assert.equal(h.notices().length,before);
  });
} finally { h.child.kill('SIGTERM'); }
const mux = await start('mux', true);
try {
  assert.equal((await mux.post('/comment?f=1', {type:'send-now',key:'foreign',row:2,col:0,text:'OTHER FILE PRIVATE'})).status,200);
  await check('wrong-file replies are rejected without notification or history leakage', async () => {
    const before = mux.notices().length;
    assert.equal((await mux.post('/reply-comment?f=0',{id:'foreign',text:'REJECTED CROSS FILE',author:'human'})).status,400);
    assert.equal(mux.notices().length,before);
    await mux.send('own',2,0,'OWN FILE ROOT');
    const notice=await mux.reply('own','NEW OWN FILE'); assert.ok(!notice.includes('OTHER FILE PRIVATE')); assert.match(notice,/history \(1 earlier messages, oldest first\):/);
  });
} finally { mux.child.kill('SIGTERM'); }
for (const [name, corrupt] of [
  ['null-reply', (comment: any) => { comment.replies = [null]; }],
  ['object-replies', (comment: any) => { comment.replies = { text: 'not an array' }; }],
  ['null-replies', (comment: any) => { comment.replies = null; }],
  ['object-attachments', (comment: any) => { comment.replies = [{ author:'agent',text:'PARTLY READABLE',attachments:{path:'bad'} }]; }],
  ['root-attachments', (comment: any) => { comment.attachments = {path:'bad'}; }],
] as const) {
  await check(`malformed ${name}: reply persists, warns, responds, emits SSE and remains live`, async () => {
    const broken = await start(name);
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 10000);
    try {
      await broken.send('bad', 2, 0, 'READABLE ROOT');
      const state = broken.stored(); corrupt(state.comments.find((c: any) => c.id === 'bad'));
      writeFileSync(broken.reviewPath, JSON.stringify(state, null, 2));
      const stream = await fetch(broken.url + '/sse', {signal:controller.signal});
      const reader = stream.body!.getReader(); await reader.read();
      const notice = await broken.reply('bad', 'NEW AFTER MALFORMED');
      assert.ok(notice.includes('  | (読めない履歴 1 件)'));
      assert.ok(notice.includes('  | human: READABLE ROOT'));
      if (name === 'object-attachments') assert.ok(notice.includes('  | agent: PARTLY READABLE'));
      assert.equal(broken.comment('bad').replies.at(-1).text, 'NEW AFTER MALFORMED');
      let events = '';
      while (!events.includes('event: reply') || !events.includes('NEW AFTER MALFORMED') || !events.includes('event: round')) {
        const chunk = await reader.read(); assert.equal(chunk.done, false); events += new TextDecoder().decode(chunk.value);
      }
      assert.equal(broken.child.exitCode, null);
      assert.equal((await fetch(broken.url + '/healthz')).status, 200);
      assert.equal((await fetch(broken.url + '/review-state')).status, 200);
      await broken.reply('bad', 'NEXT REQUEST ALSO SAVED');
      assert.equal(broken.comment('bad').replies.at(-1).text, 'NEXT REQUEST ALSO SAVED');
    } finally { clearTimeout(timer); controller.abort(); broken.child.kill('SIGTERM'); }
  });
}
await check('invalid JSON keeps the existing rejection and does not notify', async () => {
  const broken = await start('invalid-json');
  try {
    await broken.send('bad', 2, 0, 'VALID ROOT');
    const valid = readFileSync(broken.reviewPath, 'utf8'), count = broken.notices().length;
    writeFileSync(broken.reviewPath, '{');
    assert.equal((await broken.post('/reply-comment', {id:'bad',text:'REJECTED',author:'human'})).status, 409);
    assert.equal(broken.notices().length, count); assert.equal((await fetch(broken.url + '/healthz')).status, 200);
    writeFileSync(broken.reviewPath, valid);
    await broken.reply('bad', 'NEXT VALID REPLY');
  } finally { broken.child.kill('SIGTERM'); }
});
console.log('Evidence:',root);
if(failed) process.exitCode=1;
