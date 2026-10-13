import { chromium } from "playwright-core";

// Exercises a REAL Godot Web user:// save followed by hard Chromium page reload.
const origin=process.argv[2] || "http://127.0.0.1:8765";
const browser=await chromium.launch({
  executablePath:process.env.CHROME_BINARY || "/usr/bin/google-chrome",
  headless:true,
  args:["--no-sandbox","--enable-webgl","--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader"]
});
const context=await browser.newContext({viewport:{width:1100,height:760}});
const page=await context.newPage();
const traces={fresh:[],choice:[],saved:[],restored:[],interjected:[]};
const errors=[];
const prefixes={
  fresh:"D001_WEB_FRESH",
  choice:"D001_WEB_CHOICE ",
  saved:"D001_WEB_SAVED ",
  restored:"D001_WEB_RESTORED ",
  interjected:"D001_WEB_INTERJECTED "
};
page.on("console",msg=>{
  const line=msg.text();
  for(const [kind,prefix] of Object.entries(prefixes)){
    if(line.startsWith(prefix)){
      const item=line.length>prefix.length?JSON.parse(line.slice(prefix.length)):{};
      traces[kind].push(item);
      console.log(line);
    }
  }
  if(/SCRIPT ERROR:|D001_WEB_.*FAILED|D001_WEB_.*TIMEOUT|D001_WEB_INVALID/.test(line)) errors.push(line);
});
page.on("pageerror",error=>errors.push(error.message));
function check(value,why){
  if(!value)throw new Error(why+" | traces="+JSON.stringify(traces)+" | errors="+JSON.stringify(errors));
}
async function until(predicate,why,timeout=15000){
  const limit=Date.now()+timeout;
  while(Date.now()<limit && errors.length===0){
    const result=predicate();
    if(result)return result;
    await page.waitForTimeout(80);
  }
  throw new Error("Timeout waiting for "+why+" | traces="+JSON.stringify(traces)+" | errors="+JSON.stringify(errors));
}
try{
  await page.goto(origin+"/ink/index.html",{waitUntil:"load",timeout:30000});
  await until(()=>traces.fresh.length,"new browser session");
  await page.locator("canvas").first().click({position:{x:480,y:260}});
  await page.keyboard.press("k");
  await page.keyboard.down("a");
  await page.waitForTimeout(650);
  await page.keyboard.up("a");
  const choice=await until(()=>traces.choice.at(-1),"real gated Ink choice");
  check(choice.match && choice.football==="choice","Original story was not in a gated interjection");
  await page.keyboard.press("p");
  const saved=await until(()=>traces.saved.at(-1),"Godot browser save");
  check(saved.football==="choice","Did not save pending choice");
  await page.waitForTimeout(1100); // give IndexedDB auto-flush time
  await page.reload({waitUntil:"load",timeout:30000});
  const restored=await until(()=>traces.restored.at(-1),"persistent Web reload",20000);
  check(restored.football==="choice" && restored.match,"Pending choice or knowledge lost after browser reload");
  check(restored.tick===saved.tick && restored.events===saved.events,"Event log or world tick changed during refresh");
  check(JSON.stringify(restored.position)===JSON.stringify(saved.position),"Player coordinates lost after refresh");
  await page.locator("canvas").first().click({position:{x:480,y:260}});
  await page.keyboard.press("1");
  await until(()=>traces.interjected.length,"interjection after hard reload",6500);
  await page.waitForTimeout(3100);
  await page.keyboard.press("p");
  const savedEnd=await until(()=>traces.saved.length>=2 && traces.saved.at(-1),"post-rejoin save");
  await page.waitForTimeout(1100);
  await page.reload({waitUntil:"load",timeout:30000});
  const finished=await until(()=>traces.restored.length>=2 && traces.restored.at(-1),"finished reload",20000);
  check(finished.football==="finished","Finished Ink conversation replayed after second reload");
  check(finished.rumor_fact_events<=1,"Rumor fact duplicated after refresh");
  check(finished.events===savedEnd.events,"Completed conversation events changed across reload");
  check(errors.length===0,"Chromium reported game errors");
  console.log("D001_BROWSER_REFRESH_PASS: genuine Ink save, mid-choice reload, interjection, completed reload, event idempotency");
}finally{
  await context.close();
  await browser.close();
}
