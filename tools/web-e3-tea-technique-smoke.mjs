import { chromium } from 'playwright-core';

// Real default Godot game controls only. No test-only state injection.
const browser = await chromium.launch({
  executablePath: process.env.CHROME_BINARY || '/usr/bin/google-chrome',
  headless: true,
  args: ['--no-sandbox','--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']
});
const base=process.argv[2] || 'http://127.0.0.1:8765';
const context=await browser.newContext({viewport:{width:1100,height:760}});
const page=await context.newPage();
const traces=new Map(), errors=[];
let last;
page.on('console',m=>{
  const line=m.text();
  const match=/^((?:E6_GAME|E4_STORY)_[A-Z_]+) (\{.*\})$/.exec(line);
  if(match){try{
    last=JSON.parse(match[2]);
    const list=traces.get(match[1])||[];list.push(last);traces.set(match[1],list);
  }catch(e){errors.push(String(e));}}
  if(/SCRIPT ERROR:|Parse Error:|E6_GAME_BOOT_FAILED/.test(line))errors.push(line);
});
page.on('pageerror',e=>errors.push(e.message));
function check(ok,why,state=last){if(!ok)throw Error(why+' '+JSON.stringify({state,errors}));}
const count=marker=>(traces.get(marker)||[]).length;
async function until(marker,index=0){
  for(let i=0;i<300;i++){
    if(count(marker)>index)return traces.get(marker)[index];
    if(errors.length)throw Error(errors.join('\n'));
    await page.waitForTimeout(45);
  }
  throw Error('missing '+marker+' '+index+' '+JSON.stringify({last,errors}));
}
async function action(key,marker){
  const n=count(marker);await page.keyboard.press(key);return until(marker,n);
}
const snapshot=()=>action('p','E6_GAME_SAVE');
async function pulse(keys,ms=135){
  for(const k of keys)await page.keyboard.down(k);
  await page.waitForTimeout(ms);
  for(const k of [...keys].reverse())await page.keyboard.up(k);
}
async function go(targetX,targetY=70){
  let s=await snapshot();
  for(let i=0;i<50&&(Math.abs(s.x-targetX)>13||Math.abs(s.y-targetY)>13);i++){
    const keys=Math.abs(s.y-targetY)>13
      ? (s.y<targetY?['s','a']:['w','d'])
      : (s.x<targetX?['s','d']:['w','a']);
    await pulse(keys);s=await snapshot();
  }
  check(Math.abs(s.x-targetX)<=18&&Math.abs(s.y-targetY)<=18,'could not reach destination',s);
  return s;
}
async function readyTea(){
  for(let i=0;i<50;i++){
    const s=await snapshot();
    if(s.tea_ready_in===0)return s;
    await page.waitForTimeout(145);
  }
  throw Error('real P3 stage never finished');
}
async function waitTo(minute){
  let s=last;
  for(let i=0;i<100&&s.minute<minute;i++)s=await action('j','E6_GAME_WAIT');
  check(s.minute>=minute,'stalled world clock',s);
  return s;
}
try{
  await page.goto(base+'/game/index.html',{waitUntil:'load',timeout:30000});
  await page.locator('canvas').first().click({position:{x:500,y:290}});
  let s=await until('E6_GAME_READY');
  check(!s.tea_technique_known&&s.tea_technique?.phase==='unheard','free tip at game boot',s);
  await action('e','E6_GAME_DOOR');await go(197);
  check((await action('e','E6_GAME_DOOR')).location==='street','landing entry');
  await go(197);check((await action('e','E6_GAME_DOOR')).location==='kiosk','kiosk entry');
  await go(160,88);await action('o','E6_GAME_OPEN');
  s=await action('q','E6_GAME_QUIET');
  check(s.story_opportunities?.river_watch_reflection&&!s.tea_technique_known,'river did not unlock Salma or invented knowledge',s);
  await go(125,88);
  const started=count('E4_STORY_STARTED');
  await page.keyboard.press('n');
  s=await until('E4_STORY_STARTED',started);
  s=await action('Enter','E4_STORY_LINE');
  s=await action('Enter','E4_STORY_WAITING');
  check(!s.tea_technique_known&&s.river_story_choices.some(x=>x.option_id==='rest'),'authored player choice missing');
  const idx=s.river_story_choices.findIndex(x=>x.option_id==='rest');
  s=await action(String(idx+1),'E4_STORY_CHOICE');
  check(!s.tea_technique_known,'choice alone leaked P2 fact',s);
  s=await action('Enter','E4_STORY_LINE');
  check(s.tea_technique_known&&s.tea_technique?.phase==='heard','real Ink beat did not grant P2 tip',s);
  s=await action('Enter','E4_STORY_LINE');
  s=await action('Enter','E4_STORY_FINISHED');
  await go(116,80);
  await waitTo(1040);
  s=await action('g','E6_GAME_SERVE');
  check(s.order_status==='accepted','did not accept real customer');
  s=await action('g','E6_GAME_SERVE');
  check(s.tea_action==='H','P3 order did not start physical tea');
  s=await action('h','E6_GAME_TEA_HEAT');await readyTea();
  s=await action('h','E6_GAME_TEA_HEAT');
  s=await action('u','E6_GAME_TEA_POUR');await readyTea();
  s=await action('u','E6_GAME_TEA_POUR');
  check(s.tea_stage===''&&s.tea_technique?.attempt_event_id.startsWith('evt:'),'real P3 practice not recorded');
  check(s.tea_technique?.item_id.startsWith('item:')&&s.tea_technique.grade===s.tea_quality,
    'verified physical item and technique grade diverged',s);
  // The player can learn a useful principle, not purchase an automatic quality buff.
  check(['attempted','understood'].includes(s.tea_technique.phase),'practice was lost',s);
  const before=await snapshot();
  await page.waitForTimeout(1700);
  const idxReload=count('E6_GAME_RESTORED');
  await page.reload({waitUntil:'load'});
  s=await until('E6_GAME_RESTORED',idxReload);
  check(s.tea_technique_known&&s.tea_technique.item_id===before.tea_technique.item_id
    &&s.tea_technique.grade===before.tea_technique.grade
    &&s.digest===before.digest,'hard Chromium reload lost honest learning or world replay',s);
  check(!errors.length,'browser errors',errors);
  console.log('E3_TEA_TECHNIQUE_CHROMIUM_PASS real Salma Ink fact, physical P3 practice and hard reload');
}finally{await context.close();await browser.close();}
