const {chromium}=require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {spawn}=require('node:child_process');
const root=path.resolve(__dirname,'..');
const artifacts=path.join(__dirname,'artifacts','mobile-panels');
fs.mkdirSync(artifacts,{recursive:true});
async function main() {
  const server=spawn(process.execPath,['serve-web.cjs'],{cwd:root,env:{...process.env,PORT:'8094'},windowsHide:true});
  let browser;
  const results=[];
  try {
    await new Promise((resolve,reject)=>{server.stdout.once('data',resolve);server.once('error',reject);});
    browser=await chromium.launch({headless:true,executablePath:process.env.E2E_BROWSER_EXE || undefined,args:['--enable-webgl']});
    const context=await browser.newContext({viewport:{width:390,height:700},deviceScaleFactor:1,isMobile:true,hasTouch:true});
    const page=await context.newPage();
    const cdp=await context.newCDPSession(page);
    const errors=[];
    page.on('pageerror',e=>errors.push(e.message));
    page.on('console',m=>{if(m.type()==='error') errors.push(m.text());});
    const state=()=>page.evaluate(()=>window.bukhankaTestState);
    async function tap(text,disabled=false) {
      const s=await state(),v=page.viewportSize();
      const b=s.buttons.find(b=>b.text.includes(text)&&(disabled||!b.disabled)&&b.x>=0&&b.y>=0&&b.x+b.width<=v.width+1&&b.y+b.height<=v.height+1);
      if(!b) {fs.writeFileSync(path.join(artifacts,'failure.json'),JSON.stringify(s,null,2));await page.screenshot({path:path.join(artifacts,'failure.png')});}
      assert(b,'Reachable action missing: '+text);
      await page.touchscreen.tap(b.x+b.width/2,b.y+b.height/2);
      await page.waitForTimeout(550);
    }
    async function swipe(x,y,dy) {
      await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:1,x,y}]});
      for(let i=1;i<=10;i++) {
        await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{id:1,x,y:y+dy*i/10}]});
        await page.waitForTimeout(25);
      }
      await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
      await page.waitForTimeout(450);
    }
    const shot=name=>page.screenshot({path:path.join(artifacts,name+'.png')});
    function fits(s) {
      const v=page.viewportSize(),b=s.panel_bounds;
      assert(b.x>=0&&b.y>=0&&b.x+b.width<=v.width+1&&b.y+b.height<=v.height+1,'Panel overflow '+JSON.stringify(b));
      assert.equal(s.scroll.horizontal,0,'Horizontal scrolling should never be needed');
    }
    await page.goto('http://127.0.0.1:8094/?e2e=panels');
    await page.waitForFunction(()=>window.bukhankaTestState?.buttons?.length,{timeout:120000});
    console.log('Renderer: '+await page.evaluate(()=>{const gl=document.querySelector('canvas').getContext('webgl2'),ext=gl.getExtension('WEBGL_debug_renderer_info');return ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):gl.getParameter(gl.RENDERER);}));
    await tap('ЗАВЕСТИ');
    await shot('editor');
    fits(await state());
    assert((await state()).scroll.max<=1,'Default editor needs scrolling');
    await tap('Внешность');
    await shot('editor-customize');
    await tap('Отправиться');
    if((await state()).buttons.some(b=>b.text.includes('Пропустить'))) await tap('Пропустить');
    for(const [name,width,height] of [['portrait',390,700],['small',320,568],['landscape',844,300]]) {
      await page.setViewportSize({width,height});
      await page.waitForTimeout(800);
      const menu=(await state()).controls.MobileMenu;
      await page.touchscreen.tap(menu.x+menu.width/2,menu.y+menu.height/2);
      await page.waitForTimeout(550);
      for(const tab of ['Команда','Машина','Проекты','Дневник','Опции','Лагерь']) {
        await tap(tab);
        const s=await state();fits(s);
        if(name!=='landscape'&&['Команда','Машина','Проекты','Опции','Лагерь'].includes(tab)) assert(s.scroll.max<=1,tab+' requires scrolling: '+s.scroll.max);
        if(tab==='Машина') assert(s.buttons.some(b=>b.name==='BuyUpgrade'&&b.y+b.height<height),'Upgrade action is clipped');
        await shot(name+'-'+tab);
        results.push({name,tab,scroll:s.scroll.max});
        if(name==='portrait'&&tab==='Машина') {
          await tap('Вездеход');
          await page.waitForFunction(()=>window.bukhankaTestState?.popups?.length);
          const popup=(await state()).popups[0];
          assert(popup.height/popup.items>=44,'Dropdown options are too small to touch: '+JSON.stringify(popup));
          await shot('upgrade-dropdown');
          await page.touchscreen.tap(popup.x+popup.width/2,popup.y+popup.height*.9);
          await page.waitForTimeout(650);
          let modules=await state();
          assert(modules.buttons.some(b=>b.text.includes('Улучшить')),'Module selection failed');
          const beforeModules=modules.modules;
          const b=modules.buttons.find(b=>b.text.includes('Улучшить')&&!b.disabled);
          await swipe(b.x+b.width/2,b.y+b.height/2,-75);
          assert((await state()).scroll.offset>40,'Swipe starting on a purchase button fails');
          assert.deepEqual((await state()).modules,beforeModules,'Swipe accidentally purchases an upgrade');
          // Restore the first category for the subsequent viewport checks.
          await tap('Модули лагеря');
          await page.waitForFunction(()=>window.bukhankaTestState?.popups?.length);
          const menu=(await state()).popups[0];
          await page.touchscreen.tap(menu.x+menu.width/2,menu.y+menu.height*.1);
          await page.waitForTimeout(550);
        }
      }
      await tap('Выбрать место');
      let s=await state();fits(s);
      assert.equal(s.scroll.max,0,'Placement must not scroll');
      assert(s.camp_map.width>=200&&s.camp_map.height>=80,'Map is too small');
      for(const label of ['Поставить лагерь','Повернуть','Найти место']) {
        assert(s.buttons.some(b=>b.text===label&&b.y+b.height<=height),'Placement action clipped: '+label);
      }
      await shot(name+'-placement');
      const before=s.candidate;
      await swipe(s.camp_map.x+s.camp_map.width/2,s.camp_map.y+s.camp_map.height/2,-25);
      s=await state();assert.notDeepEqual(s.candidate,before,'Finger does not move the campsite');assert.equal(s.scroll.offset,0);
      const angle=s.camp_angle;
      await tap('Повернуть');assert(Math.abs((await state()).camp_angle-angle-Math.PI/2)<.01,'Rotation failed');
      await tap('Найти место');
      await tap('Поставить лагерь');
      await page.waitForFunction(()=>window.bukhankaTestState?.camping,null,{timeout:5000}).catch(async error=>{await shot(name+'-place-failure');fs.writeFileSync(path.join(artifacts,'place-failure.json'),JSON.stringify(await state(),null,2));throw error;});
      assert((await state()).camping,'Campsite cannot be placed');
      assert(!(await state()).ghost,'Placement grid remains after placing camp');
      const camp=(await state()).controls.MobileMenu;
      await page.touchscreen.tap(camp.x+camp.width/2,camp.y+camp.height/2);
      await page.waitForTimeout(550);
      await tap('Свернуть лагерь');
      await page.waitForFunction(()=>!window.bukhankaTestState?.camping,null,{timeout:5000});
      // Overflowing settings: start the swipe on an active button. Its tap must
      // be cancelled, so the details remain expanded while the list scrolls.
      if(name==='landscape') {
        const options=(await state()).controls.MobileSettings;
        await page.touchscreen.tap(options.x+options.width/2,options.y+options.height/2);
        await page.waitForTimeout(550);
        s=await state();
        await swipe(s.scroll.bounds.x+s.scroll.bounds.width/2,s.scroll.bounds.y+s.scroll.bounds.height-8,-80);
        await tap('Звук и путешествие');
        s=await state();
        const scroll=s.scroll.bounds;
        const toggle=s.buttons.find(b=>b.text.includes('Звук и путешествие'));
        assert(s.scroll.max>100,'No overflowing list to test');
        // Scroll down by swiping on the quality/toggle area, then swipe on a
        // real action button further down and ensure it does not fire.
        await swipe(scroll.x+scroll.width/2,scroll.y+scroll.height-8,-70);
        assert((await state()).scroll.offset>30,'Swipe over active controls does not scroll');
        s=await state();
        const action=s.buttons.find(b=>b.text.includes('Переключить общий')&&b.y>=scroll.y&&b.y+b.height<=scroll.y+scroll.height);
        if(action) await swipe(action.x+action.width/2,action.y+action.height/2,-35);
        assert((await state()).buttons.some(b=>b.text.includes('Проверить обновление')),'Swipe accidentally collapsed settings');
        for(let i=0;i<8;i++) {
          s=await state();
          const slider=s.sliders.VoiceVolume;
          if(slider&&slider.y>=scroll.y&&slider.y+slider.height<=scroll.y+scroll.height) {
            const volume=s.voice_volume;
            await swipe(slider.x+slider.width*.25,slider.y+slider.height/2,-40);
            assert(Math.abs((await state()).voice_volume-volume)<.001,'Vertical slider swipe changes volume');
            break;
          }
          await swipe(scroll.x+scroll.width/2,scroll.y+scroll.height-8,-50);
          assert(i<7,'Cannot reach the volume slider');
        }
        await shot('landscape-settings-scroll');
        await tap('×');
      }
    }
    assert.deepEqual(errors,[],'Browser errors');
    fs.writeFileSync(path.join(artifacts,'summary.json'),JSON.stringify({results,errors},null,2));
    console.log(JSON.stringify({results,errors}));
  } finally {if(browser)await browser.close();server.kill();}
}
main().catch(e=>{console.error(e);process.exitCode=1;});
