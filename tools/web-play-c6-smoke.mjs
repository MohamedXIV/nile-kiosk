import { chromium } from "playwright-core";

// C6 — real Godot Web, no O/offer input; previous unattended service outcome
// changes repeat customer interest without a parallel scene or reputation bar.
const browser=await chromium.launch({executablePath:process.env.CHROME_BINARY||"/usr/bin/google-chrome",
  headless:true,args:["--no-sandbox","--enable-webgl","--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader"]});
const context=await browser.newContext({viewport:{width:1100,height:760}});
const page=await context.newPage();
const markers=["PLAY_C1_READY","PLAY_C1_RESTORED","PLAY_C1_TIME","PLAY_C1_SAVED","PLAY_C3_BLOCKED"];
const traces=Object.fromEntries(markers.map(m=>[m,[]]));
const errors=[];
page.on("console",msg=>{
  const line=msg.text();
  for(const marker of markers)if(line.startsWith(marker+" ")){
    try{traces[marker].push(JSON.parse(line.slice(marker.length+1)));}
    catch(e){errors.push("bad trace: "+String(e));}
  }
  if(/SCRIPT ERROR:|PLAY_C[136]_.*FAILED/.test(line))errors.push(line);
});
page.on("pageerror",e=>errors.push(e.message));
const check=(x,why)=>{if(!x)throw Error(why+" "+JSON.stringify({traces,errors}));};
async function until(marker,index=0){
  for(let i=0;i<500;i++){
    if(traces[marker].length>index)return traces[marker][index];
    if(errors.length)break;
    await page.waitForTimeout(75);
  }
  throw Error("Missing "+marker+" #"+index+" "+JSON.stringify(errors));
}
async function key(k){await page.keyboard.press(k);}
try{
  await page.goto((process.argv[2]||"http://127.0.0.1:8765")+"/play-c6/index.html",{waitUntil:"load",timeout:30000});
  await page.locator("canvas").first().click({position:{x:480,y:245}});
  const ready=await until("PLAY_C1_READY");
  check(ready.location==="roof"&&ready.money===300&&ready.auto_count===0,
    "C6 unbalanced QA-only world not booted");
  await key("t");  // minute 5: Reda arrived and asked
  const offered=await until("PLAY_C1_TIME",0);
  check(offered.minute===5&&offered.npc_reda==="kiosk"&&offered.auto_count===1&&
    offered.auto_status==="offered"&&offered.auto_experience_count===1&&
    offered.auto_experience?.last_outcome==="none"&&
    offered.auto_experience?.chance_bp===10000&&offered.location==="roof",
    "First independent order not generated at visit minute 5");
  await key("g");
  const blocked=await until("PLAY_C3_BLOCKED",0);
  check(blocked.revision===offered.revision&&blocked.auto_status==="offered",
    "Offscreen player illegally fulfilled repeat customer");
  await key("p");
  const saved=await until("PLAY_C1_SAVED",0);
  check(saved.digest===offered.digest,"Save mutated first customer attempt");
  await page.waitForTimeout(1500);
  await page.reload({waitUntil:"load",timeout:30000});
  const restored=await until("PLAY_C1_RESTORED",0);
  check(restored.digest===saved.digest&&restored.auto_status==="offered"&&
    restored.auto_experience_count===1,"First Web reload lost customer offer");

  await key("t");  // minute 10: expiry of first order
  const expired=await until("PLAY_C1_TIME",1);
  check(expired.minute===10&&expired.auto_status==="abandoned"&&expired.money===300,
    "Customer was not abandoned at minute 10");
  await key("t");  // minute 15
  const before=await until("PLAY_C1_TIME",2);
  check(before.minute===15&&before.auto_experience_count===1,
    "Second attempt fired early");
  await key("t");  // minute 20 contains second due minute 17
  const after=await until("PLAY_C1_TIME",3);
  check(after.minute===20&&after.auto_count===1&&after.auto_status==="abandoned"&&
    after.auto_experience_count===2&&after.auto_experience?.last_outcome==="abandoned"&&
    after.auto_experience?.last_order_id==="demand:qa:reda:revisit:1"&&
    after.auto_experience?.adjustment_bp===-10000&&
    after.auto_experience?.chance_bp===0&&
    after.auto_experience_reason==="not_interested"&&
    after.auto_experience_outcome==="skipped"&&after.money===300,
    "Prior abandonment didn't suppress second visit based on real canonical order");
  await key("p");
  const saved2=await until("PLAY_C1_SAVED",1);
  await page.waitForTimeout(1500);
  await page.reload({waitUntil:"load",timeout:30000});
  const final=await until("PLAY_C1_RESTORED",1);
  check(final.digest===saved2.digest&&final.auto_experience_count===2&&
    final.auto_experience?.chance_bp===0&&final.money===300&&final.auto_count===1,
    "Second Web reload changed customer experience history");
  await key("p");
  const repeated=await until("PLAY_C1_SAVED",2);
  check(repeated.digest===final.digest&&repeated.revision===final.revision&&errors.length===0,
    "Repeat save mutated world or introduced phantom visit");
  console.log("PLAY_C6_CHROMIUM_PASS: real abandonment suppressed follow-up customer interest, exact canonical world across two hard Web reloads");
}finally{await context.close();await browser.close();}
