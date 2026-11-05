import assert from 'node:assert/strict';
import http from 'node:http';
import {spawn} from 'node:child_process';
import {mkdtempSync,readFileSync,rmSync,writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {chromium} from 'playwright';
function deferred(){let resolve!:()=>void;const promise=new Promise<void>(r=>{resolve=r;});return {promise,resolve};}
const root=mkdtempSync(join(tmpdir(),'yunomi-first-response-'));const file=join(root,'report.md');writeFileSync(file,'# First response\n');
const script=new URL('../_build/js/release/build/server/server.js',import.meta.url).pathname;
const proc=spawn(process.execPath,[script,file,'--no-open','--port','0'],{cwd:root,env:{...process.env,IKESU_PANE_ID:'',IKESU_SOCKET_PATH:'',IKESU:'',HERDR_PANE_ID:'',TMUX_PANE:'',YUNOMI_NOTIFY_CMD:'',YUNOMI_REVIEW_DIR:join(root,'review'),YUNOMI_LOCK_DIR:join(root,'locks')},stdio:['ignore','pipe','pipe']});let output='';
const port=await new Promise<number>((resolve,reject)=>{const read=(c:Buffer)=>{output+=c.toString();const m=output.match(/http:\/\/127\.0\.0\.1:(\d+)/);if(m)resolve(Number(m[1]));};proc.stdout.on('data',read);proc.stderr.on('data',read);proc.once('exit',c=>reject(Error(`${c}: ${output}`)));setTimeout(()=>reject(Error(output)),15000).unref();});
const connected=deferred(),firstRound=deferred(),secondRound=deferred();let eventsResponse:http.ServerResponse|undefined;let pending='',holding=true;const frames:string[]=[];let oldRound='';const requests:{path:string;body:any}[]=[];
const proxy=http.createServer((req,res)=>{const isPost=req.method==='POST' && /\/(create-global-comment|reply-comment)/.test(req.url||'');const chunks:Buffer[]=[];if(isPost)req.on('data',c=>chunks.push(c));const up=http.request({host:'127.0.0.1',port,path:req.url,method:req.method,headers:req.headers},response=>{if(isPost)requests.push({path:req.url!,body:JSON.parse(Buffer.concat(chunks).toString())});res.writeHead(response.statusCode||200,response.headers);
 if(req.url?.startsWith('/sse')){eventsResponse=res;connected.resolve();response.on('data',chunk=>{pending+=chunk.toString();let i;while((i=pending.indexOf('\n\n'))>=0){const frame=pending.slice(0,i+2);pending=pending.slice(i+2);if(frame.startsWith('event: round\n')){const state=JSON.parse(frame.slice(frame.indexOf('data: ')+6).trim());const c=state.review.comments.find((x:any)=>x.text==='first response root');if(c && !(c.replies||[]).some((r:any)=>r.text==='second after response')){oldRound=frame;firstRound.resolve();}if(c && (c.replies||[]).some((r:any)=>r.text==='second after response'))secondRound.resolve();}if(holding)frames.push(frame);else res.write(frame);}});}else response.pipe(res);
 res.on('close',()=>response.destroy());});req.pipe(up);up.on('error',()=>res.destroy());});
await new Promise<void>(resolve=>proxy.listen(0,'127.0.0.1',resolve));const proxyPort=(proxy.address() as {port:number}).port;
const browser=await chromium.launch();try{
 const page=await browser.newPage();await page.goto(`http://127.0.0.1:${proxyPort}/`);await connected.promise;const toggle=page.locator('#review-loop-panel .review-loop-sidebar-toggle');await toggle.waitFor();if(await page.locator('#review-loop-panel.review-loop-sidebar-collapsed').count())await toggle.click();
 const send=async(text:string)=>{await page.locator('#review-loop-panel textarea').fill(text);await page.locator('#review-loop-panel .review-loop-reply-form button[type=submit]').click();};
 await send('first response root');await page.locator('.review-loop-conversation-message',{hasText:'first response root'}).locator('.conversation-send-status.is-saved').waitFor();await firstRound.promise;
 const image=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=','base64');await page.locator('#review-loop-panel input[type=file]').setInputFiles({name:'saved.png',mimeType:'image/png',buffer:image});await page.locator('#review-loop-panel .review-loop-reply-preview img').waitFor();
 await send('second after response');const second=page.locator('.review-loop-conversation-message',{hasText:'second after response'});await second.locator('.conversation-send-status.is-saved').waitFor();await secondRound.promise;
 assert.deepEqual(requests.map(r=>r.path),['/create-global-comment','/reply-comment']);const review=JSON.parse(readFileSync(join(root,'review','review.json'),'utf8'));assert.equal(requests[1].body.id,review.comments[0].id);assert.equal(review.comments[0].replies[0].text,'second after response');
 const scope=await page.evaluate(()=>JSON.parse((window as any).__YUNOMI_LAST_REVIEW_JSON__).review_scope);assert.match(await page.evaluate(k=>localStorage.getItem(`yunomi:conversation-queue:${k}`)||'',scope),/data:image/);
 holding=false;for(const frame of frames)eventsResponse!.write(frame);
 await page.waitForFunction(k=>JSON.parse(localStorage.getItem(`yunomi:conversation-queue:${k}`)||'[]').length===0,scope);assert.equal(await second.count(),1);assert.equal(await second.locator('img').count(),1);
 eventsResponse!.write(oldRound);
 await page.waitForFunction(()=>{const state=JSON.parse((window as any).__YUNOMI_LAST_REVIEW_JSON__);const c=state.review.comments.find((x:any)=>x.text==='first response root');return !!c && !(c.replies||[]).some((r:any)=>r.text==='second after response');});
 assert.equal(await second.count(),1);assert.equal(await second.locator('.conversation-send-status.is-saved').count(),1);assert.equal(await second.locator('img').count(),1);
 console.log('PASS create HTTP first, new reply, queue image pruning and replayed old SSE');
}finally{await browser.close();await new Promise<void>(resolve=>proxy.close(()=>resolve()));await new Promise<void>(resolve=>{proc.once('exit',()=>resolve());proc.kill('SIGTERM');});rmSync(root,{recursive:true,force:true});}
