extends SceneTree
## Production SYS P2 domain acceptance: no D001 fixture authority.
const Kernel = preload("res://scripts/core/world_kernel.gd")
var failures: Array[String] = []

func _initialize() -> void:
    _identity_and_commands()
    _visits_and_conflicts()
    _social_witnesses()
    _step_equivalence()
    _persistence_and_integrity()
    if failures.is_empty():
        print("SYS P2: PASS (5 groups: lifecycle, routines, social/privacy, time-jumps, replay/persistence)")
        quit(0)
        return
    for f in failures:
        push_error(f)
    print("SYS P2: FAIL (%d assertions)" % failures.size())
    quit(1)

func check(ok: bool, reason: String) -> void:
    if not ok:
        failures.append(reason)

func command(id: String, kind: String, payload: Dictionary = {}, actor: String = "system:director") -> Dictionary:
    return {"id": id, "actor_id": actor, "kind": kind, "payload": payload}

func send(k, id: String, kind: String, payload: Dictionary = {}, actor: String = "system:director") -> Dictionary:
    return k.dispatch(command(id, kind, payload, actor))

func register(k, id: String, place: String = "") -> Dictionary:
    return send(k, "register:" + id, "npc.register", {"npc_id": id, "location_id": place})

func routine(id: String, npc_id: String, place: String, start: int, finish: int, period: int = 0) -> Dictionary:
    return {"routine_id": id, "npc_id": npc_id, "location_id": place,
        "start_minute": start, "end_minute": finish, "period_minutes": period}

func effects(k) -> Array:
    var result: Array = []
    for e in k.event_history_after(0):
        if e["kind"] == "time.advanced":
            for item in e["payload"]["effect"]["npc_outcomes"]:
                result.append(item.duplicate(true))
    return result

func _identity_and_commands() -> void:
    var k = Kernel.new(22)
    var first: Dictionary = register(k, "npc:a", "home")
    check(first["ok"], "register")
    check(send(k, "register:npc:a", "npc.register", {"npc_id":"npc:a","location_id":"home"}) == first, "register retry receipt")
    check(register(k, "npc:a")["code"] == "NPC_EXISTS", "duplicate identity")
    check(register(k, "player")["code"] == "NPC_EXISTS", "player is not NPC")
    check(send(k, "bad","npc.register",{"npc_id":"npc:b","location_id":3})["code"] == "INVALID_LOCATION", "invalid place")
    check(k.npc("npc:a")["location_id"] == "home", "initial presence")
    check(send(k, "move","npc.move",{"npc_id":"npc:a","location_id":"kiosk"})["ok"], "relocation")
    check(k.npc("npc:a")["base_location_id"] == "kiosk", "base relocation")
    var leaked: Dictionary = k.npc("npc:a")
    leaked["location_id"] = "nowhere"
    check(k.npc("npc:a")["location_id"] == "kiosk", "read projection mutated truth")
    check(send(k, "unknown","npc.move",{"npc_id":"unregistered","location_id":"kiosk"})["code"] == "UNKNOWN_NPC", "unknown NPC moved")
    var before: String = JSON.stringify(k.view())
    check(send(k,"fault","npc.routine.create",routine("short","npc:a","kiosk",10,20,5))["code"] == "OVERLAPPING_PERIOD", "overlap repeat allowed")
    check(send(k,"fault2","npc.routine.create",routine("short","npc:a","kiosk",10,10))["code"] == "INVALID_TIME", "zero-duration visit")
    check(before == JSON.stringify(k.view()), "rejected command mutated world")

