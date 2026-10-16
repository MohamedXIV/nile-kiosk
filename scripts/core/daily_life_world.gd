extends RefCounted
## E1/P0: world-owned workday and sleeping state. No scene-owned phase or clock.
const Clock = preload("res://scripts/core/world_clock.gd")
var policy: Dictionary = {}
var open: bool = false
var last_wake_day: int = -1
var sleep_count: int = 0

static func owns(kind: String) -> bool:
    return kind in ["life.configure", "life.open", "life.close", "life.sleep"]

static func event_kind(kind: String) -> String:
    match kind:
        "life.configure": return "life.configured"
        "life.open": return "life.opened"
        "life.close": return "life.closed"
        "life.sleep": return "life.slept"
    return ""

static func command_kind(kind: String) -> String:
    match kind:
        "life.configured": return "life.configure"
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
          minute: int) -> Dictionary:
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
    if policy.is_empty(): return fail("LIFE_NOT_CONFIGURED")
    if actor != "player" or not payload.is_empty(): return fail("INVALID_PLAYER_ACTION")
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
        "life.open", "life.close": open = bool(effect["open"])
        "life.sleep":
            last_wake_day = int(effect["wake_day"])
            sleep_count += 1
