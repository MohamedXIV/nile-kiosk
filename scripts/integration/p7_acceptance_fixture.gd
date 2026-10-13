extends RefCounted
## SYS P7 integration FIXTURE: deliberately authored sample content, NEVER world defaults.
## Uses the same public commands a production content/gameplay adapter would use.
static func send(session: RefCounted, id: String, kind: String, data: Dictionary,
        actor: String = "system:director") -> Dictionary:
    return session.command("p7:" + id, actor, kind, data)

static func _add(session: RefCounted, id: String, kind: String, data: Dictionary,
        actor: String = "system:director") -> String:
    var result: Dictionary = send(session, id, kind, data, actor)
    if not result.get("ok", false):
        return id + ": " + str(result.get("code", "UNKNOWN"))
    return ""

static func populate(session: RefCounted) -> Dictionary:
    var error: String
    for name in ["samir", "mahmoud", "mona", "hossam"]:
        error = _add(session, "npc:" + name, "npc.register",
            {"npc_id": name, "location_id": "kiosk"})
        if not error.is_empty(): return {"ok": false, "error": error}
    error = _add(session, "npc:visitor", "npc.register", {"npc_id":"visitor","location_id":"home"})
    if not error.is_empty(): return {"ok": false,"error":error}
    error = _add(session, "routine:visitor", "npc.routine.create",
        {"routine_id":"shift","npc_id":"visitor","location_id":"kiosk",
            "start_minute":2,"end_minute":15,"period_minutes":0})
    if not error.is_empty(): return {"ok": false,"error":error}
    error = _add(session, "player", "social.player.place", {"location_id":"kiosk"})
    if not error.is_empty(): return {"ok": false,"error":error}
    for fact in [["sports:match","samir"],["sports:result","samir"],["shop:rumor","hossam"]]:
        error = _add(session, "fact:"+fact[0], "social.fact.register",
            {"fact_id":fact[0],"source_npc_id":fact[1],"visibility":"public"})
        if not error.is_empty(): return {"ok": false,"error":error}
    error = _add(session,"social:trust","social.familiarity.set",
        {"observer_id":"player","npc_id":"mahmoud","level":"trusted"})
    if not error.is_empty(): return {"ok": false,"error":error}
    error = _add(session,"social:match","social.speak",{"speaker_id":"samir","fact_id":"sports:match",
        "mode":"broadcast","audience_ids":[]},"samir")
    if not error.is_empty(): return {"ok": false,"error":error}
    # Multiple P3 cooking jobs and live P4 service, independent of Ink and frames.
    var cooking: Array = [
        ["ingredient", "ingredient.define", {"ingredient_id":"leaves","unit":"g"}],
        ["stock", "stock.add", {"ingredient_id":"leaves","quantity":8}],
        ["station", "station.register", {"station_id":"hotplate","station_type":"heat"}],
        ["recipe", "recipe.define", {"recipe_id":"tea",
            "steps":[{"station_type":"heat","inputs":{"leaves":2},"work_minutes":2}],
            "shelf_minutes":0}],
        ["cook", "cook.start", {"job_id":"batch","recipe_id":"tea","deadline_minute":40}],
        ["cooking", "cook.step.begin", {"job_id":"batch","station_id":"hotplate"}]
    ]
    for entry in cooking:
        error = _add(session, entry[0], entry[1], entry[2])
        if not error.is_empty(): return {"ok":false,"error":error}
    var service: Array = [
        ["venue","service.configure",{"venue_id":"kiosk","location_id":"kiosk","counter_slots":2,
            "takeaway_slots":1,"table_ids":["t1"]},"system:director"],
        ["offer","order.offer",{"order_id":"order:tea","venue_id":"kiosk","npc_id":"samir",
            "recipe_id":"tea","route":"counter","deadline_minute":40},"samir"],
        ["accept","order.accept",{"order_id":"order:tea","seat_id":""},"player"],
        ["price","economy.recipe.price.set",{"recipe_id":"tea","amount_minor":175},"system:pricing"]
    ]
    for entry in service:
        error = _add(session,entry[0],entry[1],entry[2],entry[3])
        if not error.is_empty(): return {"ok":false,"error":error}
    # Roof and apartment economics here are fixture-only, never production constants.
    var property: Array = [
        ["roof","housing.unit.register",{"unit_id":"roof","location_id":"roof","kind":"roof",
            "area_sqm":0,"rent_minor":0,"period_minutes":0},"system:housing"],
        ["flat","housing.unit.register",{"unit_id":"flat","location_id":"flat","kind":"apartment",
            "area_sqm":60,"rent_minor":150,"period_minutes":10},"system:housing"],
        ["roof_access","housing.roof.grant",{"unit_id":"roof"},"system:bootstrap"],
        ["grant_cash","economy.fund",{"transaction_id":"start_cash","amount_minor":1000,
            "source_id":"fixture:initial"},"system:treasury"],
        ["rent_start","housing.lease.start",{"lease_id":"lease","unit_id":"flat",
            "transaction_id":"first_rent"},"player"],
        ["item_type","home.type.define",{"type_id":"cupboard","price_minor":0,
            "actions":["open"]},"system:catalog"],
        ["item_grant","home.object.grant",{"object_id":"cupboard1","type_id":"cupboard"},"system:bootstrap"],
        ["roof_visit","social.player.place",{"location_id":"roof"},"system:director"],
        ["item_place","home.object.place",{"object_id":"cupboard1","unit_id":"roof","slot_id":"wall"},"player"],
        ["back_kiosk","social.player.place",{"location_id":"kiosk"},"system:director"]
    ]
    for entry in property:
        error = _add(session,entry[0],entry[1],entry[2],entry[3])
        if not error.is_empty(): return {"ok":false,"error":error}
    var basic: Dictionary = {"requires_known":[],"requires_trusted":"",
        "disclose_fact_id":"","speaker_id":""}
    var ask: Dictionary = basic.duplicate(true)
    ask["text"]="I saw the match."
    ask["requires_known"]=["sports:match"]
    ask["requires_trusted"]="mahmoud"
    ask["disclose_fact_id"]="sports:result"
    ask["speaker_id"]="samir"
    var quiet: Dictionary = basic.duplicate(true)
    quiet["text"]="Stay quiet."
    var stories: Array = [
        ["a",{"story_id":"a","beats":{
            "a_open":{"speaker_id":"samir","fact_id":""},
            "a_question":{"speaker_id":"mahmoud","fact_id":""},
            "a_yes":{"speaker_id":"mahmoud","fact_id":""},
            "a_quiet":{"speaker_id":"samir","fact_id":""},
            "a_end":{"speaker_id":"samir","fact_id":""}
        },"choice_points":{"match_choice":{"ask":ask,"quiet":quiet}}}],
        ["b",{"story_id":"b","beats":{
            "b_open":{"speaker_id":"mona","fact_id":""},
            "b_rumor":{"speaker_id":"hossam","fact_id":"shop:rumor"},
            "b_end":{"speaker_id":"mona","fact_id":""}
        },"choice_points":{}}]
    ]
    for story in stories:
        error=_add(session,"story:"+story[0],"narrative.story.register",story[1],"system:narrative")
        if not error.is_empty(): return {"ok":false,"error":error}
    return {"ok":true}

