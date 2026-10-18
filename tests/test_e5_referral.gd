extends SceneTree
const Game = preload("res://scripts/gameplay/game_entry.gd")
const Kernel = preload("res://scripts/core/world_kernel.gd")
const OFFER = "hoda:tea-introduction"
const FACT = "mahmoud:tea-supplier"
const SAVE = "user://e5-referral-test.json"
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
func run() -> void:
    if FileAccess.file_exists(SAVE):DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
    var g: RefCounted = Game.new();ok(g.start(SAVE),"boot")
    var registered: Dictionary = g.session.world.economy_view().get("supply_offers",{})
    if not registered.has(OFFER):
        check(false,"production supplier catalog is missing");g.dispose();done();return
    rejected(g,"supply.purchase",{"offer_id":OFFER},"FACT_NOT_KNOWN")
    rejected(g,"supply.purchase",{"offer_id":OFFER,"amount_minor":0},"INVALID_PAYLOAD")
    rejected(g,"supply.purchase",{"offer_id":"invented"},"UNKNOWN_OFFER")
    rejected(g,"supply.purchase",{"offer_id":OFFER},"UNAUTHORIZED","mahmoud")
    # P2 owns private audiences. Registering/knowing by an NPC is not player knowledge.
    ok(cmd(g,"social.fact.register",{"fact_id":"private:supplier","source_npc_id":"mahmoud","visibility":"trusted"},"system:director"),"private fact")
    rejected(g,"social.speak",{"speaker_id":"salma","fact_id":FACT,"mode":"broadcast","audience_ids":[]},"FACT_NOT_KNOWN","salma")
    rejected(g,"social.speak",{"speaker_id":"mahmoud","fact_id":"private:supplier","mode":"broadcast","audience_ids":[]},"PRIVATE_BROADCAST","mahmoud")
    await learn(g)
    rejected(g,"social.speak",{"speaker_id":"mahmoud","fact_id":"private:supplier","mode":"directed","audience_ids":["player"]},"PRIVACY_DENIED","mahmoud")
    check(not g.session.world.player_knows("private:supplier"),"private fact leaked")
    var initial: Dictionary = g.session.world.view()
    var expired: RefCounted = Game.new();ok(expired.start("user://e5-empty-expiry.json"),"expiry shell")
    check(expired.session.world.restore_snapshot(initial),"fork expiry")
    ok(expired.session.advance(120,"e5:expired"),"real expiry time")
    rejected(expired,"supply.purchase",{"offer_id":OFFER},"OFFER_EXPIRED");expired.dispose()
    var paused: RefCounted = Game.new();ok(paused.start("user://e5-empty-paused.json"),"paused shell")
    check(paused.session.world.restore_snapshot(initial),"fork pause")
    ok(cmd(paused,"time.pause",{},"system:clock"),"pause")
    rejected(paused,"supply.purchase",{"offer_id":OFFER},"PAUSED");paused.dispose()
    var poor: RefCounted = Game.new();ok(poor.start("user://e5-empty-poor.json"),"poor shell")
    check(poor.session.world.restore_snapshot(initial),"fork funds")
    ok(cmd(poor,"economy.pay",{"transaction_id":"e5:spend","recipient_id":"world:vendors","amount_minor":poor.session.world.balance_minor(),"cause_id":"ordinary-expense"}),"spend actual budget")
    rejected(poor,"supply.purchase",{"offer_id":OFFER},"INSUFFICIENT_FUNDS");poor.dispose()
    var refused: RefCounted = Game.new();ok(refused.start("user://e5-empty-decline.json"),"decline shell")
    check(refused.session.world.restore_snapshot(initial),"fork decline")
    var money: int = refused.session.world.balance_minor()
    var stock: int = int(refused.session.world.cooking_view()["stock"]["leaves"])
    var minute: int = int(refused.session.world.view()["world_minute"])
    ok(refused.referral_decline(),"explicitly decline delivery")
    check(refused.session.world.balance_minor()==money and refused.session.world.cooking_view()["stock"]["leaves"]==stock and refused.session.world.view()["world_minute"]==minute,"decline granted/revoked resources")
    rejected(refused,"supply.purchase",{"offer_id":OFFER},"OFFER_RESOLVED")
    rejected(refused,"supply.decline",{"offer_id":OFFER},"OFFER_RESOLVED")
    refused.dispose()
    var over: RefCounted = Game.new();ok(over.start("user://e5-empty-overflow.json"),"overflow shell")
    check(over.session.world.restore_snapshot(initial),"fork stock bounds")
    var leaves: int = int(over.session.world.cooking_view()["stock"]["leaves"])
    ok(cmd(over,"stock.add",{"ingredient_id":"leaves","quantity":2147483647-leaves},"system:stock"),"fill stock to bound")
    rejected(over,"supply.purchase",{"offer_id":OFFER},"AMOUNT_OVERFLOW");over.dispose()
    money=g.session.world.balance_minor();stock=int(g.session.world.cooking_view()["stock"]["leaves"]);minute=int(g.status()["minute"])
    var received: Dictionary = g.referral_purchase();ok(received,"canonical paid delivery")
    check(g.session.world.balance_minor()==money-550,"incorrect paid goods plus delivery")
    check(g.session.world.cooking_view()["stock"]["leaves"]==stock+30,"phantom/missing stock")
    check(g.status()["minute"]==minute+15,"delivery did not consume P1 time")
    var receipt: Dictionary = g.session.world.economy_view()["supply_resolutions"][OFFER]
    check(receipt.get("status","")=="purchased" and receipt.get("event_id","")==received.get("event_id","") and receipt.get("completed_minute",0)==minute+15,"unaudited supply resolution")
    var tx: Dictionary = g.session.world.economy_view()["transactions"][receipt["transaction_id"]]
    check(tx["from_account"]=="player" and tx["to_account"]=="world:vendors" and tx["amount_minor"]==550,"wrong canonical ledger")
    check(receipt.get("knowledge_event_id","")==g.session.world.social_view()["knowledge"]["player"][FACT]["event_id"],"missing knowledge provenance")
    rejected(g,"supply.purchase",{"offer_id":OFFER},"OFFER_RESOLVED")
    rejected(g,"economy.refund",{"transaction_id":"e5:refund","original_transaction_id":receipt["transaction_id"]},"DOMAIN_REFUND_REQUIRED","system:treasury")
    ok(g.save_game(),"save actual delivery")
    var final: Dictionary = g.session.world.view();g.dispose()
    var restored: RefCounted = Game.new();ok(restored.start(SAVE),"hard disk reload")
    check(Kernel._matches(final,restored.session.world.view()),"delivery replay mismatch")
    rejected(restored,"supply.purchase",{"offer_id":OFFER},"OFFER_RESOLVED")
    var forged: Dictionary = final.duplicate(true);forged["economy"]["supply_resolutions"][OFFER]["knowledge_event_id"]="fake"
    check(not Kernel.new().restore_snapshot(forged),"forged contact provenance restored")
    var legacy: Dictionary = Kernel.new().view();legacy["version"]=11
    legacy["economy"].erase("supply_offers");legacy["economy"].erase("supply_resolutions")
    var migrated: RefCounted=Kernel.new();check(migrated.restore_snapshot(legacy) and migrated.view()["version"]==12,"supported schema11 upgrade failed")
    var downgrade: Dictionary=final.duplicate(true);downgrade["version"]=11
    downgrade["economy"].erase("supply_offers");downgrade["economy"].erase("supply_resolutions")
    check(not Kernel.new().restore_snapshot(downgrade),"new supply events smuggled into old save")
    restored.dispose();DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE));done()
func done() -> void:
    if errors.is_empty(): print("E5 REFERRAL: PASS");quit(0)
    else: print("E5 REFERRAL: FAIL "+str(errors.size()));quit(1)
