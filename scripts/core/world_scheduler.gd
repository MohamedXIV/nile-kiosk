extends RefCounted
## Bounded, deterministic, snapshot-independent scheduler planning.
const MAX_FIRINGS_PER_ADVANCE: int = 20000
const MAX_REPEAT: int = 2147483647

static func _before(a: Dictionary, b: Dictionary) -> bool:
    if a["due_minute"] != b["due_minute"]:
        return a["due_minute"] < b["due_minute"]
    if a["priority"] != b["priority"]:
        return a["priority"] < b["priority"]
    if a["created_sequence"] != b["created_sequence"]:
        return a["created_sequence"] < b["created_sequence"]
    return a["job_id"] < b["job_id"]

static func plan(jobs: Dictionary, limit: int, advance_sequence: int) -> Dictionary:
    var working: Dictionary = jobs.duplicate(true)
    var fires: Array = []
    while true:
        var earliest: Dictionary = {}
        for job_id in working:
            var candidate: Dictionary = working[job_id]
            if candidate["status"] == "pending" and candidate["due_minute"] <= limit:
                if earliest.is_empty() or _before(candidate, earliest):
                    earliest = candidate
        if earliest.is_empty():
            return {"ok": true, "fires": fires}
        if fires.size() >= MAX_FIRINGS_PER_ADVANCE:
            return {"ok": false, "code": "FIRING_LIMIT"}
        var index: int = fires.size() + 1
        var fire_id: String = "fire:%012d:%06d" % [advance_sequence, index]
        fires.append({
            "fire_id": fire_id, "job_id": earliest["job_id"],
            "world_minute": earliest["due_minute"],
            "priority": earliest["priority"], "topic": earliest["topic"],
            "data": earliest["data"].duplicate(true),
            "created_sequence": earliest["created_sequence"],
            "source_actor_id": earliest["source_actor_id"],
            "source_command_id": earliest["source_command_id"],
            "occurrence": earliest["execution_count"] + 1
        })
        var next: Dictionary = earliest.duplicate(true)
        next["execution_count"] += 1
        next["last_fire_id"] = fire_id
        var interval: int = next["every_minutes"]
        if interval == 0 or interval > MAX_REPEAT - next["due_minute"]:
            next["status"] = "completed"
        else:
            next["due_minute"] += interval
        working[next["job_id"]] = next
