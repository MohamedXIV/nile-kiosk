extends SceneTree
## Real production SYS P0 kernel, not dialogue/cooking spike tests.
const Kernel = preload("res://scripts/core/world_kernel.gd")

var failures: Array[String] = []

func _initialize() -> void:
    _commands()
    _replay()
    _persistence()
    _corruption()
    if failures.is_empty():
        print("SYS P0: PASS (4 groups: validation, deterministic replay, persistence, atomic rejection)")
        quit(0)
        return
    for f in failures:
        push_error(f)
    print("SYS P0: FAIL (%d assertions)" % failures.size())
    quit(1)

func check(condition: bool, reason: String) -> void:
    if not condition:
        failures.append(reason)

func cmd(id: String, fact_id: String, actor: String = "npc:samir") -> Dictionary:
    return {"id": id, "actor_id": actor, "kind": "knowledge.grant", "payload": {"fact_id": fact_id}}

func _commands() -> void:
    var world=Kernel.new(17)
    check(not world.dispatch({"id":"c1","actor_id":"person","kind":"unknown","payload":{}})["ok"],"unknown command accepted")
    check(world.dispatch({"id":"","actor_id":"person","kind":"knowledge.grant","payload":{"fact_id":"k"}})["code"]=="INVALID_ID","bad id accepted")
    check(world.dispatch({"id":"empty","actor_id":"person","kind":"knowledge.grant","payload":{}})["code"]=="INVALID_PAYLOAD","bad payload accepted")
    var first: Dictionary=world.dispatch(cmd("c1","hassan_shop_rumor"))
    check(first["ok"] and first["code"]=="APPLIED" and first["revision"]==1,"first event absent")
    check(world.dispatch(cmd("c1","hassan_shop_rumor"))==first,"identical command not idempotent")
    check(world.dispatch(cmd("c1","other_fact"))["code"]=="ID_CONFLICT","reuse conflicting command ID accepted")
    check(world.dispatch(cmd("c2","hassan_shop_rumor"))["code"]=="ALREADY_KNOWN","duplicate fact emitted twice")
    check(world.view()["sequence"]==1 and world.view()["events"].size()==1,"duplicate emitted an event")
    check(world.has_fact("hassan_shop_rumor"),"fact not canonical")
    var leaked: Array[Dictionary]=world.event_history_after(0)
    leaked[0]["payload"]["fact_id"]="tampered"
    check(world.has_fact("hassan_shop_rumor") and not world.has_fact("tampered"),"read projection can mutate truth")
    check(world.event_history_after(1).is_empty(),"event-history offset ignored")

func _replay() -> void:
    var a=Kernel.new(42)
    var b=Kernel.new(42)
    for id in ["tea","rent","person"]:
        check(a.dispatch(cmd("evt-"+id,id,"world"))==b.dispatch(cmd("evt-"+id,id,"world")),"different command reply")
    check(JSON.stringify(a.view())==JSON.stringify(b.view()),"same world/input not byte-deterministic")
    var replay=Kernel.new(1)
    check(replay.restore_snapshot(a.view()),"failed to replay full event log")
    check(JSON.stringify(replay.view())==JSON.stringify(a.view()),"replay changed canonical bytes")
    check(replay.dispatch(cmd("evt-person","person","world"))["revision"]==3,"replay applied an old command")
    check(replay.dispatch(cmd("evt-new","new","world"))["revision"]==4,"new command event not continuing sequence")

func _persistence() -> void:
    var world=Kernel.new(91)
    world.dispatch(cmd("c1","knows_match"))
    world.dispatch(cmd("c2","hassan_shop_rumor"))
    var path: String="user://nk-sys-p0.json"
    check(world.save_to_file(path),"snapshot file write failed")
    var loaded=Kernel.new(1)
    check(loaded.load_from_file(path),"snapshot file read/replay failed")
    check(JSON.stringify(loaded.view())==JSON.stringify(world.view()),"JSON roundtrip changed model")
    check(loaded.dispatch(cmd("c2","hassan_shop_rumor"))["revision"]==2,"receipt lost on reload")
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _corruption() -> void:
    var world=Kernel.new(7)
    world.dispatch(cmd("a","fact_a"))
    var before: String=JSON.stringify(world.view())
    var bad=world.view()
    bad["facts"]["injected"]=true
    check(not world.restore_snapshot(bad),"accepted tampered facts")
    check(JSON.stringify(world.view())==before,"tampering partially changed world")
    bad=world.view()
    bad["events"][0]["event_id"]="forged"
    check(not world.restore_snapshot(bad),"accepted forged event ID")
    check(JSON.stringify(world.view())==before,"forged event partially changed world")
    bad=world.view()
    bad["receipts"].clear()
    check(not world.restore_snapshot(bad),"accepted missing command receipts")
    check(JSON.stringify(world.view())==before,"missing receipts partially changed world")
    bad=world.view()
    bad["receipts"]["a"]["result"]["revision"]=1.5
    check(not world.restore_snapshot(bad),"accepted fractional event revision")
    check(JSON.stringify(world.view())==before,"fractional revision partially changed world")
    bad=world.view()
    bad["version"]=999
    check(not world.restore_snapshot(bad),"accepted future schema")
    check(JSON.stringify(world.view())==before,"schema failure partially changed world")
    bad=world.view()
    bad["world_minute"]=60
    check(not world.restore_snapshot(bad),"accepted unowned future clock state")
