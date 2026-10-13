import { chromium } from "playwright-core";

// Real QA Godot Web scene, actual keyboard-driven P3/P4/P5 actions, real saves.
const browser = await chromium.launch({executablePath:process.env.CHROME_BINARY || "/usr/bin/google-chrome",
  headless:true,args:["--no-sandbox","--enable-webgl","--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader"]});
const context = await browser.newContext({viewport:{width:1100,height:760}});
const page = await context.newPage();
const marks = ["PLAY_C1_READY","PLAY_C1_RESTORED","PLAY_C1_TRAVEL","PLAY_C1_SAVED","PLAY_C1_TIME",
  "PLAY_C3_OFFERED","PLAY_C3_ACTION","PLAY_C3_BLOCKED","PLAY_C3_DENIED"];
const traces = Object.fromEntries(marks.map(x=>[x,[]]));
const errors=[];
page.on("console",msg=>{
  const s=msg.text();
  for(const m of marks) if(s.startsWith(m+" ")){
    try {const value=JSON.parse(s.slice(m.length+1));traces[m].push(value);console.log(s);}
    catch(e){errors.push("BAD_TRACE: "+String(e));}
  }
  if(/SCRIPT ERROR:|PLAY_C1_.*FAILED|PLAY_C3_.*FAILED/.test(s))errors.push(s);
});
page.on("pageerror",err=>errors.push(err.message));
function check(x,why){if(!x)throw new Error(why+" "+JSON.stringify({traces,errors}));}
async function until(marker,index=0){
  for(let i=0;i<460;i++){
    if(traces[marker].length>index)return traces[marker][index];
    if(errors.length)break;
    await page.waitForTimeout(75);
  }
  throw new Error("Expected "+marker+" #"+index+" errors="+JSON.stringify(errors));
}
async function press(key){await page.keyboard.press(key);}
async function walk(key,n){for(let i=0;i<n;i++)await press(key);}
async function act(index,kind){
  await press("g");
  const v=await until("PLAY_C3_ACTION",index);
  check(v.order_status!=="none","missing active order during "+kind);
  return v;
}
try {
  await page.goto((process.argv[2]||"http://127.0.0.1:8765")+"/play-c1/index.html",{waitUntil:"load",timeout:30000});
  await page.locator("canvas").first().click({position:{x:480,y:245}});
  const initial=await until("PLAY_C1_READY");
  check(initial.location==="roof" && initial.money===300,"C0 world not ready");
  await press("e");await until("PLAY_C1_TRAVEL",0);
  await walk("d",9);await press("e");await until("PLAY_C1_TRAVEL",1);
  await walk("d",9);await press("e");await until("PLAY_C1_TRAVEL",2);
  await walk("d",3);
  await press("o");
  const offered=await until("PLAY_C3_OFFERED");
  check(offered.location==="kiosk" && offered.x===99 && offered.order_status==="offered","NPC offer incorrect");
  const accepted=await act(0,"accept");
  check(accepted.order_status==="accepted","order not accepted");
  const preparing=await act(1,"start");
  check(preparing.job_stage==="waiting","cook job not started");
  const first=await act(2,"begin");
  check(first.job_stage==="active" && first.job_step===0,"first station not active");
  await press("g");
  const notReady=await until("PLAY_C3_BLOCKED");
  check(notReady.job_stage==="active","prematurely finished station");
  await press("p");
  const saved=await until("PLAY_C1_SAVED");
  check(saved.digest===first.digest && saved.job_stage==="active","save altered active prep");
  await page.waitForTimeout(1400);
  await page.reload({waitUntil:"load",timeout:30000});
  const restored=await until("PLAY_C1_RESTORED");
  check(restored.digest===saved.digest && restored.x===99 && restored.order_status==="accepted" &&
    restored.job_stage==="active","mid-cook state or XY lost in hard reload");
  await press("t");await until("PLAY_C1_TIME",0);
  const afterHeat=await act(3,"finish");
  check(afterHeat.job_stage==="waiting" && afterHeat.job_step===1,"wrong first recipe step");
  const serving=await act(4,"serve");
  check(serving.job_stage==="active" && serving.job_step===1,"second station not active");
  await press("t");await until("PLAY_C1_TIME",1);
  const cooked=await act(5,"finish");
  check(cooked.job_stage==="completed" && cooked.item_status==="ready","prepared item missing");
  const delivered=await act(6,"deliver");
  check(delivered.order_status==="delivered" && delivered.item_status==="used" &&
    delivered.money===300,"delivery didn't use item or minted cash");
  const quoted=await act(7,"quote");
  check(quoted.money===300 && quoted.payment_status==="awaiting_ledger","quote minted money");
  const settled=await act(8,"settle");
  check(settled.payment_status==="settled" && settled.money===317,"authored price not journaled once");
  await press("p");
  const saved2=await until("PLAY_C1_SAVED",1);
  await page.waitForTimeout(1400);
  await page.reload({waitUntil:"load",timeout:30000});
  const final=await until("PLAY_C1_RESTORED",1);
  check(final.digest===saved2.digest && final.money===317 && final.payment_status==="settled" &&
    final.item_status==="used" && final.order_status==="delivered","settled reload duplicated money or events");
  await press("g");
  const exhausted=await until("PLAY_C3_BLOCKED",1);
  check(exhausted.revision===final.revision,"finished order spawned another step");
  await press("p");
  const repeated=await until("PLAY_C1_SAVED",2);
  check(repeated.revision===final.revision && repeated.digest===final.digest && errors.length===0,
    "repeat save mutated canonical world");
  console.log("PLAY_C3_CHROMIUM_PASS: real NPC offer, multi-step cooking, mid-cook reload, delivery/ledger settlement and second reload");
} finally {await context.close();await browser.close();}
