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
  for (const outcome of (process.argv[3] ? [process.argv[3]] : ['boats','work','ignore'])) {
    const context = await browser.newContext({viewport:{width:1100,height:760}});
    const page = await context.newPage();
    const traces = new Map();
    const errors = [];
    let last;
    page.on('console',msg=>{
      const text=msg.text();
      const match=/^((?:E6_GAME|E4_CONVERSATION)_[A-Z_]+) (\{.*\})$/.exec(text);
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
    async function waitTo(minute, precise=false) {
      let s=last;
      for(let i=0;i<350 && s.minute<minute;i++) {
        // Real game time keeps moving (one minute every two seconds), while J
        // advances five. Near a short authored speech window, let the real P1
        // clock reach the beat instead of jumping over it with another J.
        if(precise && s.minute+5>=minute) {
          await page.waitForTimeout(160);
          s=await snapshot();
        } else {
          s=await action('j','E6_GAME_WAIT');
        }
        if(i%70===69)console.log(outcome+' waiting: '+s.minute);
      }
      check(s.minute>=minute,'canonical wait stalled',s);return s;
    }
    async function readyTea() {
      for(let i=0;i<45;i++) {
        const s=await snapshot();if(s.tea_ready_in===0)return s;
        await page.waitForTimeout(200);
      }
      throw new Error('physical tea stage did not become ready');
    }
    console.log('conversation '+outcome);
    await page.goto(base+'/game/index.html',{waitUntil:'load',timeout:30000});
    await page.locator('canvas').first().click({position:{x:500,y:290}});
    let s=await until('E6_GAME_READY');
    await action('e','E6_GAME_DOOR');await goX(197);
    check((await action('e','E6_GAME_DOOR')).location==='street','landing portal',last);
    await goX(197);check((await action('e','E6_GAME_DOOR')).location==='kiosk','street portal',last);
    await goX(117);await action('o','E6_GAME_OPEN');
    // This authored remark lasts only until minute 1044; never use a J
    // five-minute jump when approaching its first boundary.
    s=await waitTo(1039,true);
    check(s.ambient_npc==='salma' && s.ambient_beat===0,'independent opening missing',s);
    await action('g','E6_GAME_SERVE');await action('g','E6_GAME_SERVE');
    await action('h','E6_GAME_TEA_HEAT');
    s=await waitTo(1049,true);
    check(s.ambient_npc==='mahmoud' && s.ambient_beat===1 && s.conversation_near,'actual exchange boundary missing',s);
    s=await action('f','E6_GAME_TALK');check(!s.supplier_known && !s.conversation_fact_known,'generic listen bypassed authored information',s);
    if(outcome!=='ignore') {
      const startedCount=count('E4_CONVERSATION_STARTED');await page.keyboard.press('t');s=await until('E4_CONVERSATION_STARTED',startedCount);
      s=await action('Enter','E4_CONVERSATION_LINE');
      check(s.dialogue_text.includes('river ever rests'),'unrelated Ink scene',s);
      // Heat/lift while the real dialogue is open: cooking remains an actual P3 action.
      s=await action('h','E6_GAME_TEA_HEAT');check(s.tea_action==='U','cooking blocked by conversation',s);
      if(outcome==='boats') {
        await persisted(await snapshot());const n=count('E6_GAME_RESTORED');await page.reload({waitUntil:'load'});s=await until('E6_GAME_RESTORED',n);
        check(s.conversation_phase==='running','line save lost',s);
        const rn=count('E4_CONVERSATION_RESUMED');await page.keyboard.press('t');await until('E4_CONVERSATION_RESUMED',rn);
      }
      s=await action('Enter','E4_CONVERSATION_WAITING');check(s.conversation_choices.length===2,'real Ink choice absent',s);
      await page.screenshot({path:'/tmp/nile-conversation-'+outcome+'-choice.png'});
      await persisted(await snapshot());const n=count('E6_GAME_RESTORED');await page.reload({waitUntil:'load'});s=await until('E6_GAME_RESTORED',n);
      check(s.conversation_phase==='choice' && !s.conversation_fact_known,'pending choice changed knowledge',s);
      const rn=count('E4_CONVERSATION_RESUMED');await page.keyboard.press('t');s=await until('E4_CONVERSATION_RESUMED',rn);
      // Walk away with choice open: normal controls move and caption dismisses.
      await goX(35);s=await snapshot();check(!s.conversation_near && !s.conversation_fact_known,'walk-away privacy failure',s);
      s=await action('t','E4_CONVERSATION_REJECTED');check(!s.conversation_fact_known,'distant join leaked fact',s);
      await goX(117);
      const rr=count('E4_CONVERSATION_RESUMED');await page.keyboard.press('t');s=await until('E4_CONVERSATION_RESUMED',rr);
      const i=s.conversation_choices.findIndex(o=>o.option_id===outcome);check(i>=0,'authored response missing',s);
      s=await action(String(i+1),'E4_CONVERSATION_CHOICE');check(!s.conversation_fact_known,'question granted unheard information',s);
      s=await action('Enter','E4_CONVERSATION_LINE');check(s.conversation_fact_known===(outcome==='boats'),'heard fact mismatch',s);
      s=await action('Enter','E4_CONVERSATION_LINE');check(s.dialogue_text.includes('leave you to the tea'),'response did not reconverge',s);
      await action('Enter','E4_CONVERSATION_FINISHED');
      check(!last.conversation_near,'consumed prompt repeats',last);
    } else {
      s=await action('h','E6_GAME_TEA_HEAT');
      check(!s.conversation_phase && !s.conversation_fact_known,'ignoring manufactured narrative',s);
    }
    await action('u','E6_GAME_TEA_POUR');await readyTea();s=await action('u','E6_GAME_TEA_POUR');
    check(s.tea_quality && s.tea_stage==='','actual tea unfinished',s);
    s=await waitTo(1059);
    if(s.minute<1064)check(s.ambient_beat===2,'NPC conversation never continued',s);
    await waitTo(1065);check(!last.ambient_line,'ignored conversation did not end',last);
    await persisted(await snapshot());const n=count('E6_GAME_RESTORED');await page.reload({waitUntil:'load'});s=await until('E6_GAME_RESTORED',n);
    check(s.conversation_fact_known===(outcome==='boats') && (outcome==='ignore'?s.conversation_phase==='':s.conversation_phase==='finished'),'final persisted outcome',s);
    check(errors.length===0,'browser errors',errors);
    await page.screenshot({path:'/tmp/nile-conversation-'+outcome+'.png'});
    console.log('E4_LIVING_CONVERSATION_CHROMIUM_PASS '+outcome);
    await context.close();
  }
} finally {await browser.close();}
