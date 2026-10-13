import { chromium } from "playwright-core";

// Real Godot Web input to C0-backed spatial presentation. The scene is QA-only.
const browser = await chromium.launch({
  executablePath: process.env.CHROME_BINARY || "/usr/bin/google-chrome",
  headless: true,
  args: ["--no-sandbox", "--enable-webgl", "--use-gl=angle",
    "--use-angle=swiftshader", "--enable-unsafe-swiftshader"]
});
const context = await browser.newContext({viewport:{width:1100,height:760}});
const page = await context.newPage();
const markers = ["READY","RESTORED","TRAVEL","HEARD","SAVED","TIME","DENIED"];
const seen = Object.fromEntries(markers.map(m=>[m,[]]));
const errors = [];
page.on("console",msg=>{
  const s = msg.text();
  for(const m of markers){
    const prefix = "PLAY_C1_"+m+" ";
    if(s.startsWith(prefix)){
      try {
        seen[m].push(JSON.parse(s.slice(prefix.length)));
        console.log(s);
      } catch(e){ errors.push("BAD_TRACE: "+String(e)); }
    }
  }
  if(/SCRIPT ERROR:|PLAY_C1_.*FAILED/.test(s)) errors.push(s);
});
page.on("pageerror",e=>errors.push(e.message));
function check(ok,why){
  if(!ok) throw new Error(why+" "+JSON.stringify({seen,errors}));
}
async function until(marker,index=0){
  for(let i=0;i<400;i++){
    if(seen[marker].length>index) return seen[marker].at(-1);
    if(errors.length) break;
    await page.waitForTimeout(75);
  }
  throw new Error("Missing "+marker+" index="+index+" errors="+JSON.stringify(errors));
}
async function key(name){
  await page.keyboard.press(name);
}
async function walk(name,n){
  for(let i=0;i<n;i++) await key(name);
}
try {
  await page.goto((process.argv[2]||"http://127.0.0.1:8765")+"/play-c1/index.html",
    {waitUntil:"load",timeout:30000});
  await page.locator("canvas").first().click({position:{x:480,y:245}});
  const initial = await until("READY");
  check(initial.location==="roof" && initial.revision>=24 && initial.money===300 &&
    initial.flat_access===false && initial.known===false,"C0 catalog not booted from JSON");
  await key("e");
  const landing = await until("TRAVEL",0);
  check(landing.location==="landing","Roof doorway failed");
  await walk("d",9);
  await key("e");
  const street = await until("TRAVEL",1);
  check(street.location==="street","Landing route failed");
  await walk("d",9);
  await key("e");
  const kiosk = await until("TRAVEL",2);
  check(kiosk.location==="kiosk","Street to kiosk failed");
  await walk("d",3);
  await key("f");
  const heard = await until("HEARD");
  check(heard.known===true && heard.location==="kiosk","Real P2 hearing did not occur at NPC");
  await key("p");
  const saved = await until("SAVED",0);
  check(saved.digest===heard.digest && saved.revision===heard.revision,
    "Saving changed canonical world");
  await page.waitForTimeout(1500);
  await page.reload({waitUntil:"load",timeout:30000});
  const restored = await until("RESTORED",0);
  check(restored.digest===saved.digest && restored.known===true &&
    restored.location==="kiosk" && restored.x===45,
    "Whole world location/knowledge did not survive hard reload");
  await key("t");
  const advanced = await until("TIME");
  check(advanced.minute===5 && advanced.npc_reda==="kiosk",
    "NPC offscreen routine did not advance while player remained in kiosk");
  await key("p");
  const saved2 = await until("SAVED",1);
  await page.waitForTimeout(1500);
  await page.reload({waitUntil:"load",timeout:30000});
  const after = await until("RESTORED",1);
  check(after.digest===saved2.digest && after.revision===saved2.revision &&
    after.minute===5 && after.known && after.npc_reda==="kiosk",
    "Second reload duplicated world events or erased NPC routine");
  await key("p");
  const resaved = await until("SAVED",2);
  check(resaved.digest===after.digest && resaved.revision===after.revision &&
    errors.length===0, "Save produced ghost events or browser errors");
  console.log("PLAY_C1_CHROMIUM_PASS: actual keyboard room traversal, proximity hearing, scheduled NPC and two full Web reloads");
} finally {
  await context.close();
  await browser.close();
}
