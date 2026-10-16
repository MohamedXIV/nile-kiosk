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
  await press("j"); await until("E6_GAME_WAIT",0);
  await press("j"); await until("E6_GAME_WAIT",1);
  await press("j");
  const afterWait = await until("E6_GAME_WAIT",2);
  check(afterWait.minute >= 1035 && afterWait.npc_mahmoud === "kiosk" && afterWait.order_status === "offered", "autonomous order did not appear");
  await press("g");
  const accepted = await until("E6_GAME_SERVE",0);
  check(accepted.order_status === "accepted", "canonical customer order not accepted");
  await press("p");
  const saved = await until("E6_GAME_SAVE");
  check(saved.order_status === "accepted" && saved.location === "kiosk", "save after order acceptance");
  // Godot Web syncs user:// into browser storage asynchronously; match established Chromium save gates.
  await page.waitForTimeout(1600);
  await page.reload({ waitUntil: "load" });
  const restored = await until("E6_GAME_RESTORED");
  check(restored.digest === saved.digest && restored.location === "kiosk" && restored.order_status === "accepted",
    "browser reload lost game state, pending order or location");
  check(errors.length === 0, "browser errors");
  await page.screenshot({path:"/tmp/nile-e6-game-entry.png"});
  console.log("E6_GAME_CHROMIUM_PASS: production entry, spatial travel, autonomous order, real acceptance, save/reload");
} finally {
  await context.close();
  await browser.close();
}
