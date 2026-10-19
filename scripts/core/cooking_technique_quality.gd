extends RefCounted
## Read-only P3 projection from Kernel-verified events. No clock or saved state.
## PROPOSED sensory weights; never changes inventory, money, needs or knowledge.
static func assess(item: Dictionary, recipe: Dictionary, history: Array[Dictionary]) -> Dictionary:
    var expected_actions: int = 0
    for step in recipe["steps"]:
        if step.has("technique"): expected_actions += 1
    if expected_actions == 0: return {}
    var index: int = 0
    var active_start: int = -1
    var active_minutes: int = 0
    var action_at_active: int = -1
    var previous_finish: int = -1
    var late: int = 0
    var action_late: int = 0
    var handoff: int = 0
    var interruptions: int = 0
    var actions: int = 0
    for event in history:
        var kind: String = str(event["kind"])
        if kind not in ["cook.step_begun","cook.step_resumed","cook.step_interrupted","cook.step_actioned","cook.step_finished"]:
            continue
        var request: Dictionary = event["payload"]["request"]
        if request.get("job_id","") != item["job_id"]: continue
        if index >= recipe["steps"].size(): return {}
        var step: Dictionary = recipe["steps"][index]
        var when: int = int(event["world_minute"])
        match kind:
            "cook.step_begun", "cook.step_resumed":
                if active_start >= 0: return {}
                if kind == "cook.step_begun" and previous_finish >= 0:
                    handoff = mini(20,handoff + mini(20,when - previous_finish))
                active_start = when
            "cook.step_interrupted":
                if active_start < 0: return {}
                active_minutes += when - active_start
                active_start = -1
                interruptions = mini(3,interruptions + 1)
            "cook.step_actioned":
                if active_start < 0 or action_at_active >= 0 or not step.has("technique"): return {}
                active_minutes += when - active_start
                active_start = when
                action_at_active = active_minutes
                action_late = mini(20,action_late + mini(20,maxi(0,active_minutes - int(step["work_minutes"]))))
                actions += 1
            "cook.step_finished":
                if active_start < 0: return {}
                active_minutes += when - active_start
                var overtime: int = active_minutes - int(step["work_minutes"])
                if step.has("technique"):
                    if action_at_active < 0: return {}
                    overtime = active_minutes - action_at_active - int(step["technique"]["finish_minutes"])
                late = mini(20,late + mini(20,maxi(0,overtime)))
                previous_finish = when
                index += 1
                active_start = -1
                active_minutes = 0
                action_at_active = -1
    if index != recipe["steps"].size() or actions != expected_actions or previous_finish != int(item["created_minute"]):
        return {}
    var score: int = maxi(25,100 - (late + action_late) * 8 - handoff * 2 - interruptions * 10)
    return {"item_id":item["item_id"],"grade":"good" if score >= 85 else ("okay" if score >= 60 else "rough"),
        "score":score,"late_minutes":late,"action_late_minutes":action_late,
        "handoff_minutes":handoff,"interruptions":interruptions,"technique_actions":actions,
        "source_event_id":item["event_id"]}
