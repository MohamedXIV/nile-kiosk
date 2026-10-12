import { chromium } from "playwright-core";
import crypto from "node:crypto";
import fs from "node:fs";
const base = process.argv[2] || "http://127.0.0.1:8767";
const output = process.argv[3] || "assets/v001/web-previews";
fs.mkdirSync(output, { recursive: true });
const browser = await chromium.launch({
  executablePath: process.env.CHROME_BINARY || "/usr/bin/google-chrome",
  headless: true,
  args: ["--no-sandbox", "--enable-webgl", "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"]
});
let ready=false;
let moved=false;
const modes=[];
const errors=[];
try {
  const page=await browser.newPage({ viewport: {width:960,height:540}});
  page.on("console", msg=>{
    const t=msg.text();
    if(t.includes("V001_BAKED_READY")) ready=true;
    if(t.includes("V001_FURNITURE_MOVED: chair")) moved=true;
    if(t.includes("V001_MODE:")) modes.push(t);
    if(/SCRIPT ERROR:|V001_.*FAIL/.test(t)) errors.push(t);
  });
  page.on("pageerror",err=>errors.push(err.message));
  await page.goto(base+"/index.html",{waitUntil:"load",timeout:30000});
  const until=Date.now()+30000;
  while(!ready && !errors.length && Date.now()<until) await page.waitForTimeout(200);
  if(!ready || errors.length) throw Error("V001 Web didn't load baked sprites: "+JSON.stringify(errors));
  const canvas=page.locator("canvas").first();
  await canvas.click({position:{x:460,y:260},timeout:10000});
  await page.waitForTimeout(500);
  const before=await page.screenshot({path:output+"/street_day.png"});
  await page.keyboard.press("e");
  await page.waitForTimeout(350);
  await page.keyboard.press("e");
  await page.waitForTimeout(850);
  if(!modes.some(x=>x.includes("V001_MODE: apartment")))
    throw Error("V001 did not traverse lobby to apartment: "+JSON.stringify(modes));
  const apartmentDay=await page.screenshot({path:output+"/apartment_day.png"});
  await page.keyboard.press("1");
  await page.keyboard.press("g");
  await page.waitForTimeout(450);
  if(!moved) throw Error("V001 did not move furniture in live Web game");
  await page.screenshot({path:output+"/apartment_chair_moved.png"});
  await page.keyboard.press("n");
  await page.waitForTimeout(650);
  const night=await page.screenshot({path:output+"/apartment_night.png"});
  await page.keyboard.press("Backspace");
  await page.keyboard.press("Backspace");
  await page.waitForTimeout(800);
  if(!modes.some(x=>x.includes("V001_MODE: street"))) throw Error("V001 did not return to street");
  await page.screenshot({path:output+"/street_night.png"});
  function digest(x) {return crypto.createHash("sha256").update(x).digest("hex");}
  if(digest(apartmentDay)===digest(night)||digest(before)===digest(apartmentDay))
    throw Error("V001 art appears visually identical across modes/day-night");
  if(errors.length) throw Error("Web script errors: "+JSON.stringify(errors));
  console.log("V001_REAL_WEB_ART_PASS: loaded real baked sprites, street/lobby/apartment, furniture movement, night variant");
} finally {
  await browser.close();
}