func _visits_and_conflicts() -> void:
    var k = Kernel.new(11)
    register(k,"npc:a","home_a")
    register(k,"npc:b","home_b")
    check(send(k,"a","npc.routine.create",routine("daily","npc:a","kiosk",10,20,1440))["ok"], "daily routine")
    check(send(k,"b","npc.routine.create",routine("collision","npc:a","market",15,25))["ok"], "overlapping routine registration")
    check(send(k,"c","npc.routine.create",routine("independent","npc:b","kiosk",11,19))["ok"], "second NPC")
    check(send(k,"forged","schedule.create",{"job_id":"x","due_minute":5,"priority":1,"topic":"npc.visit.start","data":{},"every_minutes":0})["code"] == "INVALID_PAYLOAD", "reserved topic forged")
    check(send(k,"override","schedule.cancel",{"job_id":"npc:daily:begin"})["code"] == "DOMAIN_OWNED_JOB", "foreign job cancellation")
    check(send(k,"override2","schedule.reschedule",{"job_id":"npc:daily:begin","due_minute":30,"priority":1})["code"] == "DOMAIN_OWNED_JOB", "foreign job reschedule")
    check(k.advance_time(16,"advance16")["ok"], "advance to overlapping starts")
    check(k.npc("npc:a")["location_id"] == "kiosk" and k.npc("npc:a")["routine_id"] == "daily", "overlap displaced active visit")
    check(k.npc("npc:b")["location_id"] == "kiosk", "other NPC prevented")
    var all: Array = effects(k)
    check(all.size() == 3, "start firing count")
    if all.size() == 3:
        check(all[0]["outcome"] == "arrived" and all[1]["outcome"] == "arrived" and all[2]["outcome"] == "missed_busy", "conflict outcomes")
    check(send(k,"interrupt","npc.visit.interrupt",{"npc_id":"npc:a","reason":"called_away"})["ok"], "interrupt")
    check(k.npc("npc:a")["location_id"] == "home_a" and k.npc("npc:a")["routine_id"] == "", "interruption release")
    check(k.advance_time(14,"advance30")["ok"], "advance to 30")
    all = effects(k)
    check(all.size() == 6 and all[4]["outcome"] == "skipped", "late end after interruption")
    check(send(k,"cancel","npc.routine.cancel",{"routine_id":"daily"})["ok"], "cancel routine")
    check(k.npc_routines()["daily"]["status"] == "cancelled", "routine cancellation state")
    check(k.advance_time(2000,"future")["ok"] and k.npc("npc:a")["location_id"] == "home_a", "cancelled recurring visit reappeared")
    check(send(k,"cancel_again","npc.routine.cancel",{"routine_id":"daily"})["code"] == "ROUTINE_NOT_ACTIVE", "repeat cancellation")
    check(send(k,"retire","npc.visit.interrupt",{"npc_id":"npc:a","reason":"x"})["code"] == "NO_ACTIVE_VISIT", "double interrupt")

func _social_witnesses() -> void:
    var k = Kernel.new()
    register(k, "samir", "kiosk")
    register(k, "mahmoud", "kiosk")
    register(k, "distant", "home")
    check(send(k,"source","social.fact.register",{"fact_id":"recipe:soak","source_npc_id":"samir","visibility":"public"})["ok"], "fact source")
    check(not k.player_knows("recipe:soak"), "knowledge leaked to absent player")
    check(send(k,"public1","social.speak",{"speaker_id":"samir","fact_id":"recipe:soak","mode":"broadcast","audience_ids":[]},"samir")["ok"], "NPC-NPC speech without player")
    check(k.social_view()["knowledge"]["mahmoud"].has("recipe:soak"), "co-present NPC didn't hear")
    check(not k.social_view()["knowledge"]["distant"].has("recipe:soak"), "distant NPC heard")
    check(not k.player_knows("recipe:soak"), "absent player heard offscreen")
    check(send(k,"player","social.player.place",{"location_id":"kiosk"})["ok"], "player placement")
    check(send(k,"public2","social.speak",{"speaker_id":"mahmoud","fact_id":"recipe:soak","mode":"broadcast","audience_ids":[]},"mahmoud")["ok"], "NPC repeats shared fact")
    check(k.player_knows("recipe:soak"), "player didn't hear shared public fact")
    check(k.social_view()["knowledge"]["player"]["recipe:soak"]["source_npc_id"] == "mahmoud", "heard provenance")
    check(send(k,"private_fact","social.fact.register",{"fact_id":"secret:work","source_npc_id":"samir","visibility":"trusted"})["ok"], "private fact")
    check(send(k,"privacy","social.speak",{"speaker_id":"samir","fact_id":"secret:work","mode":"broadcast","audience_ids":[]},"samir")["code"] == "PRIVATE_BROADCAST", "privacy bypass")
    check(send(k,"private_denied","social.speak",{"speaker_id":"samir","fact_id":"secret:work","mode":"directed","audience_ids":["player"]},"samir")["code"] == "PRIVACY_DENIED", "trust bypass")
    check(send(k,"trust","social.familiarity.set",{"observer_id":"player","npc_id":"samir","level":"trusted"})["ok"], "trust")
    check(send(k,"private_ok","social.speak",{"speaker_id":"samir","fact_id":"secret:work","mode":"directed","audience_ids":["player"]},"samir")["ok"], "private directed")
    check(k.player_knows("secret:work"), "private knowledge not recorded")
    check(not k.social_view()["knowledge"]["mahmoud"].has("secret:work"), "private fact overheard")
    check(send(k,"away","social.player.place",{"location_id":""})["ok"], "player left")
    check(send(k,"away_speech","social.speak",{"speaker_id":"samir","fact_id":"secret:work","mode":"directed","audience_ids":["player"]},"samir")["code"] == "AUDIENCE_ABSENT", "remote eavesdropping")
    var before: String = JSON.stringify(k.view())
    check(send(k,"fake_actor","social.speak",{"speaker_id":"samir","fact_id":"recipe:soak","mode":"broadcast","audience_ids":[]},"distant")["code"] == "INVALID_SPEAKER", "speaker forged")
    check(before == JSON.stringify(k.view()), "bad social request mutated world")

