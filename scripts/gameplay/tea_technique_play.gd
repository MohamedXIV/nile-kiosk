extends RefCounted
## E3 COOK-03: a pure projection, not a new experience/skill meter.
## P2/P6 is the only owner of what was heard; P3 events/items own attempts.
const FACT = "salma:tea-timing-tip"

static func progress(session: RefCounted) -> Dictionary:
    var result: Dictionary = {"phase":"unheard","heard_event_id":"","attempt_event_id":"",
        "item_id":"","grade":"","created_minute":-1}
    var social: Dictionary = session.world.social_view()
    var known: Dictionary = social["knowledge"].get("player",{}).get(FACT,{})
    if known.is_empty(): return result
    var heard: String = str(known.get("event_id",""))
    result["phase"] = "heard"
    result["heard_event_id"] = heard
    var world: Dictionary = session.world.view()
    var started: Dictionary = {}
    # Only real player preparation begun AFTER the committed tip can count.
    # Ink text/option selection alone never grants technique mastery.
    for event in world["events"]:
        if str(event["kind"]) != "cook.started" or str(event["actor_id"]) != "player":
            continue
        if str(event["event_id"]) <= heard: continue
        var request: Dictionary = event["payload"]["request"]
        if str(request.get("recipe_id","")) != "tea": continue
        started[str(request.get("job_id",""))] = str(event["event_id"])
    if started.is_empty(): return result
    result["phase"] = "attempted"
    var jobs: Array = started.values()
    jobs.sort()
    result["attempt_event_id"] = str(jobs.back())
    for item in world["cooking"]["items"].values():
        if not started.has(str(item["job_id"])): continue
        var quality: Dictionary = session.world.prepared_quality(str(item["item_id"]))
        if quality.is_empty(): continue
        var item_start: String = str(started[str(item["job_id"])])
        if item_start < str(result["attempt_event_id"]): continue
        result["attempt_event_id"] = item_start
        result["item_id"] = str(item["item_id"])
        result["grade"] = str(quality["grade"])
        result["created_minute"] = int(item["created_minute"])
        result["phase"] = "understood" if str(quality["grade"]) == "good" else "attempted"
    return result
