// Native browser gesture contract for the exact production selection guard.
// Full application coverage remains in preview_selection_comments and table_cell_comment_regression.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { chromium } from 'playwright';
const source = readFileSync(new URL('../src/ui/dom.mbt', import.meta.url), 'utf8');
const start = source.indexOf('extern "js" fn install_preview_selection_scroll_guard()');
assert.ok(start >= 0);
const body = source.slice(start).split('\n').filter(line => line.trimStart().startsWith('#|')).map(line => line.slice(line.indexOf('#|') + 2)).join('\n');
const browser = await chromium.launch();
const page = await browser.newPage({viewport:{width:1100,height:900}});
let failures = 0;
async function reset() {
  await page.setContent('<div class="md-left" style="height:600px;overflow:auto"><div id="md-preview" style="font:20px monospace"><p id="first">abcdefghij klmnopqrst uvwxyz</p><p id="second">Second paragraph</p></div></div>');
  await page.evaluate(body => { (0, eval)('(' + body + ')')(); }, body);
}
async function points(id: string, start: number, end: number) {
  return page.locator(id).evaluate((el, {start,end}) => {
    const range = document.createRange(); range.setStart(el.firstChild!,start); range.setEnd(el.firstChild!,end);
    const rect = range.getBoundingClientRect(); return {x:rect.left,end:rect.right,y:rect.top+rect.height/2};
  },{start,end});
}
async function drag(from: {x:number;y:number}, to: {x:number;y:number}) {
  await page.mouse.move(from.x,from.y); await page.mouse.down(); await page.mouse.move(to.x,to.y,{steps:12}); await page.mouse.up();
}
async function selection() { return page.evaluate(() => window.getSelection()?.toString()); }
async function check(name: string, fn:()=>Promise<void>) {
  await reset();
  try { await fn(); console.log('PASS',name); } catch(error) { failures++; console.error('FAIL',name,error); }
}
try {
  await check('double click preserves the whole word without scroll', async()=>{
    const word=await points('#first',0,10);
    await page.mouse.dblclick((word.x+word.end)/2,word.y);
    assert.equal(await selection(),'abcdefghij');
  });
  await check('Shift click preserves a multiple-paragraph selection without scroll', async()=>{
    const first=await points('#first',8,10),second=await points('#second',0,16);
    await drag({x:first.x,y:first.y},{x:first.end,y:first.y});
    await page.keyboard.down('Shift'); await page.mouse.click(second.end,second.y); await page.keyboard.up('Shift');
    assert.equal(await selection(),'ij klmnopqrst uvwxyz\n\nSecond paragraph');
  });
  await check('triple click preserves the whole paragraph',async()=>{
    const first=await points('#first',0,10);
    await page.mouse.click((first.x+first.end)/2,first.y,{clickCount:3});
    assert.equal((await selection())?.trim(),'abcdefghij klmnopqrst uvwxyz');
  });
  for(const backwards of [false,true]) await check(`${backwards?'backward':'forward'} horizontal drag preserves exact text without scroll`,async()=>{
    const word=await points('#first',11,21);
    await drag({x:backwards?word.end:word.x,y:word.y},{x:backwards?word.x:word.end,y:word.y});
    assert.equal(await selection(),'klmnopqrst');
  });
  await check('cross-paragraph drag preserves the complete range',async()=>{
    const first=await points('#first',8,10),second=await points('#second',0,16);
    await drag({x:first.x,y:first.y},{x:second.end,y:second.y});
    assert.equal(await selection(),'ij klmnopqrst uvwxyz\n\nSecond paragraph');
  });
} finally { await browser.close(); }
if(failures) process.exitCode=1;
