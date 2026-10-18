extends SceneTree
const Game = preload("res://scripts/gameplay/game_entry.gd")
const Kernel = preload("res://scripts/core/world_kernel.gd")
const OFFER = "hoda:tea-introduction"
const FACT = "mahmoud:tea-supplier"
const SAVE = "user://e5-procurement-test.json"
const MARKET = "market:tea-collection"
var errors: Array[String] = []
var serial: int = 0
func _initialize() -> void: call_deferred("run")
func check(v: bool, message: String) -> void:
    if not v: errors.append(message); push_error(message)
func ok(r: Dictionary, label: String) -> void: check(r.get("ok",false),label+": "+str(r))
func cmd(g: RefCounted, kind: String, p: Dictionary, actor: String = "player") -> Dictionary:
    serial+=1
    return g.session.command("e5:test:"+str(serial),actor,kind,p)
func move(g: RefCounted,n: int) -> void:
    for i in range(n): ok(g.move_world(18,0),"walk")
func learn(g: RefCounted) -> void:
    move(g,1);ok(g.travel_near(),"roof exit");move(g,9);ok(g.travel_near(),"landing exit")
    move(g,9);ok(g.travel_near(),"street exit");move(g,4);ok(g.open_kiosk(),"open")
    ok(g.session.advance(19,"e5:first-visit"),"scheduled first visit")
    ok(g.service_near(),"accept");ok(g.service_near(),"prepare")
    ok(g.tea_action_near("H"),"heat");ok(g.wait_minutes(2),"two minutes");ok(g.tea_action_near("H"),"lift")
    ok(g.tea_action_near("U"),"pour");ok(g.wait_minutes(1),"pour time");ok(g.tea_action_near("U"),"finish")
    ok(g.service_near(),"deliver");ok(g.service_near(),"quote");ok(g.service_near(),"settle")
    ok(g.session.advance(2479-int(g.status()["minute"]),"e5:next-visit"),"return")
    g.memory_story_begin()
    for i in range(180):
        if g.memory_story_ready():break
        await process_frame
    ok(g.memory_story_begin(),"real returning conversation");ok(g.memory_story_next(),"remember")
    ok(g.memory_story_next(),"choice");ok(g.memory_story_choose("supplier"),"ask about stock")
    check(not g.session.world.player_knows(FACT),"choice alone granted unheard fact")
    ok(g.memory_story_next(),"hear supplier contact")
    check(g.session.world.player_knows(FACT),"real conversation did not teach supplier")
func rejected(g: RefCounted, kind: String, p: Dictionary, code: String, actor: String = "player") -> void:
    var before: String = JSON.stringify(g.session.world.view())
    var r: Dictionary = cmd(g,kind,p,actor)
    check(r.get("code","")==code,"expected "+code+" got "+str(r))
    check(JSON.stringify(g.session.world.view())==before,"rejected contract changed canonical state")
func fork_game(snapshot: Dictionary, label: String) -> RefCounted:
    var g: RefCounted = Game.new();ok(g.start("user://procurement-"+label+".json"),"fork shell")
    check(g.session.world.restore_snapshot(snapshot),"fork canonical evidence")
    return g
