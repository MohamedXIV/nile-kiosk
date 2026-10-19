import { chromium } from "playwright-core";

// Actual exported default Godot game; no QA scene, injected inventory or
// synthetic elapsed clock. P5 purchases and P3 gestures use real user input.
const browser = await chromium.launch({
  executablePath: process.env.CHROME_BINARY || "/usr/bin/google-chrome",
  headless: true,
  args: ["--no-sandbox","--enable-webgl","--use-gl=angle",
    "--use-angle=swiftshader","--enable-unsafe-swiftshader"]
});
const context = await browser.newContext({viewport:{width:1100,height:760}});
const page = await context.newPage();
const traces = {};
const errors = [];
page.on("console", m => {
  const msg = m.text();
  const found = /^((?:E6_GAME|E6_SANDWICH)_[A-Z_]+) (\{.*\})$/.exec(msg);
  if(found) {
    try { (traces[found[1]] ??= []).push(JSON.parse(found[2])); }
    catch(e) { errors.push("Invalid game trace: "+String(e)); }
  }
  if(/SCRIPT ERROR:|Parse Error:|E6_GAME_BOOT_FAILED/.test(msg))errors.push(msg);
});
page.on("pageerror",e=>errors.push(e.message));
function check(value,message) {
  if(!value)throw new Error(message+" "+JSON.stringify({errors,
    last:Object.fromEntries(Object.entries(traces).map(([key,values])=>[key,values.at(-1)]))}));
}
async function until(marker, index=0) {
  for(let i=0;i<240;i++) {
    if((traces[marker]||[]).length>index)return traces[marker][index];
    if(errors.length)break;
    await page.waitForTimeout(75);
  }
  throw new Error("No "+marker+" #"+index+" "+JSON.stringify(errors));
}
const press = key => page.keyboard.press(key);
async function moveDiagonal(ms) {
  await page.keyboard.down("s");await page.keyboard.down("d");
  await page.waitForTimeout(ms);
  await page.keyboard.up("s");await page.keyboard.up("d");
}
async function action(key, marker) {
  const index=(traces[marker]||[]).length;
  await press(key);
  return until(marker,index);
}
try {
  const base=process.argv[2]||"http://127.0.0.1:8765";
  await page.goto(base+"/game/index.html",{waitUntil:"load",timeout:30000});
  await page.locator("canvas").first().click({position:{x:500,y:290}});
  const initial=await until("E6_GAME_READY");
  check(initial.location==="roof" && initial.money===6000 &&
    initial.sandwich?.offers?.length===6 && initial.sandwich.stage==="",
    "starter scene did not load authored sandwich offers");
  let opened=await action("F7","E6_SANDWICH_TOGGLE");
  check(opened.sandwich_visible,"F7 overlay not visible");
  let remote=await action("1","E6_GAME_SANDWICH_PURCHASE");
  check(remote.money===6000 && !remote.sandwich.offers[0].resolved,
    "remote purchase invented stock");
  await action("F7","E6_SANDWICH_TOGGLE");
  await action("e","E6_GAME_DOOR");
  await moveDiagonal(1260);
  await action("e","E6_GAME_DOOR");
  await moveDiagonal(1230);
  const kiosk=await action("e","E6_GAME_DOOR");
  check(kiosk.location==="kiosk","cannot reach real kiosk");
  await moveDiagonal(520);
  opened=await action("F7","E6_SANDWICH_TOGGLE");
  check(opened.sandwich_visible && opened.sandwich.near,
    "sandwich counter is not reachable");
  for(let i=1;i<=6;i++) {
    const bought=await action(String(i),"E6_GAME_SANDWICH_PURCHASE");
    check(bought.sandwich.offers[i-1].resolved,
      "real purchase missing for ingredient "+i);
  }
  const paid=traces.E6_GAME_SANDWICH_PURCHASE.at(-1);
  check(paid.money===4440,"paid six offers must debit 1560 minor units");
  let started=await action("Enter","E6_GAME_SANDWICH_STEP");
  check(started.sandwich.stage==="waiting" && started.sandwich.step_index===0,
    "sandwich job not canonically started");
  let seasoned=await action("Enter","E6_GAME_SANDWICH_STEP");
  check(seasoned.sandwich.stage==="active","seasoning did not begin");
  await action("j","E6_GAME_WAIT");
  await action("Enter","E6_GAME_SANDWICH_STEP"); // Finish seasoning
  const pan=await action("Enter","E6_GAME_SANDWICH_STEP");
  check(pan.sandwich.step_index===1 && pan.sandwich.stage==="active",
    "pan stage missing");
  await action("j","E6_GAME_WAIT"); // Five real minutes on first face.
  const turned=await action("Enter","E6_GAME_SANDWICH_STEP");
  check(turned.sandwich.step_index===1 && turned.sandwich.stage==="active",
    "turn skipped or ended frying instead of changing same active step");
  const saved=await action("p","E6_GAME_SAVE");
  check(saved.sandwich.stage==="active" && saved.sandwich.step_index===1,
    "mid-pan save missing P3 state");
  await page.waitForTimeout(1800);
  await page.reload({waitUntil:"load"});
  const restored=await until("E6_GAME_RESTORED");
  check(restored.location==="kiosk" && restored.money===4440 &&
    restored.sandwich.stage==="active" && restored.sandwich.step_index===1 &&
    restored.sandwich.offers.every(offer=>offer.resolved),
    "hard Web reload lost paid stock/turn stage");
  opened=await action("F7","E6_SANDWICH_TOGGLE");
  check(opened.sandwich_visible && opened.sandwich.near,
    "workstation not usable after reload");
  await action("j","E6_GAME_WAIT");
  let lifted=await action("Enter","E6_GAME_SANDWICH_STEP");
  check(lifted.sandwich.stage==="waiting" && lifted.sandwich.step_index===2,
    "second face did not finish");
  await action("Enter","E6_GAME_SANDWICH_STEP"); // Assembly begin
  const finished=await action("Enter","E6_GAME_SANDWICH_STEP");
  check(finished.sandwich.stage==="" && finished.sandwich.item_id.startsWith("item:player:sandwich:") &&
    finished.sandwich.score>=25 && finished.sandwich.score<100 &&
    ["okay","rough"].includes(finished.sandwich.grade),
    "timed real sandwich did not yield imperfect verified item quality");
  await action("p","E6_GAME_SAVE");
  await page.waitForTimeout(1700);
  await page.reload({waitUntil:"load"});
  const completed=await until("E6_GAME_RESTORED",1);
  check(completed.sandwich.item_id===finished.sandwich.item_id &&
    completed.sandwich.score===finished.sandwich.score &&
    completed.money===4440,"completed item/quality and P5 payment did not replay");
  check(errors.length===0,"Godot browser script failures");
  console.log("GAME_FIRST_SANDWICH_CHROMIUM_PASS: paid stock, real timed P3 actions, two hard browser reloads, provenance-derived grade");
} finally {
  await context.close();
  await browser.close();
}
