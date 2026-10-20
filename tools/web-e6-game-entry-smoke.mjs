import { chromium } from "playwright-core";
import { readFileSync } from "node:fs";
const monaMeeting = JSON.parse(readFileSync(new URL("../content/social/nile_mona_visit.v1.json", import.meta.url), "utf8")).meeting_point;
const sceneRooms = Object.fromEntries(JSON.parse(readFileSync(
  new URL("../content/navigation/nile_opening_routes.v1.json", import.meta.url),
  "utf8")).rooms.map(room => [room.id, room]));

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
  const match = /^((?:E6_GAME|E6_TRAVEL|E6_AUDIO|E6_HELP|E4_STORY|E4_NPC|E4_VISITOR)_[A-Z_]+) (\{.*\})$/.exec(line);
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
// Read-only presentation acceptance at real 960×540 Godot resolution.
function checkRoomFrame(state, label) {
  const room = sceneRooms[state.location];
  check(room && Number.isFinite(state.view_zoom) && state.view_zoom > 0 &&
    Number.isFinite(state.view_origin_x) && Number.isFinite(state.view_origin_y),
    label + " has no valid view frame");
  const projected = ([x,y]) => ({
    x: state.view_origin_x + (x-y)*1.36*state.view_zoom,
    y: state.view_origin_y + (x+y)*0.68*state.view_zoom
  });
  // Player-follow camera deliberately crops distant room corners; require
  // the *visible player* to stay inside the safe playfield instead of
  // enforcing the previous zoom-to-fit-whole-room camera.
  const visibleActor={x:state.camera_actor_x,y:state.camera_actor_y};
  check(Number.isFinite(visibleActor.x) && Number.isFinite(visibleActor.y) &&
    visibleActor.x >= 100 && visibleActor.x <= 860 &&
    visibleActor.y >= 114 && visibleActor.y <= 352,
    label + " player hidden behind interface in new follow camera");
  check(state.view_zoom >= 1.15,
    label + " camera shrunk back to unreadable full-room zoom");
  const origin=projected([0,0]),right=projected([18,0]),up=projected([0,18]);
  check(Math.abs((right.x-origin.x)+(up.x-origin.x))<0.02 &&
    Math.abs((right.y-origin.y)-(up.y-origin.y))<0.02,
    label + " isometric axes changed during camera follow");
  const actor = projected([state.x,state.y]);
  check(Math.abs(actor.x-state.view_actor_x) < 0.2 &&
    Math.abs(actor.y-state.view_actor_y) < 0.2,
    label + " avatar projection disagrees with canonical player position");
}
// P6 authored neighbor beats are 10 world-minutes apart with 5-minute
// visibility windows (content/social/nile_neighbors_conversation.v1.json).
// Room fades and actual movement cannot freeze P1 or hold NPC dialogue for us.
function checkAuthenticAmbient(state, label) {
  const minute = state.minute;
  const elapsed = minute - 1039;
  const beat = Math.floor(elapsed/10);
  const active = elapsed>=0 && beat<3 && elapsed%10<5;
  const speaker = ["salma","mahmoud","salma"][beat];
  // The NPC scheduler can have an active authored beat even when the player
  // cannot hear it: walls, distance and autonomous NPC movement still apply.
  if(state.ambient_npc!=="") {
    check(active && state.ambient_npc===speaker && state.ambient_beat===beat &&
      typeof state.ambient_line==="string" && state.ambient_line.length>0,
      label+" projected unearned or out-of-window NPC speech");
  } else {
    check(state.ambient_beat===-1 && state.ambient_line==="",
      label+" kept a stale ambient beat after the NPCs fell out of hearing");
  }
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
  check(initial.location === "roof" && initial.minute === 990 && initial.money === 6000, "not starter world");
  checkRoomFrame(initial,"fresh rooftop");
  check(initial.sound_enabled === true && initial.sound_room === "roof" && !initial.sound_kettle,
    "roof ambience not initialized in real playable scene");
  await press("0");
  const audioOff = await until("E6_AUDIO_TOGGLE",0);
  check(audioOff.sound_enabled === false && audioOff.sound_room === "roof", "mute did not affect ambient engine");
  await press("0");
  const audioOn = await until("E6_AUDIO_TOGGLE",1);
  check(audioOn.sound_enabled === true, "sound-on did not resume ambient engine");
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
  // Going straight to the shop is a player choice. Spending 12 minutes on
  // rooftop radio first can genuinely miss the first closed-demand slot.
  // Exercise radio use after the shift, without holding NPCs for this test.
  check(!placedRadio.bed_owned && !placedRadio.bed_placed, "bed gifted at boot");
  await press("t");
  const boughtBed = await until("E6_GAME_BED",0);
  check(boughtBed.bed_owned && !boughtBed.bed_placed && boughtBed.money === placedRadio.money - boughtBed.bed_price,
    "secondhand bed did not debit P5 ledger");
  check(boughtBed.mood === placedRadio.mood && boughtBed.rest === placedRadio.rest,
    "purchasing a bed gave free Mood/Rest");
  await press("t");
  const placedBed = await until("E6_GAME_BED",1);
  check(placedBed.bed_placed && placedBed.money === boughtBed.money, "bed placement failed or double-charged");
  await press("y");
  const storedBed = await until("E6_GAME_BED_STORE");
  check(!storedBed.bed_placed && storedBed.bed_owned, "stored bed still treated as placed");
  await press("t");
  const replacedBed = await until("E6_GAME_BED",2);
  check(replacedBed.bed_placed && replacedBed.money === boughtBed.money, "bed restore charged again");
  const fadeIndex=(traces.E6_TRAVEL_FADE_START||[]).length;
  await press("e");
  const fading=await until("E6_TRAVEL_FADE_START",fadeIndex);
  check(fading.location==="roof" && fading.x===175 && fading.y===70,
    "fade started after silently teleporting the canonical player");
  const landing = await until("E6_GAME_DOOR",0);
  check(landing.location === "landing" && landing.x===40,
    "real roof/landing portal must commit between fade-out and fade-in");
  checkRoomFrame(landing,"roof-to-landing");
  await moveDiagonal(1260);
  await press("e");
  const street = await until("E6_GAME_DOOR",1);
  check(street.location === "street", "landing/street portal");
  checkRoomFrame(street,"landing-to-street");
  await moveDiagonal(1230);
  await press("e");
  const kiosk = await until("E6_GAME_DOOR",2);
  check(kiosk.location === "kiosk" && kiosk.sound_room === "kiosk",
    "street/kiosk portal or location-based ambient transition missing");
  check(kiosk.minute >= street.minute+30 && kiosk.minute <= street.minute+33,
    "30 canonical travel minutes must elapse across street/kiosk portal");
  checkRoomFrame(kiosk,"street-to-kiosk");
  await moveDiagonal(520);
  await press("o");
  const opened = await until("E6_GAME_OPEN");
  check(opened.kiosk_open === true, "player did not open the kiosk");
  // Wait using genuine P1 time until the first authored evening exchange,
  // rather than baking the earlier rooftop-radio delay into the fixture.
  let waitCursor=(traces.E6_GAME_WAIT||[]).length;
  let firstAside;
  for (let i=0;i<9;i++) {
    await press("j");
    firstAside=await until("E6_GAME_WAIT",waitCursor++);
    if(firstAside.minute>=1039)break;
  }
  check(firstAside.minute >= 1039 && firstAside.minute <= 1050,
    "player could not reach the authored first evening exchange");
  checkAuthenticAmbient(firstAside,"first kiosk wait");
  await press("j");
  const silence = await until("E6_GAME_WAIT",waitCursor++);
  checkAuthenticAmbient(silence,"second kiosk wait");
  await press("j");
  const afterWait = await until("E6_GAME_WAIT",waitCursor++);
  check(afterWait.minute >= 1035 && afterWait.npc_mahmoud === "kiosk" && afterWait.order_status === "offered",
    "autonomous order did not appear");
  checkAuthenticAmbient(afterWait,"third kiosk wait");
  check(!afterWait.customer_reaction,
    "customer reaction was invented before any real tea delivery");
  // Chromium's J wait advances five full world minutes, so the two-minute
  // approach has already finished when the first polled offer is observed.
  check(afterWait.npc_mahmoud_mode === "counter" && afterWait.npc_mahmoud_x === 145 &&
    afterWait.npc_mahmoud_y === 85 && afterWait.npc_mahmoud_waypoints >= 3,
    "real customer didn't take a nontrivial Godot navigation route to the counter");
  await press("g");
  const accepted = await until("E6_GAME_SERVE",0);
  check(accepted.order_status === "accepted", "canonical customer order not accepted");
  await press("g");
  const teaStarted = await until("E6_GAME_SERVE",1);
  check(teaStarted.tea_action === "H" && teaStarted.tea_stage === "waiting", "tea did not request heat");
  await press("g");
  const blockedShortcut = await until("E6_GAME_SERVE",2);
  check(blockedShortcut.tea_stage === "waiting" && blockedShortcut.tea_action === "H" &&
    blockedShortcut.leaves_stock === teaStarted.leaves_stock && blockedShortcut.money === teaStarted.money &&
    blockedShortcut.active_order === teaStarted.active_order,
    "G shortcut bypassed hands-on tea");
  await press("u");
  const wrongPour = await until("E6_GAME_TEA_POUR",0);
  // The P1 real-time clock keeps running between browser key events. The
  // rejected gesture must preserve service/resources, not freeze world time.
  check(wrongPour.tea_stage === "waiting" && wrongPour.tea_action === "H" &&
    wrongPour.leaves_stock === teaStarted.leaves_stock && wrongPour.money === teaStarted.money &&
    wrongPour.active_order === teaStarted.active_order && wrongPour.order_status === "accepted",
    "incorrect first gesture changed cooking or resources");
  await press("h");
  const heated = await until("E6_GAME_TEA_HEAT",0);
  check(heated.tea_stage === "active" && heated.tea_ready_in > 0 && heated.sound_kettle,
    "real kettle heating did not activate contextual audio");
  // Godot Native asserts an immediate early H rejects without mutation.
  // The real browser advances world minutes while waiting for key/log updates,
  // so a second H isn't guaranteed to be premature by the time it is pressed.
  await press("j"); await until("E6_GAME_WAIT",waitCursor++);
  await press("h");
  const lifted = await until("E6_GAME_TEA_HEAT",1);
  check(lifted.tea_stage === "waiting" && lifted.tea_action === "U", "lifting kettle didn't advance canonical recipe");
  check(lifted.npc_mahmoud_mode === "counter" && lifted.npc_mahmoud_x === 145 &&
    lifted.npc_mahmoud_y === 85, "real NPC didn't reach physical counter");
  checkAuthenticAmbient(lifted,"heating NPC speech");
  await press("u");
  const poured = await until("E6_GAME_TEA_POUR",1);
  check(poured.tea_stage === "active", "pour action didn't begin P3 serving step");
  await press("j"); await until("E6_GAME_WAIT",waitCursor++);
  await press("u");
  const finishedTea = await until("E6_GAME_TEA_POUR",2);
  check(finishedTea.tea_stage === "" && finishedTea.order_status === "accepted" && !finishedTea.sound_kettle,
    "finished tea wasn't authentic prepared item for pending order");
  // Batch A adds an authored reconvergence beat at 17:39–17:44. It must
  // progress while cooking, then return to silence outside that exact window.
  const inClosingBeat = finishedTea.minute % 1440 >= 1059 && finishedTea.minute % 1440 < 1064;
  check(finishedTea.ambient_line === (inClosingBeat ? "Quiet or busy, we still have this bit of river." : ""),
    "independent conversation closing beat/silence disagrees with P1 time");
  check(finishedTea.tea_quality === "rough" && finishedTea.tea_quality_score >= 25 &&
    finishedTea.tea_quality_score < 60 && finishedTea.tea_quality_item.startsWith("item:play:c3:prep:"),
    "late player actions did not create a distinct real P3 tea quality");
  check(finishedTea.customer_reaction === "", "NPC reacted before actually receiving the tea");
  // Mahmoud initiates his own Ink greeting at genuine P4 delivery, without
  // pressing M/Talk. Observe the real authoring/clock, not a fake dialogue.
  const npcInitiatedIndex = (traces.E4_NPC_INITIATED || []).length;
  await press("g");
  const deliveredTea = await until("E6_GAME_SERVE",3);
  check(deliveredTea.order_status === "delivered" && deliveredTea.ambient_line === "" &&
    deliveredTea.customer_reaction_npc === "mahmoud" &&
    deliveredTea.customer_reaction.includes("strong") &&
    deliveredTea.customer_reaction_order === deliveredTea.active_order &&
    deliveredTea.customer_reaction_event.startsWith("evt:"),
    "NPC quality response not grounded in delivered real rough tea");
  check(deliveredTea.npc_mahmoud_mode === "returning" && deliveredTea.npc_mahmoud_x === 145,
    "customer snapped back before he left the counter");
  check(deliveredTea.mahmoud_invitation?.source_event_id === deliveredTea.customer_reaction_event &&
    deliveredTea.mahmoud_invitation?.initiator_npc_id === "mahmoud" &&
    deliveredTea.mahmoud_invite_near,
    "Mahmoud didn't originate a real proximity-gated call after HIS delivery");
  const npcChoices = await until("E4_NPC_INITIATED",npcInitiatedIndex);
  check(npcChoices.mahmoud_story_phase === "choice" &&
    npcChoices.mahmoud_story_choices?.length === 2 &&
    npcChoices.mahmoud_story_deadline > npcChoices.minute,
    "automatic NPC initiative did not commit the genuine timed Ink choices");
  const npcLine = await until("E4_NPC_LINE");
  check(npcLine.dialogue_text.includes("Before I go"),
    "NPC initiation did not speak the genuine authored Ink opening line");
  await press("2"); // Stable option ID order: busy, listen.
  const npcChoice = await until("E4_NPC_CHOICE");
  check(npcChoice.mahmoud_story_phase === "running", "accepting NPC dialogue didn't commit Ink choice");
  await press("Enter"); await until("E4_NPC_LINE",1);
  await press("Enter"); await until("E4_NPC_LINE",2);
  await press("Enter");
  const npcFinished = await until("E4_NPC_FINISHED");
  check(npcFinished.mahmoud_story_phase === "finished", "NPC-initiated story didn't finish");
  const deniedNpcIndex = (traces.E4_NPC_REJECTED || []).length;
  await press("m");
  const deniedNpc = await until("E4_NPC_REJECTED",deniedNpcIndex);
  check(deniedNpc.mahmoud_story_phase === "finished", "NPC conversation offered again after completion");
  // Approach the physical riverside quiet spot; spend authored time while
  // a real NPC has received his tea. No Mood/finance reward.
  await moveDiagonal(480);
  await press("q");
  const riverMoment = await until("E6_GAME_QUIET");
  check(riverMoment.quiet_count === 1 && riverMoment.last_quiet === "river_watch" &&
    riverMoment.order_status === "delivered", "quiet moment lost the delivered customer order");
  check(riverMoment.npc_mahmoud_mode === "standing" && riverMoment.npc_mahmoud_x === 200 &&
    riverMoment.npc_mahmoud_y === 110, "NPC couldn't return home as player enjoyed quiet moment");
  check(riverMoment.story_opportunities?.river_watch_reflection &&
    riverMoment.river_story_phase === "", "canonical Nile opportunity didn't unlock before the real conversation");
  check(riverMoment.npc_mona === "kiosk" &&
    ["visiting","arriving"].includes(riverMoment.npc_mona_mode),
    "nonbuyer Mona didn't arrive through the independent P1/P2 routine");
  check(riverMoment.player_knows_mona_visit === false,
    "Mona taught the player a fact before the authored conversation");
  // Q is a life.activity_done elapsed-time event. The explicitly-authored
  // opportunity listens to canonical time.advanced instead; the next real
  // world-time step must observe Mona's actual presence before offering Ink.
  const visitorClockIndex = (traces.E6_GAME_WAIT || []).length;
  await press("j");
  const visitorClock = await until("E6_GAME_WAIT",visitorClockIndex);
  check(visitorClock.npc_mona === "kiosk" &&
    visitorClock.npc_mona_mode === "visiting" &&
    visitorClock.story_opportunities?.mona_visits_salma &&
    !visitorClock.player_knows_mona_visit,
    "Mona opportunity didn't unlock on canonical time.advanced with player present");
  // The riverside rail is physically near Mona's P2/schedule-derived visit
  // spot. She is not an order: the player explicitly opts into her Ink story.
  const visitorStartedIndex = (traces.E4_VISITOR_STARTED || []).length;
  let visitorJoined = false;
  for (let attempt=0; attempt<12; attempt++) {
    const loading = (traces.E4_VISITOR_LOADING || []).length;
    const rejected = (traces.E4_VISITOR_REJECTED || []).length;
    await press("l");
    for(let i=0;i<35;i++) {
      if((traces.E4_VISITOR_STARTED || []).length > visitorStartedIndex || (traces.E4_VISITOR_LOADING || []).length > loading) {
        await until("E4_VISITOR_STARTED",visitorStartedIndex);visitorJoined=true;break;
      }
      if((traces.E4_VISITOR_REJECTED || []).length > rejected)break;
      await page.waitForTimeout(50);
    }
    if(visitorJoined)break;
    const latest=(traces.E4_VISITOR_REJECTED || []).at(-1);
    check(latest && !latest.player_knows_mona_visit && !latest.mona_visit_near,
      "Mona rejected a physically nearby player or leaked unheard knowledge");
    // Correct the actual player pose toward the authored, stationary meeting
    // point instead of assuming a timed walk ended within the hearing radius.
    const dx=monaMeeting[0]-latest.x, dy=monaMeeting[1]-latest.y;
    if(Math.abs(dy)>12)await nudgeY(dy>0);
    else if(dx>0)await moveDiagonal(155);
    else await walkBack(155);
  }
  check(visitorJoined,"could not approach Mona's actual visit pose");
  const visitorStarted = await until("E4_VISITOR_STARTED",visitorStartedIndex);
  check(visitorStarted.mona_story_phase === "running","Mona's visit didn't start a P6 story");
  await press("Enter");
  const visitorLine = await until("E4_VISITOR_LINE");
  check(visitorLine.player_knows_mona_visit && visitorLine.mona_story_phase === "running",
    "Mona's actual spoken Ink beat didn't teach canonical P2 knowledge");
  await press("Enter");
  const visitorWaiting = await until("E4_VISITOR_WAITING");
  check(visitorWaiting.mona_story_phase === "choice" && visitorWaiting.mona_story_choices?.length === 2,
    "Mona dialogue didn't expose real player options");
  await press("1");
  await until("E4_VISITOR_CHOICE");
  await press("Enter"); await until("E4_VISITOR_LINE",1);
  await press("Enter"); await until("E4_VISITOR_LINE",2);
  await press("Enter");
  const visitorFinished = await until("E4_VISITOR_FINISHED");
  check(visitorFinished.mona_story_phase === "finished", "Mona dialogue didn't reach canonical completion");
  const visitorRepeatIndex = (traces.E4_VISITOR_REJECTED || []).length;
  await press("l");
  await until("E4_VISITOR_REJECTED",visitorRepeatIndex);
  // Walk back towards Salma only as needed. The authored opportunity cannot
  // be started remotely from the riverside railing, even though it is unlocked.
  let conversationStarted = false;
  for (let attempt=0; attempt<9; attempt++) {
    const began = (traces.E4_STORY_STARTED || []).length;
    const loading = (traces.E4_STORY_LOADING || []).length;
    const rejected = (traces.E4_STORY_REJECTED || []).length;
    await press("n");
    for (let i=0; i<30; i++) {
      if ((traces.E4_STORY_STARTED || []).length > began) {
        conversationStarted = true;
        break;
      }
      if ((traces.E4_STORY_LOADING || []).length > loading) {
        await until("E4_STORY_STARTED", began);
        conversationStarted = true;
        break;
      }
      if ((traces.E4_STORY_REJECTED || []).length > rejected) break;
      await page.waitForTimeout(75);
    }
    if (conversationStarted) break;
    const latest = (traces.E4_STORY_REJECTED || []).at(-1);
    check(latest && Math.hypot(latest.x-125,latest.y-70) > 38,
      "Ink begin rejected when player was already near Salma");
    // NPC dialogue changes the elapsed world/play timing, so correct the
    // *actual* 2D pose towards Salma (125,70), not a repeated diagonal
    // wall-clock hold that can overshoot her at y=10.
    const dx = 125 - latest.x;
    const dy = 70 - latest.y;
    // One keyboard direction at a time avoids the transient diagonal
    // between sequential keydown events. Near Salma's table the prior
    // two-key correction bounced between (176,51) and (200,92).
    // W/A/S/D each produce an honest, collision-checked +/-12 world
    // step; never inject P2 position or teleport for this acceptance.
    const toward = dx < 0
      ? (dy >= 0 ? "a" : "w")
      : (dy >= 0 ? "s" : "d");
    await page.keyboard.down(toward);
    await page.waitForTimeout(155);
    await page.keyboard.up(toward);
  }
  check(conversationStarted, "player could not start real unlocked Salma Ink conversation");
  await press("Enter");
  const openingLine = await until("E4_STORY_LINE");
  check(openingLine.river_story_phase === "running", "Ink opening wasn't a canonical running session");
  await press("Enter");
  const pendingChoice = await until("E4_STORY_WAITING");
  check(pendingChoice.river_story_phase === "choice" &&
    pendingChoice.river_story_choices?.length === 2,
    "real Ink choices were not exposed to the player");
  // The existing save/reload below now proves a genuine **mid-choice**
  // InkPlayer cursor survives hard Chromium reload in the production scene.
  await press("p");
  const audioOffBeforeSave = (traces.E6_AUDIO_TOGGLE || []).length;
  await press("0");
  const disabledBeforeSave = await until("E6_AUDIO_TOGGLE",audioOffBeforeSave);
  check(!disabledBeforeSave.sound_enabled, "mute could not be selected before reload");
  const saved = await until("E6_GAME_SAVE");
  check(saved.order_status === "delivered" && saved.location === "kiosk", "save after customer delivery");
  // Godot Web syncs user:// into browser storage asynchronously; match established Chromium save gates.
  await page.waitForTimeout(1600);
  await page.reload({ waitUntil: "load" });
  const restored = await until("E6_GAME_RESTORED");
  checkRoomFrame(restored,"browser hard reload");
  check(restored.hunger === saved.hunger && restored.rest === saved.rest && restored.mood === saved.mood, "E2 needs lost on browser reload");
  check(!restored.sound_enabled && restored.sound_room === "kiosk",
    "sound-off preference/location was not restored after actual Chromium reload");
  check(restored.tea_quality === saved.tea_quality && restored.tea_quality_score === saved.tea_quality_score &&
    restored.tea_quality_item === saved.tea_quality_item,
    "E3 prepared cup quality changed after hard Chromium reload");
  check(restored.customer_reaction === saved.customer_reaction &&
    restored.customer_reaction_order === saved.customer_reaction_order &&
    restored.customer_reaction_event === saved.customer_reaction_event,
    "authored delivery response not reproduced by WorldKernel-backed Chromium reload");
  check(restored.npc_mahmoud_mode === saved.npc_mahmoud_mode &&
    restored.npc_mahmoud_x === saved.npc_mahmoud_x && restored.npc_mahmoud_y === saved.npc_mahmoud_y,
    "NPC position changed on Chromium hard reload");
  check(restored.digest === saved.digest && restored.bed_placed && restored.bed_owned &&
    restored.location === "kiosk" && restored.order_status === "delivered" && restored.quiet_count === 1 && restored.radio_uses === 0 && restored.radio_placed &&
    restored.river_story_phase === "choice" && restored.mahmoud_story_phase === "finished" && restored.mona_story_phase === "finished" && restored.player_knows_mona_visit, "browser reload lost game state or either canonical Ink story");
  await press("n");
  const resumedStory = await until("E4_STORY_RESUMED");
  check(resumedStory.river_story_phase === "choice" && resumedStory.river_story_choices?.length === 2,
    "restored InkPlayer didn't recover canonical player choices");
  await press("1"); // Sorted authored option IDs: city then rest.
  const selected = await until("E4_STORY_CHOICE");
  check(selected.river_story_phase === "running", "player decision didn't commit to WorldKernel");
  await press("Enter");
  await until("E4_STORY_LINE",1);
  await press("Enter");
  await until("E4_STORY_LINE",2);
  await press("Enter");
  const finishedStory = await until("E4_STORY_FINISHED");
  check(finishedStory.river_story_phase === "finished" &&
    finishedStory.story_opportunities?.river_watch_reflection,
    "Ink narrative didn't complete from one-shot canonical opportunity");
  const deniedIndex = (traces.E4_STORY_REJECTED || []).length;
  await press("n");
  const deniedRepeat = await until("E4_STORY_REJECTED",deniedIndex);
  check(deniedRepeat.river_story_phase === "finished", "finished dialogue repeated");
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
  await press("r");
  const listenedRadio = await until("E6_GAME_RADIO_LISTEN",1);
  check(listenedRadio.radio_uses === 1 && listenedRadio.quiet_count === 2 &&
    listenedRadio.last_quiet === "radio_listen" &&
    listenedRadio.minute >= backHome.minute + 12,
    "late radio use did not advance canonical P1 time and housing usage");
  check(listenedRadio.mood > backHome.mood,
    "actual local radio use had no positive contextual mood effect");
  await press("q");
  const rooftopMoment = await until("E6_GAME_QUIET",1);
  check(rooftopMoment.quiet_count === 3 && rooftopMoment.last_quiet === "roof_breeze" &&
    rooftopMoment.money === saved.money, "roof moment or no-reward boundary failed");
  await press("z");
  const slept = await until("E6_GAME_SLEEP");
  check(slept.day === 2 && slept.hour === 8 && slept.sleep_count === 1 && !slept.kiosk_open && slept.bed_placed && slept.rest >= rooftopMoment.rest,
    "player did not reach canonical next-day morning");
  await press("p");
  const morningSaved = await until("E6_GAME_SAVE",1);
  await page.waitForTimeout(1700);
  await page.reload({ waitUntil: "load" });
  const morningRestored = await until("E6_GAME_RESTORED",1);
  check(morningRestored.digest === morningSaved.digest && morningRestored.bed_placed && morningRestored.sleep_count === 1 && morningRestored.quiet_count === 3 && morningRestored.radio_uses === 1 &&
    morningRestored.location === "roof" && morningRestored.day === 2,
    "sleep/day save replay failed: " + JSON.stringify({
      saved:{revision:morningSaved.revision,digest:morningSaved.digest,minute:morningSaved.minute,day:morningSaved.day,radio_uses:morningSaved.radio_uses,quiet_count:morningSaved.quiet_count,save_storage_status:morningSaved.save_storage_status},
      restored:{revision:morningRestored.revision,digest:morningRestored.digest,minute:morningRestored.minute,day:morningRestored.day,radio_uses:morningRestored.radio_uses,quiet_count:morningRestored.quiet_count,sleep_count:morningRestored.sleep_count,bed_placed:morningRestored.bed_placed,location:morningRestored.location}}));
  // Exercise F1 only AFTER timed P1/P4 social beats and all core journey
  // assertions: a live-world help test must not alter scheduled-story timing.
  // F1 is a view-only help overlay in the actual Chromium game canvas.
  await press("F1");
  const help = await until("E6_HELP_TOGGLE", 0);
  check(help.help_visible && help.location === morningRestored.location &&
    help.money === morningRestored.money, "controls overlay changed the player world");
  const waitsBeforeHelp = (traces.E6_GAME_WAIT || []).length;
  await press("j");
  check((traces.E6_GAME_WAIT || []).length === waitsBeforeHelp,
    "help overlay allowed an invisible player action");
  await press("Escape");
  const helpDismissed = await until("E6_HELP_TOGGLE", 1);
  check(!helpDismissed.help_visible, "Esc did not dismiss help");
  await press("F1"); const helpAgain = await until("E6_HELP_TOGGLE", 2);
  check(helpAgain.help_visible, "F1 did not reopen help");
  await press("F1"); const helpClosed = await until("E6_HELP_TOGGLE", 3);
  check(!helpClosed.help_visible, "F1 did not close help");
  check(errors.length === 0, "browser errors");
  await page.screenshot({path:"/tmp/nile-e6-game-entry.png"});
  console.log("E4_NONBUYER_CHROMIUM_PASS: Mona independently visits without order, optional Ink speech learns P2 fact, choices and hard reload persist");
  console.log("E4_NPC_INITIATIVE_CHROMIUM_PASS: real delivered tea triggered Mahmoud invite; player consent, native Ink choice and no repeat persisted after hard reload");
  console.log("E4_STORY_CHROMIUM_PASS: real player-selected Salma Ink, branch, mid-choice hard Web reload, no repeat");
  console.log("E6_GAME_CHROMIUM_PASS: production entry, autonomous service, save/reload");
  console.log("E6_AMBIENCE_CHROMIUM_PASS: live roof/kiosk/kettle audio context, persistent mute and hard browser reload");
  console.log("E1_GAME_CHROMIUM_PASS: voluntary close, return home, canonical sleep, next day and hard Web reload");
  console.log("E1_QUIET_CHROMIUM_PASS: riverside and rooftop quiet moments, uninterrupted customer state and hard reload");
  console.log("E1_RADIO_CHROMIUM_PASS: purchase, place, listen, real P5 usage, scheduler and reload");
  console.log("E2_NEEDS_CHROMIUM_PASS: clock needs, no purchase buff, real leisure and hard reload");
  console.log("E2_HOME_BED_CHROMIUM_PASS: paid P5 bed, real placement/storage, no instant buff, next-day rest and reload");
  console.log("E3_TEA_HANDS_CHROMIUM_PASS: heat/lift/pour/finish real P3 preparation, wrong and early gesture rejected, G blocked, saved Web");
  console.log("E3_TEA_QUALITY_CHROMIUM_PASS: overdue kettle/pour reduces canonical item score, visual quality and hard browser replay");
  console.log("E3_CUSTOMER_REACTION_CHROMIUM_PASS: delivered rough cup triggers authored Mahmoud line, replays after hard Web reload");
  console.log("E4_COUNTER_VISIT_CHROMIUM_PASS: real P4 offer brings guest to counter, service returns him, hearing and rendering share pose and reload");
  console.log("E4_AMBIENT_EXCHANGE_CHROMIUM_PASS: Salma and Mahmoud exchange two incidental spatial remarks as the player cooks; silence and delivered-cup precedence");
} finally {
  await context.close();
  await browser.close();
}