static func seed_sessions(session: RefCounted) -> Dictionary:
    if not session.ink_ready("a") or not session.ink_ready("b"):
        return {"ok":false,"code":"INK_NOT_READY"}
    var a: Dictionary = session.ink_begin("a","a",["samir","mahmoud","player"],"p7:a:start")
    var b: Dictionary = session.ink_begin("b","b",["mona","hossam"],"p7:b:start")
    if not a.get("ok",false) or not b.get("ok",false): return {"ok":false,"code":"SESSION_START_FAILED"}
    for step in ["a:open","a:question"]:
        if session.ink_next("a","p7:"+step).get("code")!="LINE":
            return {"ok":false,"code":"A_LINE_FAILED"}
    if session.ink_next("a","p7:a:wait").get("code")!="WAITING":
        return {"ok":false,"code":"CHOICE_FAILED"}
    if session.ink_next("b","p7:b:open").get("code")!="LINE":
        return {"ok":false,"code":"B_LINE_FAILED"}
    # The exact P2 player-location transition controls who actually heard B.
    var r: Dictionary = send(session,"offscreen","social.player.place",{"location_id":"roof"})
    if not r.get("ok",false): return r
    for step in ["rumor","end"]:
        if session.ink_next("b","p7:b:"+step).get("code")!="LINE":
            return {"ok":false,"code":"B_LINE_FAILED"}
    if session.ink_next("b","p7:b:finish").get("code")!="FINISHED":
        return {"ok":false,"code":"B_FINISH_FAILED"}
    r = send(session,"return","social.player.place",{"location_id":"kiosk"})
    if not r.get("ok",false): return r
    if not session.advance(12,"p7:time:12").get("ok",false):
        return {"ok":false,"code":"WORLD_ADVANCE_FAILED"}
    return {"ok":true}
