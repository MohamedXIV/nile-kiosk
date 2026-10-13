extends RefCounted
## Pure integer civil-clock projections. No player-day speed or fictional date.
const MINUTES_PER_DAY: int = 24 * 60
const MAX_MINUTE: int = 2147483647
const MAX_RATE: int = 64

static func at(minute: int) -> Dictionary:
    return {
        "day_index": minute / MINUTES_PER_DAY,
        "minute_of_day": minute % MINUTES_PER_DAY,
        "hour": (minute % MINUTES_PER_DAY) / 60,
        "minute": minute % 60
    }

static func advance_target(current: int, steps: int, rate: int) -> Dictionary:
    if steps < 0 or steps > MAX_MINUTE:
        return {"ok": false, "code": "INVALID_TIME"}
    if rate < 1 or rate > MAX_RATE:
        return {"ok": false, "code": "INVALID_RATE"}
    if steps > (MAX_MINUTE - current) / rate:
        return {"ok": false, "code": "TIME_OVERFLOW"}
    return {"ok": true, "target": current + steps * rate}