func run() -> void:
    if FileAccess.file_exists(SAVE):DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
    var g: RefCounted = Game.new();ok(g.start(SAVE),"boot")
    if not g.has_method("market_purchase"):
        check(false,"public production collection missing");g.dispose();done();return
    var raw: Dictionary = g.session.world.economy_view()["supply_offers"][MARKET]
    check(raw["required_fact"].is_empty(),"public option accidentally knowledge gated")
    var opening: Dictionary = g.session.world.view()
    rejected(g,"supply.purchase",{"offer_id":MARKET},"WRONG_LOCATION")
    move(g,1);ok(g.travel_near(),"roof exit");move(g,9);ok(g.travel_near(),"landing exit")
    move(g,9);ok(g.travel_near(),"street exit");move(g,4);ok(g.open_kiosk(),"open")
    var public_start: Dictionary = g.session.world.view()
    check(not g.session.world.player_knows(FACT),"public route test already knows contact")
    var leaves: int = g.status()["leaves_stock"]
    var money: int = g.status()["money"]
    var minute: int = g.status()["minute"]
    var rev: int = g.session.world.view()["sequence"]
    ok(cmd(g,"schedule.create",{"job_id":"procurement:clock","due_minute":minute+7,"priority":50,"topic":"procurement:proof","data":{},"every_minutes":0},"system:director"),"schedule actual elapsed proof")
    ok(g.market_purchase(),"public actual collection")
    check(g.status()["money"]==money-450 and g.status()["leaves_stock"]==leaves+30 and g.status()["minute"]==minute+40,"public route costs/time/stock")
    check(g.session.world.view()["needs"]["hunger"]==public_start["needs"]["hunger"]-(int((minute+40)/45)-int(minute/45)),"collection ignores needs")
    check(g.status()["offer_count"]>0,"unattended world schedule stopped")
    var fires: Array = g.session.world.scheduled_events_after(rev)
    var fire: Dictionary = {}
    for f in fires:
        if f["job_id"]=="procurement:clock":fire=f
    check(not fire.is_empty(),"elapsed scheduled firing missing")
    if not fire.is_empty():ok(cmd(g,"schedule.ack",{"consumer_id":"procurement:test","fire_id":fire["fire_id"]},"system:consumer"),"elapsed ACK")
    check(not g.status()["supplier_known"],"public purchase invents referral")
    rejected(g,"supply.purchase",{"offer_id":MARKET},"OFFER_RESOLVED")
    ok(g.save_game(),"market disk save")
    var bought: Dictionary = g.session.world.view();g.dispose();g=Game.new();ok(g.start(SAVE),"reload actual public route")
    check(Kernel._matches(g.session.world.view(),bought),"market replay mismatch")
    var second: Dictionary = raw.duplicate(true);second["offer_id"]="market:second-listing"
    ok(cmd(g,"supply.offer.register",second,"system:catalog"),"another listing same finite lot")
    rejected(g,"supply.purchase",{"offer_id":second["offer_id"]},"SUPPLY_OUT_OF_STOCK")
    second["offer_id"]="market:conflict";second["availability"]["stock_quantity"]=99
    rejected(g,"supply.offer.register",second,"SUPPLY_LOT_CONFLICT","system:catalog")
    g.dispose()
    # All failure/decline paths begin with the same real public world.
    for scenario in ["poor","before","late","closed","decline","empty","short","paused","duplicate"]:
        g=fork_game(public_start,scenario)
        if scenario=="poor":
            ok(cmd(g,"economy.pay",{"transaction_id":"procurement:spend","recipient_id":"world:vendors","amount_minor":g.status()["money"],"cause_id":"ordinary-expense"}),"real spend")
            rejected(g,"supply.purchase",{"offer_id":MARKET},"INSUFFICIENT_FUNDS")
        elif scenario=="before":
            ok(g.session.advance(1430,"procurement:before"),"next day before market opens")
            rejected(g,"supply.purchase",{"offer_id":MARKET},"OFFER_NOT_OPEN")
        elif scenario=="late":
            ok(g.session.advance(85,"procurement:late"),"late approach")
            rejected(g,"supply.purchase",{"offer_id":MARKET},"COLLECTION_TOO_LATE")
        elif scenario=="closed":
            ok(g.session.advance(120,"procurement:closed"),"wait to market closing")
            rejected(g,"supply.purchase",{"offer_id":MARKET},"OFFER_EXPIRED")
        elif scenario=="decline":
            var pre: Dictionary=g.status();ok(g.market_decline(),"decline public collection")
            check(g.status()["money"]==pre["money"] and g.status()["minute"]==pre["minute"] and g.status()["leaves_stock"]==pre["leaves_stock"],"decline mutated economy/time/stock")
            rejected(g,"supply.purchase",{"offer_id":MARKET},"OFFER_RESOLVED")
        elif scenario in ["empty","short"]:
            var limited: Dictionary=raw.duplicate(true);limited["offer_id"]="market:"+scenario;limited["availability"]["lot_id"]=limited["offer_id"]
            limited["availability"]["stock_quantity"]=0 if scenario=="empty" else 29
            ok(cmd(g,"supply.offer.register",limited,"system:catalog"),"finite authored short stock")
            rejected(g,"supply.purchase",{"offer_id":limited["offer_id"]},"SUPPLY_OUT_OF_STOCK")
        elif scenario=="paused":
            ok(cmd(g,"time.pause",{},"system:clock"),"pause")
            rejected(g,"supply.purchase",{"offer_id":MARKET},"PAUSED")
        else:
            var r: Dictionary=g.session.command("procurement:exact-id","player","supply.purchase",{"offer_id":MARKET});ok(r,"fixed ID purchase")
            var before: Dictionary=g.session.world.view()
            check(g.session.command("procurement:exact-id","player","supply.purchase",{"offer_id":MARKET})==r,"P0 retry not idempotent")
            check(Kernel._matches(before,g.session.world.view()),"retry double spent/stocked")
        rejected(g,"supply.purchase",{"offer_id":MARKET,"quantity":900},"INVALID_PAYLOAD")
        g.dispose()
    # Equivalent genuine earned-contact state, not fabricated player knowledge.
    if FileAccess.file_exists(SAVE):DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
    g=Game.new();ok(g.start(SAVE),"comparison boot");await learn(g)
    ok(g.session.advance(31,"procurement:afternoon-choice"),"real later departure decision")
    var equal: Dictionary=g.session.world.view();g.dispose()
    var delivery: RefCounted=fork_game(equal,"delivery")
    var collection: RefCounted=fork_game(equal,"collection")
    ok(delivery.referral_purchase(),"earned delivery")
    ok(collection.market_purchase(),"public alternative from same starting state")
    check(delivery.status()["money"]==collection.status()["money"]-100,"delivery fee not measurable")
    check(collection.status()["minute"]==delivery.status()["minute"]+25,"collection time tradeoff not measurable")
    check(collection.status()["leaves_stock"]==delivery.status()["leaves_stock"],"unequal goods comparison")
    check(delivery.session.world.npc("mona")["location_id"]=="kiosk" and collection.session.world.npc("mona")["location_id"]!="kiosk","long trip must miss actual independent Mona visit")
    var receipt: Dictionary=collection.session.world.economy_view()["supply_resolutions"][MARKET]
    var tx: Dictionary=collection.session.world.economy_view()["transactions"][receipt["transaction_id"]]
    check(tx["amount_minor"]==450 and receipt["knowledge_event_id"].is_empty(),"public audited provenance wrong")
    var tamper: Dictionary=collection.session.world.view();tamper["economy"]["supply_resolutions"][MARKET]["quantity"]=999
    check(not Kernel.new().restore_snapshot(tamper),"forged market goods replayed")
    check(Kernel.new().restore_snapshot(collection.session.world.view()),"comparison collection replay")
    delivery.dispose();collection.dispose();done()
func done() -> void:
    if errors.is_empty(): print("E5 PROCUREMENT: PASS");quit(0)
    else: print("E5 PROCUREMENT: FAIL "+str(errors.size()));quit(1)
