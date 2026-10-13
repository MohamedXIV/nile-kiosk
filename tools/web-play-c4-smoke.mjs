import { chromium } from "playwright-core";
// Real Godot Web: customer offers in the background without player pressing O.
const browser = await chromium.launch({
  executablePath:process.env.CHROME_BINARY || "/usr/bin/google-chrome",headless:true,
  args:["--no-sandbox","--enable-webgl","--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader"]
});
const context=await browser.newContext({viewport:{width:1100,height:760}});
const page=await context.newPage();
const marks=["PLAY_C1_READY","PLAY_C1_RESTORED","PLAY_C1_TIME","PLAY_C1_SAVED","PLAY_C3_BLOCKED"];
const traces=Object.fromEntries(marks.map(m=>[m,[]]));
const errors=[];
page.on("console",msg=>{
  const line=msg.text();
  for(const m of marks)if(line.startsWith(m+" ")){
    try {traces[m].push(JSON.parse(line.slice(m.length+1)));}
    catch(e){errors.push("bad log "+String(e));}
  }
  if(/SCRIPT ERROR:|PLAY_C1_.*FAILED|PLAY_C4_.*FAILED/.test(line)) errors.push(line);
});
page.on("pageerror",e=>errors.push(e.message));
const check=(v,why)=>{if(!v)throw Error(why+" "+JSON.stringify({traces,errors}));};
async function until(m,index=0){
  for(let i=0;i<390;i++){
    if(traces[m].length>index)return traces[m][index];
    if(errors.length)break;
    await page.waitForTimeout(80);
  }
  throw Error("Missing "+m+" #"+index+" "+JSON.stringify(errors));
}
async function key(name){await page.keyboard.press(name);}
try{
  const url=(process.argv[2]||"http://127.0.0.1:8765")+"/play-c4/index.html";
  await page.goto(url,{waitUntil:"load",timeout:30000});
  await page.locator("canvas").first().click({position:{x:480,y:240}});
  const initial=await until("PLAY_C1_READY");
  check(initial.location==="roof" && initial.auto_count===0 && initial.money===300,"No real initial world");
  await key("t");
  const arrival=await until("PLAY_C1_TIME",0);
  check(arrival.minute===5 && arrival.npc_reda==="kiosk" && arrival.auto_count===0,
    "NPC did not arrive or ordered before policy time");
  await key("t");
  const offered=await until("PLAY_C1_TIME",1);
  check(offered.minute===10 && offered.auto_count===1 && offered.auto_customer==="reda" &&
    offered.auto_status==="offered" && offered.location==="roof" && offered.money===300,
    "World-timed NPC did not offer order autonomously, or moved player/money");
  await key("g");
  const cannotAccept=await until("PLAY_C3_BLOCKED");
  check(cannotAccept.revision===offered.revision && cannotAccept.auto_status==="offered",
    "Offscreen player accepted order by UI");
  await key("p");
  const saved=await until("PLAY_C1_SAVED",0);
  check(saved.digest===offered.digest,"Save mutated offscreen order");
  await page.waitForTimeout(1500);
  await page.reload({waitUntil:"load",timeout:30000});
  const restored=await until("PLAY_C1_RESTORED",0);
  check(restored.digest===saved.digest && restored.auto_status==="offered" &&
    restored.location==="roof","Offscreen demand/clock lost through hard reload");
  for(let i=0;i<4;i++)await key("t");
  const expired=await until("PLAY_C1_TIME",5);
  check(expired.minute===30 && expired.auto_status==="abandoned" && expired.money===300,
    "Large/split world deadline did not expire unattended order");
  await key("t");await key("t");
  const departed=await until("PLAY_C1_TIME",7);
  check(departed.minute===40 && departed.npc_reda==="street" &&
    departed.auto_count===1 && departed.auto_status==="abandoned","NPC or expired state diverged");
  await key("p");
  const finalSave=await until("PLAY_C1_SAVED",1);
  await page.waitForTimeout(1500);
  await page.reload({waitUntil:"load",timeout:30000});
  const final=await until("PLAY_C1_RESTORED",1);
  check(final.digest===finalSave.digest && final.minute===40 &&
    final.auto_count===1 && final.auto_status==="abandoned" && final.money===300,
    "Reload duplicated autonomous order or invented player income");
  await key("p");
  const repeated=await until("PLAY_C1_SAVED",2);
  check(repeated.digest===final.digest && repeated.revision===final.revision &&
    errors.length===0,"Repeated save created ghost orders/events");
  console.log("PLAY_C4_CHROMIUM_PASS: independent NPC scheduled offer, unattended expiry, absent-player service rejection, two real Web reloads");
} finally {await context.close();await browser.close();}
