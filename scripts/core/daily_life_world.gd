extends RefCounted
## E1/P0: world-owned workday and sleeping state. No scene-owned phase or clock.
const Clock = preload("res://scripts/core/world_clock.gd")
var policy: Dictionary = {}
var open: bool = false
var last_wake_day: int = -1
var sleep_count: int = 0

static func owns(kind: String) -> bool:
    return kind in ["life.configure", "life.activities.configure", "life.activities.extend", "life.activity", "life.open", "life.close", "life.sleep"]

static func event_kind(kind: String) -> String:
    match kind:
        "life.configure": return "life.configured"
        "life.activities.configure": return "life.activities_configured"
        "life.activities.extend": return "life.activities_extended"
        "life.activity": return "life.activity_done"
        "life.open": return "life.opened"
        "life.close": return "life.closed"
        "life.sleep": return "life.slept"
    return ""

static func command_kind(kind: String) -> String:
    match kind:
        "life.configured": return "life.configure"
        "life.activities_configured": return "life.activities.configure"
        "life.activities_extended": return "life.activities.extend"
        "life.activity_done": return "life.activity"
        "life.opened": return "life.open"
        "life.closed": return "life.close"
        "life.slept": return "life.sleep"
    return ""

static func fail(code: String) -> Dictionary:
    return {"ok":false,"code":code}

func snapshot() -> Dictionary:
    return {"policy":policy.duplicate(true),"open":open,
        "last_wake_day":last_wake_day,"sleep_count":sleep_count}

func is_open(venue_id: String) -> bool:
    return policy.is_empty() or str(policy["venue_id"]) != venue_id or open

func blocked_venue() -> String:
    return str(policy["venue_id"]) if not policy.is_empty() and not open else ""

