extends SceneTree
## SYS P1: production deterministic scheduling acceptance, distinct from D001/V001.
const Kernel = preload("res://scripts/core/world_kernel.gd")
var failures: Array[String] = []

func _initialize() -> void:
    _clock()
    _lifecycle()
    _equivalence()
    _consumers()
    _persistence()
    _replay()
    if failures.is_empty():
        print("SYS P1: PASS (6 groups: clock, lifecycle, chunking, consumers, persistence, replay)")
        quit(0)
        return
    for f in failures:
        push_error(f)
    print("SYS P1: FAIL (%d checks)" % failures.size())
    quit(1)

func check(valid: bool, label: String) -> void:
    if not valid:
        failures.append(label)

func cmd(id: String, kind: String, payload: Dictionary = {}, actor: String = "actor:test") -> Dictionary:
    return {"id":id, "kind":kind, "payload":payload, "actor_id":actor}

func job(id: String, at: int, priority: int = 100, topic: String = "fixture", interval: int = 0, data: Dictionary = {}) -> Dictionary:
    return {"job_id":id, "due_minute":at, "priority":priority, "topic":topic, "data":data, "every_minutes":interval}

func _clock() -> void:
    var k = Kernel.new(9)
    check(k.calendar() == {"day_index":0,"minute_of_day":0,"hour":0,"minute":0}, "epoch")
    check(k.advance_time(1439,"a")["ok"], "advance 1439")
    check(k.calendar()["day_index"] == 0 and k.calendar()["hour"] == 23 and k.calendar()["minute"] == 59, "23:59")
    check(k.advance_time(1,"b")["ok"] and k.calendar()["day_index"] == 1 and k.calendar()["minute_of_day"] == 0, "midnight")
    check(k.advance_time(2880,"c")["ok"] and k.calendar()["day_index"] == 3, "several days")
    var before: String = JSON.stringify(k.view())
    check(k.advance_time(0,"zero")["code"] == "NO_OP" and before == JSON.stringify(k.view()), "zero mutated")
    check(k.advance_time(-1,"negative")["code"] == "INVALID_TIME", "negative allowed")
    check(k.advance_time(1.5,"fractional")["code"] == "INVALID_TIME", "fraction allowed")
    check(k.advance_time("5","string")["code"] == "INVALID_TIME", "string allowed")
    check(k.advance_time(2147483647,"overflow")["code"] == "TIME_OVERFLOW", "overflow allowed")
    check(before == JSON.stringify(k.view()), "rejected time mutated")
    check(k.dispatch(cmd("pause","time.pause"))["ok"], "pause")
    check(k.advance_time(3,"paused")["code"] == "PAUSED", "paused clock advanced")
    check(k.dispatch(cmd("pause2","time.pause"))["code"] == "ALREADY_PAUSED", "double pause")
    check(k.dispatch(cmd("resume","time.resume"))["ok"], "resume")
    check(k.dispatch(cmd("speed","time.rate.set",{"minutes_per_step":3}))["ok"], "rate set")
    check(k.advance_time(2,"scaled")["ok"] and k.view()["world_minute"] == 4326, "rate math")
    check(k.dispatch(cmd("bad-rate","time.rate.set",{"minutes_per_step":0}))["code"] == "INVALID_RATE", "zero rate")
    check(k.dispatch(cmd("bad-rate2","time.rate.set",{"minutes_per_step":1.5}))["code"] == "INVALID_RATE", "fraction rate")
    check(k.dispatch(cmd("bad-rate3","time.rate.set",{"minutes_per_step":65}))["code"] == "INVALID_RATE", "unbounded rate")

