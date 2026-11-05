import assert from 'node:assert/strict';
import http from 'node:http';
import {spawn} from 'node:child_process';
import {mkdtempSync,readFileSync,rmSync,writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {chromium} from 'playwright';
function deferred(){let resolve!:()=>void;const promise=new Promise<void>(r=>{resolve=r;});return {promise,resolve};}
const root=mkdtempSync(join(tmpdir(),'yunomi-recovery-'));const file=join(root,'report.md');writeFileSync(file,'# Recovery\n');
const log=join(root,'notify.log');writeFileSync(log,'');const notify=join(root,'notify.mjs');writeFileSync(notify,"import {appendFileSync} from 'node:fs';appendFileSync(process.env.NOTIFY_LOG,'sent\\n');");
const script=new URL('../_build/js/release/build/server/server.js',import.meta.url).pathname;
const proc=spawn(process.execPath,[script,file,'--no-open','--port','0'],{cwd:root,env:{...process.env,IKESU_PANE_ID:'',IKESU_SOCKET_PATH:'',IKESU:'',HERDR_PANE_ID:'',TMUX_PANE:'',YUNOMI_NOTIFY_CMD:`${process.execPath} ${notify} {msg}`,NOTIFY_LOG:log,YUNOMI_REVIEW_DIR:join(root,'review'),YUNOMI_LOCK_DIR:join(root,'locks')},stdio:['ignore','pipe','pipe']});let output='';
const port=await new Promise<number>((resolve,reject)=>{const read=(c:Buffer)=>{output+=c.toString();const m=output.match(/http:\/\/127\.0\.0\.1:(\d+)/);if(m)resolve(Number(m[1]));};proc.stdout.on('data',read);proc.stderr.on('data',read);proc.once('exit',c=>reject(Error(`${c}: ${output}`)));setTimeout(()=>reject(Error(output)),15000).unref();});
let connected=deferred(), held=deferred(), dropped=deferred(), holdEvents=true, dropNext=false, holdNext=false, releaseHeld:(()=>void)|undefined, cutHeld:(()=>void)|undefined, flush:(()=>void)|undefined;
const requests:{path:string;body:any}[]=[];
const proxy=http.createServer((req,res)=>{const isPost=req.method==='POST' && /\/(create-global-comment|reply-comment)/.test(req.url||'');const chunks:Buffer[]=[];if(isPost)req.on('data',c=>chunks.push(c));
 const upstream=http.request({host:'127.0.0.1',port,path:req.url,method:req.method,headers:req.headers},up=>{const events=req.url?.startsWith('/sse');if(isPost)requests.push({path:req.url!,body:JSON.parse(Buffer.concat(chunks).toString())});
 if(isPost && dropNext){dropNext=false;const body:Buffer[]=[];up.on('data',c=>body.push(c));up.on('end',()=>{res.writeHead(up.statusCode||200,up.headers);res.write(Buffer.concat(body).subarray(0,1));setImmediate(()=>{res.destroy();dropped.resolve();});});}
 else if(isPost && holdNext){holdNext=false;const body:Buffer[]=[];up.on('data',c=>body.push(c));up.on('end',()=>{releaseHeld=()=>{res.writeHead(up.statusCode||200,up.headers);res.end(Buffer.concat(body));};cutHeld=()=>{res.writeHead(up.statusCode||200,up.headers);res.write(Buffer.concat(body).subarray(0,1));setImmediate(()=>res.destroy());};held.resolve();});}
 else {res.writeHead(up.statusCode||200,up.headers);const buffered:Buffer[]=[];if(events){flush=()=>{holdEvents=false;for(const c of buffered.splice(0))res.write(c);};connected.resolve();}up.on('data',c=>{if(events && holdEvents)buffered.push(c);else res.write(c);});up.on('end',()=>res.end());}
 res.on('close',()=>up.destroy());});req.pipe(upstream);upstream.on('error',()=>res.destroy());});
await new Promise<void>(resolve=>proxy.listen(0,'127.0.0.1',resolve));const proxyPort=(proxy.address() as {port:number}).port;
const browser=await chromium.launch();try {
 const page=await browser.newPage();await page.goto(`http://127.0.0.1:${proxyPort}/`);await connected.promise;const toggle=page.locator('#review-loop-panel .review-loop-sidebar-toggle');await toggle.waitFor();if(await page.locator('#review-loop-panel.review-loop-sidebar-collapsed').count())await toggle.click();
 const send=async(text:string)=>{await page.locator('#review-loop-panel .review-loop-reply-form textarea').fill(text);await page.locator('#review-loop-panel .review-loop-reply-form button[type=submit]').click();};
 const bubble=(text:string)=>page.locator('.review-loop-conversation-message',{hasText:text});const stored=()=>JSON.parse(readFileSync(join(root,'review','review.json'),'utf8'));const notices=()=>readFileSync(log,'utf8').trim().split('\n').filter(Boolean).length;
 // A lost create response can be retried from its bubble; B waits and follows it.
 dropNext=true;await send('create lost');await dropped.promise;await bubble('create lost').locator('.conversation-send-status.is-unknown').waitFor();
 const firstId=requests.at(-1)!.body.clientId;await send('create follower');assert.equal(requests.length,1);
 await bubble('create lost').getByRole('button',{name:'Retry'}).click();await bubble('create follower').locator('.conversation-send-status.is-saved').waitFor({timeout:20000});
 assert.deepEqual(requests.map(r=>r.path),['/create-global-comment','/create-global-comment','/reply-comment']);assert.equal(requests[1].body.clientId,firstId);
 let thread=stored().comments.find((c:any)=>c.clientId===firstId);assert.equal(thread.replies[0].text,'create follower');assert.equal(notices(),2);
 assert.ok(flush);flush!();await page.waitForFunction(()=>{const scope=JSON.parse((window as any).__YUNOMI_LAST_REVIEW_JSON__).review_scope;return JSON.parse(localStorage.getItem(`yunomi:conversation-queue:${scope}`)||'[]').length===0;});
 assert.equal(await bubble('create lost').count(),1);assert.equal(await bubble('create follower').count(),1);
 // A saved reply can be retried after its thread was resolved.
 holdEvents=true;dropped=deferred();dropNext=true;await send('reply lost before resolve');await dropped.promise;await bubble('reply lost before resolve').locator('.conversation-send-status.is-unknown').waitFor();
 const replyId=requests.at(-1)!.body.clientId;const before=notices();const resolved=await page.request.post(`http://127.0.0.1:${proxyPort}/resolve-comment`,{data:{id:thread.id}});assert.equal(resolved.status(),200);
 await bubble('reply lost before resolve').getByRole('button',{name:'Retry'}).click();await bubble('reply lost before resolve').locator('.conversation-send-status.is-saved').waitFor();
 assert.equal(requests.at(-1)!.body.clientId,replyId);assert.equal(requests.at(-1)!.body.id,thread.id);assert.equal(stored().comments.find((c:any)=>c.id===thread.id).replies.filter((r:any)=>r.clientId===replyId).length,1);assert.equal(notices(),before+1); // resolve notification only
 flush!();await page.waitForFunction(id=>(JSON.parse((window as any).__YUNOMI_LAST_REVIEW_JSON__).review.comments||[]).some((c:any)=>c.id===id && c.status==='resolved'),thread.id);
 // A stored root with a buffered response and a queued B: reload never resends, and B can be resumed.
 holdEvents=true;held=deferred();holdNext=true;await send('reload root');await held.promise;await send('reload follower');
 const countBeforeReload=requests.length;connected=deferred();await page.reload();await connected.promise;
 await bubble('reload root').locator('.conversation-send-status.is-saved').waitFor();await bubble('reload follower').getByRole('button',{name:'Retry'}).waitFor();assert.equal(requests.length,countBeforeReload);
 await bubble('reload follower').getByRole('button',{name:'Retry'}).click();await bubble('reload follower').locator('.conversation-send-status.is-saved').waitFor();
 thread=stored().comments.find((c:any)=>c.text==='reload root');assert.equal(stored().comments.filter((c:any)=>c.text==='reload root').length,1);assert.equal(thread.replies.filter((r:any)=>r.text==='reload follower').length,1);
 assert.ok(releaseHeld);releaseHeld!();
 holdEvents=true;held=deferred();holdNext=true;
 const beforeSseCut=notices(), startRequest=requests.length;
 await send('sse first cut A');await held.promise;await send('sse first cut B');
 assert.equal(requests.length,startRequest+1);assert.ok(flush);flush!();
 await bubble('sse first cut A').locator('.conversation-send-status.is-saved').waitFor();
 assert.ok(cutHeld);cutHeld!();
 await bubble('sse first cut B').locator('.conversation-send-status.is-saved').waitFor({timeout:20000});
 await page.waitForFunction(()=>{const scope=JSON.parse((window as any).__YUNOMI_LAST_REVIEW_JSON__).review_scope;return JSON.parse(localStorage.getItem(`yunomi:conversation-queue:${scope}`)||'[]').length===0;});
 const finalThread=stored().comments.find((c:any)=>c.text==='reload root');
 assert.deepEqual(finalThread.replies.slice(-2).map((r:any)=>r.text),['sse first cut A','sse first cut B']);
 assert.equal(requests.length,startRequest+2);assert.equal(notices(),beforeSseCut+2);
 console.log('PASS UI retry create/reply, resolved idempotence, queue cleanup, reload recovery and SSE-before-cut continuation');
}finally{await browser.close();await new Promise<void>(resolve=>proxy.close(()=>resolve()));await new Promise<void>(resolve=>{proc.once('exit',()=>resolve());proc.kill('SIGTERM');});rmSync(root,{recursive:true,force:true});}