func plan(kind: String, payload: Dictionary, actor: String,
          society: RefCounted, spatial: RefCounted, service: RefCounted,
          housing: RefCounted, minute: int) -> Dictionary:
    if kind == "life.configure":
        if actor != "system:director" or payload.size() != 5:
            return fail("INVALID_AUTHOR_OR_POLICY")
        for key in ["venue_id","kiosk_room_id","home_room_id","wake_minute","minimum_sleep_minutes"]:
            if not payload.has(key): return fail("INVALID_POLICY")
        for key in ["venue_id","kiosk_room_id","home_room_id"]:
            if typeof(payload[key]) != TYPE_STRING or (payload[key] as String).is_empty():
                return fail("INVALID_POLICY")
        if typeof(payload["wake_minute"]) != TYPE_INT or int(payload["wake_minute"]) < 0 or int(payload["wake_minute"]) >= Clock.MINUTES_PER_DAY:
            return fail("INVALID_WAKE")
        if typeof(payload["minimum_sleep_minutes"]) != TYPE_INT or int(payload["minimum_sleep_minutes"]) < 1 or int(payload["minimum_sleep_minutes"]) > Clock.MINUTES_PER_DAY:
            return fail("INVALID_SLEEP")
        if not policy.is_empty(): return fail("ALREADY_CONFIGURED")
        if not service.venues.has(payload["venue_id"]) or service.venues[payload["venue_id"]]["location_id"] != payload["kiosk_room_id"]:
            return fail("UNKNOWN_VENUE")
        if not spatial.initialized():
            # C0 authoring may configure life after C0 but before navigation:
            # this is intentionally forbidden; use WorldSession.configure_life after graph.
            return fail("SPATIAL_NOT_INITIALIZED")
        var rooms: Dictionary = {}
        for room in spatial.graph["rooms"]: rooms[room["id"]] = true
        if not rooms.has(payload["home_room_id"]) or not rooms.has(payload["kiosk_room_id"]) or payload["home_room_id"] == payload["kiosk_room_id"]:
            return fail("INVALID_ROOMS")
        return {"ok":true,"effect":{"policy":payload.duplicate(true)}}
    if kind in ["life.activities.configure", "life.activities.extend"]:
        if actor != "system:director" or payload.size() != 1 or not payload.has("activities"):
            return fail("INVALID_ACTIVITY_POLICY")
        if policy.is_empty(): return fail("LIFE_NOT_CONFIGURED")
        if kind == "life.activities.configure" and policy.has("activities"):
            return fail("ACTIVITIES_ALREADY_CONFIGURED")
        if kind == "life.activities.extend" and not policy.has("activities"):
            return fail("ACTIVITIES_NOT_CONFIGURED")
        if typeof(payload["activities"]) != TYPE_ARRAY or payload["activities"].is_empty() or payload["activities"].size() > 8:
            return fail("INVALID_ACTIVITY_POLICY")
        if payload["activities"].size() + (policy.get("activities",[]).size() if kind == "life.activities.extend" else 0) > 8:
            return fail("TOO_MANY_ACTIVITIES")
        var seen: Dictionary = {}
        if kind == "life.activities.extend":
            for previous in policy["activities"]: seen[previous["id"]] = true
        for activity in payload["activities"]:
            if typeof(activity) != TYPE_DICTIONARY or activity.size() not in [7,9]:
                return fail("INVALID_ACTIVITY_POLICY")
            for key in ["id","room_id","x","y","radius","minutes","requires_closed"]:
                if not activity.has(key): return fail("INVALID_ACTIVITY_POLICY")
            if typeof(activity["id"]) != TYPE_STRING or (activity["id"] as String).is_empty() or (activity["id"] as String).length() > 64 or seen.has(activity["id"]):
                return fail("INVALID_ACTIVITY_POLICY")
            seen[activity["id"]] = true
            if activity.size() == 9:
                if not activity.has("requires_object_type") or not activity.has("requires_slot_id"):
                    return fail("INVALID_ACTIVITY_POLICY")
                if typeof(activity["requires_object_type"]) != TYPE_STRING or typeof(activity["requires_slot_id"]) != TYPE_STRING:
                    return fail("INVALID_ACTIVITY_POLICY")
                if (activity["requires_object_type"] as String).is_empty() or (activity["requires_slot_id"] as String).is_empty():
                    return fail("INVALID_ACTIVITY_POLICY")
                if not housing.types.has(activity["requires_object_type"]) or "listen" not in housing.types[activity["requires_object_type"]]["actions"]:
                    return fail("UNKNOWN_ACTIVITY_OBJECT_TYPE")
                if activity["room_id"] != policy["home_room_id"]:
                    return fail("INVALID_ACTIVITY_ROOM")
            var found: Dictionary = {}
            for room in spatial.graph["rooms"]:
                if room["id"] == activity["room_id"]: found = room
            if found.is_empty() or activity["room_id"] not in [policy["home_room_id"],policy["kiosk_room_id"]]:
                return fail("INVALID_ACTIVITY_ROOM")
            for field in ["x","y","radius","minutes"]:
                if typeof(activity[field]) != TYPE_INT: return fail("INVALID_ACTIVITY_POLICY")
            if int(activity["x"]) < 0 or int(activity["x"]) > int(found["width"]) or int(activity["y"]) < 0 or int(activity["y"]) > int(found["height"]):
                return fail("INVALID_ACTIVITY_POSITION")
            if int(activity["radius"]) < 1 or int(activity["radius"]) > 50 or int(activity["minutes"]) < 1 or int(activity["minutes"]) > 60 or typeof(activity["requires_closed"]) != TYPE_BOOL:
                return fail("INVALID_ACTIVITY_POLICY")
        var all_activities: Array = policy.get("activities",[]).duplicate(true) if kind == "life.activities.extend" else []
        all_activities.append_array(payload["activities"].duplicate(true))
        return {"ok":true,"effect":{"activities":all_activities}}
    if policy.is_empty(): return fail("LIFE_NOT_CONFIGURED")
    if actor != "player": return fail("INVALID_PLAYER_ACTION")
    if kind == "life.activity":
        if payload.size() != 1 or typeof(payload.get("activity_id")) != TYPE_STRING:
            return fail("INVALID_ACTIVITY")
        for activity in policy.get("activities",[]):
            if activity["id"] != payload["activity_id"]: continue
            if not spatial.initialized() or spatial.player["room_id"] != activity["room_id"]:
                return fail("WRONG_ACTIVITY_ROOM")
            var dx: int = int(spatial.player["x"]) - int(activity["x"])
            var dy: int = int(spatial.player["y"]) - int(activity["y"])
            if dx*dx + dy*dy > int(activity["radius"]) * int(activity["radius"]):
                return fail("TOO_FAR")
            if bool(activity["requires_closed"]) and open: return fail("CLOSE_KIOSK_FIRST")
            if int(activity["minutes"]) > Clock.MAX_MINUTE - minute:
                return fail("TIME_OVERFLOW")
            var effect: Dictionary = {"to_minute":minute+int(activity["minutes"]),"activity_id":str(activity["id"])}
            if activity.has("requires_object_type"):
                var ids: Array = housing.objects.keys()
                ids.sort()
                var chosen: String = ""
                for obj_id in ids:
                    var obj: Dictionary = housing.objects[obj_id]
                    if obj["type_id"] == activity["requires_object_type"] and obj["unit_id"] == activity["room_id"] and obj["slot_id"] == activity["requires_slot_id"] and housing.allowed(obj["unit_id"]):
                        chosen = str(obj_id)
                        break
                if chosen.is_empty(): return fail("REQUIRED_OBJECT_NOT_PLACED")
                var use_request: Dictionary = {"object_id":chosen,"action_id":"listen"}
                var use_result: Dictionary = housing.plan("home.object.interact",use_request,actor,society, null, {},minute)
                if not use_result.get("ok",false): return use_result
                effect["object_use"] = use_request
            return {"ok":true,"effect":effect}
        return fail("UNKNOWN_ACTIVITY")
    if not payload.is_empty(): return fail("INVALID_PLAYER_ACTION")
    var location: String = str(spatial.player["room_id"]) if spatial.initialized() else society.player_location
    match kind:
        "life.open":
            if location != policy["kiosk_room_id"]: return fail("NOT_AT_KIOSK")
            if open: return fail("ALREADY_OPEN")
            return {"ok":true,"effect":{"open":true}}
        "life.close":
            if location != policy["kiosk_room_id"]: return fail("NOT_AT_KIOSK")
            if not open: return fail("ALREADY_CLOSED")
            return {"ok":true,"effect":{"open":false}}
        "life.sleep":
            if location != policy["home_room_id"]: return fail("NOT_AT_HOME")
            if open: return fail("CLOSE_KIOSK_FIRST")
            var today: int = minute / Clock.MINUTES_PER_DAY
            if last_wake_day == today: return fail("ALREADY_SLEPT_TODAY")
            var wake: int = (today+1)*Clock.MINUTES_PER_DAY + int(policy["wake_minute"])
            if wake - minute < int(policy["minimum_sleep_minutes"]):
                wake += Clock.MINUTES_PER_DAY
            if wake > Clock.MAX_MINUTE: return fail("TIME_OVERFLOW")
            return {"ok":true,"effect":{"to_minute":wake,"wake_day":wake / Clock.MINUTES_PER_DAY}}
    return fail("UNKNOWN_LIFE_ACTION")

func apply_command(kind: String, effect: Dictionary) -> void:
    match kind:
        "life.configure": policy = effect["policy"].duplicate(true)
        "life.activities.configure", "life.activities.extend": policy["activities"] = effect["activities"].duplicate(true)
        "life.open", "life.close": open = bool(effect["open"])
        "life.sleep":
            last_wake_day = int(effect["wake_day"])
            sleep_count += 1
