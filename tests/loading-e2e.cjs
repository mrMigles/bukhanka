const {chromium} = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname,'..');
const artifacts = path.join(__dirname,'artifacts','loading-e2e');
fs.mkdirSync(artifacts,{recursive:true});
process.env.PORT = '8093';
const server = require('../serve-web.cjs');
const ordinary = server.listeners('request')[0];
server.removeAllListeners('request');
let transientRequests = 0;
let stalledRequests = 0;
server.on('request',(req,res) => {
  const fault = req.headers['x-boot-test'];
  if(req.url.endsWith('.wasm')) {
    if(fault==='stall' || (fault==='stall-retry' && stalledRequests++===0)) {
      const {version}=JSON.parse(fs.readFileSync(path.join(root,'builds/Web/version.json'),'utf8'));
      const bytes=fs.readFileSync(path.join(root,`builds/Web/game-${version}.wasm`));
      res.writeHead(200,{'Content-Type':'application/wasm','Content-Length':bytes.length});
      res.write(bytes.subarray(0,65536));
      return; // Intentionally leave a real HTTP stream unfinished.
    }
    if(fault==='transient' && transientRequests++===0) {res.writeHead(503).end('Temporary failure');return;}
  }
  ordinary(req,res);
});
async function main() {
  const browser=await chromium.launch({headless:true,executablePath:process.env.E2E_BROWSER_EXE || undefined,args:['--enable-webgl']});
  try {
    for(const name of ['success','stall','compile-error','watchdog','transient','stall-retry']) {
      const context=await browser.newContext({viewport:{width:390,height:844},deviceScaleFactor:2,isMobile:true,hasTouch:true,extraHTTPHeaders:{'X-Boot-Test':name}});
      await context.addInitScript(name => {
        window.BUKHANKA_BOOT_TIMEOUTS={idleMs:name.startsWith('stall')?1200:30000,startupMs:name==='watchdog'?1500:120000,maxRetries:['transient','stall-retry'].includes(name)?2:0,retryDelayMs:100};
        if(name==='compile-error') WebAssembly.instantiateStreaming=async () => {throw new WebAssembly.CompileError('Injected mobile compilation failure');};
        if(name==='watchdog') WebAssembly.instantiateStreaming=() => new Promise(()=>{});
      },name);
      const page=await context.newPage();
      if(name==='success') {
        const network=await context.newCDPSession(page);
        await network.send('Network.enable');
        await network.send('Network.emulateNetworkConditions',{offline:false,latency:70,downloadThroughput:1280000,uploadThroughput:512000,connectionType:'cellular4g'});
      }
      const errors=[];
      page.on('pageerror',e=>errors.push(e.message));
      const start=Date.now();
      await page.goto('http://127.0.0.1:8093/?e2e=loading-'+name,{waitUntil:'domcontentloaded'});
      await page.waitForFunction(()=>window.bukhankaBootState);
      await page.screenshot({path:path.join(artifacts,name+'-poster.png')});
      if(['success','transient','stall-retry'].includes(name)) {
        await page.waitForFunction(()=>window.bukhankaBootState?.phase==='ready',null,{timeout:120000});
        await page.waitForFunction(()=>!document.getElementById('status'));
        assert((await page.evaluate(()=>window.bukhankaTestState.buttons)).length>0,'Ready before game UI exists');
        if(name==='transient') assert.equal(transientRequests,2,'Automatic retry does not restart the download');
        if(name==='stall-retry') assert.equal(stalledRequests,2,'A stalled stream does not trigger a fresh download');
        assert.deepEqual(errors,[]);
        if(name==='success') assert(Date.now()-start<60000,'Fast mobile-network startup takes more than a minute');
      } else {
        await page.waitForFunction(()=>window.bukhankaBootState?.phase==='error',null,{timeout:10000});
        assert(await page.locator('#retry').isVisible());
        assert(await page.locator('#safe-start').isVisible());
        assert((await page.locator('#retry').boundingBox()).height>=48);
        const error=await page.evaluate(()=>window.bukhankaBootState.error);
        if(name==='stall') assert.match(error,/передавать|abort/i);
        if(name==='compile-error') assert.match(error,/compilation failure/);
        if(name==='watchdog') assert.match(error,/отведённое время/);
        await page.screenshot({path:path.join(artifacts,name+'-error.png')});
        if(name==='compile-error') {
          await page.setViewportSize({width:844,height:300});
          const retry=await page.locator('#retry').boundingBox();
          assert(retry.y>=0&&retry.y+retry.height<=300,'Landscape retry is clipped');
          await page.screenshot({path:path.join(artifacts,'landscape-error.png')});
        }
      }
      console.log(JSON.stringify({name,elapsedMs:Date.now()-start,state:await page.evaluate(()=>window.bukhankaBootState),errors}));
      await context.close();
    }
  } finally {await browser.close();server.close();}
}
main().catch(e=>{console.error(e);process.exitCode=1;server.close();});
