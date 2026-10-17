import { chromium } from "playwright-core";

// E6/P0: launch the real default scene (not D001 or QA), navigate, and reload.
const browser = await chromium.launch({
  executablePath: process.env.CHROME_BINARY || "/usr/bin/google-chrome",
  headless: true,
  args: ["--no-sandbox", "--enable-webgl", "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"]
});
const context = await browser.newContext({ viewport: { width: 1100, height: 760 } });
const page = await context.newPage();
const traces = {};
const errors = [];
page.on("console", message => {
  const line = message.text();
  const match = /^(E6_GAME_[A-Z_]+) (\{.*\})$/.exec(line);
  if (match) {
    try {
      (traces[match[1]] ??= []).push(JSON.parse(match[2]));
      console.log(line);
    } catch (e) { errors.push("Malformed game status: " + String(e)); }
  }
  if (/SCRIPT ERROR:|Parse Error:|E6_GAME_BOOT_FAILED/.test(line)) errors.push(line);
});
page.on("pageerror", e => errors.push(e.message));
function check(ok, msg) {
  if (!ok) throw new Error(msg + " " + JSON.stringify({ traces, errors }));
}
async function until(marker, index=0) {
  for (let i=0; i<220; i++) {
    if ((traces[marker] || []).length > index) return traces[marker][index];
    if (errors.length) break;
    await page.waitForTimeout(75);
  }
  throw new Error("Missing "+marker+" #"+index+"; "+JSON.stringify(errors));
}
async function moveDiagonal(ms) {
  await page.keyboard.down("s");
  await page.keyboard.down("d");
  await page.waitForTimeout(ms);
  await page.keyboard.up("s");
  await page.keyboard.up("d");
}
async function press(key) { await page.keyboard.press(key); }
async function walkBack(ms) {
  await page.keyboard.down("w");
  await page.keyboard.down("a");
  await page.waitForTimeout(ms);
  await page.keyboard.up("a");
  await page.keyboard.up("w");
}
async function nudgeY(towardsPositive) {
  // S+A follows world +Y, W+D world -Y in the fixed 2:1 controls.
  const keys = towardsPositive ? ["s","a"] : ["w","d"];
  await page.keyboard.down(keys[0]);
  await page.keyboard.down(keys[1]);
  await page.waitForTimeout(160);
  await page.keyboard.up(keys[1]);
  await page.keyboard.up(keys[0]);
}
async function walkBackThroughDoor(destination, doorwayX) {
  // Timed key-holds are frame-rate-dependent in Chromium; don't assume a
  // 1400 ms walk lands precisely within the 38-unit world portal radius.
  await walkBack(1060);
  for (let attempt=0; attempt<9; attempt++) {
    const index = (traces.E6_GAME_DOOR || []).length;
    await press("e");
    const seen = await until("E6_GAME_DOOR", index);
    if (seen.location === destination) return seen;
    const dx = doorwayX - seen.x;
    const dy = 70 - seen.y;
    if (Math.abs(dy) > 20) await nudgeY(dy > 0);
    else if (Math.abs(dx) > 8) {
      if (dx > 0) await moveDiagonal(155);
      else await walkBack(155);
    } else {
      // Within the axis tolerances but just outside a circular doorway.
      await nudgeY(dy > 0);
    }
  }
  throw new Error("Could not traverse return doorway to " + destination);
}
try {
  const base = process.argv[2] || "http://127.0.0.1:8765";
  await page.goto(base + "/game/index.html", { waitUntil: "load", timeout: 30000 });
  await page.locator("canvas").first().click({ position: {x:500,y:290} });
  const initial = await until("E6_GAME_READY");
  check(initial.location === "roof" && initial.minute === 1020 && initial.money === 6000, "not starter world");
  check(initial.radio_owned === false && initial.radio_uses === 0, "radio gifted before purchase");
  check(initial.hunger < 75 && initial.rest < 80 && initial.mood >= 25, "E2 needs not driven by actual opening clock");
  await press("r");
  const unavailableRadio = await until("E6_GAME_RADIO_LISTEN",0);
  check(unavailableRadio.radio_uses === 0 && unavailableRadio.minute === initial.minute, "phantom radio play");
  await press("b");
  const acquiredRadio = await until("E6_GAME_RADIO_BUY");
  check(acquiredRadio.money === 4800 && acquiredRadio.radio_owned && !acquiredRadio.radio_placed, "real P5 purchase/ledger");
  check(acquiredRadio.mood === initial.mood, "radio purchase granted free E2 mood");
  await press("v");
  const placedRadio = await until("E6_GAME_RADIO_PLACE");
  check(placedRadio.radio_placed && placedRadio.money === 4800, "radio not placed in home");
  await press("r");
  const listenedRadio = await until("E6_GAME_RADIO_LISTEN",1);
  check(listenedRadio.radio_uses === 1 && listenedRadio.quiet_count === 1 &&
    listenedRadio.last_quiet === "radio_listen" && listenedRadio.minute === 1032,
    "radio use did not advance canonical time and housing usage");
  check(listenedRadio.mood > placedRadio.mood, "actual radio use has no contextual E2 effect");
  await press("e");
  const landing = await until("E6_GAME_DOOR",0);
  check(landing.location === "landing", "roof/landing portal");
  await moveDiagonal(1260);
  await press("e");
  const street = await until("E6_GAME_DOOR",1);
  check(street.location === "street", "landing/street portal");
  await moveDiagonal(1230);
  await press("e");
  const kiosk = await until("E6_GAME_DOOR",2);
  check(kiosk.location === "kiosk", "street/kiosk portal");
  await moveDiagonal(520);
  await press("o");
  const opened = await until("E6_GAME_OPEN");
  check(opened.kiosk_open === true, "player did not open the kiosk");
  await press("j"); await until("E6_GAME_WAIT",0);
  await press("j"); await until("E6_GAME_WAIT",1);
  await press("j");
  const afterWait = await until("E6_GAME_WAIT",2);
  check(afterWait.minute >= 1035 && afterWait.npc_mahmoud === "kiosk" && afterWait.order_status === "offered", "autonomous order did not appear");
  await press("g");
  const accepted = await until("E6_GAME_SERVE",0);
  check(accepted.order_status === "accepted", "canonical customer order not accepted");
  // Approach the physical riverside quiet spot; spend authored time while
  // a real NPC has an accepted order. No fake Mood/finance reward.
  await moveDiagonal(480);
  await press("q");
  const riverMoment = await until("E6_GAME_QUIET");
  check(riverMoment.quiet_count === 2 && riverMoment.last_quiet === "river_watch" &&
    riverMoment.order_status === "accepted", "quiet moment lost the live customer order");
  await press("p");
  const saved = await until("E6_GAME_SAVE");
  check(saved.order_status === "accepted" && saved.location === "kiosk", "save after order acceptance");
  // Godot Web syncs user:// into browser storage asynchronously; match established Chromium save gates.
  await page.waitForTimeout(1600);
  await page.reload({ waitUntil: "load" });
  const restored = await until("E6_GAME_RESTORED");
  check(restored.hunger === saved.hunger && restored.rest === saved.rest && restored.mood === saved.mood, "E2 needs lost on browser reload");
  check(restored.digest === saved.digest && restored.location === "kiosk" && restored.order_status === "accepted" && restored.quiet_count === 2 && restored.radio_uses === 1 && restored.radio_placed,
    "browser reload lost game state, pending order or location");
  await press("c");
  const closed = await until("E6_GAME_CLOSE");
  check(closed.kiosk_open === false && closed.location === "kiosk", "early voluntary close failed");
  // Use live portal-travel feedback to correct small frame-rate differences
  // rather than relying on a wall-clock hold to hit three narrow doorways.
  const backStreet = await walkBackThroughDoor("street", 35);
  check(backStreet.location === "street", "kiosk-to-street return");
  const backLanding = await walkBackThroughDoor("landing", 40);
  check(backLanding.location === "landing", "street-to-landing return");
  const backHome = await walkBackThroughDoor("roof", 35);
  check(backHome.location === "roof", "landing-to-home return");
  await press("q");
  const rooftopMoment = await until("E6_GAME_QUIET",1);
  check(rooftopMoment.quiet_count === 3 && rooftopMoment.last_quiet === "roof_breeze" &&
    rooftopMoment.money === saved.money, "roof moment or no-reward boundary failed");
  await press("z");
  const slept = await until("E6_GAME_SLEEP");
  check(slept.day === 2 && slept.hour === 8 && slept.sleep_count === 1 && !slept.kiosk_open,
    "player did not reach canonical next-day morning");
  await press("p");
  const morningSaved = await until("E6_GAME_SAVE",1);
  await page.waitForTimeout(1700);
  await page.reload({ waitUntil: "load" });
  const morningRestored = await until("E6_GAME_RESTORED",1);
  check(morningRestored.digest === morningSaved.digest && morningRestored.sleep_count === 1 && morningRestored.quiet_count === 3 && morningRestored.radio_uses === 1 &&
    morningRestored.location === "roof" && morningRestored.day === 2, "sleep/day save replay failed");
  check(errors.length === 0, "browser errors");
  await page.screenshot({path:"/tmp/nile-e6-game-entry.png"});
  console.log("E6_GAME_CHROMIUM_PASS: production entry, autonomous service, save/reload");
  console.log("E1_GAME_CHROMIUM_PASS: voluntary close, return home, canonical sleep, next day and hard Web reload");
  console.log("E1_QUIET_CHROMIUM_PASS: riverside and rooftop quiet moments, uninterrupted customer state and hard reload");
  console.log("E1_RADIO_CHROMIUM_PASS: purchase, place, listen, real P5 usage, scheduler and reload");
  console.log("E2_NEEDS_CHROMIUM_PASS: clock needs, no purchase buff, real leisure and hard reload");
} finally {
  await context.close();
  await browser.close();
}
