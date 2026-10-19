import { chromium } from "playwright-core";

// Actual exported default Godot game; no QA scene, injected inventory or
// synthetic elapsed clock. P5 purchases and P3 gestures use real user input.
const browser = await chromium.launch({
  executablePath: process.env.CHROME_BINARY || "/usr/bin/google-chrome",
  headless: true,
  args: ["--no-sandbox","--enable-webgl","--use-gl=angle",
    "--use-angle=swiftshader","--enable-unsafe-swiftshader"]
});
const context = await browser.newContext({viewport:{width:1100,height:760},hasTouch:true});
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
async function moveHome(ms) {
  await page.keyboard.down("w");await page.keyboard.down("a");
  await page.waitForTimeout(ms);
  await page.keyboard.up("w");await page.keyboard.up("a");
}
async function action(key, marker) {
  const index=(traces[marker]||[]).length;
  await press(key);
  return until(marker,index);
}
async function saveDurably() {
  const marker="E6_GAME_SAVE_CONFIRMED";
  const index=(traces[marker]||[]).length;
  const saved=await action("p","E6_GAME_SAVE");
  check(saved.save_storage_status==="pending" || saved.save_storage_status==="confirmed",
    "Web save did not start browser durability verification");
  const acknowledged=await until(marker,index);
  check(acknowledged.save_storage_status==="confirmed" &&
    acknowledged.save_storage_revision===saved.revision,
    "IndexedDB confirmed a different P0 world revision");
  return saved;
}
async function clickControl(x, y, marker, useTouch=false) {
  const index=(traces[marker]||[]).length;
  // Godot's logical 960x540 viewport is aspect-fitted inside the
  // responsive browser canvas. Convert draw/UI coordinates to CSS pixels.
  const canvas=page.locator("canvas").first();
  const bounds=await canvas.evaluate(element => {
    const r=element.getBoundingClientRect();
    return {left:r.left,top:r.top,width:r.width,height:r.height};
  });
  const scale=Math.min(bounds.width/960,bounds.height/540);
  const position={
    x:(bounds.width-960*scale)/2+x*scale,
    y:(bounds.height-540*scale)/2+y*scale
  };
  if(useTouch) {
    // Real browser touchscreen event, not a synthesized Godot JS action.
    await page.touchscreen.tap(bounds.left+position.x,bounds.top+position.y);
  } else {
    await canvas.click({position});
  }
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
  check(initial.sandwich.heat_state==="idle" &&
    initial.sandwich.stock.liver===0 && !initial.sandwich.can_start,
    "unpaid counter must communicate real missing stock");
  check(initial.next_step_phase==="head_to_shop",
    "initial guide must follow the actual roof-to-kiosk route");
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
  check(kiosk.next_step_phase==="open_kiosk",
    "closed actual kiosk must show the next-step open objective");
  await moveDiagonal(520);
  opened=await clickControl(812,387,"E6_SANDWICH_TOGGLE");
  check(opened.sandwich_visible && opened.sandwich.near,
    "actual Godot Button failed to open reachable sandwich counter");
  for(let i=1;i<=6;i++) {
    const bought=i===1
      ? await clickControl(494,174,"E6_GAME_SANDWICH_PURCHASE",true)
      : await action(String(i),"E6_GAME_SANDWICH_PURCHASE");
    check(bought.sandwich.offers[i-1].resolved,
      "real purchase missing for ingredient "+i);
  }
  const paid=traces.E6_GAME_SANDWICH_PURCHASE.at(-1);
  check(paid.money===4440,"paid six offers must debit 1560 minor units");
  check(paid.sandwich.can_start && paid.sandwich.stock.liver===400 &&
    paid.sandwich.offers.every(offer=>offer.unit),
    "paid stock, units and recipe readiness must be drawn from P3");
  let started=await clickControl(251,415,"E6_GAME_SANDWICH_STEP");
  check(started.sandwich.stage==="waiting" && started.sandwich.step_index===0,
    "sandwich job not canonically started");
  let seasoned=await action("Enter","E6_GAME_SANDWICH_STEP");
  check(seasoned.sandwich.stage==="active","seasoning did not begin");
  await action("j","E6_GAME_WAIT");
  await action("Enter","E6_GAME_SANDWICH_STEP"); // Finish seasoning
  const pan=await action("Enter","E6_GAME_SANDWICH_STEP");
  check(pan.sandwich.step_index===1 && pan.sandwich.stage==="active",
    "pan stage missing");
  check(pan.sandwich.heat_state==="warming" && pan.sandwich.heat_minutes===2,
    "pan illustration did not receive canonical lead-in timing");
  await clickControl(414,414,"E6_GAME_WAIT"); // Godot Button, real P1 clock.
  const turnWindow=traces.E6_GAME_WAIT.at(-1);
  check(turnWindow.sandwich.heat_state==="turn_window",
    "pan did not show the real turn window");
  const turned=await clickControl(251,414,"E6_GAME_SANDWICH_STEP");
  check(turned.sandwich.step_index===1 && turned.sandwich.stage==="active",
    "turn skipped or ended frying instead of changing same active step");
  check(turned.sandwich.heat_state==="turned" &&
    turned.sandwich.heat_minutes===2,
    "post-turn other-side window not projected from P3");
  const saved=await saveDurably();
  check(saved.sandwich.stage==="active" && saved.sandwich.step_index===1,
    "mid-pan save missing P3 state");
  await page.reload({waitUntil:"load"});
  const restored=await until("E6_GAME_RESTORED");
  check(restored.location==="kiosk" && restored.money===4440 &&
    restored.sandwich.stage==="active" && restored.sandwich.step_index===1 &&
    restored.sandwich.offers.every(offer=>offer.resolved),
    "hard Web reload lost paid stock/turn stage");
  check(restored.sandwich.heat_state==="turned" &&
    restored.sandwich.heat_minutes===2,
    "visual turn readiness not reconstructed after hard browser reload");
  opened=await clickControl(810,385,"E6_SANDWICH_TOGGLE");
  check(opened.sandwich_visible && opened.sandwich.near,
    "clickable workstation did not restore after browser hard reload");
  const overcooked=await action("j","E6_GAME_WAIT");
  check(overcooked.sandwich.heat_state==="second_face_late" &&
    overcooked.sandwich.heat_minutes>=3,
    "real overcooking warning missing despite elapsed canonical world time");
  let lifted=await action("Enter","E6_GAME_SANDWICH_STEP");
  check(lifted.sandwich.stage==="waiting" && lifted.sandwich.step_index===2,
    "second face did not finish");
  await action("Enter","E6_GAME_SANDWICH_STEP"); // Assembly begin
  const finished=await action("Enter","E6_GAME_SANDWICH_STEP");
  check(finished.sandwich.stage==="" && finished.sandwich.item_id.startsWith("item:player:sandwich:") &&
    finished.sandwich.score>=25 && finished.sandwich.score<100 &&
    ["okay","rough"].includes(finished.sandwich.grade),
    "timed real sandwich did not yield imperfect verified item quality");
  const closedCounter=await clickControl(650,415,"E6_SANDWICH_TOGGLE");
  check(!closedCounter.sandwich_visible,
    "real Godot Close Button did not release the cooking overlay");
  await saveDurably();
  await page.reload({waitUntil:"load"});
  const completed=await until("E6_GAME_RESTORED",1);
  check(completed.sandwich.item_id===finished.sandwich.item_id &&
    completed.sandwich.score===finished.sandwich.score &&
    completed.money===4440,"completed item/quality and P5 payment did not replay");

  // P4: the store was closed at 17:15, so the existing tea offer was
  // correctly skipped. Opening before 18:00 produces Salma's *real*
  // scheduled sandwich order without injecting an NPC or an order.
  let customer=await action("o","E6_GAME_OPEN");
  check(customer.kiosk_open,"real kiosk opening failed");
  while(customer.minute<1080) customer=await action("j","E6_GAME_WAIT");
  check(customer.order_recipe==="liver_sandwich" &&
    customer.order_npc==="salma" && customer.order_status==="offered",
    "canonical P4 schedule did not offer the sandwich");
  check(customer.next_step_phase==="accept_order",
    "authentic scheduled Salma offer must drive guide priority");
  let accepted=await action("g","E6_GAME_SERVE");
  check(accepted.order_status==="accepted" &&
    accepted.money===4440,"G did not accept P4 sandwich order");
  check(accepted.next_step_phase==="deliver_order" &&
    accepted.sandwich.item_status==="ready",
    "guide must recognize the already-prepared paid P3 item");
  let delivered=await action("g","E6_GAME_SERVE");
  check(delivered.order_status==="delivered" &&
    delivered.customer_reaction_npc==="salma" &&
    delivered.money===4440,
    "G did not deliver the genuine prepared item and project Salma's reaction");
  check(delivered.next_step_phase==="collect_payment" &&
    delivered.sandwich.item_status==="used",
    "delivered P3 item must not be advertised as still ready");
  check(delivered.customer_reaction_order===accepted.active_order,
    "reaction has no P4 provenance");
  let quoted=await action("g","E6_GAME_SERVE");
  check(quoted.money===4440 && quoted.order_payment==="awaiting_ledger",
    "P5 quote must not credit funds");
  let settled=await action("g","E6_GAME_SERVE");
  check(settled.money===4990 && settled.order_payment==="settled",
    "customer must pay exactly 550 only after P4 delivery");
  check(settled.next_step_phase==="close_after_sale",
    "real P5 settled sale should guide shop closing");
  // Close, walk every P2 portal home, and sleep using the E1 policy.
  const closed=await action("c","E6_GAME_CLOSE");
  check(!closed.kiosk_open,"closing the shop changed no state");
  await moveHome(520);
  check((await action("e","E6_GAME_DOOR")).location==="street",
    "could not leave kiosk");
  await moveHome(1230);
  check((await action("e","E6_GAME_DOOR")).location==="landing",
    "could not return from street");
  await moveHome(1260);
  check((await action("e","E6_GAME_DOOR")).location==="roof",
    "could not walk home from landing");
  const slept=await action("z","E6_GAME_SLEEP");
  check(slept.day===2 && slept.minute>=1920 && slept.minute<1930 &&
    slept.sleep_count===1 && !slept.kiosk_open,
    "E1 sleep failed to wake on next morning");
  check(slept.next_step_phase==="head_to_shop",
    "yesterday's settled sale must not block day-two guidance");
  check((await action("e","E6_GAME_DOOR")).location==="landing",
    "could not leave the roof next morning");
  await moveDiagonal(1260);
  check((await action("e","E6_GAME_DOOR")).location==="street",
    "day-two landing path blocked");
  await moveDiagonal(1230);
  check((await action("e","E6_GAME_DOOR")).location==="kiosk",
    "cannot enter kiosk on day two");
  await moveDiagonal(520);
  await saveDurably();
  await page.reload({waitUntil:"load"});
  const paidAgain=await until("E6_GAME_RESTORED",2);
  check(paidAgain.money===4990 && paidAgain.order_payment==="settled" &&
    paidAgain.sandwich.item_id===finished.sandwich.item_id,
    "real paid sandwich replay lost P3 item or P5 money");

  // Day-2 market: genuinely move P1 world clock across midnight. The six
  // public supplier lots must reopen, and every repeat costs real P5 money.
  let dayTwo=paidAgain;
  while(dayTwo.minute<1440) dayTwo=await action("j","E6_GAME_WAIT");
  check(dayTwo.sandwich.offers.length===6 &&
    dayTwo.sandwich.offers.every(offer=>!offer.resolved),
    "same six public lots did not reopen on the next canonical day");
  const reopen=await clickControl(810,385,"E6_SANDWICH_TOGGLE");
  check(reopen.sandwich_visible && reopen.sandwich.near,
    "player lost kitchen access after next-day travel through time");
  for(let i=1;i<=6;i++) {
    const fresh=await action(String(i),"E6_GAME_SANDWICH_PURCHASE");
    check(fresh.sandwich.offers[i-1].resolved,
      "next-day market repeat didn't issue a second receipt for "+i);
  }
  const restocked=traces.E6_GAME_SANDWICH_PURCHASE.at(-1);
  check(restocked.money===3430 && restocked.sandwich.stock.liver===700,
    "next-day real market should debit 1560 and only add 400g liver");
  const duplicate=await action("5","E6_GAME_SANDWICH_PURCHASE");
  check(duplicate.money===3430 && duplicate.sandwich.stock.liver===700,
    "same-day repeat key minted free or double-bought supplies");
  await saveDurably();
  await page.reload({waitUntil:"load"});
  const secondDayReplay=await until("E6_GAME_RESTORED",3);
  check(secondDayReplay.money===3430 && secondDayReplay.sandwich.stock.liver===700 &&
    secondDayReplay.sandwich.offers.every(offer=>offer.resolved) &&
    secondDayReplay.sleep_count===1,
    "second day cash, stock and authentic overnight sleep were not persisted");
  // Genuine day-two customer, not a test-authored NPC/order.
  let next=secondDayReplay;
  while(next.minute<2490) next=await action("j","E6_GAME_WAIT");
  check((await action("o","E6_GAME_OPEN")).kiosk_open,
    "shop was not reopened for the returning customer");
  while(next.minute<2520) next=await action("j","E6_GAME_WAIT");
  check(next.order_recipe==="liver_sandwich" &&
    next.order_npc==="salma" && next.order_status==="offered",
    "scheduled second-day Salma demand was skipped");
  const acceptedDayTwo=await action("g","E6_GAME_SERVE");
  check(acceptedDayTwo.order_status==="accepted","G could not accept day-two order");
  check(acceptedDayTwo.next_step_phase==="prepare_liver",
    "day-two accepted order must follow real P3 stock and preparation");
  await action("F7","E6_SANDWICH_TOGGLE");
  await action("Enter","E6_GAME_SANDWICH_STEP"); // Start
  await action("Enter","E6_GAME_SANDWICH_STEP"); // Season
  await action("j","E6_GAME_WAIT");
  await action("Enter","E6_GAME_SANDWICH_STEP"); // Finish seasoning
  await action("Enter","E6_GAME_SANDWICH_STEP"); // Pan
  await action("j","E6_GAME_WAIT");
  await action("Enter","E6_GAME_SANDWICH_STEP"); // Actual turn
  await action("j","E6_GAME_WAIT");
  await action("Enter","E6_GAME_SANDWICH_STEP"); // Lift
  await action("Enter","E6_GAME_SANDWICH_STEP"); // Assemble
  const secondDish=await action("Enter","E6_GAME_SANDWICH_STEP");
  check(secondDish.sandwich.item_id!==finished.sandwich.item_id &&
    secondDish.sandwich.stock.liver===600,
    "returning customer did not receive an independently cooked dish");
  await action("F7","E6_SANDWICH_TOGGLE");
  check((await action("g","E6_GAME_SERVE")).order_status==="delivered",
    "no authentic second-day item delivery");
  await action("g","E6_GAME_SERVE"); // Quote
  const paidTwo=await action("g","E6_GAME_SERVE"); // Settle
  check(paidTwo.money===3980 && paidTwo.order_payment==="settled",
    "two-day cashflow must equal 6000 - 2*1560 + 2*550");
  await saveDurably();
  await page.reload({waitUntil:"load"});
  const finalReplay=await until("E6_GAME_RESTORED",4);
  check(finalReplay.money===3980 && finalReplay.sandwich.stock.liver===600 &&
    finalReplay.order_payment==="settled" && finalReplay.sleep_count===1,
    "two-day save/play/reload lost revenue, stock or sleep count");
  check(errors.length===0,"Godot browser script failures");
  console.log("GAME_FIRST_SANDWICH_CHROMIUM_PASS: paid P5 stock, timed P3 turning, real Salma P4 delivery and 550 settlement, five hard reloads, including slept overnight and second real customer");
} finally {
  await context.close();
  await browser.close();
}
