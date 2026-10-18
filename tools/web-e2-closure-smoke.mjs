import { chromium } from 'playwright-core';
import { waitForGodotSave } from './browser-save-observer.mjs';
// Default scene, ordinary keyboard controls, read-only persistence observation.
const browser = await chromium.launch({executablePath:process.env.CHROME_BINARY || '/usr/bin/chromium',headless:true,args:['--no-sandbox','--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const proofs=[];
function check(value,label){if(!value)throw new Error(label);}
try {
  for(const placed of [false,true]) {
    const context=await browser.newContext({viewport:{width:1100,height:760}});
    const page=await context.newPage();const traces={};const errors=[];
    page.on('console',message=>{const line=message.text();const m=/^(E6_GAME_[A-Z_]+) (\{.*\})$/.exec(line);if(m)(traces[m[1]]??=[]).push(JSON.parse(m[2]));if(/SCRIPT ERROR:|Parse Error:|BOOT_FAILED/.test(line))errors.push(line);});
    page.on('pageerror',e=>errors.push(e.message));
    async function until(marker,index=0){for(let i=0;i<1200;i++){if(traces[marker]?.length>index)return traces[marker][index];if(errors.length)throw new Error(errors.join('\n'));await page.waitForTimeout(10);}throw new Error('Missing '+marker+' '+index);}
    async function act(key,marker){const n=traces[marker]?.length||0;await page.keyboard.press(key);return until(marker,n);}
    await page.goto((process.argv[2]||'http://127.0.0.1:8877')+'/game/index.html');
    await page.locator('canvas').first().click({position:{x:500,y:290}});
    const initial=await until('E6_GAME_READY');
    check(initial.location==='roof'&&initial.money===6000,'fresh default world required');
    const bought=await act('t','E6_GAME_BED');const bed=await act('t','E6_GAME_BED');
    check(bought.money===initial.money-3400&&bed.bed_placed,'real P5 paid bed');
    check(bought.mood===initial.mood&&bed.mood===initial.mood,'buying/placing must not grant happiness');
    if(!placed)await act('y','E6_GAME_BED_STORE');
    const healthy=await act('q','E6_GAME_QUIET');
    check(healthy.mood-initial.mood===4,'healthy rooftop quiet benefit');
    let tired=healthy;
    while(tired.minute<3900)tired=await act('j','E6_GAME_WAIT');
    check(tired.hunger===0&&tired.rest<25,'genuine neglected days');
    const quiet=await act('q','E6_GAME_QUIET');
    check(quiet.mood-tired.mood<=1,'same quiet responds to physical context');
    const morning=await act('z','E6_GAME_SLEEP');
    check(morning.rest>quiet.rest,'actual sleep recovers rest');
    const saved=await act('p','E6_GAME_SAVE');
    await waitForGodotSave(page,'nile-kiosk-game-v1.json',data=>data.sequence===saved.revision);
    await page.reload();const restored=await until('E6_GAME_RESTORED');
    check(restored.digest===saved.digest&&['hunger','rest','mood','bed_placed','minute'].every(k=>restored[k]===saved[k]),'genuine Web disk/replay mismatch');
    check(errors.length===0,'browser runtime errors');
    proofs.push({placed,healthy,tired,quiet,morning,restored});
    await context.close();
  }
  const [bare,bed]=proofs;
  check(bare.morning.minute===bed.morning.minute,'same canonical wake time');
  check(bed.morning.rest===bare.morning.rest+12,'placed versus legitimately stored bed sleep');
  console.log('E2_BROWSER_PROOF '+JSON.stringify(proofs));
  console.log('E2_CLOSURE_CHROMIUM_PASS: actual needs contexts, paid placed/stored bed sleep, genuine Web save/replay');
} finally {await browser.close();}
