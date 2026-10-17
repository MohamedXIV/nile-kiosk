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
  const match = /^(E6_GAME_[A-Z]+) (\{.*\})$/.exec(line);
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
try {
  const base = process.argv[2] || "http://127.0.0.1:8765";
  await page.goto(base + "/game/index.html", { waitUntil: "load", timeout: 30000 });
  await page.locator("canvas").first().click({ position: {x:500,y:290} });
  const initial = await until("E6_GAME_READY");
  check(initial.location === "roof" && initial.minute === 1020 && initial.money === 6000, "not starter world");
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
  check(riverMoment.quiet_count === 1 && riverMoment.last_quiet === "river_watch" &&
    riverMoment.order_status === "accepted", "quiet moment lost the live customer order");
  await press("p");
  const saved = await until("E6_GAME_SAVE");
  check(saved.order_status === "accepted" && saved.location === "kiosk", "save after order acceptance");
  // Godot Web syncs user:// into browser storage asynchronously; match established Chromium save gates.
  await page.waitForTimeout(1600);
  await page.reload({ waitUntil: "load" });
  const restored = await until("E6_GAME_RESTORED");
  check(restored.digest === saved.digest && restored.location === "kiosk" && restored.order_status === "accepted" && restored.quiet_count === 1,
    "browser reload lost game state, pending order or location");
  await press("c");
  const closed = await until("E6_GAME_CLOSE");
  check(closed.kiosk_open === false && closed.location === "kiosk", "early voluntary close failed");
  // The river spot is deliberately farther from the exit than the counter.
  await walkBack(1400);
  await press("e");
  const backStreet = await until("E6_GAME_DOOR",3);
  check(backStreet.location === "street", "kiosk-to-street return");
  await walkBack(1400);
  await press("e");
  const backLanding = await until("E6_GAME_DOOR",4);
  check(backLanding.location === "landing", "street-to-landing return");
  await walkBack(1400);
  await press("e");
  const backHome = await until("E6_GAME_DOOR",5);
  check(backHome.location === "roof", "landing-to-home return");
  await press("q");
  const rooftopMoment = await until("E6_GAME_QUIET",1);
  check(rooftopMoment.quiet_count === 2 && rooftopMoment.last_quiet === "roof_breeze" &&
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
  check(morningRestored.digest === morningSaved.digest && morningRestored.sleep_count === 1 && morningRestored.quiet_count === 2 &&
    morningRestored.location === "roof" && morningRestored.day === 2, "sleep/day save replay failed");
  check(errors.length === 0, "browser errors");
  await page.screenshot({path:"/tmp/nile-e6-game-entry.png"});
  console.log("E6_GAME_CHROMIUM_PASS: production entry, autonomous service, save/reload");
  console.log("E1_GAME_CHROMIUM_PASS: voluntary close, return home, canonical sleep, next day and hard Web reload");
  console.log("E1_QUIET_CHROMIUM_PASS: riverside and rooftop quiet moments, uninterrupted customer state and hard reload");
} finally {
  await context.close();
  await browser.close();
}