func normalized_outcomes(k) -> Array:
    var output: Array = []
    for e in effects(k):
        output.append([e["npc_id"],e["routine_id"],e["outcome"],e["at_minute"]])
    return output

func _step_equivalence() -> void:
    var a = Kernel.new(99)
    var b = Kernel.new(99)
    var c = Kernel.new(99)
    for k in [a,b,c]:
        register(k,"samir","home")
        register(k,"mahmoud","home")
        send(k,"daily","npc.routine.create",routine("shift","samir","kiosk",1300,1500,1440))
        send(k,"friend","npc.routine.create",routine("evening","mahmoud","kiosk",1300,1400,1440))
    check(a.advance_time(4400,"large")["ok"], "multi-day jump")
    check(c.advance_time(4400,"large")["ok"], "same-input repeat")
    for i in range(44):
        check(b.advance_time(100,"slice:%d"%i)["ok"], "split step")
    check(normalized_outcomes(a) == normalized_outcomes(b), "NPC chunking divergent")
    check(a.social_view() == b.social_view(), "NPC final-state divergence")
    check(JSON.stringify(a.view()) == JSON.stringify(c.view()), "replay determinism")
    check(normalized_outcomes(a).size() == 12, "recurrence missed/multiplied")

func _persistence_and_integrity() -> void:
    var k = Kernel.new(16)
    register(k, "npc:a", "home")
    send(k,"day","npc.routine.create",routine("day","npc:a","kiosk",5,15,1440))
    k.advance_time(10,"advance10")
    check(k.npc("npc:a")["routine_id"] == "day", "mid-visit")
    var path: String = "user://nk-sys-p2.json"
    check(k.save_to_file(path), "disk write")
    var loaded = Kernel.new(1)
    check(loaded.load_from_file(path), "disk read")
    check(JSON.stringify(loaded.view()) == JSON.stringify(k.view()), "JSON roundtrip canonical bytes")
    check(loaded.advance_time(1460,"continued")["ok"], "resumed daily loop")
    check(normalized_outcomes(loaded).size() == 4 and loaded.npc("npc:a")["routine_id"] == "", "reload lost or duplicated visit")
    var baseline: String = JSON.stringify(k.view())
    var corrupt: Dictionary = k.view()
    corrupt["society"]["npcs"]["npc:a"]["location_id"] = "forged"
    check(not k.restore_snapshot(corrupt), "forged NPC position")
    corrupt = k.view()
    corrupt["society"]["knowledge"]["npc:a"]["secret"] = {"fake":true}
    check(not k.restore_snapshot(corrupt), "forged knowledge")
    corrupt = k.view()
    corrupt["jobs"]["npc:day:end"]["due_minute"] = 42
    check(not k.restore_snapshot(corrupt), "tampered canonical scheduler")
    corrupt = k.view()
    corrupt["events"][2]["payload"]["effect"]["npc_outcomes"][0]["outcome"] = "missed_busy"
    check(not k.restore_snapshot(corrupt), "forged NPC transition")
    corrupt = k.view()
    corrupt["version"] = 2
    check(not k.restore_snapshot(corrupt), "v2 silently accepted")
    check(JSON.stringify(k.view()) == baseline, "corrupt restore mutated state")
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
