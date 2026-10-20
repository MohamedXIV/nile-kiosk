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
  const hit=/^((?:E6_GAME|E6_TOUCH|E6_CAMERA|E4_NPC)_[A-Z_]+) (\{.*\})$/.exec(line);
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
  // Let Godot process pointer release before changing devices to touch.
  await page.waitForTimeout(120);
}
try{
  const base=process.argv[2]||"http://127.0.0.1:8765";
  await page.goto(base+"/game/index.html",{waitUntil:"load",timeout:30000});
  await page.locator("canvas").first().click({position:{x:320,y:180}});
  const start=await until("E6_GAME_READY");
  check(start.location==="roof"&&start.x===175&&start.money===6000,
    "unexpected canonical starter world");
  // Real browser wheel event changes only isometric presentation, not
  // replay/saved P2 position, world digest, inventory or passage of time.
  const wheelAt=await pixel(450,260);
  await page.mouse.move(wheelAt.x,wheelAt.y);
  await page.mouse.wheel(0,-110);
  const wheel=await until("E6_CAMERA_ZOOM");
  check(wheel.camera_target_zoom > start.camera_target_zoom &&
    wheel.camera_target_zoom<=3.2 &&
    wheel.digest===start.digest && wheel.x===start.x && wheel.y===start.y,
    "real Web wheel must dolly in without writing P1/P2 world state");
  await page.waitForTimeout(350);
  const wheelIndex=(traces["E6_CAMERA_ZOOM"]||[]).length;
  await page.mouse.wheel(0,110);
  const out=await until("E6_CAMERA_ZOOM",wheelIndex);
  check(out.camera_target_zoom < wheel.camera_target_zoom &&
    out.digest===wheel.digest,
    "scrolling out must undo the zoom without changing the canonical world");
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
  // P11: after a real reload, use *only touch* for the customer tea recipe
  // and the NPC's optional authored Ink reply. No keyboard or world injection.
  await touch(890,476,"E6_TOUCH_TOGGLE");
  let offer=replay;
  for(let i=0;i<8 && offer.order_status!=="offered";i++){
    offer=await touch(785,383,"E6_GAME_WAIT");
  }
  check(offer.order_status==="offered" && offer.order_recipe==="tea" &&
    offer.npc_mahmoud==="kiosk","touch Wait did not expose genuine P4 tea demand");
  let accepted=await touch(897,158,"E6_GAME_SERVE");
  check(accepted.order_status==="accepted","touch Serve did not accept real P4 order");
  let tea=await touch(897,158,"E6_GAME_SERVE");
  check(tea.tea_stage==="waiting" && tea.tea_action==="H",
    "touch Serve failed to begin real P3 tea");
  tea=await touch(897,383,"E6_GAME_TEA_HEAT");
  check(tea.tea_stage==="active" && tea.tea_ready_in>0,
    "touch Heat bypassed canonical hot-kettle stage");
  await touch(785,383,"E6_GAME_WAIT");
  tea=await touch(897,383,"E6_GAME_TEA_HEAT");
  check(tea.tea_action==="U","touch Lift did not advance genuine recipe");
  tea=await touch(897,383,"E6_GAME_TEA_POUR");
  check(tea.tea_stage==="active","touch Pour did not begin real finishing step");
  await touch(785,383,"E6_GAME_WAIT");
  tea=await touch(897,383,"E6_GAME_TEA_POUR");
  check(tea.tea_stage==="" && tea.tea_quality_item,
    "touch tea did not finish an authentic prepared item");
  const delivered=await touch(897,158,"E6_GAME_SERVE");
  check(delivered.order_status==="delivered" && delivered.customer_reaction_npc==="mahmoud",
    "touch service did not deliver a canonical P3 item to P4 customer");
  check(delivered.mahmoud_invite_near,"touch player is outside real invitation range");
  let conversation=await touch(897,308,"E4_NPC_STARTED");
  check(conversation.mahmoud_story_phase==="" || conversation.mahmoud_story_phase==="running",
    "touch Talk did not open authored Ink");
  conversation=await touch(785,378,"E4_NPC_LINE");
  check(conversation.mahmoud_story_phase==="running",
    "touch Continue did not advance real Ink line");
  conversation=await touch(785,378,"E4_NPC_WAITING");
  check(conversation.mahmoud_story_choices?.length===2,
    "real Ink choices not made available to touch");
  conversation=await touch(897,378,"E4_NPC_CHOICE");
  check(conversation.mahmoud_story_phase==="running",
    "touch Reply 2 did not commit the real authored option");
  await touch(785,378,"E4_NPC_LINE");
  await touch(785,378,"E4_NPC_LINE");
  conversation=await touch(785,378,"E4_NPC_FINISHED");
  check(conversation.mahmoud_story_phase==="finished",
    "touchscreen could not conclude authored Ink encounter");
  check(errors.length===0,"Godot scripting errors");
  console.log("GAME_FIRST_WORLD_PAD_CHROMIUM_PASS: P10 landscape and IndexedDB; P11 touch-only P3 tea, P4 delivery, authored NPC Ink choice");
}finally{
  await context.close();
  await browser.close();
}
