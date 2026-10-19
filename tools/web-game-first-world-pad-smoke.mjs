import { chromium } from "playwright-core";

// Production Godot Web scene. Real browser touch and pointer events drive
// Godot Buttons and the *existing* collision-aware P2 commands.
const browser=await chromium.launch({
  executablePath:process.env.CHROME_BINARY||"/usr/bin/google-chrome",
  headless:true,
  args:["--no-sandbox","--enable-webgl","--use-gl=angle",
    "--use-angle=swiftshader","--enable-unsafe-swiftshader"]
});
const context=await browser.newContext({viewport:{width:640,height:360},hasTouch:true});
const page=await context.newPage();
const traces={};
const errors=[];
page.on("console",m=>{
  const line=m.text();
  const hit=/^((?:E6_GAME|E6_TOUCH)_[A-Z_]+) (\{.*\})$/.exec(line);
  if(hit){try{(traces[hit[1]]??=[]).push(JSON.parse(hit[2]));}
    catch(e){errors.push("Malformed game trace "+e)}}
  if(/SCRIPT ERROR:|Parse Error:|E6_GAME_BOOT_FAILED/.test(line))errors.push(line);
});
page.on("pageerror",e=>errors.push(e.message));
const check=(condition,message)=>{
  if(!condition) throw new Error(message+" "+JSON.stringify({
    errors,last:Object.fromEntries(Object.entries(traces).map(([k,v])=>[k,v.at(-1)]))}));
};
async function until(marker,index=0){
  for(let i=0;i<240;i++){
    if((traces[marker]||[]).length>index)return traces[marker][index];
    if(errors.length)break;
    await page.waitForTimeout(75);
  }
  throw new Error("No "+marker+" #"+index+" "+JSON.stringify(errors));
}
async function pixel(x,y){
  const bounds=await page.locator("canvas").first().evaluate(el=>{
    const r=el.getBoundingClientRect();
    return {left:r.left,top:r.top,width:r.width,height:r.height};
  });
  const scale=Math.min(bounds.width/960,bounds.height/540);
  return {x:bounds.left+(bounds.width-960*scale)/2+x*scale,
    y:bounds.top+(bounds.height-540*scale)/2+y*scale};
}
async function touch(x,y,marker){
  const index=(traces[marker]||[]).length;
  const loc=await pixel(x,y);
  await page.touchscreen.tap(loc.x,loc.y);
  return until(marker,index);
}
async function hold(x,y,durationMs){
  const loc=await pixel(x,y);
  await page.mouse.move(loc.x,loc.y);
  await page.mouse.down();
  await page.waitForTimeout(durationMs);
  await page.mouse.up();
}
try{
  const base=process.argv[2]||"http://127.0.0.1:8765";
  await page.goto(base+"/game/index.html",{waitUntil:"load",timeout:30000});
  await page.locator("canvas").first().click({position:{x:320,y:180}});
  const start=await until("E6_GAME_READY");
  check(start.location==="roof"&&start.x===175&&start.money===6000,
    "unexpected canonical starter world");
  // Production Godot at 640×360: buttons exceed 44 physical CSS pixels,
  // and the world camera stays inside the gap between the two control columns.
  const canvas=await page.locator("canvas").first().boundingBox();
  const scale=Math.min(canvas.width/960,canvas.height/540);
  check(scale*70>=44 && scale*68>=44,"compact landscape targets below 44px");
  const toggled=await touch(890,476,"E6_TOUCH_TOGGLE");
  check(toggled.view_actor_x>246 && toggled.view_actor_x<720,
    "pad mode did not reframe canonical actor into unobstructed world space");
  check(toggled.location==="roof"&&toggled.money===6000,
    "touch toggle should not cause world state changes");
  let entry=await touch(785,157,"E6_GAME_DOOR");
  check(entry.location==="landing"&&entry.x===40,
    "real touchscreen Door Button did not traverse P2 roof portal");
  // Held SE Button uses exactly the same screen-to-world movement as WASD S+D.
  await hold(201,305,1130);
  let moved=await touch(890,477,"E6_TOUCH_TOGGLE"); // Stop/disable.
  check(moved.location==="landing"&&moved.x>40&&moved.y===70,
    "holding pointer direction did not move through canonical P2");
  await page.waitForTimeout(350);
  let stopped=await touch(890,477,"E6_TOUCH_TOGGLE");
  check(stopped.x===moved.x&&stopped.y===moved.y,
    "player kept moving after releasing/hiding on-screen direction");
  entry=await touch(785,157,"E6_GAME_DOOR");
  check(entry.location==="street",
    "touchscreen Door Button failed the second real portal");
  await hold(201,305,1130);
  entry=await touch(785,157,"E6_GAME_DOOR");
  check(entry.location==="kiosk",
    "held pointer movement failed to reach the actual kiosk doorway");
  // Four distinct touch taps yield four 18-unit P2 steps, not teleportation.
  for(let i=0;i<4;i++){
    const at=await pixel(201,305);
    await page.touchscreen.tap(at.x,at.y);
  }
  const nearby=await touch(890,477,"E6_TOUCH_TOGGLE");
  check(nearby.location==="kiosk"&&nearby.sandwich.near&&nearby.x>=95,
    "touch taps did not reach canonical P3 kitchen proximity");
  await touch(890,477,"E6_TOUCH_TOGGLE");
  const opened=await touch(785,231,"E6_GAME_OPEN");
  check(opened.kiosk_open,"touch Open/Close did not call real E1 shop action");
  const served=await touch(897,157,"E6_GAME_SERVE");
  check(served.money===6000&&served.location==="kiosk",
    "touch service action created unsupported player money");
  const saved=await touch(785,306,"E6_GAME_SAVE");
  check(saved.save_storage_status==="pending"||saved.save_storage_status==="confirmed",
    "touch Save did not initiate canonical Web save verification");
  const ack=await until("E6_GAME_SAVE_CONFIRMED");
  check(ack.save_storage_status==="confirmed"&&
    ack.save_storage_revision===saved.revision,
    "touch Save did not confirm exact IndexedDB file revision");
  await page.reload({waitUntil:"load"});
  const replay=await until("E6_GAME_RESTORED");
  check(replay.location==="kiosk"&&replay.x===saved.x&&replay.y===saved.y&&
    replay.money===saved.money&&replay.kiosk_open===saved.kiosk_open&&
    replay.digest===saved.digest,
    "touch-driven canonical position/shop state not replayed from actual disk save");
  check(errors.length===0,"Godot scripting errors");
  console.log("GAME_FIRST_WORLD_PAD_CHROMIUM_PASS: 640x360 landscape, >=44px touch targets, safe camera, real Door/Open/Serve/Save, hold/release and IndexedDB reload");
}finally{
  await context.close();
  await browser.close();
}
