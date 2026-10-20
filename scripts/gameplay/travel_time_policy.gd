extends RefCounted
## Authored transport cost; the WorldKernel alone advances real world minutes.
## No scene-owned timers, duplicate spatial state or hidden time changes.
const MAX_COMMUTE_MINUTES = 120

static func load_packaged(path: String, portals: Array) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {"ok":false,"code":"MISSING_COMMUTE_POLICY"}
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if typeof(raw) != TYPE_DICTIONARY or raw.size() != 3 or raw.get("schema") != 1 or \
            typeof(raw.get("description")) != TYPE_STRING or \
            typeof(raw.get("portal_minutes")) != TYPE_DICTIONARY:
        return {"ok":false,"code":"INVALID_COMMUTE_POLICY"}
    var valid_ids: Dictionary = {}
    for portal in portals:
        valid_ids[str(portal["id"])] = true
    var durations: Dictionary = {}
    for portal_id in raw["portal_minutes"]:
        var minutes: Variant = raw["portal_minutes"][portal_id]
        if not valid_ids.has(portal_id) or typeof(minutes) != TYPE_INT or \
                minutes < 1 or minutes > MAX_COMMUTE_MINUTES:
            return {"ok":false,"code":"INVALID_COMMUTE_COST"}
        durations[portal_id] = minutes
    return {"ok":true,"durations":durations}

static func minutes_for(durations: Dictionary, portal_id: String) -> int:
    return int(durations.get(portal_id,0))

static func preflight(snapshot: Dictionary, minutes: int) -> Dictionary:
    if minutes <= 0:
        return {"ok":true,"steps":0}
    var rate: int = int(snapshot.get("minutes_per_step",1))
    var current: int = int(snapshot.get("world_minute",0))
    if bool(snapshot.get("paused",false)):
        return {"ok":false,"code":"PAUSED"}
    if rate <= 0 or minutes % rate != 0:
        return {"ok":false,"code":"COMMUTE_RATE_MISMATCH"}
    if current > 2147483647 - minutes:
        return {"ok":false,"code":"TIME_OVERFLOW"}
    if int(snapshot.get("sequence",0)) > 2147483647 - 2:
        return {"ok":false,"code":"SEQUENCE_EXHAUSTED"}
    return {"ok":true,"steps":minutes/rate}
