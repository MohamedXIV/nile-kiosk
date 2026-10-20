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
  for (const outcome of (process.argv[3] ? [process.argv[3]] : ['good','rough','abandoned'])) {
    const context = await browser.newContext({viewport:{width:1100,height:760}});
    const page = await context.newPage();
    const traces = new Map();
    const errors = [];
    let last;
    page.on('console',msg=>{
      const text=msg.text();
      const match=/^((?:E6_GAME|E4_MEMORY|E4_NPC)_[A-Z_]+) (\{.*\})$/.exec(text);
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
    console.log('starting '+outcome);
    await page.goto(base+'/game/index.html',{waitUntil:'load',timeout:30000});
    await page.locator('canvas').first().click({position:{x:500,y:290}});
    let s=await until('E6_GAME_READY');
    check(!s.supplier_known && !s.memory_near,'fresh world has invented history/contact',s);
    await action('e','E6_GAME_DOOR');await goX(197);
    check((await action('e','E6_GAME_DOOR')).location==='street','landing portal',last);
    await goX(197);check((await action('e','E6_GAME_DOOR')).location==='kiosk','street portal',last);
    await goX(117);await action('o','E6_GAME_OPEN');
    s=await waitTo(1039);
    check(s.offer_count===1 && !s.memory_near && !s.supplier_known,'first visit treated as memory',s);
    const unavailable=await action('F3','E6_GAME_SUPPLY_BUY');
    check(unavailable.money===s.money && unavailable.leaves_stock===s.leaves_stock && !Object.keys(unavailable.supply_resolutions).length,'unheard supplier gave stock/cash',unavailable);
    if(outcome==='abandoned') await waitTo(1157);
    else {
      await action('g','E6_GAME_SERVE');await action('g','E6_GAME_SERVE');
      await action('h','E6_GAME_TEA_HEAT');
      if(outcome==='rough') await waitTo(last.minute+20);else await readyTea();
      await action('h','E6_GAME_TEA_HEAT');await action('u','E6_GAME_TEA_POUR');
      await readyTea();s=await action('u','E6_GAME_TEA_POUR');
      check(s.tea_quality===outcome,'real cup quality not expected history',s);
      const npcInitiatedBefore=count('E4_NPC_INITIATED');
      await action('g','E6_GAME_SERVE');
      if(outcome==='good') {
        const initiated=await until('E4_NPC_INITIATED',npcInitiatedBefore);
        check(initiated.mahmoud_story_phase==='choice' &&
          initiated.mahmoud_story_choices?.length===2,
          'actual post-delivery Mahmoud did not initiate authored Ink',initiated);
      }
      // Unsolicited NPC talk cannot steal G/Serve or prevent payment,
      // even when the player has not responded to the P6 choices.
      await action('g','E6_GAME_SERVE');
      s=await action('g','E6_GAME_SERVE');
      check(s.order_payment==='settled',
        'NPC-initiated Ink must remain non-modal through real P5 payment',s);
    }
    console.log(outcome+' earlier service complete at '+last.minute);
    s=await waitTo(2479);
    console.log(outcome+' returned at '+s.minute);
    await goX(s.npc_mahmoud_x,s.npc_mahmoud_y);s=await snapshot();
    check(s.customer_memory.branch===outcome && s.memory_near && s.active_order===s.customer_memory.return_order_id && s.order_status==='offered' && s.customer_memory.order_id!==s.customer_memory.return_order_id,'later visit did not recover earlier real history',s);
    const priorOrder=s.customer_memory.order_id;
    const start=count('E4_MEMORY_STARTED');await page.keyboard.press('F2');await until('E4_MEMORY_STARTED',start);
    s=await action('Enter','E4_MEMORY_LINE');
    check(s.dialogue_text.includes('last time') && s.customer_memory.branch===outcome,'authored recognition absent',s);
    if(outcome==='rough')check(s.dialogue_text.includes('rough'),'rough tea got positive memory line',s);
    if(outcome==='good')check(s.dialogue_text.includes('timing right'),'good tea not recognized',s);
    if(outcome==='abandoned')check(s.dialogue_text.includes('had to leave'),'missed order not recognized',s);
    if(outcome==='good') {
      await persisted(await snapshot());
      const rn=count('E6_GAME_RESTORED');await page.reload({waitUntil:'load'});s=await until('E6_GAME_RESTORED',rn);
      check(s.memory_story_phase==='running','line-to-choice boundary was not saved',s);
      const resume=count('E4_MEMORY_RESUMED');await page.keyboard.press('F2');s=await until('E4_MEMORY_RESUMED',resume);
    }
    s=await action('Enter','E4_MEMORY_WAITING');
    check(s.memory_story_phase==='choice' && s.memory_story_choices.length===2 && !s.supplier_known,'choice/knowledge incorrect',s);
    await persisted(await snapshot());
    const restore=count('E6_GAME_RESTORED');await page.reload({waitUntil:'load'});s=await until('E6_GAME_RESTORED',restore);
    check(s.memory_story_phase==='choice' && s.customer_memory.order_id===priorOrder && !s.supplier_known,'pending conversation changed on hard reload',s);
    const resume=count('E4_MEMORY_RESUMED');await page.keyboard.press('F2');s=await until('E4_MEMORY_RESUMED',resume);
    const choice=outcome==='abandoned'?'leave':'supplier';
    const optionIndex=s.memory_story_choices.findIndex(o=>o.option_id===choice);
    check(optionIndex>=0,'restored authored option missing',s);
    s=await action(String(optionIndex+1),'E4_MEMORY_CHOICE');
    check(!s.supplier_known,'choosing alone granted unheard supplier info',s);
    s=await action('Enter','E4_MEMORY_LINE');
    check(s.supplier_known===(choice==='supplier'),'heard/unheard contact was wrong',s);
    await page.screenshot({path:`/tmp/nile-memory-${outcome}.png`});
    await action('Enter','E4_MEMORY_LINE');await action('Enter','E4_MEMORY_FINISHED');
    const before=await snapshot();
    if(outcome==='good') {
      s=await action('F3','E6_GAME_SUPPLY_BUY');
      const receipt=s.supply_resolutions['hoda:tea-introduction'];
      check(s.money===before.money-550 && s.leaves_stock===before.leaves_stock+30 && receipt?.status==='purchased' && receipt.completed_minute===receipt.world_minute+15 && receipt.knowledge_event_id.startsWith('evt:'),'paid delivery not canonical',s);
      check(s.minute>=before.minute+15 && s.minute<=before.minute+16,'delivery did not consume real world time',s);
      await persisted(await snapshot());
      const rn=count('E6_GAME_RESTORED');await page.reload({waitUntil:'load'});s=await until('E6_GAME_RESTORED',rn);
      check(s.money===before.money-550 && s.leaves_stock===before.leaves_stock+30 && s.supply_resolutions['hoda:tea-introduction'].status==='purchased','paid delivery lost/duplicated on reload',s);
      const duplicate=await action('F3','E6_GAME_SUPPLY_BUY');
      check(duplicate.money===s.money && duplicate.leaves_stock===s.leaves_stock,'duplicate delivery changed resources',duplicate);
    } else if(outcome==='rough') {
      s=await action('F4','E6_GAME_SUPPLY_DECLINE');
      check(s.money===before.money && s.leaves_stock===before.leaves_stock && s.supply_resolutions['hoda:tea-introduction']?.status==='declined','decline changed resources',s);
      const duplicate=await action('F3','E6_GAME_SUPPLY_BUY');
      check(duplicate.money===before.money && duplicate.leaves_stock===before.leaves_stock,'declined offer still paid/granted goods',duplicate);
      await persisted(await snapshot());const rn=count('E6_GAME_RESTORED');await page.reload({waitUntil:'load'});s=await until('E6_GAME_RESTORED',rn);
      check(s.supply_resolutions['hoda:tea-introduction']?.status==='declined','decline lost on hard reload',s);
    } else {
      s=await action('F3','E6_GAME_SUPPLY_BUY');
      check(!s.supplier_known && s.money===before.money && s.leaves_stock===before.leaves_stock && !Object.keys(s.supply_resolutions).length,'leaving conversation created phantom referral',s);
    }
    check(errors.length===0,'browser errors',errors);
    console.log(`SOCIAL_MEMORY_REFERRAL_CHROMIUM_${outcome.toUpperCase()}_PASS`);
    await context.close();
  }
  console.log('SOCIAL_MEMORY_REFERRAL_CHROMIUM_PASS');
} finally { await browser.close(); }