func _lifecycle() -> void:
    var k = Kernel.new()
    for entry in [["low",50],["high1",10],["high2",10],["cancel",100]]:
        check(k.dispatch(cmd("add:"+entry[0],"schedule.create",job(entry[0],10,entry[1])))["ok"], "schedule "+entry[0])
    check(k.dispatch(cmd("cancel","schedule.cancel",{"job_id":"cancel"}))["ok"], "cancel")
    check(k.dispatch(cmd("cancel2","schedule.cancel",{"job_id":"cancel"}))["code"] == "JOB_NOT_PENDING", "double cancel")
    check(k.dispatch(cmd("reschedule","schedule.reschedule",{"job_id":"low","due_minute":9,"priority":0}))["ok"], "reschedule")
    check(k.dispatch(cmd("reuse","schedule.create",job("low",15)))["code"] == "JOB_ID_CONFLICT", "job ID reused")
    check(k.advance_time(10,"advance")["ok"], "advance")
    var fires: Array[Dictionary] = k.scheduled_events_after(0)
    check(fires.size() == 3, "firing count")
    if fires.size() == 3:
        check(fires[0]["job_id"] == "low" and fires[0]["world_minute"] == 9, "reschedule order")
        check(fires[1]["job_id"] == "high1" and fires[2]["job_id"] == "high2", "priority / sequence order")
    check(k.view()["jobs"]["cancel"]["status"] == "cancelled", "cancel history")
    check(k.view()["jobs"]["low"]["status"] == "completed", "completion history")
    check(k.dispatch(cmd("past","schedule.create",job("past",10)))["code"] == "INVALID_DUE_TIME", "past event accepted")
    check(k.dispatch(cmd("late","schedule.reschedule",{"job_id":"high1","due_minute":20,"priority":1}))["code"] == "JOB_NOT_PENDING", "completed rescheduled")
    check(k.dispatch(cmd("add:low","schedule.create",job("low",10,50)))["revision"] == 1, "idempotent command receipt")
    check(k.dispatch(cmd("add:low","schedule.create",job("other",20)))["code"] == "ID_CONFLICT", "command ID conflict")
    check(k.dispatch(cmd("bad-data","schedule.create",job("bad",30,2,"t",0,{"position":Vector2.ONE})))["code"] == "INVALID_PAYLOAD", "non-JSON data accepted")

func _normalized(k) -> Array:
    var out: Array = []
    for fire in k.scheduled_events_after(0):
        out.append([fire["job_id"],fire["world_minute"],fire["topic"],fire["occurrence"],fire["priority"]])
    return out

func _equivalence() -> void:
    var large = Kernel.new(56)
    var small = Kernel.new(56)
    var identical = Kernel.new(56)
    for k in [large,small,identical]:
        k.dispatch(cmd("j1","schedule.create",job("a",5,10,"order.expire",12)))
        k.dispatch(cmd("j2","schedule.create",job("b",30,0,"npc.arrive")))
        k.dispatch(cmd("j3","schedule.create",job("c",120,40,"fixture",1440)))
    check(large.advance_time(480,"large")["ok"], "8h large advance")
    check(identical.advance_time(480,"large")["ok"], "identical advance")
    for i in range(48):
        check(small.advance_time(10,"small:%d"%i)["ok"], "small advance "+str(i))
    check(large.view()["world_minute"] == small.view()["world_minute"], "chunking time")
    # Fire IDs encode advance-command sequence; compare canonical occurrences and state,
    # not the intentionally different causal IDs for a chunked command history.
    check(_normalized(large) == _normalized(small), "chunking effects")
    check(large.view()["jobs"]["a"]["due_minute"] == small.view()["jobs"]["a"]["due_minute"], "next repeat due")
    check(_normalized(large).size() == 42, "expected 8h recurring firings")
    check(JSON.stringify(large.view()) == JSON.stringify(identical.view()), "identical trace not byte reproducible")

func _consumers() -> void:
    var k = Kernel.new(21)
    k.dispatch(cmd("npc","schedule.create",job("daily",1430,10,"npc.arrive",1440,{"npc_id":"samir"})))
    k.dispatch(cmd("order","schedule.create",job("deadline",1440,20,"order.expire",0,{"order_id":"q1"})))
    check(k.advance_time(4400,"days")["ok"], "multi-day")
    var all: Array[Dictionary] = k.scheduled_events_after(0)
    check(all.size() == 4, "daily and one-off counts")
    if all.size() == 4:
        check(all[0]["world_minute"] == 1430 and all[1]["world_minute"] == 1440 and all[2]["world_minute"] == 2870 and all[3]["world_minute"] == 4310, "midnight/repeats drift")
        var id: String = all[0]["fire_id"]
        check(k.unacknowledged_firings("presence").size() == 4 and k.unacknowledged_firings("orders").size() == 4, "independent consumer stream")
        check(k.dispatch(cmd("p-ack","schedule.ack",{"consumer_id":"presence","fire_id":id}))["ok"], "presence ACK")
        check(k.dispatch(cmd("o-ack","schedule.ack",{"consumer_id":"orders","fire_id":id}))["ok"], "orders ACK")
        check(k.unacknowledged_firings("presence").size() == 3 and k.unacknowledged_firings("orders").size() == 3, "independent ACK histories")
        check(k.unacknowledged_firings("presence","npc.arrive").size() == 2, "topic filtering")
        check(k.dispatch(cmd("again","schedule.ack",{"consumer_id":"presence","fire_id":id}))["code"] == "ALREADY_ACKNOWLEDGED", "duplicate ACK")
    check(k.dispatch(cmd("fake","schedule.ack",{"consumer_id":"presence","fire_id":"fake"}))["code"] == "FIRE_NOT_FOUND", "fake ACK")

