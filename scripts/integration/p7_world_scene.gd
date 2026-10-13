extends Node2D
## Production WorldKernel debug scene: visible state is always a projection.
const Session = preload("res://scripts/integration/world_session.gd")
const Fixture = preload("res://scripts/integration/p7_acceptance_fixture.gd")
const SAVE = "user://nile-kiosk-p7-production-v7.json"
var model: RefCounted
var initialized: bool = false
var notice: String = "Loading..."

func _ready() -> void:
    model = Session.new(97,SAVE)
    call_deferred("_boot")

func _boot() -> void:
    var loaded: Dictionary = model.load_existing()
    if not loaded.get("ok",false):
        push_error("P7_WEB_INVALID_SAVE " + str(loaded))
        return
    if loaded["code"] == "NEW_WORLD":
        var populated: Dictionary = Fixture.populate(model)
        if not populated.get("ok",false):
            push_error("P7_WEB_SETUP_FAILED " + str(populated))
            return
    if not model.attach_ink("a","res://content/ink/sys_p6_conversation.ink.json"):
        push_error("P7_WEB_ATTACH_A_FAILED")
        return
    if not model.attach_ink("b","res://content/ink/sys_p6_gossip.ink.json"):
        push_error("P7_WEB_ATTACH_B_FAILED")
        return
    for i in range(150):
        if model.ink.sessions["a"]["failed"] or model.ink.sessions["b"]["failed"]:
            push_error("P7_WEB_INK_FAILED")
            return
        if model.ink_ready("a") and model.ink_ready("b"):
            break
        await get_tree().process_frame
    if not model.ink_ready("a") or not model.ink_ready("b"):
        push_error("P7_WEB_INK_TIMEOUT")
        return
    if loaded["code"] == "NEW_WORLD":
        var initiated: Dictionary = Fixture.seed_sessions(model)
        if not initiated.get("ok",false):
            push_error("P7_WEB_SESSIONS_FAILED " + str(initiated))
            return
    initialized = true
    notice = "P save  /  1 Ink choice  /  E serve  /  R rent  /  T time"
    report("P7_WEB_READY" if loaded["code"] == "NEW_WORLD" else "P7_WEB_RESTORED")

func summary() -> Dictionary:
    var v: Dictionary = model.world.view()
    return {"version":v["version"],"revision":v["sequence"],"minute":v["world_minute"],
        "events":v["events"].size(),"receipts":v["receipts"].size(),
        "digest":JSON.stringify(v).sha256_text(),
        "balance":v["economy"]["accounts"]["player"],
        "cook":v["cooking"]["preparations"].get("batch",{}).get("status","missing"),
        "item":v["cooking"]["items"].get("item:batch",{}).get("status","none"),
        "order":v["service"]["orders"]["order:tea"]["status"],
        "claim":v["service"]["payment_claims"].get("payment:order:order:tea",{}).get("status","none"),
        "dues":v["housing"]["leases"]["lease"]["dues_owed"],
        "roof_access":model.world.can_access_unit("roof"),
        "flat_access":model.world.can_access_unit("flat"),
        "object_room":v["housing"]["objects"]["cupboard1"]["unit_id"],
        "visitor_location":v["society"]["npcs"]["visitor"]["location_id"],
        "session_a":v["narrative"]["sessions"]["a"]["phase"],
        "session_b":v["narrative"]["sessions"]["b"]["phase"],
        "result_known":model.world.player_knows("sports:result"),
        "rumor_known":model.world.player_knows("shop:rumor"),
        "mona_heard":v["society"]["knowledge"]["mona"].has("shop:rumor")
    }

func report(marker: String) -> void:
    print(marker + " " + JSON.stringify(summary()))
    queue_redraw()

func check(result: Dictionary, name: String) -> bool:
    if result.get("ok",false): return true
    push_error("P7_WEB_ACTION_FAILED " + name + ": " + str(result))
    return false

func action(id: String, actor: String, kind: String, p: Dictionary) -> bool:
    return check(model.command(id,actor,kind,p),kind)

func _unhandled_key_input(event: InputEvent) -> void:
    if not initialized or not (event is InputEventKey) or not event.pressed or event.echo:
        return
    match event.keycode:
        KEY_P:
            if check(model.save(),"save"): report("P7_WEB_SAVED")
        KEY_1:
            if not check(model.ink_choose("a","ask","p7:web:choice"),"choose"): return
            for id in ["reaction","rejoin"]:
                var line: Dictionary = model.ink_next("a","p7:web:"+id)
                if line.get("code") != "LINE":
                    push_error("P7_WEB_BRANCH_FAILED " + str(line))
                    return
            if model.ink_next("a","p7:web:finish").get("code") != "FINISHED":
                push_error("P7_WEB_FINISH_FAILED")
                return
            report("P7_WEB_SELECTED")
        KEY_E:
            if not action("p7:web:cook","player","cook.step.finish",{"job_id":"batch"}): return
            if not action("p7:web:deliver","player","order.deliver",{"order_id":"order:tea","item_id":"item:batch"}): return
            if not action("p7:web:quote","system:pricing","economy.order.quote",{"claim_id":"payment:order:order:tea"}): return
            if not action("p7:web:settle","system:service","economy.order.settle",
                {"claim_id":"payment:order:order:tea","transaction_id":"p7:web:payment"}): return
            report("P7_WEB_DELIVERED")
        KEY_R:
            if action("p7:web:rent","player","housing.rent.pay",
                {"lease_id":"lease","transaction_id":"p7:web:rent:payment"}): report("P7_WEB_RENT_PAID")
        KEY_T:
            if check(model.advance(6,"p7:web:time:18"),"advance"): report("P7_WEB_ADVANCED")

func _draw() -> void:
    draw_rect(Rect2(0,0,960,540),Color("#19282e"))
    draw_rect(Rect2(0,0,960,78),Color("#355358"))
    draw_string(ThemeDB.fallback_font,Vector2(25,38),"NILE KIOSK — WORLD INTEGRATION",HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color.WHITE)
    if not initialized:
        draw_string(ThemeDB.fallback_font,Vector2(30,165),"Restoring world / Ink...",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)
        return
    var s: Dictionary = summary()
    var lines: Array = [
        notice,
        "REV %s  /  Minute %s  /  Balance %s" % [s["revision"],s["minute"],s["balance"]],
        "NPC visitor: %s  /  Ink A: %s  /  B: %s" % [s["visitor_location"],s["session_a"],s["session_b"]],
        "Cooking %s  /  Order %s  /  Paid %s" % [s["cook"],s["order"],s["claim"]],
        "Roof %s  /  Flat %s  /  Rent due %s" % [s["roof_access"],s["flat_access"],s["dues"]],
        "Rumor heard by player: %s  /  Choice knowledge %s" % [s["rumor_known"],s["result_known"]],
        "Ink options: %d" % model.ink_choices("a").size()
    ]
    for i in range(lines.size()):
        draw_string(ThemeDB.fallback_font,Vector2(25,115+i*48),str(lines[i]),HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("#f1eddf"))
