import { chromium } from 'playwright-core';

// Only normal controls in the default production scene. Earlier service and
// later visits happen in this browser: no seeded world, injected commands or
// test-only game entry. Native tests additionally cover private audiences,
// overflow/insufficient funds, schema migration and adversarial replay.
const browser = await chromium.launch({
  executablePath: process.env.CHROME_BINARY || '/usr/bin/google-chrome',
  headless: true,
  args: ['--no-sandbox','--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']
});
const base = process.argv[2] || 'http://127.0.0.1:8765';
function check(ok, message, state) { if (!ok) throw new Error(message+' '+JSON.stringify(state)); }
try {
  for (const outcome of (process.argv[3] ? [process.argv[3]] : ['public','decline','expired','delivery','collection'])) {
    const context = await browser.newContext({viewport:{width:1100,height:760}});
    const page = await context.newPage();
    const traces = new Map();
    const errors = [];
    let last;
    page.on('console',msg=>{
      const text=msg.text();
      const match=/^((?:E6_GAME|E4_MEMORY)_[A-Z_]+) (\{.*\})$/.exec(text);
      if (match) {
        try { last=JSON.parse(match[2]); const a=traces.get(match[1])||[]; a.push(last); traces.set(match[1],a); }
        catch(e) {errors.push(String(e));}
      }
      if (/SCRIPT ERROR:|Parse Error:|E6_GAME_BOOT_FAILED/.test(text)) errors.push(text);
    });
    page.on('pageerror',e=>errors.push(e.message));
    const count=marker=>(traces.get(marker)||[]).length;
    async function until(marker,index=0) {
      for(let i=0;i<300;i++) {
        if(count(marker)>index) return traces.get(marker)[index];
        if(errors.length) throw new Error(errors.join('\n'));
        await page.waitForTimeout(40);
      }
      throw new Error(`Missing ${marker} #${index}; last=${JSON.stringify(last)} errors=${errors}`);
    }
    async function action(key,marker) {const n=count(marker); await page.keyboard.press(key); return until(marker,n);}
    const snapshot=()=>action('p','E6_GAME_SAVE');
    async function persisted(saved) {
      let observed=null;
      for(let i=0;i<70;i++) {
        observed=await page.evaluate(async()=>{
          for(const info of await indexedDB.databases()) {
            const db=await new Promise((resolve,reject)=>{const q=indexedDB.open(info.name);q.onsuccess=()=>resolve(q.result);q.onerror=()=>reject(q.error);});
            try {
              if(!db.objectStoreNames.contains('FILE_DATA'))continue;
              const entries=await new Promise((resolve,reject)=>{
                const values=[];const q=db.transaction('FILE_DATA','readonly').objectStore('FILE_DATA').openCursor();
                q.onsuccess=()=>{const c=q.result;if(!c){resolve(values);return;}values.push({key:c.key,value:c.value});c.continue();};q.onerror=()=>reject(q.error);
              });
              for(const entry of entries)if(String(entry.key).endsWith('/nile-kiosk-game-v1.json')) {
                try {return JSON.parse(new TextDecoder().decode(entry.value.contents));}catch {}
              }
            }finally{db.close();}
          }
          return null;
        });
        if(observed?.sequence===saved.revision)return;
        await page.waitForTimeout(150);
      }
      throw new Error('Godot save was not persisted to IndexedDB; expected revision '+saved.revision+' observed '+observed?.sequence);
    }

    async function pulse(keys,ms=135) {
      for(const key of keys)await page.keyboard.down(key);
      await page.waitForTimeout(ms);
      for(const key of [...keys].reverse())await page.keyboard.up(key);
    }
    async function goX(target,targetY=70) {
      let s=await snapshot();
      for(let i=0;i<45 && (Math.abs(s.x-target)>13 || Math.abs(s.y-targetY)>13);i++) {
        const keys=Math.abs(s.y-targetY)>13 ? (s.y<targetY?['s','a']:['w','d']) : (s.x<target?['s','d']:['w','a']);
        await pulse(keys);s=await snapshot();
      }
      check(Math.abs(s.x-target)<=18 && Math.abs(s.y-targetY)<=18,'could not walk to target',s);return s;
    }
    async function waitTo(minute) {
      let s=last;
      for(let i=0;i<350 && s.minute<minute;i++){s=await action('j','E6_GAME_WAIT');if(i%70===69)console.log(outcome+' waiting: '+s.minute);}
      check(s.minute>=minute,'canonical wait stalled',s);return s;
    }
    async function readyTea() {
      for(let i=0;i<45;i++) {
        const s=await snapshot();if(s.tea_ready_in===0)return s;
        await page.waitForTimeout(200);
      }
      throw new Error('physical tea stage did not become ready');
    }
    console.log('procurement '+outcome);
    await page.goto(base+'/game/index.html',{waitUntil:'load',timeout:30000});
    await page.locator('canvas').first().click({position:{x:500,y:290}});
    let s=await until('E6_GAME_READY');
    await action('e','E6_GAME_DOOR');await goX(197);
    check((await action('e','E6_GAME_DOOR')).location==='street','landing portal',last);
    await goX(197);check((await action('e','E6_GAME_DOOR')).location==='kiosk','street portal',last);
    await goX(117);await action('o','E6_GAME_OPEN');
    if(outcome==='delivery'||outcome==='collection') {
      await waitTo(1039);
      await action('g','E6_GAME_SERVE');await action('g','E6_GAME_SERVE');await action('h','E6_GAME_TEA_HEAT');await readyTea();
      await action('h','E6_GAME_TEA_HEAT');await action('u','E6_GAME_TEA_POUR');await readyTea();await action('u','E6_GAME_TEA_POUR');
      await action('g','E6_GAME_SERVE');await action('g','E6_GAME_SERVE');await action('g','E6_GAME_SERVE');
      s=await waitTo(2479);await goX(s.npc_mahmoud_x,s.npc_mahmoud_y);
      const started=count('E4_MEMORY_STARTED');await page.keyboard.press('F2');await until('E4_MEMORY_STARTED',started);
      await action('Enter','E4_MEMORY_LINE');s=await action('Enter','E4_MEMORY_WAITING');
      const i=s.memory_story_choices.findIndex(o=>o.option_id==='supplier');check(i>=0,'real supplier question absent',s);
      s=await action(String(i+1),'E4_MEMORY_CHOICE');check(!s.supplier_known,'unheard referral granted',s);
      s=await action('Enter','E4_MEMORY_LINE');check(s.supplier_known,'actual earned answer missing',s);
      await action('Enter','E4_MEMORY_LINE');await action('Enter','E4_MEMORY_FINISHED');
      check(s.market_offer.status==='available','equivalent alternative unavailable at real return',s);
      await waitTo(2510);
    } else check(!s.supplier_known,'public path got invented contact',s);
    if(outcome==='expired') await waitTo(1140);
    const before=await snapshot();
    if(outcome==='decline') {
      s=await action('F6','E6_GAME_MARKET_DECLINE');
      check(s.money===before.money && s.leaves_stock===before.leaves_stock && s.supply_resolutions['market:tea-collection']?.status==='declined','decline changed goods/cash',s);
    } else if(outcome==='expired') {
      s=await action('F5','E6_GAME_MARKET_BUY');
      check(s.money===before.money && s.leaves_stock===before.leaves_stock && !s.supply_resolutions['market:tea-collection'] && s.market_offer.status==='OFFER_EXPIRED','expired market created stock',s);
      s=await action('F6','E6_GAME_MARKET_DECLINE');check(s.money===before.money && s.leaves_stock===before.leaves_stock && s.supply_resolutions['market:tea-collection']?.status==='declined','after-hours refusal unavailable',s);
    } else {
      const delivery=outcome==='delivery';const cost=delivery?550:450;const minutes=delivery?15:40;
      s=await action(delivery?'F3':'F5',delivery?'E6_GAME_SUPPLY_BUY':'E6_GAME_MARKET_BUY');
      const receipt=s.supply_resolutions[delivery?'hoda:tea-introduction':'market:tea-collection'];
      check(s.money===before.money-cost && s.leaves_stock===before.leaves_stock+30 && receipt?.status==='purchased' && receipt.completed_minute===receipt.world_minute+minutes,'audited cost/time/goods mismatch',s);
      check(s.minute>=before.minute+minutes && s.minute<=before.minute+minutes+1,'world clock not advanced',s);
      check(delivery?receipt.knowledge_event_id.startsWith('evt:'):receipt.knowledge_event_id==='','knowledge provenance incorrect',s);
      if(outcome==='delivery'||outcome==='collection')check(delivery?s.npc_mona==='kiosk':s.npc_mona!=='kiosk','trip duration did not affect real independent social visit',s);
      if(outcome==='public')check(!s.supplier_known && s.offer_count>0,'public access or unattended schedule wrong',s);
      const totals={money:s.money,leaves:s.leaves_stock};
      const again=await action(delivery?'F3':'F5',delivery?'E6_GAME_SUPPLY_BUY':'E6_GAME_MARKET_BUY');
      check(again.money===totals.money && again.leaves_stock===totals.leaves,'duplicate purchase created inventory',again);
    }
    const expected=await snapshot();await persisted(expected);const rn=count('E6_GAME_RESTORED');await page.reload({waitUntil:'load'});s=await until('E6_GAME_RESTORED',rn);
    check(s.money===expected.money && s.leaves_stock===expected.leaves_stock && JSON.stringify(s.supply_resolutions)===JSON.stringify(expected.supply_resolutions),'hard reload changed procurement outcome',s);
    check(errors.length===0,'browser errors',errors);
    await page.screenshot({path:'/tmp/nile-procurement-'+outcome+'.png'});
    console.log('E5_PROCUREMENT_CHROMIUM_PASS '+outcome);
    await context.close();
  }
} finally {await browser.close();}
