// Run after build-web.ps1. Install Playwright or set PLAYWRIGHT_MODULE to its directory.
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawn } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const artifacts = path.join(__dirname, 'artifacts', 'mobile-e2e');
const port = Number(process.env.E2E_PORT || 8087);
const summary = [];
fs.mkdirSync(artifacts, { recursive: true });
const angleError = (a, b) => Math.abs(Math.atan2(Math.sin(a-b), Math.cos(a-b)));
async function main() {
  const server = spawn(process.execPath, ['serve-web.cjs'], {cwd: root, env: {...process.env, PORT: String(port)}, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe']});
  let browser;
  try {
    await new Promise((resolve, reject) => {server.stdout.once('data', resolve); server.once('error', reject); server.once('exit', code => reject(Error('Web server exited: '+code)));});
    browser = await chromium.launch({headless: true, executablePath: process.env.E2E_BROWSER_EXE || undefined, args: ['--enable-webgl']});
    for (const [name, config] of [
      ['phone', {viewport: {width:390,height:844},deviceScaleFactor:2,isMobile:true,hasTouch:true}],
      ['small-phone', {viewport: {width:320,height:568},deviceScaleFactor:1,isMobile:true,hasTouch:true}],
      ['desktop', {viewport: {width:1280,height:800},deviceScaleFactor:1}],
    ]) {
      if (process.env.E2E_TARGET && process.env.E2E_TARGET !== name) continue;
      const context = await browser.newContext(config);
      const page = await context.newPage();
      if(process.env.E2E_MOBILE_NETWORK && config.hasTouch) {
        const network=await context.newCDPSession(page);
        await network.send('Network.enable');
        await network.send('Network.emulateNetworkConditions',{offline:false,latency:70,downloadThroughput:1280000,uploadThroughput:512000,connectionType:'cellular4g'});
      }
      const errors = [];
      page.on('pageerror', e => errors.push(e.message));
      page.on('console', m => {if(m.type()==='error') errors.push(m.text());});
      const started = Date.now();
      await page.goto(`${process.env.E2E_BASE_URL || `http://127.0.0.1:${port}`}/?e2e=${name}`, {waitUntil:'domcontentloaded'});
      await page.waitForFunction(()=>window.bukhankaTestState?.buttons?.length>0, null, {timeout:120000});
      await page.waitForTimeout(1000);
      const state = () => page.evaluate(()=>window.bukhankaTestState);
      const shot = phase => page.screenshot({path:path.join(artifacts, `${name}-${phase}.png`)});
      async function tapRect(b) {
        if(config.hasTouch) await page.touchscreen.tap(b.x+b.width/2,b.y+b.height/2);
        else await page.mouse.click(b.x+b.width/2,b.y+b.height/2);
        await page.waitForTimeout(650);
      }
      async function tapText(text) {
        if(config.hasTouch && text==='Настройки') text='Опции';
        const view=page.viewportSize();
        const b=(await state()).buttons.find(b=>b.text.includes(text)&&!b.disabled&&b.x>=0&&b.y>=0&&b.x+b.width<=view.width+1&&b.y+b.height<=view.height+1);
        assert(b, 'Reachable button missing: '+text);
        await tapRect(b);
      }
      const tapControl = async key => tapRect((await state()).controls[key]);
      function checkPanel(s) {
        const b=s.panel_bounds,v=page.viewportSize();
        assert(b.x>=-1&&b.y>=-1&&b.x+b.width<=v.width+1&&b.y+b.height<=v.height+1,'Panel exceeds viewport: '+JSON.stringify(b));
      }
      function checkHud(s) {
        const v=page.viewportSize();
        let area=Math.PI*52*52;
        for(const [key,b] of Object.entries(s.controls)) {
          assert(b.width>=44&&b.height>=44, 'Small touch target: '+key);
          assert(b.x>=0&&b.y>=0&&b.x+b.width<=v.width&&b.y+b.height<=v.height, 'Unreachable control: '+key);
          assert(!(v.width/2>=b.x&&v.width/2<=b.x+b.width&&v.height/2>=b.y&&v.height/2<=b.y+b.height),'Control blocks centre');
          area+=b.width*b.height;
        }
        const gauge=s.speedometer;
        assert(gauge.width>=79&&gauge.height>=79,'Missing circular speedometer');
        assert(gauge.x>=0&&gauge.y>=0&&gauge.x+gauge.width<=v.width+1&&gauge.y+gauge.height<=v.height+1,'Speedometer exceeds viewport');
        for(const b of Object.values(s.controls)) {
          assert(gauge.x+gauge.width<=b.x+1||b.x+b.width<=gauge.x+1||gauge.y+gauge.height<=b.y+1||b.y+b.height<=gauge.y+1,'Speedometer overlaps a button');
        }
        assert(s.hud_icons.MobileCamp==='camp','Camp quick action has no tent icon');
        for(const icon of ['camp','projects','crew','upgrades','journal','settings'])
          assert(Object.values(s.hud_icons).includes(icon),'Main-screen icon missing: '+icon);
        area+=Math.PI*40*40;
        assert(area/(v.width*v.height)<(v.width<360?.22:.14), 'Driving HUD occupies too much of the view');
      }
      await shot('title');
      const loadMs=Date.now()-started;
      assert(loadMs<60000,'Default startup exceeded a minute');
      const graphics=await page.evaluate(()=>window.bukhankaGraphicsState);
      console.log(JSON.stringify({phase:'startup',name,loadMs,graphics}));
      if(config.hasTouch) {
        assert(!graphics.shadows&&graphics.nature&&graphics.scale<=.75,'Phone auto defaults are too heavy: '+JSON.stringify(graphics));
        assert(await page.evaluate(()=>document.getElementById('canvas').width<=innerWidth*1.5+1),'Unbounded mobile framebuffer');
      }
      if(config.hasTouch) assert((await state()).buttons.find(b=>b.text.includes('ЗАВЕСТИ')).height>=47,'Start touch target too small');
      await tapText('ЗАВЕСТИ');
      await page.waitForFunction(()=>window.bukhankaTestState?.panel==='editor');
      await shot('editor');
      checkPanel(await state());
      await tapText('Отправиться');
      await page.waitForTimeout(700);
      await shot('tutorial');
      if((await state()).buttons.some(b=>b.text.includes('Пропустить'))) {
        if(config.hasTouch) assert((await state()).buttons.find(b=>b.text.includes('Пропустить')).height>=44,'Tutorial touch target too small');
        await tapText('Пропустить');
      }
      await page.waitForFunction(()=>window.bukhankaTestState?.running);
      await shot('driving-hud');
      let cameraResult=null;
      if(config.hasTouch) {
        checkHud(await state());
        const cdp=await context.newCDPSession(page);
        const j=(await state()).joystick;
        const joy={id:1,x:j.x,y:j.y-38};
        const send=(type,touchPoints)=>cdp.send('Input.dispatchTouchEvent',{type,touchPoints});
        await send('touchStart',[{id:1,x:j.x,y:j.y}]);
        await send('touchMove',[joy]);
        await page.waitForTimeout(2000);
        assert((await state()).speed>3,'Joystick does not drive');
        const driving=await state();
        assert(Math.abs(Number(driving.speed_text)-Math.round(Math.abs(driving.speed)*3.6))<=3,'Speedometer does not display vehicle speed');
        let look={id:2,x:100,y:230};
        await send('touchStart',[joy,look]);
        look={...look,x:235};
        await send('touchMove',[joy,look]);
        await page.waitForTimeout(600);
        const held=(await state()).yaw;
        await page.waitForTimeout(1200);
        assert(angleError((await state()).yaw,held)<.03,'Camera fights a held look');
        assert((await state()).throttle>.8,'Looking stole the joystick');
        // CDP touchEnd ends its listed contacts; release the gesture, then keep driving.
        await send('touchEnd',[]);
        await send('touchStart',[joy]);
        await page.waitForTimeout(900);
        assert(angleError((await state()).yaw,held)<.05,'Camera returns before delay');
        await page.waitForTimeout(6500);
        await page.waitForFunction(()=>{
          const s=window.bukhankaTestState,t=Math.atan2(-s.velocity[0],s.velocity[1]);
          return s.follow_clock>=5&&Math.abs(Math.atan2(Math.sin(s.yaw-t),Math.cos(s.yaw-t)))<.12;
        },null,{timeout:8000});
        const followed=await state();
        const target=Math.atan2(-followed.velocity[0],followed.velocity[1]);
        fs.writeFileSync(path.join(artifacts,`${name}-follow-state.json`),JSON.stringify(followed,null,2));
        await shot('camera-follow');
        assert(followed.speed>2&&angleError(followed.yaw,target)<.12,'Camera failed to return behind travel: '+JSON.stringify({speed:followed.speed,throttle:followed.throttle,yaw:followed.yaw,target,clock:followed.follow_clock}));
        const fpsSamples=[];
        for(let i=0;i<5;i++) {fpsSamples.push((await state()).fps);await page.waitForTimeout(500);}
        const fpsMedian=[...fpsSamples].sort((a,b)=>a-b)[2];
        cameraResult={errorDegrees:Math.round(angleError(followed.yaw,target)*180/Math.PI),fps:fpsMedian,fpsSamples,performance:followed.performance};
        assert(cameraResult.fps>=30,'Mobile driving falls below 30 FPS');
        const b=followed.controls.MobileBrake;
        await send('touchStart',[joy,{id:3,x:b.x+b.width/2,y:b.y+b.height/2}]);
        await page.waitForTimeout(900);
        assert((await state()).braking&&(await state()).speed<followed.speed*.7,'Brake does not slow the van');
        await send('touchEnd',[]);
        await page.waitForTimeout(400);
        assert(!(await state()).braking&&(await state()).throttle===0,'Stuck driving input');
        await tapControl('MobileLowRange');
        assert((await state()).low_range&&!(await state()).tools,'Quick low range action failed');
        await tapControl('MobileLowRange');
        assert(!(await state()).low_range,'Quick high range action failed');
        await tapControl('MobileCamp');
        assert((await state()).panel==='placement'&&!(await state()).running,'Camp quick action does not open placement');
        checkPanel(await state());
        await shot('quick-camp');
        await tapText('×');
        assert(!(await state()).ghost,'Camp placement grid survives closing the window');
        await page.waitForFunction(()=>window.bukhankaTestState?.running);
        await tapControl('MobileTools');
        assert((await state()).tools&&!(await state()).running,'Tools do not pause simulation');
        const parked=(await state()).position;
        await page.waitForTimeout(700);
        assert.deepEqual((await state()).position,parked,'Vehicle moves while choosing tools');
        await shot('tools');
        await tapText('Пониженная');
        assert((await state()).low_range&&!(await state()).tools,'Low range action failed');
        await tapControl('MobileTools');
        await tapText('Пауза');
        await page.waitForFunction(()=>window.bukhankaTestState?.paused);
        await shot('pause');
        await tapText('Продолжить');
        await page.waitForFunction(()=>window.bukhankaTestState?.running);
        await tapControl('MobileMenu');
        checkPanel(await state());
        for(const tab of ['Команда','Машина','Дневник','Настройки','Лагерь']) {
          await tapText(tab); await shot('tab-'+tab);
          const s=await state();
          fs.writeFileSync(path.join(artifacts,`${name}-panel-state.json`),JSON.stringify(s,null,2));
          checkPanel(s);
        }
        await shot('menu');
        await tapText('×');
        if(name==='phone') {
          await page.setViewportSize({width:844,height:390});
          await page.waitForTimeout(1500);
          checkHud(await state());
          await shot('landscape-hud');
          await tapControl('MobileMenu');
          checkPanel(await state());
          await tapText('Настройки');
          checkPanel(await state());
          await shot('landscape-menu');
          await page.setViewportSize({width:390,height:844});
          await page.waitForTimeout(1500);
          checkPanel(await state());
          await shot('rotated-menu');
          await tapText('×');
          checkHud(await state());
        }
      } else {
        await page.keyboard.down('w');await page.waitForTimeout(3500);await page.keyboard.up('w');
        assert((await state()).speed>3,'Desktop driving failed');
        await page.keyboard.press('p');await page.waitForTimeout(700);checkPanel(await state());
        await page.keyboard.press('Escape');
      }
      assert.deepEqual(errors,[], 'Browser errors');
      const result={name,viewport:config.viewport,dpr:config.deviceScaleFactor,loadMs,cameraResult,errors};
      summary.push(result);console.log(JSON.stringify(result));
      await context.close();
    }
  } finally {
    if(browser)await browser.close();server.kill();
    fs.writeFileSync(path.join(artifacts,'summary.json'),JSON.stringify(summary,null,2));
  }
}
main().catch(e=>{console.error(e);process.exitCode=1;});