func _persistence() -> void:
    var k = Kernel.new(32)
    k.dispatch(cmd("s","schedule.create",job("daily",15,2,"fixture",1440)))
    k.dispatch(cmd("c","schedule.create",job("canceled",23)))
    k.dispatch(cmd("cancel","schedule.cancel",{"job_id":"canceled"}))
    k.advance_time(20,"advance")
    var fire_id: String = k.scheduled_events_after(0)[0]["fire_id"]
    k.dispatch(cmd("ack","schedule.ack",{"consumer_id":"one","fire_id":fire_id}))
    var path: String = "user://nk-sys-p1.json"
    check(k.save_to_file(path), "disk write")
    var loaded = Kernel.new(999)
    check(loaded.load_from_file(path), "JSON restore")
    check(JSON.stringify(loaded.view()) == JSON.stringify(k.view()), "roundtrip changed bytes")
    check(loaded.unacknowledged_firings("one").is_empty() and loaded.unacknowledged_firings("two").size() == 1, "ACK restore")
    check(loaded.advance_time(1450,"next")["ok"], "resume pending repeat")
    check(loaded.scheduled_events_after(0).size() == 2, "post-restore duplicate/missing repeat")
    check(loaded.view()["jobs"]["canceled"]["status"] == "cancelled", "lost cancellation")
    var baseline: String = JSON.stringify(k.view())
    var bad: Dictionary = k.view()
    bad["jobs"]["daily"]["due_minute"] = 200
    check(not k.restore_snapshot(bad), "tampered queue")
    bad = k.view()
    bad["acknowledgements"]["one"].clear()
    check(not k.restore_snapshot(bad), "tampered ACK")
    bad = k.view()
    bad["events"][1]["event_id"] = "forged"
    check(not k.restore_snapshot(bad), "forged event")
    bad = k.view()
    bad["events"][3]["payload"]["effect"]["fires"][0]["world_minute"] = 999
    check(not k.restore_snapshot(bad), "forged firing")
    bad = k.view()
    bad["world_minute"] = 21
    check(not k.restore_snapshot(bad), "forged clock")
    bad = k.view()
    bad["version"] = 1
    check(not k.restore_snapshot(bad), "P0 save implicitly migrated")
    check(JSON.stringify(k.view()) == baseline, "restore rejection not atomic")
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _replay() -> void:
    var a = Kernel.new(44)
    var b = Kernel.new(44)
    for k in [a,b]:
        k.dispatch(cmd("add","schedule.create",job("only",60,1,"npc.arrive",0,{"npc_id":"n1"}),"npc:director"))
        k.advance_time(60,"tick","system:scheduler")
        k.dispatch(cmd("know","knowledge.grant",{"fact_id":"heard_tea"},"npc:samir"))
    check(JSON.stringify(a.view()) == JSON.stringify(b.view()), "replay input trace")
    var event = a.scheduled_events_after(0)[0]
    check(event["source_actor_id"] == "npc:director" and event["source_command_id"] == "add", "provenance")
    check(event["sequence"] == 2 and event["event_id"] == "evt:000000000002", "event identity")
    var restored = Kernel.new(1)
    check(restored.restore_snapshot(a.view()), "replay restore")
    check(JSON.stringify(restored.view()) == JSON.stringify(a.view()), "replay bytes")
    check(restored.has_fact("heard_tea"), "P0 knowledge reducer regression")
    var leaked = restored.scheduled_events_after(0)
    leaked[0]["data"]["npc_id"] = "forged"
    check(restored.scheduled_events_after(0)[0]["data"]["npc_id"] == "n1", "mutated domain by reading")
