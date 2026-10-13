extends SceneTree
## PLAY C3 — actual C0/C2 world service loop, mid-cooking disk reload and ledger.
const Session = preload("res://scripts/integration/world_session.gd")
const Play = preload("res://scripts/integration/kiosk_service_play.gd")
const SAVE = "user://nk-play-c3-test.json"
var errors: Array[String] = []

func _initialize() -> void:
    _run()
    if errors.is_empty():
        print("PLAY C3: PASS (proximity, authored NPC offer, multi-step cooking, exact-once ledger and reload)")
        quit(0)
    else:
        for e in errors: push_error(e)
        print("PLAY C3: FAIL (%d)"%errors.size())
        quit(1)

func check(value: bool, name: String) -> void:
    if not value: errors.append(name)

func action(s: RefCounted, kind: String) -> void:
    var next: Dictionary = Play.next_action(s,"kiosk")
    check(next.get("kind","") == kind, "expected next action "+kind+" got "+JSON.stringify(next))
    var performed: Dictionary = Play.perform_next(s,"kiosk")
    check(performed.get("ok",false) and performed.get("kind","")==kind,"cannot perform "+kind+": "+JSON.stringify(performed))

func walk(s: RefCounted, id: String, dx: int) -> void:
    check(s.command("c3:"+id,"player","spatial.player.move",{"dx":dx,"dy":0}).get("ok",false),id)

func portal(s: RefCounted, id: String) -> void:
    check(s.command("c3:"+id,"player","spatial.player.travel",{"portal_id":id}).get("ok",false),id)

func _run() -> void:
    if FileAccess.file_exists(SAVE): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
    var s=Session.new(73,SAVE)
    check(s.bootstrap_from_content("res://content/world/qa_nile_kiosk.v1.json").get("ok",false),"catalog bootstrap")
    check(s.configure_navigation("res://content/navigation/qa_routes.v1.json").get("ok",false),"navigation")
    var parsed: Dictionary = Play.load_packaged("res://content/service/qa_customer_intents.v1.json")
    check(parsed.get("ok",false),"QA intent source")
    if not parsed.get("ok",false): return
    var intent: Dictionary = parsed["intents"]["qa:amina:tea:first"]
    var forged: Dictionary = {"schema":1,"intents":[intent.duplicate(true),intent.duplicate(true)]}
    check(Play.validate_manifest(forged)["code"]=="INVALID_INTENT","duplicate customer intent accepted")
    forged = {"schema":1,"intents":[intent.duplicate(true)]}
    forged["intents"][0]["wait_minutes"] = -10
    check(Play.validate_manifest(forged)["code"]=="INVALID_INTENT","negative deadline accepted")
    check(Play.load_packaged("user://hacked-intents.json")["code"]=="UNTRUSTED_INTENTS","untrusted file allowed")
    check(Play.next_action(s,"kiosk")["code"]=="PLAYER_ABSENT","service from roof")
    check(Play.offer(s,intent)["code"]=="PLAYER_ABSENT","NPC offer from rooftop")
    portal(s,"roof_to_landing")
    for i in range(9): walk(s,"landing:"+str(i),18)
    portal(s,"landing_to_street")
    for i in range(9): walk(s,"street:"+str(i),18)
    portal(s,"street_to_kiosk")
    check(Play.offer(s,intent)["code"]=="CUSTOMER_NOT_NEARBY","remote customer trigger")
    check(Play.perform_next(s,"kiosk")["code"]=="NO_ACTIVE_ORDER","invented no-order work")
    var before: String=JSON.stringify(s.world.view())
    for i in range(3): walk(s,"kiosk:"+str(i),18)
    var receipt: Dictionary=Play.offer(s,intent)
    check(receipt.get("ok",false),"NPC customer offered from real proximity")
    check(Play.offer(s,intent)["code"]=="ORDER_EXISTS","duplicate order intent")
    check(s.world.balance_minor()==300,"funds before cooking")
    check(s.world.order(intent["order_id"])["status"]=="offered","offered status")
    action(s,"order.accept")
    action(s,"cook.start")
    action(s,"cook.step.begin")
    check(Play.perform_next(s,"kiosk")["code"]=="STEP_NOT_READY","step finished without time")
    var saved: Dictionary=s.world.view()
    check(s.save().get("ok",false),"save during cooking")
    var loaded=Session.new(4,SAVE)
    check(loaded.load_existing().get("code")=="RESTORED","restore active recipe")
    check(JSON.stringify(loaded.world.view())==JSON.stringify(saved),"mid-prep world mismatch")
    check(loaded.world.spatial_view()["player"]["x"]==99,"canonical XY lost during cook")
    check(loaded.world.order(intent["order_id"])["status"]=="accepted","accepted order lost")
    check(loaded.world.cooking_view()["preparations"]["play:c3:prep:"+intent["order_id"]]["stage"]=="active","active cook job lost")
    check(loaded.advance(5,"c3:time:5").get("ok",false),"advance five")
    action(loaded,"cook.step.finish")
    action(loaded,"cook.step.begin")
    check(Play.perform_next(loaded,"kiosk")["code"]=="STEP_NOT_READY","second step finished early")
    check(loaded.advance(5,"c3:time:10").get("ok",false),"advance ten")
    action(loaded,"cook.step.finish")
    check(loaded.world.prepared_item("item:play:c3:prep:"+intent["order_id"])["status"]=="ready","prepared consumable missing")
    action(loaded,"order.deliver")
    check(loaded.world.prepared_item("item:play:c3:prep:"+intent["order_id"])["status"]=="used","delivery didn't claim item")
    check(loaded.world.balance_minor()==300,"delivery minted money without claim")
    action(loaded,"economy.order.quote")
    check(loaded.world.balance_minor()==300,"quote minted money")
    action(loaded,"economy.order.settle")
    check(loaded.world.balance_minor()==317,"price not paid from authored C0 ledger")
    check(loaded.world.order(intent["order_id"])["payment_status"]=="settled","claim unpaid")
    check(Play.perform_next(loaded,"kiosk")["code"]=="NO_ACTIVE_ORDER","already-paid order repeated")
    check(loaded.world.cooking_view()["stock"]["leaves"]==21,"ingredient stock not consumed")
    check(loaded.world.cooking_view()["stock"]["paper_cup"]==11,"serving input not consumed")
    var finished: Dictionary=loaded.world.view()
    check(loaded.save().get("ok",false),"save settled world")
    var final=Session.new(7,SAVE)
    check(final.load_existing().get("code")=="RESTORED","settled world reload")
    check(JSON.stringify(final.world.view())==JSON.stringify(finished),"settled world duplicated replay")
    check(final.world.balance_minor()==317,"settlement duplicated on load")
    check(final.save().get("ok",false),"repeat save")
    check(JSON.stringify(final.world.view())==JSON.stringify(finished),"repeat save appended events")
    if FileAccess.file_exists(SAVE): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
