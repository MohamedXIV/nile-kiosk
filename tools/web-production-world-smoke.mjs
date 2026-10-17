import { chromium } from "playwright-core";
const browser = await chromium.launch({executablePath:process.env.CHROME_BINARY || "/usr/bin/google-chrome",headless:true,
 args:["--no-sandbox","--enable-webgl","--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader"]});
const context=await browser.newContext({viewport:{width:1100,height:760}});
const page=await context.newPage();
const markers=["READY","RESTORED","SAVED","SELECTED","DELIVERED","RENT_PAID","ADVANCED"];
const rows=Object.fromEntries(markers.map(x=>[x,[]]));
const errors=[];
page.on("console", msg=>{
 const line=msg.text();
 for(const m of markers)if(line.startsWith("P7_WEB_"+m+" ")){
   rows[m].push(JSON.parse(line.slice(8+m.length)));
   console.log(line);
 }
 if(/SCRIPT ERROR:|P7_WEB_.*FAILED|P7_WEB_INVALID_SAVE/.test(line))errors.push(line);
});
page.on("pageerror",e=>errors.push(e.message));
function check(v,reason){if(!v)throw new Error(reason+" "+JSON.stringify({rows,errors}));}
async function until(marker,index=0){
 for(let i=0;i<350;i++){
   if(rows[marker].length>index)return rows[marker].at(-1);
   if(errors.length)break;
   await page.waitForTimeout(75);
 }
 throw new Error("Missing "+marker+" "+JSON.stringify(errors));
}
async function press(key){
 await page.locator("canvas").first().click({position:{x:400,y:250}});
 await page.keyboard.press(key);
}
try{
 const base=process.argv[2] || "http://127.0.0.1:8765";
 await page.goto(base+"/production-world/index.html",{waitUntil:"load",timeout:30000});
 const start=await until("READY");
 check(start.version===10 && start.minute===12 && start.events>20,"Invalid integrated world");
 check(start.session_a==="choice" && start.session_b==="finished" && start.cook==="active" && start.order==="accepted","Not mid-activity");
 check(start.dues===1 && start.rumor_known===false && start.mona_heard && start.visitor_location==="kiosk","World integration missing");
 await press("p");
 const saved=await until("SAVED");
 check(saved.digest===start.digest,"Save mutated world");
 await page.waitForTimeout(1300);
 await page.reload({waitUntil:"load"});
 const resumed=await until("RESTORED");
 check(resumed.digest===saved.digest && resumed.session_a==="choice","Hard reload lost world state");
 await press("1");
 const picked=await until("SELECTED");
 check(picked.session_a==="finished" && picked.result_known,"Ink selection not committed");
 await press("e");
 const delivered=await until("DELIVERED");
 check(delivered.order==="delivered" && delivered.item==="used" && delivered.claim==="settled" && delivered.balance===1025,"Atomic service/ledger failed");
 await press("r");
 const rent=await until("RENT_PAID");
 check(rent.dues===0 && rent.flat_access && rent.balance===875,"Rent settlement failed");
 await press("t");
 const moved=await until("ADVANCED");
 check(moved.minute===18 && moved.visitor_location==="home","NPC schedule failed");
 await press("p");
 const saved2=await until("SAVED",1);
 await page.waitForTimeout(1300);
 await page.reload({waitUntil:"load"});
 const last=await until("RESTORED",1);
 check(last.digest===saved2.digest && last.balance===875 && last.session_a==="finished" && !last.rumor_known,"Duplicate effects on browser reload");
 await press("p");
 const repeated=await until("SAVED",2);
 check(repeated.revision===last.revision && repeated.digest===last.digest && errors.length===0,"Repeat save not idempotent");
 console.log("SYS_P7_CHROMIUM_PASS: full production world, native Ink, service, rent and schedule survived two real Web reloads");
}finally{await context.close();await browser.close();}
