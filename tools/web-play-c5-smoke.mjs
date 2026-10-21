import { chromium } from "playwright-core";
import { waitForGodotSave } from "./browser-save-observer.mjs";

// Real Godot/Web scene: authored NPC-to-NPC trust, zero base chance, no player action.
const browser=await chromium.launch({executablePath:process.env.CHROME_BINARY||"/usr/bin/google-chrome",
  headless:true,args:["--no-sandbox","--enable-webgl","--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader"]});
const ctx=await browser.newContext({viewport:{width:1100,height:760}});
const page=await ctx.newPage();
const markers=["PLAY_C1_READY","PLAY_C1_RESTORED","PLAY_C1_TIME","PLAY_C1_SAVED","PLAY_C3_BLOCKED"];
const traces=Object.fromEntries(markers.map(x=>[x,[]]));
const errors=[];
page.on("console",m=>{
  const t=m.text();
  for(const k of markers)if(t.startsWith(k+" ")){
    try{traces[k].push(JSON.parse(t.slice(k.length+1)));}
    catch(e){errors.push(String(e));}
  }
  if(/SCRIPT ERROR:|PLAY_C[125]_.*FAILED/.test(t))errors.push(t);
});
page.on("pageerror",e=>errors.push(e.message));
function check(ok,msg){if(!ok)throw Error(msg+" "+JSON.stringify({traces,errors}));}
async function until(k,n=0){
  for(let i=0;i<450;i++){
    if(traces[k].length>n)return traces[k][n];
    if(errors.length)break;
    await page.waitForTimeout(75);
  }
  throw Error("Missing "+k+" #"+n+" "+JSON.stringify(errors));
}
const press=async k=>page.keyboard.press(k);
try{
  await page.goto((process.argv[2]||"http://127.0.0.1:8765")+"/play-c5/index.html",{waitUntil:"load",timeout:30000});
  await page.locator("canvas").first().click({position:{x:480,y:245}});
  const ready=await until("PLAY_C1_READY");
  check(ready.location==="roof"&&ready.money===300&&ready.auto_count===0,"C5 trusted world not ready");
  await press("t");
  const arrived=await until("PLAY_C1_TIME",0);
  check(arrived.minute===5&&arrived.npc_reda==="kiosk"&&arrived.auto_count===0,"NPC scheduled arrival not simulated");
  await press("t");
  const offered=await until("PLAY_C1_TIME",1);
  check(offered.minute===10&&offered.auto_count===1&&offered.auto_status==="offered"&&
    offered.auto_customer==="reda"&&offered.auto_social?.peer_trusted===true&&
    offered.auto_social?.fact_known===false&&offered.auto_social?.chance_bp===10000&&
    offered.location==="roof"&&offered.money===300,
    "Zero base chance did not adapt to genuine NPC trust independently of player");
  await press("g");
  const refused=await until("PLAY_C3_BLOCKED");
  check(refused.revision===offered.revision&&refused.auto_status==="offered",
    "Player remotely acted on offscreen social order");
  await press("p");
  const saved=await until("PLAY_C1_SAVED",0);
  check(saved.digest===offered.digest,"Saving mutated social offer");
  await waitForGodotSave(page,"nk-play-c5-web-qa.json",data=>data.sequence===saved.revision);
  await page.reload({waitUntil:"load",timeout:30000});
  const restored=await until("PLAY_C1_RESTORED",0);
  check(restored.digest===saved.digest&&restored.auto_social?.peer_trusted===true&&
    restored.auto_status==="offered"&&restored.money===300,"Social relationship/replay changed after Web reload");
  for(let i=0;i<4;i++)await press("t");
  const expired=await until("PLAY_C1_TIME",5);
  check(expired.minute===30&&expired.auto_status==="abandoned"&&expired.money===300,
    "Unattended relationship-influenced order never expired");
  await press("p");
  const saved2=await until("PLAY_C1_SAVED",1);
  await waitForGodotSave(page,"nk-play-c5-web-qa.json",data=>data.sequence===saved2.revision);
  await page.reload({waitUntil:"load",timeout:30000});
  const final=await until("PLAY_C1_RESTORED",1);
  check(final.digest===saved2.digest&&final.auto_status==="abandoned"&&
    final.auto_social?.chance_bp===10000&&final.money===300&&final.auto_count===1,
    "Second Web reload changed socially generated order or duplicated economy");
  await press("p");
  const repeated=await until("PLAY_C1_SAVED",2);
  check(repeated.digest===final.digest&&repeated.revision===final.revision&&errors.length===0,
    "Repeat save introduced ghost social events");
  console.log("PLAY_C5_CHROMIUM_PASS: zero-base social trust changed real NPC demand offscreen; two browser reloads retained exact world");
}finally{await ctx.close();await browser.close();}
