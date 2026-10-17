import { chromium } from "playwright-core";
import crypto from "node:crypto";
import fs from "node:fs";
const base = process.argv[2] || "http://127.0.0.1:8767";
const output = process.argv[3] || "assets/v001/web-previews";
fs.mkdirSync(output,{recursive:true});
const browser = await chromium.launch({
  executablePath:process.env.CHROME_BINARY || "/usr/bin/google-chrome",
  headless:true,
  args:["--no-sandbox","--enable-webgl","--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader"]
});
const modes=[], errors=[], lamps=[];
let ready=false, moved=false;
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
try {
  const page=await browser.newPage({viewport:{width:960,height:540}});
  page.on("console",msg=>{
    const t=msg.text();
    if(t.includes("V001_BAKED_READY"))ready=true;
    if(t.includes("V001_FURNITURE_MOVED: chair"))moved=true;
    if(t.includes("V001_MODE:"))modes.push(t);
    if(t.includes("V001_LAMP:"))lamps.push(t);
    if(/SCRIPT ERROR:|V001_.*FAIL/.test(t))errors.push(t);
  });
  page.on("pageerror",err=>errors.push(err.message));
  await page.goto(base+"/index.html",{waitUntil:"load",timeout:30000});
  const deadline=Date.now()+30000;
  while(!ready && !errors.length && Date.now()<deadline)await sleep(150);
  if(!ready || errors.length)throw Error("Baked V001 sprites did not boot: "+JSON.stringify(errors));
  await page.locator("canvas").first().click({position:{x:480,y:260}});
  await sleep(500);
  async function shot(name){return await page.screenshot({path:output+"/"+name+".png"});}
  async function key(k){await page.keyboard.press(k);await sleep(400);}
  const room=await shot("roof_room_day");
  await key("n");
  const roofNight=await shot("roof_room_night_lamp_on");
  await key("l");
  const lampOff=await shot("roof_room_night_lamp_off");
  if(!lamps.some(x=>x.includes("false")))throw Error("Dynamic Godot lamp did not toggle");
  await key("e"); // roof room -> shared roof
  const roof=await shot("roof_night");
  await key("e"); // roof -> upper landing
  const landing=await shot("landing_night");
  if(!modes.some(x=>x.includes("V001_MODE: landing")))throw Error("Shared upper landing not reached");
  await key("r"); // QA only; real rent economy deferred
  await key("e"); // landing -> apartment
  const apartment=await shot("small_apartment_night");
  if(!modes.some(x=>x.includes("V001_MODE: apartment")))throw Error("Southern apartment not reached");
  await key("1");
  await key("g");
  if(!moved)throw Error("Furniture could not be moved in rented apartment");
  await shot("small_apartment_chair_moved");
  await key("n");
  const day=await shot("small_apartment_day");
  if(!modes.some(x=>x.includes("V001_MODE: apartment | night: false")))throw Error("Day change failed");
  function digest(data){return crypto.createHash("sha256").update(data).digest("hex");}
  if(digest(room)===digest(roofNight)||digest(roofNight)===digest(lampOff)||
      digest(landing)===digest(apartment)||digest(apartment)===digest(day))
    throw Error("Roof/light/landing/apartment snapshots visually identical");
  if(errors.length)throw Error("V001 runtime errors: "+JSON.stringify(errors));
  console.log("V001_REAL_WEB_ART_PASS: baked roof room, roof, opposing-door landing, rented south flat, dynamic lamp, furniture");
}finally{
  await browser.close();
}
